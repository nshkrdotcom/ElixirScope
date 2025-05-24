defmodule ElixirScope.Capture.PipelineManager do
  @moduledoc """
  PipelineManager supervises all Layer 2 asynchronous processing components.
  
  This module manages:
  - AsyncWriterPool for processing events from ring buffers
  - EventCorrelator for establishing causal relationships
  - BackpressureManager for load management
  - Dynamic configuration updates
  """
  
  use Supervisor
  require Logger
  
  alias ElixirScope.Capture.AsyncWriterPool
  alias ElixirScope.Utils
  
  @default_config %{
    async_writer_pool_size: 4,
    batch_size: 50,
    max_backlog: 5000,
    correlation_enabled: true,
    backpressure_enabled: true
  }
  
  defstruct [
    :config,
    :start_time,
    :events_processed,
    :processing_rate,
    :children
  ]
  
  ## Public API
  
  # Module state stored in ETS for config/metrics access
  @table_name :pipeline_manager_state
  
  @doc """
  Starts the PipelineManager with optional configuration.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Gets the current state of the PipelineManager.
  """
  def get_state(pid \\ __MODULE__) do
    case :ets.lookup(@table_name, :state) do
      [{:state, state}] -> state
      [] -> create_initial_state()
    end
  end
  
  @doc """
  Updates the configuration dynamically.
  """
  def update_config(pid \\ __MODULE__, new_config) do
    current_state = get_state(pid)
    updated_config = Map.merge(current_state.config, new_config)
    updated_state = %{current_state | config: updated_config}
    
    :ets.insert(@table_name, {:state, updated_state})
    
    Logger.info("PipelineManager configuration updated: #{inspect(new_config)}")
    :ok
  end
  
  @doc """
  Performs a health check on the pipeline.
  """
  def health_check(pid \\ __MODULE__) do
    state = get_state(pid)
    children = Supervisor.which_children(pid)
    uptime_ms = Utils.monotonic_timestamp() - state.start_time
    
    %{
      status: :healthy,
      children_count: length(children),
      uptime_ms: uptime_ms
    }
  end
  
  @doc """
  Gets current metrics about pipeline performance.
  """
  def get_metrics(pid \\ __MODULE__) do
    state = get_state(pid)
    
    %{
      events_processed: state.events_processed,
      processing_rate: state.processing_rate,
      backlog_size: 0  # TODO: Implement actual backlog tracking
    }
  end
  
  @doc """
  Gracefully shuts down the pipeline manager and all children.
  """
  def shutdown(pid \\ __MODULE__) do
    Logger.info("PipelineManager shutting down gracefully")
    
    # Stop supervisor which will stop all children
    if Process.whereis(__MODULE__) do
      Supervisor.stop(pid, :normal, 5000)
    end
    
    :ok
  end
  
  ## Supervisor Implementation
  
  @impl true
  def init(opts) do
    # Parse configuration
    config = case opts do
      [] -> @default_config
      %{} = config_map -> Map.merge(@default_config, config_map)
      _other -> @default_config
    end
    
    # Create ETS table for state management
    :ets.new(@table_name, [:named_table, :public, :set])
    
    # Store initial state
    initial_state = %__MODULE__{
      config: config,
      start_time: Utils.monotonic_timestamp(),
      events_processed: 0,
      processing_rate: 0.0,
      children: []
    }
    
    :ets.insert(@table_name, {:state, initial_state})
    
    Logger.info("PipelineManager started with config: #{inspect(config)}")
    
    # Define child specification
    children = [
      # AsyncWriterPool as named child
      %{
        id: AsyncWriterPool,
        start: {AsyncWriterPool, :start_link, [[]]},
        restart: :permanent,
        shutdown: 5000,
        type: :worker
      }
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  ## Private Functions
  
  defp create_initial_state do
    %__MODULE__{
      config: @default_config,
      start_time: Utils.monotonic_timestamp(),
      events_processed: 0,
      processing_rate: 0.0,
      children: []
    }
  end
end 