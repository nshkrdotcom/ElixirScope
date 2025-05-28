defmodule ElixirScope.Capture.TemporalBridgeEnhancement do
  @moduledoc """
  Temporal Bridge Enhancement for AST-Aware Time-Travel Debugging.
  
  Extends the existing TemporalBridge with AST integration to provide:
  
  - **AST-Aware State Reconstruction**: Show code structure during execution replay
  - **Semantic Time-Travel**: Navigate through execution by AST structure
  - **Code-Centric Debugging**: View execution from the perspective of code structure
  - **Structural Replay**: Replay execution showing AST node transitions
  
  ## Integration Points
  
  - TemporalBridge: Enhanced state reconstruction
  - RuntimeCorrelator: AST-Runtime correlation
  - Enhanced AST Repository: Structural context
  - EventStore: AST-enhanced event storage
  
  ## Performance Targets
  
  - State reconstruction: <100ms for 1000 events
  - AST context lookup: <10ms per state
  - Memory overhead: <15% of base TemporalBridge
  
  ## Examples
  
      # Reconstruct state with AST context
      {:ok, state} = TemporalBridgeEnhancement.reconstruct_state_with_ast(
        session_id, timestamp, ast_repo
      )
      
      # Get execution trace with AST flow
      {:ok, trace} = TemporalBridgeEnhancement.get_ast_execution_trace(
        session_id, start_time, end_time
      )
      
      # Navigate by AST structure
      {:ok, states} = TemporalBridgeEnhancement.get_states_for_ast_node(
        session_id, ast_node_id
      )
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.Capture.TemporalBridge
  alias ElixirScope.ASTRepository.RuntimeCorrelator
  alias ElixirScope.ASTRepository.EnhancedRepository
  alias ElixirScope.Storage.EventStore
  
  @table_name :temporal_bridge_enhancement_main
  @ast_state_cache :temporal_bridge_ast_state_cache
  @execution_trace_cache :temporal_bridge_execution_trace_cache
  
  # Performance targets
  @reconstruction_timeout 100  # milliseconds
  @context_lookup_timeout 10   # milliseconds
  
  # Cache TTL (2 minutes)
  @cache_ttl 120_000
  
  defstruct [
    :temporal_bridge,
    :ast_repo,
    :correlator,
    :event_store,
    :enhancement_stats,
    :cache_stats,
    :enabled
  ]
  
  @type ast_enhanced_state :: %{
    original_state: map(),
    ast_context: map(),
    structural_info: map(),
    execution_path: list(map()),
    variable_flow: map(),
    timestamp: non_neg_integer()
  }
  
  @type ast_execution_trace :: %{
    events: list(map()),
    ast_flow: list(map()),
    state_transitions: list(ast_enhanced_state()),
    structural_patterns: list(map()),
    execution_metadata: map()
  }
  
  # GenServer API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    # Create ETS tables for caching (handle existing tables gracefully)
    try do
      :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    rescue
      ArgumentError -> 
        # Table already exists, clear it
        :ets.delete_all_objects(@table_name)
    end
    
    try do
      :ets.new(@ast_state_cache, [:named_table, :public, :set, {:read_concurrency, true}])
    rescue
      ArgumentError -> 
        # Table already exists, clear it
        :ets.delete_all_objects(@ast_state_cache)
    end
    
    try do
      :ets.new(@execution_trace_cache, [:named_table, :public, :set, {:read_concurrency, true}])
    rescue
      ArgumentError -> 
        # Table already exists, clear it
        :ets.delete_all_objects(@execution_trace_cache)
    end
    
    state = %__MODULE__{
      temporal_bridge: Keyword.get(opts, :temporal_bridge),
      ast_repo: Keyword.get(opts, :ast_repo),
      correlator: Keyword.get(opts, :correlator, RuntimeCorrelator),
      event_store: Keyword.get(opts, :event_store),
      enhancement_stats: %{
        states_reconstructed: 0,
        ast_contexts_added: 0,
        cache_hits: 0,
        cache_misses: 0,
        avg_reconstruction_time: 0.0
      },
      cache_stats: %{
        state_cache_size: 0,
        trace_cache_size: 0,
        evictions: 0
      },
      enabled: Keyword.get(opts, :enabled, true)
    }
    
    Logger.info("TemporalBridgeEnhancement started with AST integration")
    {:ok, state}
  end
  
  # Public API
  
  @doc """
  Reconstructs state at a specific timestamp with AST context.
  
  Enhances the standard TemporalBridge state reconstruction with
  AST metadata, structural information, and code context.
  
  ## Parameters
  
  - `session_id` - Session identifier
  - `timestamp` - Target timestamp for reconstruction
  - `ast_repo` - Enhanced AST Repository (optional, uses default if nil)
  
  ## Returns
  
  - `{:ok, ast_enhanced_state}` - State with AST context
  - `{:error, reason}` - Reconstruction failed
  """
  @spec reconstruct_state_with_ast(String.t(), non_neg_integer(), pid() | nil) :: 
    {:ok, ast_enhanced_state()} | {:error, term()}
  def reconstruct_state_with_ast(session_id, timestamp, ast_repo \\ nil) do
    GenServer.call(__MODULE__, {:reconstruct_state_with_ast, session_id, timestamp, ast_repo}, @reconstruction_timeout)
  end
  
  @doc """
  Gets an AST-aware execution trace for a time range.
  
  Creates a comprehensive execution trace that shows both
  runtime behavior and underlying AST structure transitions.
  
  ## Parameters
  
  - `session_id` - Session identifier
  - `start_time` - Start timestamp
  - `end_time` - End timestamp
  
  ## Returns
  
  - `{:ok, ast_execution_trace}` - AST-aware execution trace
  - `{:error, reason}` - Trace creation failed
  """
  @spec get_ast_execution_trace(String.t(), non_neg_integer(), non_neg_integer()) :: 
    {:ok, ast_execution_trace()} | {:error, term()}
  def get_ast_execution_trace(session_id, start_time, end_time) do
    GenServer.call(__MODULE__, {:get_ast_execution_trace, session_id, start_time, end_time}, @reconstruction_timeout)
  end
  
  @doc """
  Gets all states associated with a specific AST node.
  
  Enables navigation through execution history by AST structure,
  showing all times a specific code location was executed.
  
  ## Parameters
  
  - `session_id` - Session identifier
  - `ast_node_id` - AST node identifier
  
  ## Returns
  
  - `{:ok, [ast_enhanced_state]}` - List of states for the AST node
  - `{:error, reason}` - Query failed
  """
  @spec get_states_for_ast_node(String.t(), String.t()) :: 
    {:ok, list(ast_enhanced_state())} | {:error, term()}
  def get_states_for_ast_node(session_id, ast_node_id) do
    GenServer.call(__MODULE__, {:get_states_for_ast_node, session_id, ast_node_id})
  end
  
  @doc """
  Gets execution flow between two AST nodes.
  
  Shows the execution path and state transitions between
  two specific code locations.
  
  ## Parameters
  
  - `session_id` - Session identifier
  - `from_ast_node_id` - Starting AST node
  - `to_ast_node_id` - Ending AST node
  - `time_range` - Optional time range constraint
  
  ## Returns
  
  - `{:ok, execution_flow}` - Execution flow between nodes
  - `{:error, reason}` - Query failed
  """
  @spec get_execution_flow_between_nodes(String.t(), String.t(), String.t(), tuple() | nil) :: 
    {:ok, map()} | {:error, term()}
  def get_execution_flow_between_nodes(session_id, from_ast_node_id, to_ast_node_id, time_range \\ nil) do
    GenServer.call(__MODULE__, {:get_execution_flow_between_nodes, session_id, from_ast_node_id, to_ast_node_id, time_range})
  end
  
  @doc """
  Enables or disables AST enhancement for temporal operations.
  """
  @spec set_enhancement_enabled(boolean()) :: :ok
  def set_enhancement_enabled(enabled) do
    GenServer.call(__MODULE__, {:set_enhancement_enabled, enabled})
  end
  
  @doc """
  Gets enhancement statistics and performance metrics.
  """
  @spec get_enhancement_stats() :: {:ok, map()}
  def get_enhancement_stats() do
    GenServer.call(__MODULE__, :get_enhancement_stats)
  end
  
  @doc """
  Clears enhancement caches.
  """
  @spec clear_caches() :: :ok
  def clear_caches() do
    GenServer.call(__MODULE__, :clear_caches)
  end
  
  # GenServer Callbacks
  
  def handle_call({:reconstruct_state_with_ast, session_id, timestamp, ast_repo}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    case reconstruct_state_with_ast_internal(session_id, timestamp, ast_repo || state.ast_repo, state) do
      {:ok, enhanced_state} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        # Update statistics
        new_stats = update_enhancement_stats(state.enhancement_stats, :reconstruction, duration)
        new_state = %{state | enhancement_stats: new_stats}
        
        {:reply, {:ok, enhanced_state}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:get_ast_execution_trace, session_id, start_time, end_time}, _from, state) do
    case get_ast_execution_trace_internal(session_id, start_time, end_time, state) do
      {:ok, trace} ->
        {:reply, {:ok, trace}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:get_states_for_ast_node, session_id, ast_node_id}, _from, state) do
    case get_states_for_ast_node_internal(session_id, ast_node_id, state) do
      {:ok, states} ->
        {:reply, {:ok, states}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:get_execution_flow_between_nodes, session_id, from_node, to_node, time_range}, _from, state) do
    case get_execution_flow_internal(session_id, from_node, to_node, time_range, state) do
      {:ok, flow} ->
        {:reply, {:ok, flow}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:set_enhancement_enabled, enabled}, _from, state) do
    new_state = %{state | enabled: enabled}
    Logger.info("TemporalBridge AST enhancement #{if enabled, do: "enabled", else: "disabled"}")
    {:reply, :ok, new_state}
  end
  
  def handle_call(:get_enhancement_stats, _from, state) do
    stats = %{
      enhancement: state.enhancement_stats,
      cache: state.cache_stats,
      enabled: state.enabled
    }
    
    {:reply, {:ok, stats}, state}
  end
  
  def handle_call(:clear_caches, _from, state) do
    :ets.delete_all_objects(@ast_state_cache)
    :ets.delete_all_objects(@execution_trace_cache)
    
    new_cache_stats = %{
      state_cache_size: 0,
      trace_cache_size: 0,
      evictions: state.cache_stats.evictions
    }
    
    new_state = %{state | cache_stats: new_cache_stats}
    {:reply, :ok, new_state}
  end
  
  # Private Implementation
  
  defp reconstruct_state_with_ast_internal(session_id, timestamp, ast_repo, state) do
    if not state.enabled do
      # Fall back to standard reconstruction without AST
      original_state_result = case state.temporal_bridge do
        nil ->
          # No TemporalBridge available, create a mock state
          {:ok, %{session_id: session_id, timestamp: timestamp, mock: true}}
        
        bridge_ref ->
          # Use the actual TemporalBridge
          TemporalBridge.reconstruct_state_at(bridge_ref, timestamp)
      end
      
      case original_state_result do
        {:ok, original_state} ->
          enhanced_state = %{
            original_state: original_state,
            ast_context: nil,
            structural_info: %{},
            execution_path: [],
            variable_flow: %{},
            timestamp: timestamp
          }
          {:ok, enhanced_state}
        
        error -> error
      end
    else
      # Check cache first
      cache_key = "#{session_id}:#{timestamp}"
      
      case :ets.lookup(@ast_state_cache, cache_key) do
        [{^cache_key, {enhanced_state, cached_timestamp}}] ->
          if System.monotonic_time(:millisecond) - cached_timestamp < @cache_ttl do
            # Cache hit
            {:ok, enhanced_state}
          else
            # Cache expired
            :ets.delete(@ast_state_cache, cache_key)
            reconstruct_state_fresh(session_id, timestamp, ast_repo, state)
          end
        
        [] ->
          # Cache miss
          reconstruct_state_fresh(session_id, timestamp, ast_repo, state)
      end
    end
  end
  
  defp reconstruct_state_fresh(session_id, timestamp, ast_repo, state) do
    # Try to reconstruct state using TemporalBridge if available
    original_state_result = case state.temporal_bridge do
      nil ->
        # No TemporalBridge available, create a mock state
        {:ok, %{session_id: session_id, timestamp: timestamp, mock: true}}
      
      bridge_ref ->
        # Use the actual TemporalBridge
        TemporalBridge.reconstruct_state_at(bridge_ref, timestamp)
    end
    
    with {:ok, original_state} <- original_state_result,
         {:ok, events} <- get_events_for_reconstruction(session_id, timestamp, state),
         {:ok, ast_context} <- build_ast_context_for_state(events, ast_repo),
         {:ok, structural_info} <- extract_structural_info_for_state(ast_context, events),
         {:ok, execution_path} <- build_execution_path(events, ast_repo),
         {:ok, variable_flow} <- build_variable_flow_for_state(events) do
      
      enhanced_state = %{
        original_state: original_state,
        ast_context: ast_context,
        structural_info: structural_info,
        execution_path: execution_path,
        variable_flow: variable_flow,
        timestamp: timestamp
      }
      
      # Cache the result
      cache_timestamp = System.monotonic_time(:millisecond)
      :ets.insert(@ast_state_cache, {"#{session_id}:#{timestamp}", {enhanced_state, cache_timestamp}})
      
      {:ok, enhanced_state}
    else
      error -> error
    end
  end
  
  defp get_ast_execution_trace_internal(session_id, start_time, end_time, state) do
    # Check cache first
    cache_key = "trace:#{session_id}:#{start_time}:#{end_time}"
    
    case :ets.lookup(@execution_trace_cache, cache_key) do
      [{^cache_key, {trace, cached_timestamp}}] ->
        if System.monotonic_time(:millisecond) - cached_timestamp < @cache_ttl do
          {:ok, trace}
        else
          :ets.delete(@execution_trace_cache, cache_key)
          build_ast_execution_trace(session_id, start_time, end_time, state)
        end
      
      [] ->
        build_ast_execution_trace(session_id, start_time, end_time, state)
    end
  end
  
  defp build_ast_execution_trace(session_id, start_time, end_time, state) do
    with {:ok, events} <- get_events_in_range(session_id, start_time, end_time, state),
         {:ok, enhanced_events} <- enhance_events_with_ast(events, state.ast_repo),
         {:ok, ast_flow} <- build_ast_flow_from_events(enhanced_events),
         {:ok, state_transitions} <- build_state_transitions(session_id, enhanced_events, state),
         {:ok, structural_patterns} <- identify_structural_patterns_in_trace(enhanced_events) do
      
      trace = %{
        events: enhanced_events,
        ast_flow: ast_flow,
        state_transitions: state_transitions,
        structural_patterns: structural_patterns,
        execution_metadata: %{
          session_id: session_id,
          start_time: start_time,
          end_time: end_time,
          event_count: length(events),
          created_at: System.system_time(:nanosecond)
        }
      }
      
      # Cache the result
      cache_timestamp = System.monotonic_time(:millisecond)
      cache_key = "trace:#{session_id}:#{start_time}:#{end_time}"
      :ets.insert(@execution_trace_cache, {cache_key, {trace, cache_timestamp}})
      
      {:ok, trace}
    else
      error -> error
    end
  end
  
  defp get_states_for_ast_node_internal(session_id, ast_node_id, state) do
    with {:ok, events} <- get_events_for_ast_node(session_id, ast_node_id, state),
         {:ok, states} <- reconstruct_states_for_events(session_id, events, state) do
      {:ok, states}
    else
      error -> error
    end
  end
  
  defp get_execution_flow_internal(session_id, from_node, to_node, time_range, state) do
    with {:ok, from_events} <- get_events_for_ast_node(session_id, from_node, state),
         {:ok, to_events} <- get_events_for_ast_node(session_id, to_node, state),
         {:ok, flow_events} <- find_flow_events_between_nodes(from_events, to_events, time_range),
         {:ok, flow_states} <- reconstruct_states_for_events(session_id, flow_events, state) do
      
      flow = %{
        from_ast_node_id: from_node,
        to_ast_node_id: to_node,
        flow_events: flow_events,
        flow_states: flow_states,
        execution_paths: build_execution_paths_between_nodes(flow_events),
        time_range: time_range
      }
      
      {:ok, flow}
    else
      error -> error
    end
  end
  
  # Helper Functions
  
  defp get_events_for_reconstruction(session_id, timestamp, state) do
    # Get events leading up to the timestamp for context
    case state.event_store do
      nil ->
        # No EventStore available, return empty events
        {:ok, []}
      
      event_store ->
        case EventStore.query_events(event_store, %{
          session_id: session_id,
          timestamp_until: timestamp,
          limit: 100,
          order: :desc
        }) do
          {:ok, events} -> {:ok, Enum.reverse(events)}
          error -> error
        end
    end
  end
  
  defp build_ast_context_for_state(events, ast_repo) do
    # Get the most recent event with AST correlation
    case Enum.find(events, fn event -> Map.has_key?(event, :ast_node_id) end) do
      nil -> {:ok, nil}
      event ->
        case RuntimeCorrelator.get_runtime_context(ast_repo, event) do
          {:ok, context} -> {:ok, context}
          {:error, _} -> {:ok, nil}
        end
    end
  end
  
  defp extract_structural_info_for_state(ast_context, events) do
    structural_info = %{
      current_ast_node: extract_current_ast_node(ast_context),
      call_depth: calculate_call_depth(events),
      execution_context: extract_execution_context(events),
      control_flow_state: determine_control_flow_state(ast_context, events)
    }
    
    {:ok, structural_info}
  end
  
  defp build_execution_path(events, ast_repo) do
    execution_path = events
    |> Enum.filter(fn event -> Map.has_key?(event, :ast_node_id) end)
    |> Enum.map(fn event ->
      %{
        ast_node_id: event.ast_node_id,
        timestamp: Map.get(event, :timestamp),
        event_type: Map.get(event, :event_type),
        context: extract_event_context(event)
      }
    end)
    
    {:ok, execution_path}
  end
  
  defp build_variable_flow_for_state(events) do
    variable_flow = events
    |> Enum.filter(fn event -> Map.has_key?(event, :variables) end)
    |> Enum.reduce(%{}, fn event, acc ->
      variables = Map.get(event, :variables, %{})
      timestamp = Map.get(event, :timestamp)
      
      Enum.reduce(variables, acc, fn {var_name, var_value}, var_acc ->
        var_history = Map.get(var_acc, var_name, [])
        var_entry = %{value: var_value, timestamp: timestamp}
        Map.put(var_acc, var_name, [var_entry | var_history])
      end)
    end)
    |> Enum.map(fn {var_name, history} ->
      {var_name, Enum.reverse(history)}
    end)
    |> Enum.into(%{})
    
    {:ok, variable_flow}
  end
  
  defp get_events_in_range(session_id, start_time, end_time, state) do
    case state.event_store do
      nil ->
        # No EventStore available, return empty events
        {:ok, []}
      
      event_store ->
        case EventStore.query_events(event_store, %{
          session_id: session_id,
          timestamp_since: start_time,
          timestamp_until: end_time,
          order: :asc
        }) do
          {:ok, events} -> {:ok, events}
          error -> error
        end
    end
  end
  
  defp enhance_events_with_ast(events, ast_repo) do
    enhanced_events = Enum.map(events, fn event ->
      case RuntimeCorrelator.enhance_event_with_ast(ast_repo, event) do
        {:ok, enhanced_event} -> enhanced_event
        {:error, _} -> 
          # Fallback to original event
          %{
            original_event: event,
            ast_context: nil,
            correlation_metadata: %{},
            structural_info: %{},
            data_flow_info: %{}
          }
      end
    end)
    
    {:ok, enhanced_events}
  end
  
  defp build_ast_flow_from_events(enhanced_events) do
    ast_flow = enhanced_events
    |> Enum.filter(fn event -> not is_nil(event.ast_context) end)
    |> Enum.map(fn event ->
      %{
        ast_node_id: event.ast_context.ast_node_id,
        timestamp: Map.get(event.original_event, :timestamp),
        event_type: Map.get(event.original_event, :event_type),
        structural_info: event.structural_info
      }
    end)
    
    {:ok, ast_flow}
  end
  
  defp build_state_transitions(session_id, enhanced_events, state) do
    # Get state snapshots at key transition points
    transition_timestamps = enhanced_events
    |> Enum.filter(fn event -> 
      event_type = Map.get(event.original_event, :event_type)
      event_type in [:function_entry, :function_exit, :state_change]
    end)
    |> Enum.map(fn event -> Map.get(event.original_event, :timestamp) end)
    |> Enum.uniq()
    
    transitions = Enum.map(transition_timestamps, fn timestamp ->
      case reconstruct_state_with_ast_internal(session_id, timestamp, state.ast_repo, state) do
        {:ok, enhanced_state} -> enhanced_state
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)
    
    {:ok, transitions}
  end
  
  defp identify_structural_patterns_in_trace(enhanced_events) do
    patterns = enhanced_events
    |> Enum.filter(fn event -> not is_nil(event.structural_info) end)
    |> Enum.group_by(fn event -> 
      Map.get(event.structural_info, :ast_node_type, :unknown)
    end)
    |> Enum.map(fn {pattern_type, events} ->
      %{
        pattern_type: pattern_type,
        occurrences: length(events),
        first_occurrence: get_first_timestamp(events),
        last_occurrence: get_last_timestamp(events),
        frequency: calculate_pattern_frequency(events)
      }
    end)
    
    {:ok, patterns}
  end
  
  defp get_events_for_ast_node(session_id, ast_node_id, state) do
    case state.event_store do
      nil ->
        # No EventStore available, return empty events
        {:ok, []}
      
      event_store ->
        case EventStore.query_events(event_store, %{
          session_id: session_id,
          ast_node_id: ast_node_id,
          order: :asc
        }) do
          {:ok, events} -> {:ok, events}
          error -> error
        end
    end
  end
  
  defp reconstruct_states_for_events(session_id, events, state) do
    timestamps = events
    |> Enum.map(fn event -> Map.get(event, :timestamp) end)
    |> Enum.uniq()
    
    states = Enum.map(timestamps, fn timestamp ->
      case reconstruct_state_with_ast_internal(session_id, timestamp, state.ast_repo, state) do
        {:ok, enhanced_state} -> enhanced_state
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)
    
    {:ok, states}
  end
  
  defp find_flow_events_between_nodes(from_events, to_events, time_range) do
    # Find events that occur between from_node and to_node executions
    from_timestamps = Enum.map(from_events, fn event -> Map.get(event, :timestamp) end)
    to_timestamps = Enum.map(to_events, fn event -> Map.get(event, :timestamp) end)
    
    # Simple implementation - find events between first from and first to
    case {from_timestamps, to_timestamps} do
      {[from_time | _], [to_time | _]} when from_time < to_time ->
        # Filter events in the time range
        flow_events = (from_events ++ to_events)
        |> Enum.filter(fn event ->
          timestamp = Map.get(event, :timestamp)
          timestamp >= from_time and timestamp <= to_time
        end)
        |> Enum.sort_by(fn event -> Map.get(event, :timestamp) end)
        
        {:ok, flow_events}
      
      _ ->
        {:ok, []}
    end
  end
  
  defp build_execution_paths_between_nodes(flow_events) do
    flow_events
    |> Enum.map(fn event ->
      %{
        ast_node_id: Map.get(event, :ast_node_id),
        timestamp: Map.get(event, :timestamp),
        event_type: Map.get(event, :event_type)
      }
    end)
  end
  
  # Utility Functions
  
  defp update_enhancement_stats(stats, operation, duration) do
    case operation do
      :reconstruction ->
        new_count = stats.states_reconstructed + 1
        new_avg = (stats.avg_reconstruction_time * (new_count - 1) + duration) / new_count
        
        %{stats | 
          states_reconstructed: new_count,
          avg_reconstruction_time: new_avg
        }
      
      :ast_context ->
        %{stats | ast_contexts_added: stats.ast_contexts_added + 1}
      
      :cache_hit ->
        %{stats | cache_hits: stats.cache_hits + 1}
      
      :cache_miss ->
        %{stats | cache_misses: stats.cache_misses + 1}
    end
  end
  
  defp extract_current_ast_node(nil), do: nil
  defp extract_current_ast_node(ast_context), do: Map.get(ast_context, :ast_node_id)
  
  defp calculate_call_depth(events) do
    events
    |> Enum.filter(fn event -> Map.get(event, :event_type) in [:function_entry, :function_exit] end)
    |> Enum.reduce(0, fn event, depth ->
      case Map.get(event, :event_type) do
        :function_entry -> depth + 1
        :function_exit -> max(0, depth - 1)
        _ -> depth
      end
    end)
  end
  
  defp extract_execution_context(events) do
    %{
      total_events: length(events),
      event_types: events |> Enum.map(fn event -> Map.get(event, :event_type) end) |> Enum.frequencies(),
      time_span: calculate_time_span(events)
    }
  end
  
  defp determine_control_flow_state(_ast_context, events) do
    # Determine current control flow state based on recent events
    recent_events = Enum.take(events, -5)
    
    cond do
      Enum.any?(recent_events, fn event -> Map.get(event, :event_type) == :exception end) ->
        :exception_handling
      
      Enum.any?(recent_events, fn event -> Map.get(event, :event_type) == :function_entry end) ->
        :function_call
      
      Enum.any?(recent_events, fn event -> Map.get(event, :event_type) == :state_change end) ->
        :state_transition
      
      true ->
        :sequential
    end
  end
  
  defp extract_event_context(event) do
    %{
      module: Map.get(event, :module),
      function: Map.get(event, :function),
      line: Map.get(event, :line),
      correlation_id: Map.get(event, :correlation_id)
    }
  end
  
  defp get_first_timestamp(events) do
    events
    |> Enum.map(fn event -> Map.get(event.original_event, :timestamp) end)
    |> Enum.min()
  end
  
  defp get_last_timestamp(events) do
    events
    |> Enum.map(fn event -> Map.get(event.original_event, :timestamp) end)
    |> Enum.max()
  end
  
  defp calculate_pattern_frequency(events) do
    if length(events) < 2 do
      0.0
    else
      time_span = get_last_timestamp(events) - get_first_timestamp(events)
      if time_span > 0 do
        length(events) / (time_span / 1_000_000_000)  # events per second
      else
        0.0
      end
    end
  end
  
  defp calculate_time_span(events) do
    if length(events) < 2 do
      0
    else
      timestamps = Enum.map(events, fn event -> Map.get(event, :timestamp) end)
      Enum.max(timestamps) - Enum.min(timestamps)
    end
  end
end 