defmodule Lab.RegistryWorkersTest do
  use ExUnit.Case, async: false

  test "registers a worker under a unique name and accesses it by name" do
    name = "worker-#{System.unique_integer([:positive])}"

    assert {:ok, pid} = Lab.RegistryWorkers.start_worker(name)
    assert Lab.RegistryWorkers.whereis(name) == pid
    assert Lab.RegistryWorkers.increment(name) == 1
    assert %{name: ^name, count: 1} = Lab.RegistryWorker.snapshot(name)
    assert {:error, {:already_started, ^pid}} = Lab.RegistryWorkers.start_worker(name)

    assert :ok = Lab.RegistryWorkers.stop_worker(name)
    assert Lab.RegistryWorkers.whereis(name) == nil
  end

  test "restarts a crashed worker under the same registered name" do
    name = "crash-#{System.unique_integer([:positive])}"
    Lab.RegistryWorker.subscribe()
    {:ok, original_pid} = Lab.RegistryWorkers.start_worker(name)
    assert_receive {:registry_worker_started, ^original_pid, %{name: ^name}}
    ref = Process.monitor(original_pid)

    Lab.RegistryWorkers.crash(name)

    assert_receive {:DOWN, ^ref, :process, ^original_pid, _reason}
    assert_receive {:registry_worker_started, new_pid, %{name: ^name, count: 0}}
    assert new_pid != original_pid
    assert Lab.RegistryWorkers.whereis(name) == new_pid

    assert :ok = Lab.RegistryWorkers.stop_worker(name)
  end
end
