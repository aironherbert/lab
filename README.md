# Lab

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Testar a autenticação da GitHub App

Configure a GitHub App e indique um repositório no qual ela esteja instalada:

```bash
export GITHUB_APP_CLIENT_ID="seu-client-id"
export GITHUB_APP_PRIVATE_KEY_PATH="/caminho/para/github-app.pem"
mix run scripts/github_repo.exs -- owner/repo
```

O script valida o JWT, cria um installation access token e exibe informações do
repositório. A GitHub App precisa estar instalada no repositório e possuir ao
menos a permissão `Metadata: read`.

Se você já conhece o installation ID, pode listar recursivamente os arquivos da
branch padrão:

```bash
mix run scripts/github_repo_files.exs -- INSTALLATION_ID owner/repo
```

Também é possível informar `GITHUB_APP_INSTALLATION_ID` e `GITHUB_REPOSITORY`
como variáveis de ambiente e executar o script sem argumentos.

Para acrescentar um texto ao `README.md` em uma nova branch e abrir um pull
request:

```bash
mix run scripts/github_readme_pr.exs -- INSTALLATION_ID owner/repo \
  "Texto acrescentado ao README"
```

A GitHub App precisa das permissões de repositório `Contents: read and write` e
`Pull requests: read and write`.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
