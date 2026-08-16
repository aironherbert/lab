defmodule LabWeb.CheckoutCartLiveTest do
  use LabWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    :ok = Lab.CheckoutCart.clear()
    :ok
  end

  test "adds an item and starts the asynchronous checkout", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/genserver-cart")

    assert has_element?(view, "#checkout-cart-lab")
    assert has_element?(view, "#checkout-empty")

    view |> element("#checkout-add-0") |> render_click()
    assert has_element?(view, "#checkout-items", "Teclado mecânico")
    assert has_element?(view, "#checkout-total", "R$ 329,90")

    view |> element("#start-checkout") |> render_click()
    assert has_element?(view, "#checkout-status")
    assert has_element?(view, "#server-responsive")
  end
end
