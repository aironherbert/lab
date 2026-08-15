defmodule Lab.ResilienceSupervisor do
  @moduledoc """
  Supervises the crash demonstration worker.

  The default `:one_for_one` strategy restarts only the failed child. Because a
  GenServer has a `:permanent` restart policy by default, it is restarted after
  any kind of exit.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(:ok) do
    children = [Lab.ResilientWorker]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
