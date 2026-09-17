defmodule Lab.Contact do
  require Logger

  alias Lab.{ContactMessage, ContactRateLimiter, Mailer}
  import Swoosh.Email

  def send_message(attrs, rate_key) do
    changeset = ContactMessage.changeset(attrs)

    cond do
      not ContactRateLimiter.allow?(rate_key) ->
        {:error, :rate_limited}

      not changeset.valid? ->
        {:error, changeset}

      Ecto.Changeset.get_field(changeset, :website) not in [nil, ""] ->
        {:ok, :ignored}

      true ->
        deliver(changeset)
    end
  end

  defp deliver(changeset) do
    config = Application.fetch_env!(:lab, __MODULE__)
    name = Ecto.Changeset.get_field(changeset, :name)
    address = Ecto.Changeset.get_field(changeset, :email)
    subject = Ecto.Changeset.get_field(changeset, :subject)
    message = Ecto.Changeset.get_field(changeset, :message)

    email =
      new()
      |> from(config[:from])
      |> to(config[:to])
      |> reply_to({name, address})
      |> subject("Contato: " <> subject)
      |> text_body("Nome: #{name}\nE-mail: #{address}\n\n#{message}")

    case Mailer.deliver(email) do
      {:ok, _} ->
        {:ok, :sent}

      {:error, reason} ->
        Logger.error("Contact email delivery failed: #{inspect(reason)}")
        {:error, :delivery_failed}
    end
  end
end
