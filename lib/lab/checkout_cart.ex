defmodule Lab.CheckoutCart do
  @moduledoc """
  A cart that coordinates a long-running checkout with a `GenServer`.

  Slow work runs in a supervised Task. The server remains available and uses
  `handle_info/2` to receive progress and the final result.
  """

  use GenServer

  @topic "checkout_cart"

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def snapshot(server \\ __MODULE__), do: GenServer.call(server, :snapshot)

  def add(product, price, server \\ __MODULE__),
    do: GenServer.call(server, {:add, product, price})

  def clear(server \\ __MODULE__), do: GenServer.call(server, :clear)
  def checkout(server \\ __MODULE__), do: GenServer.call(server, :checkout)
  def subscribe, do: Phoenix.PubSub.subscribe(Lab.PubSub, @topic)

  @impl true
  def init(opts) do
    {:ok,
     %{
       items: [],
       status: :open,
       order: nil,
       error: nil,
       task_ref: nil,
       task_pid: nil,
       checkout_fun: Keyword.get(opts, :checkout_fun, &run_checkout/2)
     }}
  end

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, public_state(state), state}

  def handle_call({:add, product, price}, _from, state)
      when state.status in [:open, :completed] do
    item = %{id: System.unique_integer([:positive, :monotonic]), product: product, price: price}
    state = %{state | items: state.items ++ [item], status: :open, order: nil, error: nil}
    broadcast(state)
    {:reply, {:ok, item}, state}
  end

  def handle_call({:add, _product, _price}, _from, state) do
    {:reply, {:error, :checkout_in_progress}, state}
  end

  def handle_call(:clear, _from, state) when state.status in [:open, :completed] do
    state = %{state | items: [], status: :open, order: nil, error: nil}
    broadcast(state)
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state), do: {:reply, {:error, :checkout_in_progress}, state}

  def handle_call(:checkout, _from, %{items: []} = state), do: {:reply, {:error, :empty}, state}

  def handle_call(:checkout, _from, %{status: :open} = state) do
    server = self()

    task =
      Task.Supervisor.async_nolink(Lab.CheckoutTaskSupervisor, fn ->
        state.checkout_fun.(server, state.items)
      end)

    state = %{state | status: :starting, task_ref: task.ref, task_pid: task.pid, error: nil}
    broadcast(state)
    {:reply, :ok, state}
  end

  def handle_call(:checkout, _from, state), do: {:reply, {:error, :already_processing}, state}

  @impl true
  def handle_info({:checkout_progress, task_pid, status}, %{task_pid: task_pid} = state)
      when status in [:reserving_stock, :charging_payment] do
    state = %{state | status: status}
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({ref, {:ok, order}}, %{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])
    state = %{state | items: [], status: :completed, order: order, task_ref: nil, task_pid: nil}
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({ref, {:error, reason}}, %{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])
    state = %{state | status: :open, error: reason, task_ref: nil, task_pid: nil}
    broadcast(state)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    state = %{state | status: :open, error: {:task_failed, reason}, task_ref: nil, task_pid: nil}
    broadcast(state)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp run_checkout(server, items) do
    send(server, {:checkout_progress, self(), :reserving_stock})
    Process.sleep(900)
    send(server, {:checkout_progress, self(), :charging_payment})
    Process.sleep(900)

    {:ok,
     %{
       id: "PED-#{System.unique_integer([:positive])}",
       total: Enum.sum_by(items, & &1.price),
       item_count: length(items)
     }}
  end

  defp public_state(state) do
    Map.take(state, [:items, :status, :order, :error])
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(Lab.PubSub, @topic, {:checkout_cart_updated, public_state(state)})
  end
end
