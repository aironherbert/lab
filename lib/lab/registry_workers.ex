defmodule Lab.RegistryWorkers do
  @moduledoc "Public API for workers addressed by name through `Registry`."

  def start_worker(name) when is_binary(name) do
    name = String.trim(name)

    if name == "" do
      {:error, :blank_name}
    else
      DynamicSupervisor.start_child(Lab.DynamicSupervisor, {Lab.RegistryWorker, name})
    end
  end

  def increment(name), do: Lab.RegistryWorker.increment(name)
  def crash(name), do: Lab.RegistryWorker.crash(name)

  def stop_worker(name) do
    case whereis(name) do
      nil -> {:error, :not_found}
      pid -> DynamicSupervisor.terminate_child(Lab.DynamicSupervisor, pid)
    end
  end

  def whereis(name) do
    case Registry.lookup(Lab.ProcessRegistry, name) do
      [{pid, _value}] when is_pid(pid) ->
        if Process.alive?(pid), do: pid, else: nil

      [] ->
        nil
    end
  end

  def list_workers do
    Lab.ProcessRegistry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.flat_map(fn {name, pid} ->
      try do
        state = Lab.RegistryWorker.snapshot(name)
        [Map.put(state, :pid, pid)]
      catch
        :exit, _reason -> []
      end
    end)
    |> Enum.sort_by(& &1.name)
  end
end
