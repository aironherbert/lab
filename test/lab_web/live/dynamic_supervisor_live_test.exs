defmodule LabWeb.DynamicSupervisorLiveTest do
  use LabWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "dynamically starts, uses, and stops a worker", %{conn: conn} do
    existing_pids = Enum.map(Lab.DynamicWorkers.list_workers(), & &1.pid)
    Enum.each(existing_pids, &Lab.DynamicWorkers.stop_worker/1)

    {:ok, view, html} = live(conn, ~p"/dynamic-supervisor")
    assert html =~ "DynamicSupervisor"
    assert has_element?(view, "#empty-workers")

    view |> element("#start-worker") |> render_click()
    assert has_element?(view, "#worker-count", "1 filho")

    [worker] = Lab.DynamicWorkers.list_workers()
    worker_selector = "#workers-dynamic-worker-#{worker.id}"
    view |> element("#{worker_selector} button", "Trabalhar") |> render_click()
    assert has_element?(view, worker_selector, "1")

    view |> element("#{worker_selector} button", "Encerrar") |> render_click()
    assert has_element?(view, "#empty-workers")
  end
end
