defmodule Lab.ResilientWorker do
  @moduledoc """
  A GenServer designed to demonstrate how a supervisor recovers from crashes.

  Its state intentionally lives only in memory. When `crash/0` terminates the
  process, `Lab.ResilienceSupervisor` starts a fresh process with fresh state.
  """

  use GenServer

  @topic "resilient_worker"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name, __MODULE__))
  end

  def status(server \\ __MODULE__), do: GenServer.call(server, :status)
  def work(server \\ __MODULE__), do: GenServer.cast(server, :work)
  def crash(server \\ __MODULE__), do: GenServer.cast(server, :crash)

  def subscribe do
    Phoenix.PubSub.subscribe(Lab.PubSub, @topic)
  end

  @impl true
  def init(:ok) do
    state = %{jobs: 0, started_at: DateTime.utc_now()}
    Phoenix.PubSub.broadcast(Lab.PubSub, @topic, {:worker_started, self(), state})
    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast(:work, state) do
    state = %{state | jobs: state.jobs + 1}
    Phoenix.PubSub.broadcast(Lab.PubSub, @topic, {:worker_updated, self(), state})
    {:noreply, state}
  end

  def handle_cast(:crash, _state) do
    raise "crash didático solicitado pela interface"
  end
end
