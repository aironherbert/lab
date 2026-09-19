# Lab

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Formulário de contato

A página de exemplo está em `/contato`. Em desenvolvimento, os e-mails enviados
ficam disponíveis em `/dev/mailbox`.

Para usar o formulário em outro site, envie JSON para `POST /api/contact`:

```json
{
  "name": "Ana",
  "email": "ana@example.com",
  "subject": "Orçamento",
  "message": "Olá, gostaria de conversar."
}
```

A API responde `202` quando aceita a mensagem, `422` para campos inválidos,
`429` ao exceder cinco tentativas em dez minutos por IP e `503` se a entrega
falhar. O campo opcional `website` deve ficar vazio; ele funciona como
proteção contra robôs. Não envie o destinatário nem a chave pela API.

Em produção, configure `CONTACT_FROM_EMAIL` (remetente autorizado no provedor),
`CONTACT_TO_EMAIL` (destinatário fixo) e `MAIL_PROVIDER` como `resend` ou
`mailgun`. Use `RESEND_API_KEY` para Resend, ou `MAILGUN_API_KEY` e
`MAILGUN_DOMAIN` para Mailgun. Para chamadas de outro domínio feitas pelo
navegador, configure `CONTACT_ALLOWED_ORIGINS` com as origens exatas separadas
por vírgula, por exemplo `https://site.example,https://www.site.example`.
As credenciais devem ser definidas no ambiente do servidor, nunca no JavaScript
nem em arquivos versionados.

### Fly.io sem banco de dados

O formulário não usa Postgres. Em produção, `Lab.Repo` só inicia quando
`DATABASE_URL` está configurada; por isso, é possível publicar apenas a
aplicação com `fly launch --no-deploy --no-db --ha=false`. Escolha uma única
máquina pequena e confira o custo da região no painel do Fly. Antes do primeiro `fly deploy`,
configure os secrets do formulário, `PHX_HOST` e `PHX_SERVER=true`, e confira
que a porta interna do `fly.toml` é `4000`. Se o Fly gerar um comando de
migração em `[deploy]`, remova-o enquanto a aplicação não tiver banco.

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
