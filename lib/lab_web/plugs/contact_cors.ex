defmodule LabWeb.Plugs.ContactCors do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    allowed_origins = Application.get_env(:lab, :contact_allowed_origins, [])

    case get_req_header(conn, "origin") do
      [] ->
        conn

      [origin] ->
        if origin in allowed_origins do
          conn
          |> put_resp_header("access-control-allow-origin", origin)
          |> put_resp_header("vary", "Origin")
          |> maybe_preflight()
        else
          conn |> send_resp(:forbidden, "Origin not allowed") |> halt()
        end
    end
  end

  defp maybe_preflight(%{method: "OPTIONS"} = conn) do
    conn
    |> put_resp_header("access-control-allow-methods", "POST, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "content-type")
    |> send_resp(:no_content, "")
    |> halt()
  end

  defp maybe_preflight(conn), do: conn
end
