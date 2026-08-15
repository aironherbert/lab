defmodule Lab.ResilientWorkerTest do
  use ExUnit.Case, async: false

  test "the supervisor replaces the worker after a crash" do
    Lab.ResilientWorker.subscribe()
    old_pid = Process.whereis(Lab.ResilientWorker)
    ref = Process.monitor(old_pid)
    initial_jobs = Lab.ResilientWorker.status().jobs

    Lab.ResilientWorker.work()
    assert %{jobs: jobs} = Lab.ResilientWorker.status()
    assert jobs == initial_jobs + 1

    Lab.ResilientWorker.crash()

    assert_receive {:DOWN, ^ref, :process, ^old_pid, _reason}
    assert_receive {:worker_started, new_pid, %{jobs: 0}}
    assert new_pid != old_pid
    assert Process.whereis(Lab.ResilientWorker) == new_pid
  end
end
