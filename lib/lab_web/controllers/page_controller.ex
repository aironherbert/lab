defmodule LabWeb.PageController do
  use LabWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
