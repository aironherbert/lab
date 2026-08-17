defmodule GitHubRepoScript do
  @api_url "https://api.github.com"

  def run(argv) do
    {owner, repo} = repository!(argv)
    jwt = Lab.GitHub.Auth.generate_jwt()

    app = request!(:get, "/app", jwt)
    IO.puts("JWT válido para a GitHub App: #{app["name"] || app["slug"]}")

    installation = request!(:get, "/repos/#{owner}/#{repo}/installation", jwt)
    IO.puts("Instalação encontrada: #{installation["id"]}")

    token_response =
      request!(
        :post,
        "/app/installations/#{installation["id"]}/access_tokens",
        jwt,
        json: %{}
      )

    repository = request!(:get, "/repos/#{owner}/#{repo}", token_response["token"])

    IO.puts("\nInformações do repositório:\n")

    repository
    |> Map.take([
      "full_name",
      "description",
      "private",
      "default_branch",
      "language",
      "stargazers_count",
      "forks_count",
      "open_issues_count",
      "html_url"
    ])
    |> Jason.encode!(pretty: true)
    |> IO.puts()
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

  defp repository!([full_name]) do
    case String.split(full_name, "/", parts: 2) do
      [owner, repo] when owner != "" and repo != "" -> {owner, repo}
      _ -> usage_error!()
    end
  end

  defp repository!([owner, repo]) when owner != "" and repo != "", do: {owner, repo}

  defp repository!([]) do
    case System.get_env("GITHUB_REPOSITORY") do
      nil -> usage_error!()
      full_name -> repository!([full_name])
    end
  end

  defp repository!(_argv), do: usage_error!()

  defp usage_error! do
    raise """
    Informe o repositório como owner/repo:
      mix run scripts/github_repo.exs -- owner/repo

    Ou configure GITHUB_REPOSITORY=owner/repo.
    """
  end
end

GitHubRepoScript.run(System.argv())
