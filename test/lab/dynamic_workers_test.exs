defmodule Lab.DynamicWorkersTest do
  use ExUnit.Case, async: false

  test "starts and intentionally removes a child at runtime" do
    {:ok, id, pid} = Lab.DynamicWorkers.start_worker()

    assert %{id: ^id, jobs: 0} = Lab.DynamicWorker.snapshot(pid)
    assert Enum.any?(Lab.DynamicWorkers.list_workers(), &(&1.pid == pid))

    assert :ok = Lab.DynamicWorkers.stop_worker(pid)
    refute Enum.any?(Lab.DynamicWorkers.list_workers(), &(&1.id == id))
  end

  test "restarts a crashed permanent child without affecting another child" do
    {:ok, crashed_id, crashed_pid} = Lab.DynamicWorkers.start_worker()
    {:ok, survivor_id, survivor_pid} = Lab.DynamicWorkers.start_worker()
    Lab.DynamicWorker.subscribe()
    ref = Process.monitor(crashed_pid)

    Lab.DynamicWorker.crash(crashed_pid)

    assert_receive {:DOWN, ^ref, :process, ^crashed_pid, _reason}
    assert_receive {:dynamic_worker_started, new_pid, %{id: ^crashed_id}}
    assert new_pid != crashed_pid
    assert Process.alive?(survivor_pid)
    assert %{id: ^survivor_id} = Lab.DynamicWorker.snapshot(survivor_pid)

    assert :ok = Lab.DynamicWorkers.stop_worker(new_pid)
    assert :ok = Lab.DynamicWorkers.stop_worker(survivor_pid)
  end

  test "lists only dynamic workers when a registered worker uses the same supervisor" do
    name = "registered-#{System.unique_integer([:positive])}"
    {:ok, registered_pid} = Lab.RegistryWorkers.start_worker(name)
    {:ok, dynamic_id, dynamic_pid} = Lab.DynamicWorkers.start_worker()

    assert [%{id: ^dynamic_id, pid: ^dynamic_pid}] =
             Enum.filter(Lab.DynamicWorkers.list_workers(), &(&1.id == dynamic_id))

    assert :ok = Lab.DynamicWorkers.stop_worker(dynamic_pid)
    assert :ok = Lab.RegistryWorkers.stop_worker(name)
    refute Process.alive?(registered_pid)
  end
end
