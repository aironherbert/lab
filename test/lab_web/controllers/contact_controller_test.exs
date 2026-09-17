defmodule LabWeb.ContactControllerTest do
  use LabWeb.ConnCase, async: false

  @valid_params %{
    "name" => "Ana",
    "email" => "ana@example.com",
    "subject" => "Orcamento",
    "message" => "Gostaria de conversar."
  }

  test "accepts a message and uses the configured destination", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/contact", Jason.encode!(Map.put(@valid_params, "to", "attacker@example.com")))

    assert json_response(conn, 202) == %{"status" => "accepted"}
    assert_receive {:email, email}
    assert email.to == [{"", "destino@example.test"}]
    assert email.from == {"", "contato@example.test"}
    assert email.reply_to == {"Ana", "ana@example.com"}
    assert email.text_body =~ "Gostaria de conversar."
  end

  test "rejects invalid input without sending", %{conn: conn} do
    conn = post(conn, "/api/contact", Map.put(@valid_params, "email", "bad\naddress@example.com"))

    assert %{"errors" => %{"email" => [_]}} = json_response(conn, 422)
    refute_receive {:email, _}
  end

  test "interpolates length errors", %{conn: conn} do
    conn =
      post(conn, "/api/contact", Map.put(@valid_params, "subject", String.duplicate("a", 151)))

    assert %{"errors" => %{"subject" => ["deve ter no máximo 150 caracteres"]}} =
             json_response(conn, 422)
  end

  test "silently accepts the honeypot without sending", %{conn: conn} do
    conn = post(conn, "/api/contact", Map.put(@valid_params, "website", "https://spam.test"))

    assert json_response(conn, 202) == %{"status" => "accepted"}
    refute_receive {:email, _}
  end

  test "limits repeated requests from one IP", %{conn: conn} do
    conn = %{conn | remote_ip: {192, 0, 2, 60}}

    for _ <- 1..5 do
      assert conn |> post("/api/contact", @valid_params) |> json_response(202)
    end

    limited = post(conn, "/api/contact", @valid_params)
    assert json_response(limited, 429) == %{"error" => "rate_limited"}
    assert get_resp_header(limited, "retry-after") == ["600"]
  end

  test "allows configured browser origins and rejects others", %{conn: conn} do
    previous_origins = Application.get_env(:lab, :contact_allowed_origins, [])
    Application.put_env(:lab, :contact_allowed_origins, ["https://site.example"])

    on_exit(fn -> Application.put_env(:lab, :contact_allowed_origins, previous_origins) end)

    preflight =
      conn
      |> put_req_header("origin", "https://site.example")
      |> options("/api/contact")

    assert response(preflight, 204) == ""
    assert get_resp_header(preflight, "access-control-allow-origin") == ["https://site.example"]

    rejected =
      conn
      |> put_req_header("origin", "https://other.example")
      |> post("/api/contact", @valid_params)

    assert response(rejected, 403) == "Origin not allowed"
    refute_receive {:email, _}
  end
end
