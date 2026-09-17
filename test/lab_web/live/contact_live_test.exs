defmodule LabWeb.ContactLiveTest do
  use LabWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the form and sends a message", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/contato")
    assert has_element?(view, "#contact-form")

    view
    |> form("#contact-form",
      contact: %{
        name: "Ana",
        email: "ana@example.com",
        subject: "Oi",
        message: "Mensagem de teste"
      }
    )
    |> render_submit()

    assert has_element?(view, "#contact-success")
    assert_receive {:email, email}
    assert email.to == [{"", "destino@example.test"}]
  end

  test "shows validation errors and does not send", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/contato")

    view
    |> form("#contact-form",
      contact: %{name: "Ana", email: "invalido", subject: "Oi", message: "Mensagem de teste"}
    )
    |> render_submit()

    assert has_element?(view, "#contact-form .text-error")

    refute_receive {:email, _}
  end
end
