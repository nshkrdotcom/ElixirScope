defmodule ElixirScope.Application do
  @moduledoc """
  ElixirScope Application Supervisor

  Manages the lifecycle of all ElixirScope components in a supervised manner.
  The supervision tree is designed to be fault-tolerant and to restart 
  components in the correct order if failures occur.
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Don't start in test environment to avoid conflicts
    if Application.get_env(:elixir_scope, :test_mode, false) do
      {:ok, self()}
    else
      Logger.info("Starting ElixirScope application...")

      children = [
        # Core configuration and utilities (no dependencies)
        {ElixirScope.Config, []},
        
        # Layer 1: Core capture pipeline will be added here
        # {ElixirScope.Capture.PipelineManager, []},
        
        # Layer 2: Storage and correlation will be added here
        # {ElixirScope.Storage.QueryCoordinator, []},
        
        # Layer 4: AI components will be added here
        # {ElixirScope.AI.Orchestrator, []},
      ]

      opts = [strategy: :one_for_one, name: ElixirScope.Supervisor]
      
      case Supervisor.start_link(children, opts) do
        {:ok, pid} ->
          Logger.info("ElixirScope application started successfully")
          {:ok, pid}
        
        {:error, reason} ->
          Logger.error("Failed to start ElixirScope application: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Stopping ElixirScope application...")
    :ok
  end
end 