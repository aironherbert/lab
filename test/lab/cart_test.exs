defmodule Lab.CartTest do
  use ExUnit.Case, async: true

  setup do
    name = Module.concat(__MODULE__, "Cart#{System.unique_integer([:positive])}")
    start_supervised!({Lab.Cart, name: name})
    %{cart: name}
  end

  test "stores items and calculates the total", %{cart: cart} do
    coffee = Lab.Cart.add("Café", 1850, cart)
    bread = Lab.Cart.add("Pão de queijo", 700, cart)

    assert Lab.Cart.items(cart) == [coffee, bread]
    assert Lab.Cart.total(cart) == 2550
  end

  test "removes an item and clears the cart", %{cart: cart} do
    item = Lab.Cart.add("Café", 1850, cart)
    Lab.Cart.add("Bolo", 1250, cart)

    Lab.Cart.remove(item.id, cart)
    assert Enum.map(Lab.Cart.items(cart), & &1.product) == ["Bolo"]

    Lab.Cart.clear(cart)
    assert Lab.Cart.items(cart) == []
    assert Lab.Cart.total(cart) == 0
  end
end
