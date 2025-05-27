defmodule ElixirScope.ASTRepository.RuntimeCorrelator do
  @moduledoc """
  Runtime correlation bridge that maps runtime events to AST nodes.
  
  This module provides the core functionality for correlating runtime execution
  events with static AST analysis data, enabling the hybrid architecture.
  
  Key responsibilities:
  - Map correlation IDs from runtime events to AST node IDs
  - Maintain temporal correlation data
  - Provide fast lookup capabilities (<5ms target)
  - Update AST repository with runtime insights
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.Utils
  alias ElixirScope.Storage.DataAccess
  alias ElixirScope.ASTRepository.Repository
  
  @type correlation_id :: binary()
  @type ast_node_id :: binary()
  @type runtime_event :: map()
  @type correlation_result :: {:ok, ast_node_id()} | {:error, term()}
  
  defstruct [
    # Core State
    :repository_pid,          # Repository process PID
    :data_access,            # DataAccess instance for events
    :correlation_cache,      # ETS table for fast correlation lookup
    :temporal_index,         # ETS table for temporal queries
    :statistics,             # Correlation statistics
    
    # Configuration
    :cache_size_limit,       # Maximum cache entries
    :correlation_timeout,    # Timeout for correlation operations
    :cleanup_interval,       # Cache cleanup interval
    :performance_tracking,   # Enable performance tracking
    
    # Metadata
    :start_time,             # Start timestamp
    :total_correlations,     # Total correlations performed
    :successful_correlations, # Successful correlations
    :failed_correlations     # Failed correlations
  ]
  
  @type t :: %__MODULE__{}
  
  # Default configuration
  @default_config %{
    cache_size_limit: 100_000,
    correlation_timeout: 5_000,
    cleanup_interval: 300_000,  # 5 minutes
    performance_tracking: true
  }
  
  # ETS table options
  @cache_opts [:set, :public, {:read_concurrency, true}, {:write_concurrency, true}]
  @temporal_opts [:bag, :public, {:read_concurrency, true}, {:write_concurrency, true}]
  
  #############################################################################
  # Public API
  #############################################################################
  
  @doc """
  Starts the RuntimeCorrelator with the given repository and configuration.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Correlates a runtime event with AST nodes.
  
  Returns the AST node ID that correlates with the event, or an error if
  no correlation can be established.
  """
  @spec correlate_event(GenServer.server(), runtime_event()) :: correlation_result()
  def correlate_event(correlator \\ __MODULE__, runtime_event) do
    GenServer.call(correlator, {:correlate_event, runtime_event})
  end
  
  @doc """
  Batch correlates multiple runtime events for better performance.
  """
  @spec correlate_events(GenServer.server(), [runtime_event()]) :: 
    {:ok, [{correlation_id(), ast_node_id()}]} | {:error, term()}
  def correlate_events(correlator \\ __MODULE__, runtime_events) do
    GenServer.call(correlator, {:correlate_events, runtime_events})
  end
  
  @doc """
  Gets all runtime events correlated with a specific AST node.
  """
  @spec get_correlated_events(GenServer.server(), ast_node_id()) :: 
    {:ok, [runtime_event()]} | {:error, term()}
  def get_correlated_events(correlator \\ __MODULE__, ast_node_id) do
    GenServer.call(correlator, {:get_correlated_events, ast_node_id})
  end
  
  @doc """
  Gets correlation statistics and performance metrics.
  """
  @spec get_statistics(GenServer.server()) :: {:ok, map()}
  def get_statistics(correlator \\ __MODULE__) do
    GenServer.call(correlator, :get_statistics)
  end
  
  @doc """
  Performs a health check on the correlator.
  """
  @spec health_check(GenServer.server()) :: {:ok, map()} | {:error, term()}
  def health_check(correlator \\ __MODULE__) do
    GenServer.call(correlator, :health_check)
  end
  
  @doc """
  Updates the correlation mapping for an AST node.
  """
  @spec update_correlation_mapping(GenServer.server(), correlation_id(), ast_node_id()) :: :ok
  def update_correlation_mapping(correlator \\ __MODULE__, correlation_id, ast_node_id) do
    GenServer.call(correlator, {:update_correlation_mapping, correlation_id, ast_node_id})
  end
  
  @doc """
  Queries events within a time range for temporal correlation.
  """
  @spec query_temporal_events(GenServer.server(), integer(), integer()) :: 
    {:ok, [runtime_event()]} | {:error, term()}
  def query_temporal_events(correlator \\ __MODULE__, start_time, end_time) do
    GenServer.call(correlator, {:query_temporal_events, start_time, end_time})
  end

  @doc """
  Gets all runtime events correlated with a specific AST node, ordered chronologically.
  
  This is the primary function for AST-centric debugging queries.
  """
  @spec get_events_for_ast_node(GenServer.server(), ast_node_id()) :: 
    {:ok, [runtime_event()]} | {:error, term()}
  def get_events_for_ast_node(correlator \\ __MODULE__, ast_node_id) do
    GenServer.call(correlator, {:get_events_for_ast_node, ast_node_id})
  end
  
  #############################################################################
  # GenServer Callbacks
  #############################################################################
  
  @impl true
  def init(opts) do
    Logger.info("🔧 RuntimeCorrelator.init starting with opts: #{inspect(opts)}")
    Logger.info("🔍 Checking Config GenServer availability...")
    
    config_pid = GenServer.whereis(ElixirScope.Config)
    Logger.info("📍 Config GenServer PID: #{inspect(config_pid)}")
    
    if config_pid do
      Logger.info("✅ Config GenServer found, testing responsiveness...")
      try do
        config_result = ElixirScope.Config.get([:ast_repository])
        Logger.info("✅ Config retrieved successfully: #{inspect(config_result)}")
      rescue
        error ->
          Logger.error("❌ Config GenServer unresponsive: #{inspect(error)}")
          Logger.error("📍 Error details: #{inspect(__STACKTRACE__)}")
          {:stop, {:config_unresponsive, error}}
      end
    else
      Logger.error("❌ Config GenServer not found!")
      Logger.error("📍 Available registered processes: #{inspect(Process.registered())}")
      {:stop, :config_not_found}
    end
    
    repository_pid = Keyword.get(opts, :repository_pid)
    Logger.info("🏗️ Building config with repository_pid: #{inspect(repository_pid)}")
    config = build_config(opts)
    
    Logger.info("🔧 Creating correlator state...")
    case create_correlator_state(repository_pid, config) do
      {:ok, state} ->
        # Schedule periodic cleanup
        schedule_cleanup(state.cleanup_interval)
        
        Logger.info("✅ RuntimeCorrelator started successfully with repository: #{inspect(repository_pid)}")
        {:ok, state}
      
      {:error, reason} ->
        Logger.error("❌ Failed to initialize RuntimeCorrelator: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_call({:correlate_event, runtime_event}, _from, state) do
    start_time = if state.performance_tracking, do: Utils.monotonic_timestamp(), else: nil
    
    result = correlate_event_impl(state, runtime_event)
    
    # Update statistics and performance tracking
    new_state = update_correlation_stats(state, result, start_time)
    
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call({:correlate_events, runtime_events}, _from, state) do
    start_time = if state.performance_tracking, do: Utils.monotonic_timestamp(), else: nil
    
    results = Enum.map(runtime_events, &correlate_event_impl(state, &1))
    
    # Extract successful correlations
    successful_correlations = results
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, {correlation_id, ast_node_id}} -> {correlation_id, ast_node_id} end)
    
    # Update statistics
    new_state = update_batch_correlation_stats(state, results, start_time)
    
    {:reply, {:ok, successful_correlations}, new_state}
  end
  
  @impl true
  def handle_call({:get_correlated_events, ast_node_id}, _from, state) do
    result = get_correlated_events_impl(state, ast_node_id)
    {:reply, result, state}
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
  def handle_call({:update_correlation_mapping, correlation_id, ast_node_id}, _from, state) do
    :ets.insert(state.correlation_cache, {correlation_id, ast_node_id})
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_call({:query_temporal_events, start_time, end_time}, _from, state) do
    result = query_temporal_events_impl(state, start_time, end_time)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_events_for_ast_node, ast_node_id}, _from, state) do
    result = get_events_for_ast_node_impl(state, ast_node_id)
    {:reply, result, state}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    new_state = perform_cleanup(state)
    schedule_cleanup(state.cleanup_interval)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.debug("RuntimeCorrelator received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  #############################################################################
  # Private Implementation Functions
  #############################################################################
  
  defp build_config(opts) do
    user_config = Keyword.get(opts, :config, %{})
    Map.merge(@default_config, user_config)
  end
  
  defp create_correlator_state(repository_pid, config) do
    if is_nil(repository_pid) do
      {:error, :repository_pid_required}
    else
      try do
        # Create ETS tables for caching and temporal indexing
        correlation_cache = :ets.new(:correlation_cache, @cache_opts)
        temporal_index = :ets.new(:temporal_index, @temporal_opts)
        
        # Create DataAccess instance for event storage
        {:ok, data_access} = DataAccess.new([name: :correlator_events])
        
        state = %__MODULE__{
          repository_pid: repository_pid,
          data_access: data_access,
          correlation_cache: correlation_cache,
          temporal_index: temporal_index,
          statistics: %{},
          cache_size_limit: config.cache_size_limit,
          correlation_timeout: config.correlation_timeout,
          cleanup_interval: config.cleanup_interval,
          performance_tracking: config.performance_tracking,
          start_time: Utils.monotonic_timestamp(),
          total_correlations: 0,
          successful_correlations: 0,
          failed_correlations: 0
        }
        
        {:ok, state}
      rescue
        error -> {:error, {:initialization_failed, error}}
      end
    end
  end
  
  defp correlate_event_impl(state, runtime_event) do
    correlation_id = extract_correlation_id(runtime_event)
    
    if correlation_id do
      case lookup_correlation(state, correlation_id) do
        {:ok, ast_node_id} ->
          # Store the event for future analysis
          store_correlated_event(state, runtime_event, ast_node_id)
          
          # Update temporal index
          timestamp = extract_timestamp(runtime_event)
          :ets.insert(state.temporal_index, {timestamp, {correlation_id, ast_node_id}})
          
          {:ok, {correlation_id, ast_node_id}}
        
        {:error, :not_found} ->
          # Try to get correlation from repository
          case Repository.correlate_event(state.repository_pid, runtime_event) do
            {:ok, ast_node_id} ->
              # Cache the correlation for future use
              :ets.insert(state.correlation_cache, {correlation_id, ast_node_id})
              
              # Store the event
              store_correlated_event(state, runtime_event, ast_node_id)
              
              # Update temporal index
              timestamp = extract_timestamp(runtime_event)
              :ets.insert(state.temporal_index, {timestamp, {correlation_id, ast_node_id}})
              
              {:ok, {correlation_id, ast_node_id}}
            
            {:error, reason} ->
              {:error, reason}
          end
        
        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :no_correlation_id}
    end
  end
  
  defp lookup_correlation(state, correlation_id) do
    case :ets.lookup(state.correlation_cache, correlation_id) do
      [{^correlation_id, ast_node_id}] -> {:ok, ast_node_id}
      [] -> {:error, :not_found}
    end
  end
  
  defp store_correlated_event(state, runtime_event, ast_node_id) do
    # Enrich the event with correlation information
    enriched_event = Map.merge(runtime_event, %{
      correlated_ast_node_id: ast_node_id,
      correlation_timestamp: Utils.monotonic_timestamp()
    })
    
    # Store in DataAccess for future queries
    case DataAccess.store_event(state.data_access, enriched_event) do
      :ok -> :ok
      {:error, reason} ->
        Logger.warning("Failed to store correlated event: #{inspect(reason)}")
        :ok  # Don't fail correlation due to storage issues
    end
  end
  
  defp get_correlated_events_impl(state, ast_node_id) do
    get_events_for_ast_node_impl(state, ast_node_id)
  end

  defp get_events_for_ast_node_impl(state, ast_node_id) do
    try do
      # Get all correlation IDs for this AST node from temporal index
      correlation_ids = :ets.select(state.temporal_index, [
        {{:_, {:'$1', ast_node_id}}, [], [:'$1']}
      ])
      
      # Get events from DataAccess for each correlation ID
      events = Enum.flat_map(correlation_ids, fn correlation_id ->
        case DataAccess.query_by_correlation(state.data_access, correlation_id) do
          {:ok, events} -> events
          {:error, _} -> []
        end
      end)
      
      # Sort by timestamp for chronological order
      sorted_events = Enum.sort_by(events, fn event ->
        extract_timestamp(event)
      end)
      
      {:ok, sorted_events}
    rescue
      error -> {:error, {:query_failed, error}}
    end
  end
  
  defp query_temporal_events_impl(state, start_time, end_time) do
    try do
      # Query temporal index for events in the time range
      temporal_entries = :ets.select(state.temporal_index, [
        {{:'$1', :'$2'}, 
         [{:andalso, {:>=, :'$1', start_time}, {:'=<', :'$1', end_time}}], 
         [:'$2']}
      ])
      
      # Extract correlation IDs and get the actual events
      correlation_ids = Enum.map(temporal_entries, fn {correlation_id, _ast_node_id} -> correlation_id end)
      
      # Get events from DataAccess
      events = Enum.flat_map(correlation_ids, fn correlation_id ->
        case DataAccess.query_by_correlation(state.data_access, correlation_id) do
          {:ok, events} -> events
          {:error, _} -> []
        end
      end)
      
      {:ok, events}
    rescue
      error -> {:error, {:temporal_query_failed, error}}
    end
  end
  
  defp update_correlation_stats(state, result, start_time) do
    new_total = state.total_correlations + 1
    
    {new_successful, new_failed} = case result do
      {:ok, _} -> {state.successful_correlations + 1, state.failed_correlations}
      {:error, _} -> {state.successful_correlations, state.failed_correlations + 1}
    end
    
    # Update performance statistics if tracking is enabled
    new_statistics = if state.performance_tracking and start_time do
      duration = Utils.monotonic_timestamp() - start_time
      update_performance_stats(state.statistics, duration)
    else
      state.statistics
    end
    
    %{state |
      total_correlations: new_total,
      successful_correlations: new_successful,
      failed_correlations: new_failed,
      statistics: new_statistics
    }
  end
  
  defp update_batch_correlation_stats(state, results, start_time) do
    successful_count = Enum.count(results, &match?({:ok, _}, &1))
    failed_count = length(results) - successful_count
    
    new_total = state.total_correlations + length(results)
    new_successful = state.successful_correlations + successful_count
    new_failed = state.failed_correlations + failed_count
    
    # Update performance statistics if tracking is enabled
    new_statistics = if state.performance_tracking and start_time do
      duration = Utils.monotonic_timestamp() - start_time
      update_batch_performance_stats(state.statistics, duration, length(results))
    else
      state.statistics
    end
    
    %{state |
      total_correlations: new_total,
      successful_correlations: new_successful,
      failed_correlations: new_failed,
      statistics: new_statistics
    }
  end
  
  defp update_performance_stats(statistics, duration) do
    current_avg = Map.get(statistics, :average_correlation_time, 0.0)
    current_count = Map.get(statistics, :correlation_count, 0)
    
    new_count = current_count + 1
    new_avg = (current_avg * current_count + duration) / new_count
    
    Map.merge(statistics, %{
      average_correlation_time: new_avg,
      correlation_count: new_count,
      last_correlation_time: duration
    })
  end
  
  defp update_batch_performance_stats(statistics, duration, batch_size) do
    current_avg = Map.get(statistics, :average_batch_correlation_time, 0.0)
    current_count = Map.get(statistics, :batch_correlation_count, 0)
    
    new_count = current_count + 1
    new_avg = (current_avg * current_count + duration) / new_count
    
    Map.merge(statistics, %{
      average_batch_correlation_time: new_avg,
      batch_correlation_count: new_count,
      last_batch_correlation_time: duration,
      last_batch_size: batch_size
    })
  end
  
  defp collect_statistics(state) do
    uptime = Utils.monotonic_timestamp() - state.start_time
    success_rate = if state.total_correlations > 0 do
      state.successful_correlations / state.total_correlations
    else
      0.0
    end
    
    %{
      uptime_ms: uptime,
      total_correlations: state.total_correlations,
      successful_correlations: state.successful_correlations,
      failed_correlations: state.failed_correlations,
      success_rate: success_rate,
      cache_size: :ets.info(state.correlation_cache, :size),
      temporal_index_size: :ets.info(state.temporal_index, :size),
      performance_stats: state.statistics
    }
  end
  
  defp perform_health_check(state) do
    cache_size = :ets.info(state.correlation_cache, :size)
    _temporal_size = :ets.info(state.temporal_index, :size)
    
    status = cond do
      cache_size > state.cache_size_limit * 0.9 -> :warning
      not Process.alive?(state.repository_pid) -> :error
      true -> :healthy
    end
    
    %{
      status: status,
      uptime_ms: Utils.monotonic_timestamp() - state.start_time,
      cache_utilization: cache_size / state.cache_size_limit,
      repository_alive: Process.alive?(state.repository_pid),
      memory_usage: %{
        correlation_cache: :ets.info(state.correlation_cache, :memory),
        temporal_index: :ets.info(state.temporal_index, :memory)
      }
    }
  end
  
  defp perform_cleanup(state) do
    # Clean up old entries from cache if it's getting too large
    cache_size = :ets.info(state.correlation_cache, :size)
    
    if cache_size > state.cache_size_limit do
      # Simple cleanup: remove oldest 10% of entries
      # In practice, you'd want a more sophisticated LRU strategy
      entries_to_remove = div(cache_size, 10)
      
      # Get all keys and remove the first N (this is a simplified approach)
      all_keys = :ets.select(state.correlation_cache, [{{:'$1', :_}, [], [:'$1']}])
      keys_to_remove = Enum.take(all_keys, entries_to_remove)
      
      Enum.each(keys_to_remove, fn key ->
        :ets.delete(state.correlation_cache, key)
      end)
      
      Logger.debug("RuntimeCorrelator cleanup: removed #{entries_to_remove} cache entries")
    end
    
    state
  end
  
  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
  
  defp extract_correlation_id(%{correlation_id: correlation_id}), do: correlation_id
  defp extract_correlation_id(%{"correlation_id" => correlation_id}), do: correlation_id
  defp extract_correlation_id(_), do: nil
  
  defp extract_timestamp(%{timestamp: timestamp}), do: timestamp
  defp extract_timestamp(%{"timestamp" => timestamp}), do: timestamp
  defp extract_timestamp(_), do: Utils.monotonic_timestamp()
end 