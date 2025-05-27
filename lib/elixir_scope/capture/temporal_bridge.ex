defmodule ElixirScope.Capture.TemporalBridge do
  @moduledoc """
  Bridge between InstrumentationRuntime and TemporalStorage for real-time temporal correlation.
  
  This module provides the integration layer that connects runtime event capture
  with temporal storage and AST correlation, enabling Cinema Debugger functionality.
  
  ## Features
  
  - Real-time event correlation with AST nodes
  - Temporal indexing of runtime events
  - Integration with existing InstrumentationRuntime
  - Cinema Debugger query interface
  - Performance-optimized event processing
  
  ## Architecture
  
  ```
  InstrumentationRuntime → TemporalBridge → TemporalStorage
                                ↓
                        AST Node Correlation
                                ↓
                        Cinema Debugger Queries
  ```
  
  ## Usage
  
      # Start the temporal bridge
      {:ok, bridge} = TemporalBridge.start_link()
      
      # Events from InstrumentationRuntime are automatically correlated
      # and stored in TemporalStorage for Cinema Debugger queries
      
      # Query temporal events
      {:ok, events} = TemporalBridge.get_events_in_range(bridge, start_time, end_time)
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, "function_def_123")
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.Capture.TemporalStorage
  alias ElixirScope.Utils
  
  @type bridge_ref :: pid() | atom()
  @type temporal_event :: map()
  @type ast_node_id :: binary()
  @type correlation_id :: term()
  
  defstruct [
    :bridge_id,
    :temporal_storage,      # TemporalStorage process
    :event_buffer,         # Buffer for batch processing
    :correlation_cache,    # Cache for AST correlations
    :stats,               # Bridge statistics
    :config               # Configuration options
  ]
  
  @type t :: %__MODULE__{}
  
  # Default configuration
  @default_config %{
    buffer_size: 1000,
    flush_interval: 100,
    enable_correlation_cache: true,
    cache_size_limit: 10_000,
    enable_performance_tracking: true
  }
  
  #############################################################################
  # Public API
  #############################################################################
  
  @doc """
  Starts the TemporalBridge process.
  
  ## Options
  
  - `:name` - Process name (optional)
  - `:temporal_storage` - Existing TemporalStorage process (optional)
  - `:buffer_size` - Event buffer size (default: 1000)
  - `:flush_interval` - Buffer flush interval in ms (default: 100)
  
  ## Examples
  
      {:ok, bridge} = TemporalBridge.start_link()
      {:ok, bridge} = TemporalBridge.start_link(name: :main_bridge)
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end
  
  @doc """
  Correlates and stores a runtime event with temporal indexing.
  
  This is called by InstrumentationRuntime to store events with
  AST correlation and temporal indexing.
  
  ## Examples
  
      event = %{
        timestamp: Utils.monotonic_timestamp(),
        correlation_id: "exec_123",
        ast_node_id: "function_def_456",
        event_type: :function_entry,
        data: %{module: MyModule, function: :my_function}
      }
      
      :ok = TemporalBridge.correlate_event(bridge, event)
  """
  @spec correlate_event(bridge_ref(), temporal_event()) :: :ok | {:error, term()}
  def correlate_event(bridge, event) do
    GenServer.cast(bridge, {:correlate_event, event})
  end
  
  @doc """
  Gets events within a time range with AST correlation.
  
  ## Examples
  
      {:ok, events} = TemporalBridge.get_events_in_range(bridge, start_time, end_time)
  """
  @spec get_events_in_range(bridge_ref(), integer(), integer()) :: {:ok, [temporal_event()]} | {:error, term()}
  def get_events_in_range(bridge, start_time, end_time) do
    GenServer.call(bridge, {:get_events_in_range, start_time, end_time})
  end
  
  @doc """
  Gets events associated with a specific AST node.
  
  ## Examples
  
      {:ok, events} = TemporalBridge.get_events_for_ast_node(bridge, "function_def_123")
  """
  @spec get_events_for_ast_node(bridge_ref(), ast_node_id()) :: {:ok, [temporal_event()]} | {:error, term()}
  def get_events_for_ast_node(bridge, ast_node_id) do
    GenServer.call(bridge, {:get_events_for_ast_node, ast_node_id})
  end
  
  @doc """
  Gets events associated with a specific correlation ID.
  
  ## Examples
  
      {:ok, events} = TemporalBridge.get_events_for_correlation(bridge, "exec_456")
  """
  @spec get_events_for_correlation(bridge_ref(), correlation_id()) :: {:ok, [temporal_event()]} | {:error, term()}
  def get_events_for_correlation(bridge, correlation_id) do
    GenServer.call(bridge, {:get_events_for_correlation, correlation_id})
  end
  
  @doc """
  Gets bridge statistics and performance metrics.
  
  ## Examples
  
      {:ok, stats} = TemporalBridge.get_stats(bridge)
  """
  @spec get_stats(bridge_ref()) :: {:ok, map()} | {:error, term()}
  def get_stats(bridge) do
    GenServer.call(bridge, :get_stats)
  end
  
  @doc """
  Flushes the event buffer to TemporalStorage.
  
  ## Examples
  
      :ok = TemporalBridge.flush_buffer(bridge)
  """
  @spec flush_buffer(bridge_ref()) :: :ok | {:error, term()}
  def flush_buffer(bridge) do
    GenServer.call(bridge, :flush_buffer)
  end
  
  #############################################################################
  # Cinema Debugger Interface
  #############################################################################
  
  @doc """
  Reconstructs system state at a specific point in time.
  
  This is a Cinema Debugger primitive that analyzes all events
  up to a specific timestamp to reconstruct system state.
  
  ## Examples
  
      {:ok, state} = TemporalBridge.reconstruct_state_at(bridge, timestamp)
  """
  @spec reconstruct_state_at(bridge_ref(), integer()) :: {:ok, map()} | {:error, term()}
  def reconstruct_state_at(bridge, timestamp) do
    GenServer.call(bridge, {:reconstruct_state_at, timestamp})
  end
  
  @doc """
  Traces execution path leading to a specific event.
  
  This is a Cinema Debugger primitive that reconstructs the
  execution sequence that led to a particular event.
  
  ## Examples
  
      {:ok, path} = TemporalBridge.trace_execution_path(bridge, target_event)
  """
  @spec trace_execution_path(bridge_ref(), temporal_event()) :: {:ok, [temporal_event()]} | {:error, term()}
  def trace_execution_path(bridge, target_event) do
    GenServer.call(bridge, {:trace_execution_path, target_event})
  end
  
  @doc """
  Gets AST nodes that were active during a time range.
  
  This is a Cinema Debugger primitive that shows which AST nodes
  had events during a specific time window.
  
  ## Examples
  
      {:ok, nodes} = TemporalBridge.get_active_ast_nodes(bridge, start_time, end_time)
  """
  @spec get_active_ast_nodes(bridge_ref(), integer(), integer()) :: {:ok, [ast_node_id()]} | {:error, term()}
  def get_active_ast_nodes(bridge, start_time, end_time) do
    GenServer.call(bridge, {:get_active_ast_nodes, start_time, end_time})
  end
  
  #############################################################################
  # Integration with InstrumentationRuntime
  #############################################################################
  
  @doc """
  Registers this bridge as the temporal correlation handler.
  
  This integrates the bridge with InstrumentationRuntime so that
  events are automatically correlated and stored.
  
  ## Examples
  
      :ok = TemporalBridge.register_as_handler(bridge)
  """
  @spec register_as_handler(bridge_ref()) :: :ok | {:error, term()}
  def register_as_handler(bridge) do
    # Register this bridge as the temporal correlation handler
    :persistent_term.put(:elixir_scope_temporal_bridge, bridge)
    :ok
  end
  
  @doc """
  Unregisters this bridge as the temporal correlation handler.
  
  ## Examples
  
      :ok = TemporalBridge.unregister_handler()
  """
  @spec unregister_handler() :: :ok
  def unregister_handler() do
    :persistent_term.erase(:elixir_scope_temporal_bridge)
    :ok
  end
  
  @doc """
  Gets the currently registered temporal bridge.
  
  This is used by InstrumentationRuntime to send events to the bridge.
  
  ## Examples
  
      {:ok, bridge} = TemporalBridge.get_registered_bridge()
  """
  @spec get_registered_bridge() :: {:ok, bridge_ref()} | {:error, :not_registered}
  def get_registered_bridge() do
    case :persistent_term.get(:elixir_scope_temporal_bridge, nil) do
      nil -> {:error, :not_registered}
      bridge -> {:ok, bridge}
    end
  end
  
  #############################################################################
  # GenServer Implementation
  #############################################################################
  
  @impl true
  def init(opts) do
    config = Map.merge(@default_config, Map.new(opts))
    
    case create_bridge_state(config, opts) do
      {:ok, state} ->
        # Schedule periodic buffer flush
        schedule_flush(config.flush_interval)
        
        Logger.info("TemporalBridge started with config: #{inspect(config)}")
        {:ok, state}
      
      {:error, reason} ->
        Logger.error("Failed to initialize TemporalBridge: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_cast({:correlate_event, event}, state) do
    new_state = buffer_event(state, event)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call({:get_events_in_range, start_time, end_time}, _from, state) do
    case TemporalStorage.get_events_in_range(state.temporal_storage, start_time, end_time) do
      {:ok, events} ->
        {:reply, {:ok, events}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_events_for_ast_node, ast_node_id}, _from, state) do
    case TemporalStorage.get_events_for_ast_node(state.temporal_storage, ast_node_id) do
      {:ok, events} ->
        {:reply, {:ok, events}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_events_for_correlation, correlation_id}, _from, state) do
    case TemporalStorage.get_events_for_correlation(state.temporal_storage, correlation_id) do
      {:ok, events} ->
        {:reply, {:ok, events}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = calculate_bridge_stats(state)
    {:reply, {:ok, stats}, state}
  end
  
  @impl true
  def handle_call(:flush_buffer, _from, state) do
    case flush_buffer_impl(state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:reconstruct_state_at, timestamp}, _from, state) do
    case reconstruct_state_at_impl(state, timestamp) do
      {:ok, reconstructed_state} ->
        {:reply, {:ok, reconstructed_state}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:trace_execution_path, target_event}, _from, state) do
    case trace_execution_path_impl(state, target_event) do
      {:ok, execution_path} ->
        {:reply, {:ok, execution_path}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_active_ast_nodes, start_time, end_time}, _from, state) do
    case get_active_ast_nodes_impl(state, start_time, end_time) do
      {:ok, ast_nodes} ->
        {:reply, {:ok, ast_nodes}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_info(:flush_buffer, state) do
    case flush_buffer_impl(state) do
      {:ok, new_state} ->
        schedule_flush(state.config.flush_interval)
        {:noreply, new_state}
      {:error, reason} ->
        Logger.warning("Failed to flush buffer: #{inspect(reason)}")
        schedule_flush(state.config.flush_interval)
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
  
  #############################################################################
  # Private Implementation
  #############################################################################
  
  defp create_bridge_state(config, opts) do
    try do
      bridge_id = Utils.generate_id()
      
      # Get or create TemporalStorage
      temporal_storage = case Keyword.get(opts, :temporal_storage) do
        nil ->
          {:ok, storage} = TemporalStorage.start_link()
          storage
        storage ->
          storage
      end
      
      # Create correlation cache if enabled
      correlation_cache = if config.enable_correlation_cache do
        :ets.new(:temporal_correlation_cache, [:set, :public, {:read_concurrency, true}])
      else
        nil
      end
      
      state = %__MODULE__{
        bridge_id: bridge_id,
        temporal_storage: temporal_storage,
        event_buffer: [],
        correlation_cache: correlation_cache,
        stats: %{
          events_processed: 0,
          events_buffered: 0,
          correlations_cached: 0,
          buffer_flushes: 0,
          created_at: Utils.wall_timestamp()
        },
        config: config
      }
      
      {:ok, state}
    rescue
      error -> {:error, {:initialization_failed, error}}
    end
  end
  
  defp buffer_event(state, event) do
    # Add correlation metadata if available
    enriched_event = enrich_event_with_correlation(state, event)
    
    # Add to buffer
    new_buffer = [enriched_event | state.event_buffer]
    new_stats = %{state.stats | 
      events_processed: state.stats.events_processed + 1,
      events_buffered: length(new_buffer)
    }
    
    new_state = %{state | event_buffer: new_buffer, stats: new_stats}
    
    # Flush if buffer is full
    if length(new_buffer) >= state.config.buffer_size do
      case flush_buffer_impl(new_state) do
        {:ok, flushed_state} -> flushed_state
        {:error, _reason} -> new_state  # Keep buffering on flush error
      end
    else
      new_state
    end
  end
  
  defp enrich_event_with_correlation(state, event) do
    # Add timestamp if not present
    event_with_timestamp = Map.put_new(event, :timestamp, Utils.monotonic_timestamp())
    
    # Add bridge metadata to the event data, not the top level
    # This ensures compatibility with TemporalStorage's normalization
    enriched_data = Map.merge(event_with_timestamp, %{
      bridge_id: state.bridge_id,
      bridge_timestamp: Utils.wall_timestamp(),
      temporal_correlation: true
    })
    
    # Structure the event for TemporalStorage
    %{
      timestamp: enriched_data.timestamp,
      ast_node_id: Map.get(enriched_data, :ast_node_id),
      correlation_id: Map.get(enriched_data, :correlation_id),
      data: enriched_data
    }
  end
  
  defp flush_buffer_impl(state) do
    try do
      # Store all buffered events in TemporalStorage
      results = Enum.map(state.event_buffer, fn event ->
        TemporalStorage.store_event(state.temporal_storage, event)
      end)
      
      # Check for errors
      errors = Enum.filter(results, &match?({:error, _}, &1))
      
      if Enum.empty?(errors) do
        # Update statistics
        new_stats = %{state.stats |
          events_buffered: 0,
          buffer_flushes: state.stats.buffer_flushes + 1
        }
        
        new_state = %{state | event_buffer: [], stats: new_stats}
        {:ok, new_state}
      else
        {:error, {:flush_errors, errors}}
      end
    rescue
      error -> {:error, {:flush_failed, error}}
    end
  end
  
  defp calculate_bridge_stats(state) do
    # Get TemporalStorage stats
    temporal_stats = case TemporalStorage.get_stats(state.temporal_storage) do
      {:ok, stats} -> stats
      {:error, _} -> %{}
    end
    
    # Combine with bridge stats
    Map.merge(state.stats, %{
      temporal_storage: temporal_stats,
      correlation_cache_size: if(state.correlation_cache, do: :ets.info(state.correlation_cache, :size), else: 0),
      buffer_size: length(state.event_buffer),
      config: state.config
    })
  end
  
  defp reconstruct_state_at_impl(state, timestamp) do
    try do
      # Get all events up to the timestamp
      case TemporalStorage.get_events_in_range(state.temporal_storage, 0, timestamp) do
        {:ok, events} ->
          # Reconstruct state by replaying events
          reconstructed_state = replay_events_for_state(events)
          {:ok, reconstructed_state}
        
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error -> {:error, {:state_reconstruction_failed, error}}
    end
  end
  
  defp trace_execution_path_impl(state, target_event) do
    try do
      correlation_id = Map.get(target_event, :correlation_id)
      
      if correlation_id do
        # Get all events for this correlation
        case TemporalStorage.get_events_for_correlation(state.temporal_storage, correlation_id) do
          {:ok, events} ->
            # Sort by timestamp to get execution order
            execution_path = Enum.sort_by(events, & &1.timestamp)
            {:ok, execution_path}
          
          {:error, reason} ->
            {:error, reason}
        end
      else
        {:error, :no_correlation_id}
      end
    rescue
      error -> {:error, {:execution_trace_failed, error}}
    end
  end
  
  defp get_active_ast_nodes_impl(state, start_time, end_time) do
    try do
      # Get all events in the time range
      case TemporalStorage.get_events_in_range(state.temporal_storage, start_time, end_time) do
        {:ok, events} ->
          # Extract unique AST node IDs
          ast_nodes = events
                     |> Enum.map(&Map.get(&1, :ast_node_id))
                     |> Enum.filter(&(&1 != nil))
                     |> Enum.uniq()
          
          {:ok, ast_nodes}
        
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error -> {:error, {:ast_nodes_query_failed, error}}
    end
  end
  
  defp replay_events_for_state(events) do
    # Simple state reconstruction - can be enhanced for specific use cases
    Enum.reduce(events, %{}, fn event, acc_state ->
      # Extract event type from the data field (TemporalStorage structure)
      event_type = Map.get(event.data, :event_type)
      
      case event_type do
        :function_entry ->
          module = get_in(event.data, [:data, :module]) || Map.get(event.data, :module)
          function = get_in(event.data, [:data, :function]) || Map.get(event.data, :function)
          if module && function do
            function_key = "#{module}.#{function}"
            Map.put(acc_state, function_key, %{status: :active, entry_time: event.timestamp})
          else
            acc_state
          end
        
        :function_exit ->
          module = get_in(event.data, [:data, :module]) || Map.get(event.data, :module)
          function = get_in(event.data, [:data, :function]) || Map.get(event.data, :function)
          if module && function do
            function_key = "#{module}.#{function}"
            Map.put(acc_state, function_key, %{status: :completed, exit_time: event.timestamp})
          else
            acc_state
          end
        
        :state_change ->
          state_data = get_in(event.data, [:data, :state]) || Map.get(event.data, :state, %{})
          Map.merge(acc_state, state_data)
        
        _ ->
          acc_state
      end
    end)
  end
  
  defp schedule_flush(interval) do
    Process.send_after(self(), :flush_buffer, interval)
  end
end 