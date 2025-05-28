defmodule ElixirScope.Capture.EnhancedInstrumentation do
  @moduledoc """
  Enhanced Instrumentation Integration for AST-Runtime Correlation.
  
  Extends the existing InstrumentationRuntime with revolutionary debugging features:
  
  - **Structural Breakpoints**: Break on AST patterns during execution
  - **Data Flow Breakpoints**: Break when variables flow through specific AST paths  
  - **Semantic Watchpoints**: Track variables through AST structure
  - **AST-Aware Event Capture**: Enhanced event capture with AST metadata
  
  ## Integration Points
  
  - InstrumentationRuntime: Enhanced event capture
  - RuntimeCorrelator: AST-Runtime correlation
  - Enhanced AST Repository: Structural analysis
  - EventStore: AST-enhanced event storage
  
  ## Performance Targets
  
  - Breakpoint evaluation: <100µs per event
  - AST correlation overhead: <50µs per event
  - Memory overhead: <5% of base instrumentation
  
  ## Examples
  
      # Enable enhanced instrumentation
      EnhancedInstrumentation.enable_ast_correlation()
      
      # Set structural breakpoint
      EnhancedInstrumentation.set_structural_breakpoint(%{
        pattern: quote(do: {:handle_call, _, _}),
        condition: :pattern_match_failure
      })
      
      # Set data flow breakpoint
      EnhancedInstrumentation.set_data_flow_breakpoint(%{
        variable: "user_id",
        ast_path: ["MyModule", "authenticate"]
      })
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.Capture.InstrumentationRuntime
  alias ElixirScope.ASTRepository.RuntimeCorrelator
  alias ElixirScope.ASTRepository.EnhancedRepository
  alias ElixirScope.Events
  
  @table_name :enhanced_instrumentation_main
  @breakpoint_table :enhanced_instrumentation_breakpoints
  @watchpoint_table :enhanced_instrumentation_watchpoints
  
  # Performance targets
  @breakpoint_eval_timeout 100  # microseconds
  @correlation_timeout 50       # microseconds
  
  defstruct [
    :ast_repo,
    :correlator,
    :enabled,
    :breakpoint_stats,
    :correlation_stats,
    :event_hooks,
    :ast_correlation_enabled
  ]
  
  @type breakpoint_condition :: :any | :pattern_match_failure | :exception | :slow_execution | :high_memory
  @type flow_condition :: :assignment | :pattern_match | :function_call | :pipe_operator | :case_clause
  
  # GenServer API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    # Create ETS tables for breakpoints and watchpoints (handle existing tables gracefully)
    try do
      :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    rescue
      ArgumentError -> 
        # Table already exists, clear it
        :ets.delete_all_objects(@table_name)
    end
    
    try do
      :ets.new(@breakpoint_table, [:named_table, :public, :set, {:read_concurrency, true}])
    rescue
      ArgumentError -> 
        # Table already exists, clear it
        :ets.delete_all_objects(@breakpoint_table)
    end
    
    try do
      :ets.new(@watchpoint_table, [:named_table, :public, :set, {:read_concurrency, true}])
    rescue
      ArgumentError -> 
        # Table already exists, clear it
        :ets.delete_all_objects(@watchpoint_table)
    end
    
    state = %__MODULE__{
      ast_repo: Keyword.get(opts, :ast_repo),
      correlator: Keyword.get(opts, :correlator, RuntimeCorrelator),
      enabled: Keyword.get(opts, :enabled, false),
      breakpoint_stats: %{
        structural_hits: 0,
        data_flow_hits: 0,
        evaluations: 0,
        avg_eval_time: 0.0
      },
      correlation_stats: %{
        events_correlated: 0,
        correlation_failures: 0,
        avg_correlation_time: 0.0
      },
      event_hooks: %{},
      ast_correlation_enabled: Keyword.get(opts, :ast_correlation_enabled, true)
    }
    
    # Register event hooks with InstrumentationRuntime
    register_event_hooks()
    
    Logger.info("EnhancedInstrumentation started with AST correlation: #{state.ast_correlation_enabled}")
    {:ok, state}
  end
  
  # Public API
  
  @doc """
  Enables AST correlation for all instrumentation events.
  
  When enabled, all events captured by InstrumentationRuntime will be
  enhanced with AST metadata and correlation information.
  """
  @spec enable_ast_correlation() :: :ok
  def enable_ast_correlation() do
    GenServer.call(__MODULE__, :enable_ast_correlation)
  end
  
  @doc """
  Disables AST correlation to reduce overhead.
  """
  @spec disable_ast_correlation() :: :ok
  def disable_ast_correlation() do
    GenServer.call(__MODULE__, :disable_ast_correlation)
  end
  
  @doc """
  Sets a structural breakpoint that triggers on AST patterns.
  
  ## Parameters
  
  - `breakpoint_spec` - Structural breakpoint specification
  
  ## Examples
  
      # Break on any GenServer handle_call pattern match failure
      EnhancedInstrumentation.set_structural_breakpoint(%{
        id: "genserver_pattern_fail",
        pattern: quote(do: {:handle_call, _, _}),
        condition: :pattern_match_failure,
        ast_path: ["MyGenServer"],
        enabled: true
      })
  """
  @spec set_structural_breakpoint(map()) :: {:ok, String.t()} | {:error, term()}
  def set_structural_breakpoint(breakpoint_spec) do
    GenServer.call(__MODULE__, {:set_structural_breakpoint, breakpoint_spec})
  end
  
  @doc """
  Sets a data flow breakpoint that triggers on variable flow.
  
  ## Parameters
  
  - `breakpoint_spec` - Data flow breakpoint specification
  
  ## Examples
  
      # Break when user_id flows through authentication
      EnhancedInstrumentation.set_data_flow_breakpoint(%{
        id: "user_auth_flow",
        variable: "user_id",
        ast_path: ["MyModule", "authenticate"],
        flow_conditions: [:assignment, :pattern_match],
        enabled: true
      })
  """
  @spec set_data_flow_breakpoint(map()) :: {:ok, String.t()} | {:error, term()}
  def set_data_flow_breakpoint(breakpoint_spec) do
    GenServer.call(__MODULE__, {:set_data_flow_breakpoint, breakpoint_spec})
  end
  
  @doc """
  Sets a semantic watchpoint that tracks variables through AST structure.
  
  ## Parameters
  
  - `watchpoint_spec` - Semantic watchpoint specification
  
  ## Examples
  
      # Watch state variable through GenServer lifecycle
      EnhancedInstrumentation.set_semantic_watchpoint(%{
        id: "state_tracking",
        variable: "state",
        track_through: [:pattern_match, :function_call],
        ast_scope: "MyGenServer.handle_call/3",
        enabled: true
      })
  """
  @spec set_semantic_watchpoint(map()) :: {:ok, String.t()} | {:error, term()}
  def set_semantic_watchpoint(watchpoint_spec) do
    GenServer.call(__MODULE__, {:set_semantic_watchpoint, watchpoint_spec})
  end
  
  @doc """
  Removes a breakpoint or watchpoint by ID.
  """
  @spec remove_breakpoint(String.t()) :: :ok
  def remove_breakpoint(breakpoint_id) do
    GenServer.call(__MODULE__, {:remove_breakpoint, breakpoint_id})
  end
  
  @doc """
  Lists all active breakpoints and watchpoints.
  """
  @spec list_breakpoints() :: {:ok, map()}
  def list_breakpoints() do
    GenServer.call(__MODULE__, :list_breakpoints)
  end
  
  @doc """
  Gets enhanced instrumentation statistics.
  """
  @spec get_stats() :: {:ok, map()}
  def get_stats() do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Enhanced function entry reporting with AST correlation.
  
  This is called by the enhanced AST transformer to report function entries
  with full AST context and breakpoint evaluation.
  """
  @spec report_enhanced_function_entry(module(), atom(), list(), String.t(), String.t()) :: :ok
  def report_enhanced_function_entry(module, function, args, correlation_id, ast_node_id) do
    GenServer.cast(__MODULE__, {:enhanced_function_entry, module, function, args, correlation_id, ast_node_id})
  end
  
  @doc """
  Enhanced function exit reporting with AST correlation.
  """
  @spec report_enhanced_function_exit(String.t(), term(), non_neg_integer(), String.t()) :: :ok
  def report_enhanced_function_exit(correlation_id, return_value, duration_ns, ast_node_id) do
    GenServer.cast(__MODULE__, {:enhanced_function_exit, correlation_id, return_value, duration_ns, ast_node_id})
  end
  
  @doc """
  Enhanced variable snapshot reporting with semantic analysis.
  """
  @spec report_enhanced_variable_snapshot(String.t(), map(), non_neg_integer(), String.t()) :: :ok
  def report_enhanced_variable_snapshot(correlation_id, variables, line, ast_node_id) do
    GenServer.cast(__MODULE__, {:enhanced_variable_snapshot, correlation_id, variables, line, ast_node_id})
  end
  
  # GenServer Callbacks
  
  def handle_call(:enable_ast_correlation, _from, state) do
    new_state = %{state | ast_correlation_enabled: true}
    Logger.info("AST correlation enabled for enhanced instrumentation")
    {:reply, :ok, new_state}
  end
  
  def handle_call(:disable_ast_correlation, _from, state) do
    new_state = %{state | ast_correlation_enabled: false}
    Logger.info("AST correlation disabled for enhanced instrumentation")
    {:reply, :ok, new_state}
  end
  
  def handle_call({:set_structural_breakpoint, breakpoint_spec}, _from, state) do
    case create_structural_breakpoint(breakpoint_spec) do
      {:ok, breakpoint_id, breakpoint} ->
        :ets.insert(@breakpoint_table, {breakpoint_id, {:structural, breakpoint}})
        Logger.info("Structural breakpoint set: #{breakpoint_id}")
        {:reply, {:ok, breakpoint_id}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:set_data_flow_breakpoint, breakpoint_spec}, _from, state) do
    case create_data_flow_breakpoint(breakpoint_spec) do
      {:ok, breakpoint_id, breakpoint} ->
        :ets.insert(@breakpoint_table, {breakpoint_id, {:data_flow, breakpoint}})
        Logger.info("Data flow breakpoint set: #{breakpoint_id}")
        {:reply, {:ok, breakpoint_id}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:set_semantic_watchpoint, watchpoint_spec}, _from, state) do
    case create_semantic_watchpoint(watchpoint_spec) do
      {:ok, watchpoint_id, watchpoint} ->
        :ets.insert(@watchpoint_table, {watchpoint_id, watchpoint})
        Logger.info("Semantic watchpoint set: #{watchpoint_id}")
        {:reply, {:ok, watchpoint_id}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:remove_breakpoint, breakpoint_id}, _from, state) do
    :ets.delete(@breakpoint_table, breakpoint_id)
    :ets.delete(@watchpoint_table, breakpoint_id)
    Logger.info("Breakpoint/watchpoint removed: #{breakpoint_id}")
    {:reply, :ok, state}
  end
  
  def handle_call(:list_breakpoints, _from, state) do
    structural_breakpoints = :ets.select(@breakpoint_table, [
      {{:'$1', {:structural, :'$2'}}, [], [{{:'$1', :'$2'}}]}
    ]) |> Enum.into(%{})
    
    data_flow_breakpoints = :ets.select(@breakpoint_table, [
      {{:'$1', {:data_flow, :'$2'}}, [], [{{:'$1', :'$2'}}]}
    ]) |> Enum.into(%{})
    
    semantic_watchpoints = :ets.tab2list(@watchpoint_table) |> Enum.into(%{})
    
    breakpoints = %{
      structural: structural_breakpoints,
      data_flow: data_flow_breakpoints,
      semantic: semantic_watchpoints
    }
    
    {:reply, {:ok, breakpoints}, state}
  end
  
  def handle_call(:get_stats, _from, state) do
    stats = %{
      enabled: state.enabled,
      ast_correlation_enabled: state.ast_correlation_enabled,
      breakpoint_stats: state.breakpoint_stats,
      correlation_stats: state.correlation_stats,
      active_breakpoints: %{
        structural: count_breakpoints_by_type(:structural),
        data_flow: count_breakpoints_by_type(:data_flow),
        semantic: :ets.info(@watchpoint_table, :size)
      }
    }
    
    {:reply, {:ok, stats}, state}
  end
  
  def handle_cast({:enhanced_function_entry, module, function, args, correlation_id, ast_node_id}, state) do
    if state.ast_correlation_enabled do
      # Evaluate structural breakpoints
      evaluate_structural_breakpoints(module, function, args, ast_node_id, state)
      
      # Report to standard instrumentation with AST correlation
      InstrumentationRuntime.report_ast_function_entry_with_node_id(
        module, function, args, correlation_id, ast_node_id
      )
      
      # Correlate with AST repository if available
      if state.ast_repo do
        correlate_event_async(state.ast_repo, %{
          event_type: :function_entry,
          module: module,
          function: function,
          arity: length(args),
          correlation_id: correlation_id,
          ast_node_id: ast_node_id,
          timestamp: System.monotonic_time(:nanosecond)
        })
      end
    else
      # Standard reporting without AST correlation
      InstrumentationRuntime.report_function_entry(module, function, args)
    end
    
    {:noreply, state}
  end
  
  def handle_cast({:enhanced_function_exit, correlation_id, return_value, duration_ns, ast_node_id}, state) do
    if state.ast_correlation_enabled do
      # Report to standard instrumentation with AST correlation
      InstrumentationRuntime.report_ast_function_exit_with_node_id(
        correlation_id, return_value, duration_ns, ast_node_id
      )
      
      # Evaluate performance-based breakpoints
      evaluate_performance_breakpoints(duration_ns, ast_node_id, state)
    else
      # Standard reporting without AST correlation
      InstrumentationRuntime.report_function_exit(correlation_id, return_value, duration_ns)
    end
    
    {:noreply, state}
  end
  
  def handle_cast({:enhanced_variable_snapshot, correlation_id, variables, line, ast_node_id}, state) do
    if state.ast_correlation_enabled do
      # Evaluate semantic watchpoints
      evaluate_semantic_watchpoints(variables, ast_node_id, state)
      
      # Evaluate data flow breakpoints
      evaluate_data_flow_breakpoints(variables, ast_node_id, state)
      
      # Report to standard instrumentation with AST correlation
      InstrumentationRuntime.report_ast_variable_snapshot(correlation_id, variables, line, ast_node_id)
    else
      # Standard reporting without AST correlation
      InstrumentationRuntime.report_local_variable_snapshot(correlation_id, variables, line)
    end
    
    {:noreply, state}
  end
  
  # Private Implementation
  
  defp register_event_hooks() do
    # Register hooks with InstrumentationRuntime for event interception
    # This would require extending InstrumentationRuntime to support hooks
    # For now, we'll use the enhanced reporting functions directly
    :ok
  end
  
  defp create_structural_breakpoint(spec) do
    breakpoint_id = Map.get(spec, :id, generate_breakpoint_id("structural"))
    
    breakpoint = %{
      id: breakpoint_id,
      pattern: Map.get(spec, :pattern),
      condition: Map.get(spec, :condition, :any),
      ast_path: Map.get(spec, :ast_path, []),
      enabled: Map.get(spec, :enabled, true),
      hit_count: 0,
      created_at: System.system_time(:nanosecond),
      metadata: Map.get(spec, :metadata, %{})
    }
    
    case validate_structural_breakpoint(breakpoint) do
      :ok -> {:ok, breakpoint_id, breakpoint}
      error -> error
    end
  end
  
  defp create_data_flow_breakpoint(spec) do
    breakpoint_id = Map.get(spec, :id, generate_breakpoint_id("data_flow"))
    
    breakpoint = %{
      id: breakpoint_id,
      variable: Map.get(spec, :variable),
      ast_path: Map.get(spec, :ast_path, []),
      flow_conditions: Map.get(spec, :flow_conditions, [:any]),
      enabled: Map.get(spec, :enabled, true),
      hit_count: 0,
      created_at: System.system_time(:nanosecond),
      metadata: Map.get(spec, :metadata, %{})
    }
    
    case validate_data_flow_breakpoint(breakpoint) do
      :ok -> {:ok, breakpoint_id, breakpoint}
      error -> error
    end
  end
  
  defp create_semantic_watchpoint(spec) do
    watchpoint_id = Map.get(spec, :id, generate_watchpoint_id())
    
    watchpoint = %{
      id: watchpoint_id,
      variable: Map.get(spec, :variable),
      track_through: Map.get(spec, :track_through, [:all]),
      ast_scope: Map.get(spec, :ast_scope),
      enabled: Map.get(spec, :enabled, true),
      value_history: [],
      created_at: System.system_time(:nanosecond),
      metadata: Map.get(spec, :metadata, %{})
    }
    
    case validate_semantic_watchpoint(watchpoint) do
      :ok -> {:ok, watchpoint_id, watchpoint}
      error -> error
    end
  end
  
  defp evaluate_structural_breakpoints(module, function, args, ast_node_id, _state) do
    start_time = System.monotonic_time(:microsecond)
    
    # Get all structural breakpoints
    structural_breakpoints = :ets.select(@breakpoint_table, [
      {{:'$1', {:structural, :'$2'}}, [], [:'$2']}
    ])
    
    Enum.each(structural_breakpoints, fn breakpoint ->
      if breakpoint.enabled and matches_structural_pattern?(module, function, args, breakpoint) do
        trigger_structural_breakpoint(breakpoint, ast_node_id)
      end
    end)
    
    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time
    
    if duration > @breakpoint_eval_timeout do
      Logger.warning("Structural breakpoint evaluation took #{duration}µs (target: #{@breakpoint_eval_timeout}µs)")
    end
  end
  
  defp evaluate_data_flow_breakpoints(variables, ast_node_id, _state) do
    # Get all data flow breakpoints
    data_flow_breakpoints = :ets.select(@breakpoint_table, [
      {{:'$1', {:data_flow, :'$2'}}, [], [:'$2']}
    ])
    
    Enum.each(data_flow_breakpoints, fn breakpoint ->
      if breakpoint.enabled and matches_data_flow_pattern?(variables, breakpoint) do
        trigger_data_flow_breakpoint(breakpoint, ast_node_id, variables)
      end
    end)
  end
  
  defp evaluate_semantic_watchpoints(variables, ast_node_id, _state) do
    # Get all semantic watchpoints
    watchpoints = :ets.tab2list(@watchpoint_table)
    
    Enum.each(watchpoints, fn {_id, watchpoint} ->
      if watchpoint.enabled and Map.has_key?(variables, watchpoint.variable) do
        update_semantic_watchpoint(watchpoint, variables[watchpoint.variable], ast_node_id)
      end
    end)
  end
  
  defp evaluate_performance_breakpoints(duration_ns, ast_node_id, _state) do
    # Get performance-based breakpoints
    performance_breakpoints = :ets.select(@breakpoint_table, [
      {{:'$1', {:structural, :'$2'}}, 
       [{:==, {:map_get, :condition, :'$2'}, :slow_execution}], 
       [:'$2']}
    ])
    
    Enum.each(performance_breakpoints, fn breakpoint ->
      threshold = Map.get(breakpoint.metadata, :duration_threshold_ns, 1_000_000)  # 1ms default
      
      if duration_ns > threshold do
        trigger_performance_breakpoint(breakpoint, ast_node_id, duration_ns)
      end
    end)
  end
  
  defp matches_structural_pattern?(module, function, _args, breakpoint) do
    # Simple pattern matching - in practice this would be more sophisticated
    case breakpoint.ast_path do
      [] -> true  # Match any
      [target_module] -> module == String.to_atom(target_module)
      [target_module, target_function] -> 
        module == String.to_atom(target_module) and function == String.to_atom(target_function)
      _ -> false
    end
  end
  
  defp matches_data_flow_pattern?(variables, breakpoint) do
    Map.has_key?(variables, breakpoint.variable)
  end
  
  defp trigger_structural_breakpoint(breakpoint, ast_node_id) do
    Logger.info("🔴 Structural breakpoint triggered: #{breakpoint.id} at #{ast_node_id}")
    
    # Update hit count
    updated_breakpoint = %{breakpoint | hit_count: breakpoint.hit_count + 1}
    :ets.insert(@breakpoint_table, {breakpoint.id, {:structural, updated_breakpoint}})
    
    # Trigger debugger break (would integrate with debugger)
    trigger_debugger_break(:structural, breakpoint, ast_node_id)
  end
  
  defp trigger_data_flow_breakpoint(breakpoint, ast_node_id, variables) do
    Logger.info("🔵 Data flow breakpoint triggered: #{breakpoint.id} at #{ast_node_id}")
    Logger.info("Variable #{breakpoint.variable} = #{inspect(variables[breakpoint.variable])}")
    
    # Update hit count
    updated_breakpoint = %{breakpoint | hit_count: breakpoint.hit_count + 1}
    :ets.insert(@breakpoint_table, {breakpoint.id, {:data_flow, updated_breakpoint}})
    
    # Trigger debugger break
    trigger_debugger_break(:data_flow, breakpoint, ast_node_id, variables)
  end
  
  defp trigger_performance_breakpoint(breakpoint, ast_node_id, duration_ns) do
    Logger.info("🟡 Performance breakpoint triggered: #{breakpoint.id} at #{ast_node_id}")
    Logger.info("Duration: #{duration_ns / 1_000_000}ms")
    
    # Trigger debugger break
    trigger_debugger_break(:performance, breakpoint, ast_node_id, %{duration_ns: duration_ns})
  end
  
  defp update_semantic_watchpoint(watchpoint, value, ast_node_id) do
    # Add value to history
    value_entry = %{
      value: value,
      timestamp: System.monotonic_time(:nanosecond),
      ast_node_id: ast_node_id
    }
    
    updated_history = [value_entry | watchpoint.value_history]
    |> Enum.take(100)  # Keep last 100 values
    
    updated_watchpoint = %{watchpoint | value_history: updated_history}
    :ets.insert(@watchpoint_table, {watchpoint.id, updated_watchpoint})
    
    Logger.debug("📊 Semantic watchpoint updated: #{watchpoint.id} = #{inspect(value)}")
  end
  
  defp trigger_debugger_break(type, breakpoint, ast_node_id, context \\ %{}) do
    # This would integrate with a debugger interface
    # For now, we'll just log and potentially send to a debugging service
    
    break_event = %{
      type: type,
      breakpoint_id: breakpoint.id,
      ast_node_id: ast_node_id,
      context: context,
      timestamp: System.system_time(:nanosecond),
      process: self()
    }
    
    # Send to debugging service or UI
    send_to_debugger(break_event)
  end
  
  defp send_to_debugger(break_event) do
    # This would send the break event to a debugger UI or service
    # For now, we'll just store it in ETS for retrieval
    :ets.insert(@table_name, {:last_break, break_event})
    
    # Could also send to a GenServer that manages debugger UI
    # GenServer.cast(ElixirScope.Debugger.UI, {:breakpoint_hit, break_event})
  end
  
  defp correlate_event_async(ast_repo, event) do
    # Asynchronously correlate event with AST repository
    Task.start(fn ->
      case RuntimeCorrelator.correlate_event_to_ast(ast_repo, event) do
        {:ok, _ast_context} -> :ok
        {:error, reason} -> 
          Logger.debug("AST correlation failed: #{inspect(reason)}")
      end
    end)
  end
  
  # Utility Functions
  
  defp generate_breakpoint_id(type) do
    "#{type}_bp_" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end
  
  defp generate_watchpoint_id() do
    "wp_" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end
  
  defp count_breakpoints_by_type(type) do
    :ets.select(@breakpoint_table, [
      {{:'$1', {type, :'$2'}}, [], [:'$1']}
    ]) |> length()
  end
  
  defp validate_structural_breakpoint(%{pattern: pattern}) when not is_nil(pattern), do: :ok
  defp validate_structural_breakpoint(_), do: {:error, :invalid_pattern}
  
  defp validate_data_flow_breakpoint(%{variable: variable}) when not is_nil(variable), do: :ok
  defp validate_data_flow_breakpoint(_), do: {:error, :invalid_variable}
  
  defp validate_semantic_watchpoint(%{variable: variable}) when not is_nil(variable), do: :ok
  defp validate_semantic_watchpoint(_), do: {:error, :invalid_variable}
end 