defmodule Lab.Counter do
  @moduledoc """
  A small, supervised GenServer that owns a shared counter.

  Calls read state synchronously, while casts change it asynchronously. After
  every change, the process broadcasts its new state so connected LiveViews
  stay in sync.
  """

  use GenServer

  @topic "counter"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, 0, name: Keyword.get(opts, :name, __MODULE__))
  end

  def value(server \\ __MODULE__), do: GenServer.call(server, :value)
  def increment(server \\ __MODULE__), do: GenServer.cast(server, :increment)
  def decrement(server \\ __MODULE__), do: GenServer.cast(server, :decrement)
  def reset(server \\ __MODULE__), do: GenServer.cast(server, :reset)

  def subscribe do
    Phoenix.PubSub.subscribe(Lab.PubSub, @topic)
  end

  @impl true
  def init(initial_value), do: {:ok, initial_value}

  @impl true
  def handle_call(:value, _from, value), do: {:reply, value, value}

  @impl true
  def handle_cast(:increment, value), do: update(value + 1, :increment)
  def handle_cast(:decrement, value), do: update(value - 1, :decrement)
  def handle_cast(:reset, _value), do: update(0, :reset)

  defp update(value, action) do
    Phoenix.PubSub.broadcast(Lab.PubSub, @topic, {:counter_updated, value, action})
    {:noreply, value}
  end
end
