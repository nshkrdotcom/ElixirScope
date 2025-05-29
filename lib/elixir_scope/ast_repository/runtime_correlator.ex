defmodule ElixirScope.ASTRepository.RuntimeCorrelator do
  @moduledoc """
  AST-Runtime Correlator for the Enhanced AST Repository.
  
  Provides seamless correlation between static AST analysis and runtime behavior,
  enabling revolutionary debugging features:
  
  - **Structural Breakpoints**: Break on AST patterns during execution
  - **Data Flow Breakpoints**: Break when variables flow through specific AST paths
  - **Semantic Watchpoints**: Track variables through AST structure, not just scope
  - **AST-Aware Execution Traces**: Show code structure during execution replay
  
  ## Performance Targets
  
  - Event correlation: <1ms per event
  - AST context lookup: <10ms
  - Runtime query enhancement: <50ms
  - Memory overhead: <10% of base EventStore
  
  ## Integration Points
  
  - EventStore: ast_node_id correlation
  - InstrumentationRuntime: Enhanced event capture
  - Query Engine: Runtime-aware query optimization
  - Temporal Bridge: AST-enhanced state reconstruction
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.ASTRepository.RuntimeCorrelator.{
    Types,
    EventCorrelator,
    BreakpointManager,
    TraceBuilder,
    CacheManager
  }
  
  @table_name :runtime_correlator_main
  
  # Performance targets
  @correlation_timeout 5000
  @context_lookup_timeout 5000
  @query_enhancement_timeout 5000
  
  defstruct [
    :ast_repo,
    :event_store,
    :correlation_stats,
    :cache_stats,
    :breakpoints,
    :watchpoints
  ]
  
  # GenServer API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    # Initialize ETS table for main correlation data
    CacheManager.init_tables()
    
    state = %__MODULE__{
      ast_repo: Keyword.get(opts, :ast_repo),
      event_store: Keyword.get(opts, :event_store),
      correlation_stats: %{
        events_correlated: 0,
        context_lookups: 0,
        cache_hits: 0,
        cache_misses: 0
      },
      cache_stats: %{
        context_cache_size: 0,
        trace_cache_size: 0,
        evictions: 0
      },
      breakpoints: %{
        structural: %{},
        data_flow: %{},
        semantic: %{}
      },
      watchpoints: %{}
    }
    
    Logger.info("RuntimeCorrelator started with AST-Runtime integration")
    {:ok, state}
  end
  
  # Public API
  
  @doc """
  Correlates a runtime event to precise AST nodes.
  
  Links runtime events to their corresponding AST structure, enabling
  structural debugging and analysis.
  """
  @spec correlate_event_to_ast(pid() | atom(), map()) :: {:ok, Types.ast_context()} | {:error, term()}
  def correlate_event_to_ast(repo, event) do
    GenServer.call(__MODULE__, {:correlate_event_to_ast, repo, event}, @correlation_timeout)
  end
  
  @doc """
  Gets comprehensive AST context for a runtime event.
  
  Provides detailed AST metadata including CFG/DFG context,
  variable scope, and call hierarchy.
  """
  @spec get_runtime_context(pid() | atom(), map()) :: {:ok, Types.ast_context()} | {:error, term()}
  def get_runtime_context(repo, event) do
    GenServer.call(__MODULE__, {:get_runtime_context, repo, event}, @context_lookup_timeout)
  end
  
  @doc """
  Enhances a runtime event with AST metadata.
  
  Enriches runtime events with structural information,
  data flow context, and AST-based insights.
  """
  @spec enhance_event_with_ast(pid() | atom(), map()) :: {:ok, Types.enhanced_event()} | {:error, term()}
  def enhance_event_with_ast(repo, event) do
    GenServer.call(__MODULE__, {:enhance_event_with_ast, repo, event}, @correlation_timeout)
  end
  
  @doc """
  Builds AST-aware execution traces from runtime events.
  
  Creates comprehensive execution traces that show both
  runtime behavior and underlying AST structure.
  """
  @spec build_execution_trace(pid() | atom(), list(map())) :: {:ok, Types.execution_trace()} | {:error, term()}
  def build_execution_trace(repo, events) do
    GenServer.call(__MODULE__, {:build_execution_trace, repo, events}, @query_enhancement_timeout)
  end
  
  @doc "Sets a structural breakpoint based on AST patterns."
  @spec set_structural_breakpoint(map()) :: {:ok, String.t()} | {:error, term()}
  def set_structural_breakpoint(breakpoint_spec) do
    GenServer.call(__MODULE__, {:set_structural_breakpoint, breakpoint_spec})
  end
  
  @doc "Sets a data flow breakpoint for variable tracking."
  @spec set_data_flow_breakpoint(map()) :: {:ok, String.t()} | {:error, term()}
  def set_data_flow_breakpoint(breakpoint_spec) do
    GenServer.call(__MODULE__, {:set_data_flow_breakpoint, breakpoint_spec})
  end
  
  @doc "Sets a semantic watchpoint for variable tracking."
  @spec set_semantic_watchpoint(map()) :: {:ok, String.t()} | {:error, term()}
  def set_semantic_watchpoint(watchpoint_spec) do
    GenServer.call(__MODULE__, {:set_semantic_watchpoint, watchpoint_spec})
  end
  
  @doc "Gets correlation statistics and performance metrics."
  @spec get_correlation_stats() :: {:ok, map()}
  def get_correlation_stats() do
    GenServer.call(__MODULE__, :get_correlation_stats)
  end
  
  @doc "Clears correlation caches and resets statistics."
  @spec clear_caches() :: :ok
  def clear_caches() do
    GenServer.call(__MODULE__, :clear_caches)
  end
  
  # GenServer Callbacks
  
  def handle_call({:correlate_event_to_ast, repo, event}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    case EventCorrelator.correlate_event_to_ast(repo, event, state) do
      {:ok, ast_context} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        new_stats = update_correlation_stats(state.correlation_stats, :correlation, duration)
        new_state = %{state | correlation_stats: new_stats}
        
        {:reply, {:ok, ast_context}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:get_runtime_context, repo, event}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    case EventCorrelator.get_runtime_context(repo, event, state) do
      {:ok, context} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        
        new_stats = update_correlation_stats(state.correlation_stats, :context_lookup, duration)
        new_state = %{state | correlation_stats: new_stats}
        
        {:reply, {:ok, context}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:enhance_event_with_ast, repo, event}, _from, state) do
    case EventCorrelator.enhance_event_with_ast(repo, event, state) do
      {:ok, enhanced_event} ->
        {:reply, {:ok, enhanced_event}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:build_execution_trace, repo, events}, _from, state) do
    case TraceBuilder.build_execution_trace(repo, events) do
      {:ok, trace} ->
        {:reply, {:ok, trace}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:set_structural_breakpoint, breakpoint_spec}, _from, state) do
    case BreakpointManager.create_structural_breakpoint(breakpoint_spec) do
      {:ok, breakpoint_id, breakpoint} ->
        new_structural = Map.put(state.breakpoints.structural, breakpoint_id, breakpoint)
        new_breakpoints = %{state.breakpoints | structural: new_structural}
        new_state = %{state | breakpoints: new_breakpoints}
        
        {:reply, {:ok, breakpoint_id}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:set_data_flow_breakpoint, breakpoint_spec}, _from, state) do
    case BreakpointManager.create_data_flow_breakpoint(breakpoint_spec) do
      {:ok, breakpoint_id, breakpoint} ->
        new_data_flow = Map.put(state.breakpoints.data_flow, breakpoint_id, breakpoint)
        new_breakpoints = %{state.breakpoints | data_flow: new_data_flow}
        new_state = %{state | breakpoints: new_breakpoints}
        
        {:reply, {:ok, breakpoint_id}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:set_semantic_watchpoint, watchpoint_spec}, _from, state) do
    case BreakpointManager.create_semantic_watchpoint(watchpoint_spec) do
      {:ok, watchpoint_id, watchpoint} ->
        new_watchpoints = Map.put(state.watchpoints, watchpoint_id, watchpoint)
        new_state = %{state | watchpoints: new_watchpoints}
        
        {:reply, {:ok, watchpoint_id}, new_state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call(:get_correlation_stats, _from, state) do
    stats = %{
      correlation: state.correlation_stats,
      cache: state.cache_stats,
      breakpoints: %{
        structural: map_size(state.breakpoints.structural),
        data_flow: map_size(state.breakpoints.data_flow)
      },
      watchpoints: map_size(state.watchpoints)
    }
    
    {:reply, {:ok, stats}, state}
  end
  
  def handle_call(:clear_caches, _from, state) do
    CacheManager.clear_all_caches()
    
    new_cache_stats = %{
      context_cache_size: 0,
      trace_cache_size: 0,
      evictions: state.cache_stats.evictions
    }
    
    new_state = %{state | cache_stats: new_cache_stats}
    {:reply, :ok, new_state}
  end
  
  # Private Helper Functions
  
  defp update_correlation_stats(stats, operation, _duration) do
    case operation do
      :correlation ->
        %{stats | events_correlated: stats.events_correlated + 1}
      
      :context_lookup ->
        %{stats | context_lookups: stats.context_lookups + 1}
      
      :cache_hit ->
        %{stats | cache_hits: stats.cache_hits + 1}
      
      :cache_miss ->
        %{stats | cache_misses: stats.cache_misses + 1}
    end
  end
end
