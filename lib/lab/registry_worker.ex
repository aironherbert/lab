defmodule Lab.RegistryWorker do
  @moduledoc "A named counter registered through `Lab.ProcessRegistry`."

  use GenServer, restart: :permanent

  @topic "registry_workers"

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: via(name))
  end

  def child_spec(name) do
    %{
      id: {__MODULE__, name},
      start: {__MODULE__, :start_link, [name]},
      restart: :permanent
    }
  end

  def increment(name), do: GenServer.call(via(name), :increment)
  def crash(name), do: GenServer.cast(via(name), :crash)
  def snapshot(name), do: GenServer.call(via(name), :snapshot)
  def subscribe, do: Phoenix.PubSub.subscribe(Lab.PubSub, @topic)

  def via(name), do: {:via, Registry, {Lab.ProcessRegistry, name}}

  @impl true
  def init(name) do
    state = %{name: name, count: 0}
    Phoenix.PubSub.broadcast(Lab.PubSub, @topic, {:registry_worker_started, self(), state})
    {:ok, state}
  end

  @impl true
  def handle_call(:increment, _from, state) do
    state = %{state | count: state.count + 1}
    {:reply, state.count, state}
  end

  def handle_call(:snapshot, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast(:crash, state) do
    raise "crash solicitado no worker registrado #{state.name}"
  end
end
