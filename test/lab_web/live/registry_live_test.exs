defmodule LabWeb.RegistryLiveTest do
  use LabWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "registers, uses, rejects a duplicate, and removes a named worker", %{conn: conn} do
    name = "interface-#{System.unique_integer([:positive])}"
    {:ok, view, _html} = live(conn, ~p"/registry")

    assert has_element?(view, "#registry-form")

    view
    |> form("#registry-form", worker: %{name: name})
    |> render_submit()

    selector = "#workers-registry-worker-#{name}"
    assert has_element?(view, selector)
    assert has_element?(view, "#registry-count", "1 registro")
    assert has_element?(view, "#{selector} button", "Crash")

    view |> element("#{selector} button", "+ 1") |> render_click()
    assert has_element?(view, selector, "1")

    Lab.RegistryWorker.subscribe()
    original_pid = Lab.RegistryWorkers.whereis(name)
    ref = Process.monitor(original_pid)
    view |> element("#{selector} button", "Crash") |> render_click()

    assert_receive {:DOWN, ^ref, :process, ^original_pid, _reason}
    assert_receive {:registry_worker_started, new_pid, %{name: ^name}}
    assert new_pid != original_pid
    _ = :sys.get_state(view.pid)
    assert has_element?(view, "#registry-restarts-#{name}", "1")

    view
    |> form("#registry-form", worker: %{name: name})
    |> render_submit()

    assert has_element?(view, "#registry-error")

    view |> element("#{selector} button", "Remover") |> render_click()
    refute has_element?(view, selector)
  end
end
