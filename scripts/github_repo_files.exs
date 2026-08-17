defmodule GitHubRepoFilesScript do
  @api_url "https://api.github.com"

  def run(argv) do
    {installation_id, owner, repo} = arguments!(argv)
    jwt = Lab.GitHub.Auth.generate_jwt()

    %{"token" => installation_token} =
      request!(
        :post,
        "/app/installations/#{installation_id}/access_tokens",
        jwt,
        json: %{}
      )

    repository = request!(:get, "/repos/#{owner}/#{repo}", installation_token)
    default_branch = repository["default_branch"]

    commit =
      request!(
        :get,
        "/repos/#{owner}/#{repo}/commits/#{encode_path_segment(default_branch)}",
        installation_token
      )

    tree_sha = get_in(commit, ["commit", "tree", "sha"])

    tree =
      request!(
        :get,
        "/repos/#{owner}/#{repo}/git/trees/#{tree_sha}",
        installation_token,
        params: [recursive: "1"]
      )

    files =
      tree["tree"]
      |> Enum.filter(&(&1["type"] == "blob"))
      |> Enum.map(&Map.take(&1, ["path", "size", "sha", "url"]))

    result = %{
      "repository" => repository["full_name"],
      "branch" => default_branch,
      "total_files" => length(files),
      "truncated" => tree["truncated"],
      "files" => files
    }

    IO.puts(Jason.encode!(result, pretty: true))

    if tree["truncated"] do
      IO.puts(:stderr, "Aviso: o GitHub truncou a árvore; a lista não contém todos os arquivos.")
    end
  end

  defp request!(method, path, token, options \\ []) do
    options =
      Keyword.merge(options,
        method: method,
        url: @api_url <> path,
        headers: [
          {"accept", "application/vnd.github+json"},
          {"authorization", "Bearer #{token}"},
          {"x-github-api-version", System.get_env("GITHUB_API_VERSION", "2022-11-28")}
        ]
      )

    case Req.request(options) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        body

      {:ok, %{status: status, body: body}} ->
        message = if is_map(body), do: body["message"], else: inspect(body)
        raise "GitHub respondeu com HTTP #{status}: #{message}"

      {:error, exception} ->
        raise "Falha ao acessar o GitHub: #{Exception.message(exception)}"
    end
  end

  defp arguments!([installation_id, full_name]) do
    with true <- installation_id =~ ~r/^\d+$/,
         [owner, repo] when owner != "" and repo != "" <-
           String.split(full_name, "/", parts: 2) do
      {installation_id, owner, repo}
    else
      _ -> usage_error!()
    end
  end

  defp arguments!([]) do
    installation_id = System.get_env("GITHUB_APP_INSTALLATION_ID")
    repository = System.get_env("GITHUB_REPOSITORY")

    if installation_id && repository do
      arguments!([installation_id, repository])
    else
      usage_error!()
    end
  end

  defp arguments!(_argv), do: usage_error!()

  defp encode_path_segment(value) do
    URI.encode(value, &URI.char_unreserved?/1)
  end

  defp usage_error! do
    raise """
    Informe o installation ID e o repositório:
      mix run scripts/github_repo_files.exs -- INSTALLATION_ID owner/repo

    Ou configure GITHUB_APP_INSTALLATION_ID e GITHUB_REPOSITORY.
    """
  end
end

GitHubRepoFilesScript.run(System.argv())
