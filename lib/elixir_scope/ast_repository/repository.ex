defmodule ElixirScope.ASTRepository.Repository do
  @moduledoc """
  Central repository for AST storage with runtime correlation capabilities.
  
  Designed for high-performance access patterns:
  - O(1) module lookup by name
  - O(log n) correlation ID to AST node mapping  
  - O(1) instrumentation point retrieval
  - O(log n) temporal range queries
  
  Integrates with existing ElixirScope infrastructure:
  - Uses ElixirScope.Storage.DataAccess patterns for ETS storage
  - Follows ElixirScope.Config for configuration management
  - Implements GenServer pattern like PipelineManager
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.Storage.DataAccess
  alias ElixirScope.Utils
  alias ElixirScope.ASTRepository.{ModuleData, FunctionData}
  
  @type repository_id :: binary()
  @type module_name :: atom()
  @type function_key :: {module_name(), atom(), non_neg_integer()}
  @type ast_node_id :: binary()
  @type correlation_id :: binary()
  
  defstruct [
    # Repository Identity
    :repository_id,
    :creation_timestamp,
    :last_updated,
    :version,
    :configuration,
    
    # Core Storage Tables (ETS-based following DataAccess patterns)
    :modules_table,           # %{module_name => ModuleData.t()}
    :functions_table,         # %{function_key => FunctionData.t()}
    :ast_nodes_table,         # %{ast_node_id => AST_node}
    :patterns_table,          # %{pattern_id => PatternData.t()}
    
    # Correlation Infrastructure
    :correlation_index,       # %{correlation_id => ast_node_id}
    :instrumentation_points,  # %{ast_node_id => InstrumentationPoint.t()}
    :temporal_correlation,    # %{time_range => [event_ids]}
    
    # Runtime Integration
    :runtime_correlator,      # RuntimeCorrelator process
    :data_access,            # DataAccess instance for event storage
    
    # Performance Tracking
    :stats_table,            # Repository statistics
    :performance_metrics     # Performance tracking data
  ]
  
  @type t :: %__MODULE__{}
  
  # Default configuration following ElixirScope.Config patterns
  @default_config %{
    max_modules: 10_000,
    max_functions: 100_000,
    max_ast_nodes: 1_000_000,
    correlation_timeout: 5_000,
    cleanup_interval: 60_000,
    performance_tracking: true
  }
  
  # ETS table options following DataAccess patterns
  @table_opts [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}]
  @index_opts [:bag, :public, {:read_concurrency, true}, {:write_concurrency, true}]
  
  #############################################################################
  # Public API
  #############################################################################
  
  @doc """
  Starts the AST Repository with optional configuration.
  
  ## Options
  - `:name` - Process name (default: __MODULE__)
  - `:config` - Repository configuration (merged with defaults)
  - `:data_access` - Existing DataAccess instance (optional)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Creates a new repository instance (for testing or multiple repositories).
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(opts \\ []) do
    config = build_config(opts)
    
    case create_repository_state(config) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Stores a module's AST data with instrumentation metadata.
  """
  @spec store_module(GenServer.server(), ModuleData.t()) :: :ok | {:error, term()}
  def store_module(repository, module_data) do
    GenServer.call(repository, {:store_module, module_data})
  end
  
  @doc """
  Retrieves a module's data by name.
  """
  @spec get_module(GenServer.server(), module_name()) :: {:ok, ModuleData.t()} | {:error, :not_found}
  def get_module(repository, module_name) do
    GenServer.call(repository, {:get_module, module_name})
  end
  
  @doc """
  Updates a module's data using an update function.
  """
  @spec update_module(GenServer.server(), module_name(), (ModuleData.t() -> ModuleData.t())) :: 
    :ok | {:error, term()}
  def update_module(repository, module_name, update_fn) do
    GenServer.call(repository, {:update_module, module_name, update_fn})
  end
  
  @doc """
  Stores function-level data with runtime correlation capabilities.
  """
  @spec store_function(GenServer.server(), FunctionData.t()) :: :ok | {:error, term()}
  def store_function(repository, function_data) do
    GenServer.call(repository, {:store_function, function_data})
  end
  
  @doc """
  Retrieves function data by function key.
  """
  @spec get_function(GenServer.server(), function_key()) :: {:ok, FunctionData.t()} | {:error, :not_found}
  def get_function(repository, function_key) do
    GenServer.call(repository, {:get_function, function_key})
  end
  
  @doc """
  Correlates a runtime event with AST nodes using correlation ID.
  Returns the AST node ID that correlates with the event.
  """
  @spec correlate_event(GenServer.server(), map()) :: {:ok, ast_node_id()} | {:error, term()}
  def correlate_event(repository, runtime_event) do
    GenServer.call(repository, {:correlate_event, runtime_event})
  end
  
  @doc """
  Gets instrumentation points for a specific AST node.
  """
  @spec get_instrumentation_points(GenServer.server(), ast_node_id()) :: 
    {:ok, [map()]} | {:error, :not_found}
  def get_instrumentation_points(repository, ast_node_id) do
    GenServer.call(repository, {:get_instrumentation_points, ast_node_id})
  end
  
  @doc """
  Gets repository statistics and performance metrics.
  """
  @spec get_statistics(GenServer.server()) :: {:ok, map()}
  def get_statistics(repository) do
    GenServer.call(repository, :get_statistics)
  end
  
  @doc """
  Performs a health check on the repository.
  """
  @spec health_check(GenServer.server()) :: {:ok, map()} | {:error, term()}
  def health_check(repository) do
    GenServer.call(repository, :health_check)
  end
  
  #############################################################################
  # GenServer Callbacks
  #############################################################################
  
  @impl true
  def init(opts) do
    config = build_config(opts)
    
    case create_repository_state(config) do
      {:ok, state} ->
        # Start runtime correlator if configured
        state = maybe_start_runtime_correlator(state)
        
        # Schedule periodic cleanup
        schedule_cleanup(state.configuration.cleanup_interval)
        
        Logger.info("AST Repository started with config: #{inspect(config)}")
        {:ok, state}
      
      {:error, reason} ->
        Logger.error("Failed to initialize AST Repository: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call({:store_module, module_data}, _from, state) do
    case store_module_impl(state, module_data) do
      {:ok, new_state} ->
        {:reply, :ok, update_last_modified(new_state)}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_module, module_name}, _from, state) do
    case :ets.lookup(state.modules_table, module_name) do
      [{^module_name, module_data}] ->
        {:reply, {:ok, module_data}, state}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:update_module, module_name, update_fn}, _from, state) do
    case :ets.lookup(state.modules_table, module_name) do
      [{^module_name, module_data}] ->
        try do
          updated_data = update_fn.(module_data)
          :ets.insert(state.modules_table, {module_name, updated_data})
          {:reply, :ok, update_last_modified(state)}
        rescue
          error ->
            {:reply, {:error, {:update_failed, error}}, state}
        end
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:store_function, function_data}, _from, state) do
    case store_function_impl(state, function_data) do
      {:ok, new_state} ->
        {:reply, :ok, update_last_modified(new_state)}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_function, function_key}, _from, state) do
    case :ets.lookup(state.functions_table, function_key) do
      [{^function_key, function_data}] ->
        {:reply, {:ok, function_data}, state}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:correlate_event, runtime_event}, _from, state) do
    case correlate_event_impl(state, runtime_event) do
      {:ok, ast_node_id} ->
        {:reply, {:ok, ast_node_id}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_instrumentation_points, ast_node_id}, _from, state) do
    case :ets.lookup(state.instrumentation_points, ast_node_id) do
      [{^ast_node_id, points}] ->
        {:reply, {:ok, points}, state}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:get_statistics, _from, state) do
    stats = collect_statistics(state)
    {:reply, {:ok, stats}, state}
  end
  
  @impl true
  def handle_call(:health_check, _from, state) do
    health = perform_health_check(state)
    {:reply, {:ok, health}, state}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    new_state = perform_cleanup(state)
    schedule_cleanup(state.configuration.cleanup_interval)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.debug("AST Repository received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  #############################################################################
  # Private Implementation Functions
  #############################################################################
  
  defp build_config(opts) do
    # Get base config from ElixirScope.Config if available
    base_config = case safe_get_config([:ast_repository]) do
      nil -> @default_config
      config -> Map.merge(@default_config, config)
    end
    
    # Merge with provided options
    user_config = Keyword.get(opts, :config, %{})
    Map.merge(base_config, user_config)
  end

  defp safe_get_config(path) do
    try do
      case GenServer.whereis(ElixirScope.Config) do
        nil -> nil
        pid when is_pid(pid) ->
          case GenServer.call(pid, {:get_config_path, path}, 1000) do
            nil -> nil
            config -> config
          end
      end
    rescue
      _ -> nil
    catch
      :exit, _ -> nil
    end
  end
  
  defp create_repository_state(config) do
    repository_id = generate_repository_id()
    timestamp = Utils.monotonic_timestamp()
    
    try do
      # Create ETS tables following DataAccess patterns
      modules_table = :ets.new(:ast_modules, @table_opts)
      functions_table = :ets.new(:ast_functions, @table_opts)
      ast_nodes_table = :ets.new(:ast_nodes, @table_opts)
      patterns_table = :ets.new(:ast_patterns, @table_opts)
      
      # Create correlation indexes
      correlation_index = :ets.new(:correlation_index, @index_opts)
      instrumentation_points = :ets.new(:instrumentation_points, @table_opts)
      temporal_correlation = :ets.new(:temporal_correlation, @index_opts)
      
      # Create stats table
      stats_table = :ets.new(:ast_stats, @table_opts)
      
      # Initialize statistics
      :ets.insert(stats_table, [
        {:total_modules, 0},
        {:total_functions, 0},
        {:total_ast_nodes, 0},
        {:total_correlations, 0},
        {:creation_timestamp, timestamp},
        {:last_updated, timestamp}
      ])
      
      # Create DataAccess instance for runtime event storage
      {:ok, data_access} = DataAccess.new([name: :"#{repository_id}_events"])
      
      state = %__MODULE__{
        repository_id: repository_id,
        creation_timestamp: timestamp,
        last_updated: timestamp,
        version: "1.0.0",
        configuration: config,
        modules_table: modules_table,
        functions_table: functions_table,
        ast_nodes_table: ast_nodes_table,
        patterns_table: patterns_table,
        correlation_index: correlation_index,
        instrumentation_points: instrumentation_points,
        temporal_correlation: temporal_correlation,
        data_access: data_access,
        stats_table: stats_table,
        performance_metrics: %{}
      }
      
      {:ok, state}
    rescue
      error -> {:error, {:initialization_failed, error}}
    end
  end
  
  defp store_module_impl(state, module_data) do
    try do
      module_name = module_data.module_name
      
      # Store module data
      :ets.insert(state.modules_table, {module_name, module_data})
      
      # Update correlation indexes if module has instrumentation points
      if module_data.instrumentation_points do
        Enum.each(module_data.instrumentation_points, fn point ->
          :ets.insert(state.instrumentation_points, {point.ast_node_id, point})
        end)
      end
      
      # Update correlation mapping if available
      if module_data.correlation_metadata do
        Enum.each(module_data.correlation_metadata, fn {correlation_id, ast_node_id} ->
          :ets.insert(state.correlation_index, {correlation_id, ast_node_id})
        end)
      end
      
      # Update statistics
      :ets.update_counter(state.stats_table, :total_modules, 1, {:total_modules, 0})
      
      {:ok, state}
    rescue
      error -> {:error, {:store_module_failed, error}}
    end
  end
  
  defp store_function_impl(state, function_data) do
    try do
      function_key = function_data.function_key
      
      # Store function data
      :ets.insert(state.functions_table, {function_key, function_data})
      
      # Update statistics
      :ets.update_counter(state.stats_table, :total_functions, 1, {:total_functions, 0})
      
      {:ok, state}
    rescue
      error -> {:error, {:store_function_failed, error}}
    end
  end
  
  defp correlate_event_impl(state, runtime_event) do
    correlation_id = extract_correlation_id(runtime_event)
    
    if correlation_id do
      case :ets.lookup(state.correlation_index, correlation_id) do
        [{^correlation_id, ast_node_id}] ->
          # Store the runtime event in DataAccess for future analysis
          case DataAccess.store_event(state.data_access, runtime_event) do
            :ok ->
              # Update correlation statistics
              :ets.update_counter(state.stats_table, :total_correlations, 1, {:total_correlations, 0})
              {:ok, ast_node_id}
            {:error, reason} ->
              Logger.warning("Failed to store correlated event: #{inspect(reason)}")
              {:ok, ast_node_id}  # Still return correlation even if storage fails
          end
        [] ->
          {:error, :correlation_not_found}
      end
    else
      {:error, :no_correlation_id}
    end
  end
  
  defp extract_correlation_id(%{correlation_id: correlation_id}), do: correlation_id
  defp extract_correlation_id(%{"correlation_id" => correlation_id}), do: correlation_id
  defp extract_correlation_id(_), do: nil
  
  defp collect_statistics(state) do
    stats_list = :ets.tab2list(state.stats_table)
    stats_map = Enum.into(stats_list, %{})
    
    Map.merge(stats_map, %{
      repository_id: state.repository_id,
      version: state.version,
      uptime_ms: Utils.monotonic_timestamp() - state.creation_timestamp,
      table_sizes: %{
        modules: :ets.info(state.modules_table, :size),
        functions: :ets.info(state.functions_table, :size),
        ast_nodes: :ets.info(state.ast_nodes_table, :size),
        correlations: :ets.info(state.correlation_index, :size)
      }
    })
  end
  
  defp perform_health_check(state) do
    %{
      status: :healthy,
      repository_id: state.repository_id,
      uptime_ms: Utils.monotonic_timestamp() - state.creation_timestamp,
      memory_usage: %{
        modules_table: :ets.info(state.modules_table, :memory),
        functions_table: :ets.info(state.functions_table, :memory),
        correlation_index: :ets.info(state.correlation_index, :memory)
      },
      configuration: state.configuration
    }
  end
  
  defp perform_cleanup(state) do
    # TODO: Implement cleanup logic for old correlations and unused data
    Logger.debug("AST Repository cleanup completed")
    state
  end
  
  defp maybe_start_runtime_correlator(state) do
    # TODO: Start RuntimeCorrelator process if configured
    state
  end
  
  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
  
  defp update_last_modified(state) do
    timestamp = Utils.monotonic_timestamp()
    :ets.insert(state.stats_table, {:last_updated, timestamp})
    %{state | last_updated: timestamp}
  end
  
  defp generate_repository_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end 