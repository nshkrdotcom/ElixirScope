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
    Logger.info("Starting ElixirScope application...")

    ensure_default_cfg_dependencies()

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

  defp ensure_default_cfg_dependencies do
    unless Application.get_env(:elixir_scope, :state_manager) do
      Application.put_env(:elixir_scope, :state_manager,
        ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager)
    end

    unless Application.get_env(:elixir_scope, :ast_utilities) do
      Application.put_env(:elixir_scope, :ast_utilities,
        ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities)
    end

    unless Application.get_env(:elixir_scope, :ast_processor) do
      Application.put_env(:elixir_scope, :ast_processor,
        ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor)
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Stopping ElixirScope application...")
    :ok
  end
end 
