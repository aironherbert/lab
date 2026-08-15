defmodule LabWeb.CounterLiveTest do
  use LabWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    Lab.Counter.reset()
    _ = :sys.get_state(Lab.Counter)
    :ok
  end

  test "shows and changes the shared GenServer counter", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "GenServer na prática"
    assert has_element?(view, "#counter-value", "0")

    view |> element("#increment") |> render_click()
    assert has_element?(view, "#counter-value", "1")
    assert has_element?(view, "#last-action", "GenServer.cast(:increment)")

    view |> element("#reset") |> render_click()
    assert has_element?(view, "#counter-value", "0")
  end
end
