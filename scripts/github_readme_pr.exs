defmodule GitHubReadmePrScript do
  @api_url "https://api.github.com"

  def run(argv) do
    with config <- arguments!(argv),
         jwt <- generate_jwt!(),
         token <- installation_token!(config.installation_id, jwt),
         repository <- repository_context!(config, token),
         branch <- new_branch_name(),
         :ok <- create_branch!(repository, branch, token),
         commit_sha <- update_readme!(repository, branch, config.text, token),
         :ok <- wait_for_branch!(repository, branch, commit_sha, token),
         pull_request <- open_pull_request!(repository, branch, token) do
      IO.puts("\nPull request aberto com sucesso: #{pull_request["html_url"]}")
    end
  end

  defp generate_jwt! do
    log_step("Gerando o JWT da GitHub App")
    Lab.GitHub.Auth.generate_jwt()
  end

  defp installation_token!(installation_id, jwt) do
    log_step("Obtendo o installation access token")

    response =
      request!(
        :post,
        "/app/installations/#{installation_id}/access_tokens",
        jwt,
        json: %{}
      )

    response["token"]
  end

  defp repository_context!(config, token) do
    log_step("Consultando o repositório e sua branch padrão")

    repository = request!(:get, repo_path(config, ""), token)
    base_branch = repository["default_branch"]

    base_ref =
      request!(
        :get,
        repo_path(config, "/git/ref/heads/#{encode_path_segment(base_branch)}"),
        token
      )

    %{
      owner: config.owner,
      repo: config.repo,
      base_branch: base_branch,
      base_sha: get_in(base_ref, ["object", "sha"])
    }
  end

  defp create_branch!(repository, branch, token) do
    log_step("Criando a branch #{branch} a partir de #{repository.base_branch}")

    request!(:post, repo_path(repository, "/git/refs"), token,
      json: %{
        "ref" => "refs/heads/#{branch}",
        "sha" => repository.base_sha
      }
    )

    wait_for_branch!(repository, branch, repository.base_sha, token)
  end

  defp update_readme!(repository, branch, text, token) do
    log_step("Lendo e atualizando o README.md")

    readme =
      request!(:get, repo_path(repository, "/contents/README.md"), token,
        params: [ref: repository.base_branch]
      )

    current_content = decode_file_content!(readme)
    updated_content = String.trim_trailing(current_content) <> "\n\n" <> text <> "\n"

    update =
      request!(:put, repo_path(repository, "/contents/README.md"), token,
        json: %{
          "message" => commit_message(),
          "content" => Base.encode64(updated_content),
          "sha" => readme["sha"],
          "branch" => branch
        }
      )

    get_in(update, ["commit", "sha"])
  end

  defp open_pull_request!(repository, branch, token) do
    log_step("Abrindo o pull request para #{repository.base_branch}")

    request!(:post, repo_path(repository, "/pulls"), token,
      json: %{
        "title" => System.get_env("GITHUB_PR_TITLE", commit_message()),
        "body" => "Atualização automática do README criada pela GitHub App.",
        "head" => branch,
        "base" => repository.base_branch
      }
    )
  end

  defp decode_file_content!(readme) do
    readme["content"]
    |> String.replace(~r/\s/, "")
    |> Base.decode64!()
  end

  defp commit_message do
    System.get_env("GITHUB_COMMIT_MESSAGE", "docs: update README")
  end

  defp new_branch_name do
    timestamp = System.system_time(:second)
    suffix = System.unique_integer([:positive])
    "codex/update-readme-#{timestamp}-#{suffix}"
  end

  defp wait_for_branch!(repository, branch, expected_sha, token, attempt \\ 1) do
    if attempt == 1 do
      log_step("Aguardando o commit #{String.slice(expected_sha, 0, 7)} ficar disponível")
    end

    path = repo_path(repository, "/git/ref/heads/#{encode_path_segment(branch)}")
    response = request!(:get, path, token, accepted_statuses: [404])

    case response do
      %{"object" => %{"sha" => ^expected_sha}} ->
        :ok

      _response when attempt < 11 ->
        IO.puts(:stderr, "Aguardando a branch #{branch} refletir o commit... (#{attempt}/10)")
        Process.sleep(500)
        wait_for_branch!(repository, branch, expected_sha, token, attempt + 1)

      _response ->
        raise "O commit #{expected_sha} não ficou disponível na branch #{branch} após 5 segundos"
    end
  end

  defp request!(method, path, token, options \\ [], attempt \\ 1) do
    {accepted_statuses, request_options} = Keyword.pop(options, :accepted_statuses, [])

    request_options =
      Keyword.merge(request_options,
        method: method,
        url: @api_url <> path,
        headers: [
          {"accept", "application/vnd.github+json"},
          {"authorization", "Bearer #{token}"},
          {"x-github-api-version", System.get_env("GITHUB_API_VERSION", "2022-11-28")}
        ]
      )

    case Req.request(request_options) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        body

      {:ok, %{status: status}} when status in [502, 503, 504] and attempt < 4 ->
        wait_ms = attempt * 1_000

        IO.puts(
          :stderr,
          "GitHub respondeu com HTTP #{status} em #{method |> to_string() |> String.upcase()} #{path}. " <>
            "Nova tentativa #{attempt + 1}/4 em #{wait_ms}ms..."
        )

        Process.sleep(wait_ms)
        request!(method, path, token, options, attempt + 1)

      {:ok, %{status: status, body: body}} ->
        if status in accepted_statuses do
          %{"status" => status, "body" => body}
        else
          message = if is_map(body), do: body["message"], else: inspect(body)

          raise "GitHub respondeu com HTTP #{status} em #{method |> to_string() |> String.upcase()} #{path}: #{message}"
        end

      {:error, exception} ->
        raise "Falha ao acessar o GitHub: #{Exception.message(exception)}"
    end
  end

  defp arguments!([text]) do
    with installation_id when is_binary(installation_id) <-
           System.get_env("GITHUB_APP_INSTALLATION_ID"),
         true <- installation_id =~ ~r/^\d+$/,
         repository when is_binary(repository) <- System.get_env("GITHUB_REPOSITORY"),
         [owner, repo] when owner != "" and repo != "" <- String.split(repository, "/", parts: 2),
         true <- String.trim(text) != "" do
      %{installation_id: installation_id, owner: owner, repo: repo, text: text}
    else
      _ -> usage_error!()
    end
  end

  defp arguments!([]) do
    case System.get_env("README_UPDATE_TEXT") do
      text when is_binary(text) -> arguments!([text])
      nil -> usage_error!()
    end
  end

  defp arguments!(_argv), do: usage_error!()

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)

  defp repo_path(repository, suffix) do
    "/repos/#{repository.owner}/#{repository.repo}#{suffix}"
  end

  defp log_step(message), do: IO.puts("\n→ #{message}...")

  defp usage_error! do
    raise """
    Informe o installation ID, o repositório e o texto a acrescentar:
      export GITHUB_APP_INSTALLATION_ID=INSTALLATION_ID
      export GITHUB_REPOSITORY=owner/repo
      mix run scripts/github_readme_pr.exs -- "Texto"

    Ou configure GITHUB_APP_INSTALLATION_ID, GITHUB_REPOSITORY e README_UPDATE_TEXT.
    """
  end
end

GitHubReadmePrScript.run(System.argv())
