defmodule Lab.DynamicWorkers do
  @moduledoc "Public API for managing children under `Lab.DynamicSupervisor`."

  def start_worker do
    id = System.unique_integer([:positive, :monotonic])

    case DynamicSupervisor.start_child(Lab.DynamicSupervisor, {Lab.DynamicWorker, id}) do
      {:ok, pid} -> {:ok, id, pid}
      other -> other
    end
  end

  def stop_worker(pid), do: DynamicSupervisor.terminate_child(Lab.DynamicSupervisor, pid)

  def list_workers do
    Lab.DynamicSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.flat_map(fn {_, pid, _, _} ->
      case safe_snapshot(pid) do
        nil -> []
        state -> [Map.put(state, :pid, pid)]
      end
    end)
    |> Enum.sort_by(& &1.id)
  end

  defp safe_snapshot(pid) do
    Lab.DynamicWorker.snapshot(pid)
  catch
    :exit, _reason -> nil
  end
end
