defmodule ElixirScope.Unified.EventCorrelator do
  @moduledoc """
  Event correlation engine for ElixirScope unified tracing.
  
  Provides cross-system event correlation and unified querying:
  - Links events from runtime and AST systems
  - Maintains correlation mappings and session context
  - Provides unified event querying across all sources
  - Handles real-time event streaming
  - Manages event lifecycle and cleanup
  
  ## Event Correlation
  
  Events from different sources (runtime, AST, hybrid) are correlated using:
  - Session IDs for grouping related events
  - Correlation IDs for linking specific execution flows
  - Temporal correlation for sequence reconstruction
  - Causal relationships for dependency tracking
  """

  use GenServer
  
  alias ElixirScope.{Events, Storage, Utils}

  @type session_id :: String.t()
  @type correlation_id :: String.t()
  @type event_source :: :runtime | :ast | :hybrid
  @type trace_target :: {module(), atom(), arity()} | module()

  @type correlation_entry :: %{
    session_id: session_id(),
    correlation_id: correlation_id(),
    target: trace_target(),
    mode: atom(),
    registered_at: integer(),
    event_count: integer(),
    last_activity: integer()
  }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Starts the event correlator.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a new session for event correlation.
  
  ## Examples
  
      :ok = register_session("session_123", "corr_456", {MyModule, :func, 2}, :runtime)
  """
  @spec register_session(session_id(), correlation_id(), trace_target(), atom()) :: :ok
  def register_session(session_id, correlation_id, target, mode) do
    GenServer.call(__MODULE__, {:register_session, session_id, correlation_id, target, mode})
  end

  @doc """
  Unregisters a session from event correlation.
  """
  @spec unregister_session(session_id()) :: :ok
  def unregister_session(session_id) do
    GenServer.call(__MODULE__, {:unregister_session, session_id})
  end

  @doc """
  Queries events by correlation ID with optional filters.
  
  ## Examples
  
      {:ok, events} = query_events_by_correlation("corr_123")
      {:ok, events} = query_events_by_correlation("corr_123", %{
        event_types: [:function_call, :function_return],
        time_range: {start_time, end_time},
        limit: 100
      })
  """
  @spec query_events_by_correlation(correlation_id(), map()) :: 
    {:ok, [map()]} | {:error, term()}
  def query_events_by_correlation(correlation_id, options \\ %{}) do
    GenServer.call(__MODULE__, {:query_by_correlation, correlation_id, options})
  end

  @doc """
  Queries events by session ID.
  """
  @spec query_events_by_session(session_id(), map()) :: 
    {:ok, [map()]} | {:error, term()}
  def query_events_by_session(session_id, options \\ %{}) do
    GenServer.call(__MODULE__, {:query_by_session, session_id, options})
  end

  @doc """
  Creates a real-time event stream for a correlation ID.
  """
  @spec create_event_stream(correlation_id()) :: {:ok, pid()} | {:error, term()}
  def create_event_stream(correlation_id) do
    GenServer.call(__MODULE__, {:create_stream, correlation_id})
  end

  @doc """
  Gets correlation statistics for monitoring.
  """
  @spec get_correlation_stats() :: map()
  def get_correlation_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Correlates events across different sources for unified analysis.
  """
  @spec correlate_cross_system_events(correlation_id()) :: {:ok, map()} | {:error, term()}
  def correlate_cross_system_events(correlation_id) do
    GenServer.call(__MODULE__, {:correlate_cross_system, correlation_id})
  end

  # ============================================================================
  # GenServer Implementation
  # ============================================================================

  @impl true
  def init(_opts) do
    state = %{
      correlations: %{},  # session_id -> correlation_entry
      correlation_index: %{},  # correlation_id -> session_id
      event_streams: %{},  # correlation_id -> [stream_pid]
      stats: initialize_stats()
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:register_session, session_id, correlation_id, target, mode}, _from, state) do
    correlation_entry = %{
      session_id: session_id,
      correlation_id: correlation_id,
      target: target,
      mode: mode,
      registered_at: System.monotonic_time(:nanosecond),
      event_count: 0,
      last_activity: System.monotonic_time(:nanosecond)
    }
    
    new_state = %{
      state |
      correlations: Map.put(state.correlations, session_id, correlation_entry),
      correlation_index: Map.put(state.correlation_index, correlation_id, session_id),
      stats: update_stats(state.stats, :sessions_registered, 1)
    }
    
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister_session, session_id}, _from, state) do
    case Map.get(state.correlations, session_id) do
      nil ->
        {:reply, :ok, state}
      
      correlation_entry ->
        new_state = %{
          state |
          correlations: Map.delete(state.correlations, session_id),
          correlation_index: Map.delete(state.correlation_index, correlation_entry.correlation_id),
          stats: update_stats(state.stats, :sessions_unregistered, 1)
        }
        
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:query_by_correlation, correlation_id, options}, _from, state) do
    case query_events_internal(correlation_id, options) do
      {:ok, events} ->
        correlated_events = enhance_events_with_correlation(events, correlation_id, state)
        {:reply, {:ok, correlated_events}, state}
      
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:query_by_session, session_id, options}, _from, state) do
    case Map.get(state.correlations, session_id) do
      nil ->
        {:reply, {:error, :session_not_found}, state}
      
      correlation_entry ->
        case query_events_internal(correlation_entry.correlation_id, options) do
          {:ok, events} ->
            enhanced_events = enhance_events_with_session_context(events, correlation_entry)
            {:reply, {:ok, enhanced_events}, state}
          
          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:create_stream, correlation_id}, _from, state) do
    case create_event_stream_internal(correlation_id) do
      {:ok, stream_pid} ->
        existing_streams = Map.get(state.event_streams, correlation_id, [])
        new_streams = [stream_pid | existing_streams]
        
        new_state = %{
          state |
          event_streams: Map.put(state.event_streams, correlation_id, new_streams),
          stats: update_stats(state.stats, :streams_created, 1)
        }
        
        {:reply, {:ok, stream_pid}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    current_stats = %{
      state.stats |
      active_correlations: map_size(state.correlations),
      active_streams: count_active_streams(state.event_streams),
      correlation_index_size: map_size(state.correlation_index)
    }
    
    {:reply, current_stats, state}
  end

  @impl true
  def handle_call({:correlate_cross_system, correlation_id}, _from, state) do
    case correlate_cross_system_internal(correlation_id, state) do
      {:ok, correlation_result} ->
        {:reply, {:ok, correlation_result}, state}
      
      error ->
        {:reply, error, state}
    end
  end

  # ============================================================================
  # Private Implementation
  # ============================================================================

  defp initialize_stats do
    %{
      sessions_registered: 0,
      sessions_unregistered: 0,
      events_correlated: 0,
      streams_created: 0,
      cross_system_correlations: 0,
      last_activity: System.monotonic_time(:nanosecond)
    }
  end

  defp update_stats(stats, key, increment) do
    %{
      stats |
      key => Map.get(stats, key, 0) + increment,
      last_activity: System.monotonic_time(:nanosecond)
    }
  end

  defp query_events_internal(correlation_id, options) do
    # Query events from the storage system
    query_params = build_storage_query(correlation_id, options)
    
    case Storage.DataAccess.query_by_correlation(correlation_id, query_params) do
      {:ok, events} ->
        # Apply additional filtering and sorting
        filtered_events = apply_event_filters(events, options)
        sorted_events = sort_events(filtered_events, options)
        limited_events = apply_limit(sorted_events, options)
        
        {:ok, limited_events}
      
      error ->
        error
    end
  end

  defp build_storage_query(correlation_id, options) do
    base_query = %{correlation_id: correlation_id}
    
    base_query
    |> maybe_add_time_range(Map.get(options, :time_range))
    |> maybe_add_event_types(Map.get(options, :event_types))
    |> maybe_add_limit(Map.get(options, :limit))
  end

  defp maybe_add_time_range(query, nil), do: query
  defp maybe_add_time_range(query, {start_time, end_time}) do
    Map.merge(query, %{start_time: start_time, end_time: end_time})
  end

  defp maybe_add_event_types(query, nil), do: query
  defp maybe_add_event_types(query, event_types) when is_list(event_types) do
    Map.put(query, :event_types, event_types)
  end

  defp maybe_add_limit(query, nil), do: query
  defp maybe_add_limit(query, limit) when is_integer(limit) and limit > 0 do
    Map.put(query, :limit, limit)
  end

  defp apply_event_filters(events, options) do
    events
    |> maybe_filter_by_source(Map.get(options, :source))
    |> maybe_filter_by_module(Map.get(options, :module))
    |> maybe_filter_by_function(Map.get(options, :function))
  end

  defp maybe_filter_by_source(events, nil), do: events
  defp maybe_filter_by_source(events, source) do
    Enum.filter(events, fn event ->
      Map.get(event, :source) == source
    end)
  end

  defp maybe_filter_by_module(events, nil), do: events
  defp maybe_filter_by_module(events, module) do
    Enum.filter(events, fn event ->
      Map.get(event, :module) == module
    end)
  end

  defp maybe_filter_by_function(events, nil), do: events
  defp maybe_filter_by_function(events, function) do
    Enum.filter(events, fn event ->
      Map.get(event, :function) == function
    end)
  end

  defp sort_events(events, options) do
    sort_order = Map.get(options, :sort, :timestamp_asc)
    
    case sort_order do
      :timestamp_asc ->
        Enum.sort_by(events, fn event -> Map.get(event, :timestamp, 0) end)
      :timestamp_desc ->
        Enum.sort_by(events, fn event -> Map.get(event, :timestamp, 0) end, :desc)
      :event_type ->
        Enum.sort_by(events, fn event -> Map.get(event, :event_type, "") end)
      _ ->
        events
    end
  end

  defp apply_limit(events, options) do
    case Map.get(options, :limit) do
      nil -> events
      limit when is_integer(limit) and limit > 0 -> Enum.take(events, limit)
      _ -> events
    end
  end

  defp enhance_events_with_correlation(events, correlation_id, state) do
    session_id = Map.get(state.correlation_index, correlation_id)
    correlation_entry = Map.get(state.correlations, session_id)
    
    Enum.map(events, fn event ->
      Map.merge(event, %{
        correlation_context: %{
          session_id: session_id,
          correlation_id: correlation_id,
          target: correlation_entry && correlation_entry.target,
          mode: correlation_entry && correlation_entry.mode
        }
      })
    end)
  end

  defp enhance_events_with_session_context(events, correlation_entry) do
    Enum.map(events, fn event ->
      Map.merge(event, %{
        session_context: %{
          session_id: correlation_entry.session_id,
          target: correlation_entry.target,
          mode: correlation_entry.mode,
          registered_at: correlation_entry.registered_at
        }
      })
    end)
  end

  defp create_event_stream_internal(correlation_id) do
    # Create a GenServer that streams events in real-time
    case EventStream.start_link(correlation_id) do
      {:ok, pid} -> {:ok, pid}
      error -> error
    end
  end

  defp count_active_streams(event_streams) do
    event_streams
    |> Map.values()
    |> List.flatten()
    |> Enum.count(fn pid -> Process.alive?(pid) end)
  end

  defp correlate_cross_system_internal(correlation_id, state) do
    # Phase 1: Only runtime events available
    # Phase 2: Will implement cross-system correlation between runtime and AST
    
    case query_events_internal(correlation_id, %{}) do
      {:ok, events} ->
        correlation_result = %{
          correlation_id: correlation_id,
          total_events: length(events),
          event_sources: get_event_sources(events),
          timeline: build_event_timeline(events),
          execution_flow: analyze_execution_flow(events),
          performance_metrics: calculate_performance_metrics(events)
        }
        
        {:ok, correlation_result}
      
      error ->
        error
    end
  end

  defp get_event_sources(events) do
    events
    |> Enum.map(fn event -> Map.get(event, :source, :unknown) end)
    |> Enum.frequencies()
  end

  defp build_event_timeline(events) do
    events
    |> Enum.sort_by(fn event -> Map.get(event, :timestamp, 0) end)
    |> Enum.map(fn event ->
      %{
        timestamp: Map.get(event, :timestamp),
        event_type: Map.get(event, :event_type),
        module: Map.get(event, :module),
        function: Map.get(event, :function),
        source: Map.get(event, :source, :runtime)
      }
    end)
  end

  defp analyze_execution_flow(events) do
    # Analyze the flow of execution based on function calls and returns
    call_stack = []
    flow_analysis = %{
      function_calls: 0,
      function_returns: 0,
      exceptions: 0,
      max_call_depth: 0,
      execution_paths: []
    }
    
    Enum.reduce(events, {call_stack, flow_analysis}, fn event, {stack, analysis} ->
      case Map.get(event, :event_type) do
        :function_call ->
          new_stack = [event | stack]
          new_analysis = %{
            analysis |
            function_calls: analysis.function_calls + 1,
            max_call_depth: max(analysis.max_call_depth, length(new_stack))
          }
          {new_stack, new_analysis}
        
        :function_return ->
          new_stack = case stack do
            [_head | tail] -> tail
            [] -> []
          end
          new_analysis = %{analysis | function_returns: analysis.function_returns + 1}
          {new_stack, new_analysis}
        
        :exception ->
          new_analysis = %{analysis | exceptions: analysis.exceptions + 1}
          {stack, new_analysis}
        
        _ ->
          {stack, analysis}
      end
    end)
    |> elem(1)
  end

  defp calculate_performance_metrics(events) do
    if length(events) == 0 do
      %{total_duration_ns: 0, avg_event_interval_ns: 0, event_rate_per_second: 0}
    else
      timestamps = Enum.map(events, fn event -> Map.get(event, :timestamp, 0) end)
      min_time = Enum.min(timestamps)
      max_time = Enum.max(timestamps)
      total_duration = max_time - min_time
      
      %{
        total_duration_ns: total_duration,
        avg_event_interval_ns: if(length(events) > 1, do: total_duration / (length(events) - 1), else: 0),
        event_rate_per_second: if(total_duration > 0, do: length(events) / (total_duration / 1_000_000_000), else: 0)
      }
    end
  end
end

# ============================================================================
# Event Stream GenServer
# ============================================================================

defmodule ElixirScope.Unified.EventCorrelator.EventStream do
  @moduledoc """
  Real-time event streaming for a specific correlation ID.
  """
  
  use GenServer
  
  def start_link(correlation_id) do
    GenServer.start_link(__MODULE__, correlation_id)
  end
  
  @impl true
  def init(correlation_id) do
    # Subscribe to events for this correlation ID
    Events.subscribe_to_correlation(correlation_id)
    
    state = %{
      correlation_id: correlation_id,
      subscribers: [],
      event_count: 0,
      start_time: System.monotonic_time(:nanosecond)
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_info({:event, event}, state) do
    # Forward event to all subscribers
    Enum.each(state.subscribers, fn subscriber ->
      send(subscriber, {:stream_event, event})
    end)
    
    new_state = %{state | event_count: state.event_count + 1}
    {:noreply, new_state}
  end
  
  def subscribe(stream_pid, subscriber_pid) do
    GenServer.call(stream_pid, {:subscribe, subscriber_pid})
  end
  
  @impl true
  def handle_call({:subscribe, subscriber_pid}, _from, state) do
    new_subscribers = [subscriber_pid | state.subscribers]
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end
end 