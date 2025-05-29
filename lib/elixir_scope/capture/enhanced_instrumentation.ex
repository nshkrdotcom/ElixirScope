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
  alias ElixirScope.Capture.EnhancedInstrumentation.{
    BreakpointManager,
    WatchpointManager,
    EventHandler,
    Storage
  }

  @type breakpoint_condition :: :any | :pattern_match_failure | :exception | :slow_execution | :high_memory
  @type flow_condition :: :assignment | :pattern_match | :function_call | :pipe_operator | :case_clause

  defstruct [
    :ast_repo,
    :correlator,
    :enabled,
    :breakpoint_stats,
    :correlation_stats,
    :event_hooks,
    :ast_correlation_enabled
  ]

  # GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Initialize storage
    Storage.initialize()

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
    BreakpointManager.set_structural_breakpoint(breakpoint_spec)
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
    BreakpointManager.set_data_flow_breakpoint(breakpoint_spec)
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
    WatchpointManager.set_semantic_watchpoint(watchpoint_spec)
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

  def handle_call({:remove_breakpoint, breakpoint_id}, _from, state) do
    BreakpointManager.remove_breakpoint(breakpoint_id)
    WatchpointManager.remove_watchpoint(breakpoint_id)
    Logger.info("Breakpoint/watchpoint removed: #{breakpoint_id}")
    {:reply, :ok, state}
  end

  def handle_call(:list_breakpoints, _from, state) do
    structural_breakpoints = BreakpointManager.list_structural_breakpoints()
    data_flow_breakpoints = BreakpointManager.list_data_flow_breakpoints()
    semantic_watchpoints = WatchpointManager.list_watchpoints()

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
        structural: BreakpointManager.count_structural_breakpoints(),
        data_flow: BreakpointManager.count_data_flow_breakpoints(),
        semantic: WatchpointManager.count_watchpoints()
      }
    }

    {:reply, {:ok, stats}, state}
  end

  def handle_cast({:enhanced_function_entry, module, function, args, correlation_id, ast_node_id}, state) do
    EventHandler.handle_function_entry(module, function, args, correlation_id, ast_node_id, state)
    {:noreply, state}
  end

  def handle_cast({:enhanced_function_exit, correlation_id, return_value, duration_ns, ast_node_id}, state) do
    EventHandler.handle_function_exit(correlation_id, return_value, duration_ns, ast_node_id, state)
    {:noreply, state}
  end

  def handle_cast({:enhanced_variable_snapshot, correlation_id, variables, line, ast_node_id}, state) do
    EventHandler.handle_variable_snapshot(correlation_id, variables, line, ast_node_id, state)
    {:noreply, state}
  end

  # Private Implementation

  defp register_event_hooks() do
    # Register hooks with InstrumentationRuntime for event interception
    # This would require extending InstrumentationRuntime to support hooks
    # For now, we'll use the enhanced reporting functions directly
    :ok
  end
end
