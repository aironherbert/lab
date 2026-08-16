defmodule Lab.Cart do
  @moduledoc """
  A supervised in-memory shopping cart backed by an `Agent`.

  The Agent owns a simple list of items. This is a good fit when the process
  only needs to store state and does not need custom message handling.
  """

  use Agent

  def start_link(opts \\ []) do
    Agent.start_link(fn -> [] end, name: Keyword.get(opts, :name, __MODULE__))
  end

  def items(server \\ __MODULE__) do
    Agent.get(server, &Enum.reverse/1)
  end

  def add(product, price_in_cents, server \\ __MODULE__)
      when is_binary(product) and is_integer(price_in_cents) and price_in_cents >= 0 do
    item = %{
      id: System.unique_integer([:positive, :monotonic]),
      product: product,
      price: price_in_cents
    }

    Agent.update(server, &[item | &1])
    item
  end

  def remove(id, server \\ __MODULE__) do
    Agent.update(server, &Enum.reject(&1, fn item -> item.id == id end))
  end

  def total(server \\ __MODULE__) do
    Agent.get(server, &Enum.sum_by(&1, fn item -> item.price end))
  end

  def clear(server \\ __MODULE__) do
    Agent.update(server, fn _items -> [] end)
  end
end
