defmodule Lab.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LabWeb.Telemetry,
      Lab.Repo,
      {DNSCluster, query: Application.get_env(:lab, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Lab.PubSub},
      Lab.Counter,
      Lab.ResilienceSupervisor,
      {Registry, keys: :unique, name: Lab.ProcessRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Lab.DynamicSupervisor},
      # Start to serve requests, typically the last entry
      LabWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Lab.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LabWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
