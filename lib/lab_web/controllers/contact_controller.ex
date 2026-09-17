defmodule LabWeb.ContactController do
  use LabWeb, :controller

  alias Lab.Contact

  def create(conn, params) do
    rate_key = {:api, conn.remote_ip}

    case Contact.send_message(params, rate_key) do
      {:ok, _} ->
        conn |> put_status(:accepted) |> json(%{status: "accepted"})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, &LabWeb.CoreComponents.translate_error/1)

        conn |> put_status(:unprocessable_entity) |> json(%{errors: errors})

      {:error, :rate_limited} ->
        conn
        |> put_resp_header("retry-after", "600")
        |> put_status(:too_many_requests)
        |> json(%{error: "rate_limited"})

      {:error, :delivery_failed} ->
        conn |> put_status(:service_unavailable) |> json(%{error: "delivery_failed"})
    end
  end
end
