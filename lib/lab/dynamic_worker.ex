defmodule Lab.DynamicWorker do
  @moduledoc "A dynamically supervised worker used by the interactive lab."

  use GenServer, restart: :permanent

  @topic "dynamic_workers"

  def start_link(id), do: GenServer.start_link(__MODULE__, id)
  def work(pid), do: GenServer.cast(pid, :work)
  def crash(pid), do: GenServer.cast(pid, :crash)
  def snapshot(pid), do: GenServer.call(pid, :snapshot)

  def subscribe, do: Phoenix.PubSub.subscribe(Lab.PubSub, @topic)

  @impl true
  def init(id) do
    state = %{id: id, jobs: 0, started_at: DateTime.utc_now()}
    Phoenix.PubSub.broadcast(Lab.PubSub, @topic, {:dynamic_worker_started, self(), state})
    {:ok, state}
  end

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast(:work, state) do
    state = %{state | jobs: state.jobs + 1}
    Phoenix.PubSub.broadcast(Lab.PubSub, @topic, {:dynamic_worker_updated, self(), state})
    {:noreply, state}
  end

  def handle_cast(:crash, state) do
    raise "crash solicitado no worker dinâmico #{state.id}"
  end
end
