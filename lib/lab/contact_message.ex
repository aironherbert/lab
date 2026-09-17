defmodule Lab.ContactMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string
    field :email, :string
    field :subject, :string
    field :message, :string
    field :website, :string
  end

  def changeset(message \\ %__MODULE__{}, attrs) do
    message
    |> cast(attrs, [:name, :email, :subject, :message, :website])
    |> validate_required([:name, :email, :subject, :message], message: "é obrigatório")
    |> validate_length(:name, max: 120, message: "deve ter no máximo %{count} caracteres")
    |> validate_length(:email, max: 254, message: "deve ter no máximo %{count} caracteres")
    |> validate_length(:subject, max: 150, message: "deve ter no máximo %{count} caracteres")
    |> validate_length(:message, max: 5_000, message: "deve ter no máximo %{count} caracteres")
    |> validate_format(:name, ~r/\A[^\r\n]+\z/, message: "não é válido")
    |> validate_format(:subject, ~r/\A[^\r\n]+\z/, message: "não é válido")
    |> validate_format(:email, ~r/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/, message: "não é válido")
  end
end
