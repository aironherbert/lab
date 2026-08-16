defmodule LabWeb.AgentLiveTest do
  use LabWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    Lab.Cart.clear()
    :ok
  end

  test "adds, removes and clears products in the Agent cart", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/agent")

    assert has_element?(view, "#agent-lab")
    assert has_element?(view, "#empty-cart")
    assert has_element?(view, "#cart-total", "R$ 0,00")

    view |> element("#add-product-0") |> render_click()
    assert has_element?(view, "#cart-count", "1 item")
    assert has_element?(view, "#cart-items", "Café especial")
    assert has_element?(view, "#cart-total", "R$ 18,50")

    item = Lab.Cart.items() |> List.first()
    view |> element("#remove-item-#{item.id}") |> render_click()
    assert has_element?(view, "#empty-cart")

    view |> element("#add-product-1") |> render_click()
    view |> element("#clear-cart") |> render_click()
    assert has_element?(view, "#cart-total", "R$ 0,00")
  end
end
