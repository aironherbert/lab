defmodule LabWeb.SupervisorLiveTest do
  use LabWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "shows the worker state and performs work", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/supervisor")

    assert html =~ "Supervisor em ação"
    assert has_element?(view, "#worker-status", "processo ativo")

    initial_jobs = Lab.ResilientWorker.status().jobs
    view |> element("#do-work") |> render_click()

    assert has_element?(view, "#job-count", "%{jobs: #{initial_jobs + 1}}")
  end
end
