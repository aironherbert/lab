defmodule Lab.CheckoutCartTest do
  use ExUnit.Case, async: false

  test "coordinates slow checkout work without blocking the server" do
    test_process = self()

    checkout_fun = fn server, items ->
      send(server, {:checkout_progress, self(), :reserving_stock})
      snapshot = GenServer.call(server, :snapshot)
      send(test_process, {:worker_waiting, self(), snapshot})

      receive do
        :finish ->
          send(server, {:checkout_progress, self(), :charging_payment})

          {:ok,
           %{id: "PED-TESTE", total: Enum.sum_by(items, & &1.price), item_count: length(items)}}
      end
    end

    name = Module.concat(__MODULE__, TestCart)
    start_supervised!({Lab.CheckoutCart, name: name, checkout_fun: checkout_fun})
    Lab.CheckoutCart.subscribe()

    assert {:ok, _item} = Lab.CheckoutCart.add("Teclado", 32_990, name)
    assert :ok = Lab.CheckoutCart.checkout(name)

    assert_receive {:worker_waiting, worker, %{status: :reserving_stock}}

    # The external operation is still waiting, but the GenServer answers calls.
    assert %{status: :reserving_stock, items: [_item]} = Lab.CheckoutCart.snapshot(name)
    assert {:error, :checkout_in_progress} = Lab.CheckoutCart.add("Mouse", 18_490, name)

    send(worker, :finish)
    assert_receive {:checkout_cart_updated, %{status: :completed}}

    assert %{items: [], order: %{id: "PED-TESTE", total: 32_990}} =
             Lab.CheckoutCart.snapshot(name)
  end
end
