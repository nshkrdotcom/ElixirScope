defmodule ElixirScope do
  @moduledoc """
  Documentation for `ElixirScope`.
  This application provides tracing and introspection capabilities for Elixir projects.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # No children defined yet
    ]

    opts = [strategy: :one_for_one, name: ElixirScope.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
