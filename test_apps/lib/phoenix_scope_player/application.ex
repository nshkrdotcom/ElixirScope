defmodule PhoenixScopePlayer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Registry
      PhoenixScopePlayer.PlaybackEngine.Registry,
      # Start the Telemetry supervisor
      PhoenixScopePlayerWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: PhoenixScopePlayer.PubSub},
      # Start the Endpoint (http/https)
      PhoenixScopePlayerWeb.Endpoint
      # Start a worker by calling: PhoenixScopePlayer.Worker.start_link(arg)
      # {PhoenixScopePlayer.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhoenixScopePlayer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhoenixScopePlayerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end 