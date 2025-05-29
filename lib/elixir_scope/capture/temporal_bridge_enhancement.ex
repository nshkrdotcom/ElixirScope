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
  alias ElixirScope.Capture.TemporalBridgeEnhancement.{
    StateManager,
    TraceBuilder,
    CacheManager,
    EventProcessor,
    Types
  }

  @table_name :temporal_bridge_enhancement_main

  # Performance targets
  @reconstruction_timeout 100  # milliseconds
  @context_lookup_timeout 10   # milliseconds

  defstruct [
    :temporal_bridge,
    :ast_repo,
    :correlator,
    :event_store,
    :enhancement_stats,
    :cache_stats,
    :enabled
  ]

  # Import types from Types module
  @type ast_enhanced_state :: Types.ast_enhanced_state()
  @type ast_execution_trace :: Types.ast_execution_trace()

  # GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Create main ETS table
    CacheManager.create_table(@table_name)

    # Initialize all cache tables
    CacheManager.init_caches()

    state = %__MODULE__{
      temporal_bridge: Keyword.get(opts, :temporal_bridge),
      ast_repo: Keyword.get(opts, :ast_repo),
      correlator: Keyword.get(opts, :correlator, ElixirScope.ASTRepository.RuntimeCorrelator),
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

    case StateManager.reconstruct_state_with_ast(session_id, timestamp, ast_repo || state.ast_repo, state) do
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
    case TraceBuilder.get_ast_execution_trace(session_id, start_time, end_time, state) do
      {:ok, trace} ->
        {:reply, {:ok, trace}, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:get_states_for_ast_node, session_id, ast_node_id}, _from, state) do
    case StateManager.get_states_for_ast_node(session_id, ast_node_id, state) do
      {:ok, states} ->
        {:reply, {:ok, states}, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:get_execution_flow_between_nodes, session_id, from_node, to_node, time_range}, _from, state) do
    case TraceBuilder.get_execution_flow_between_nodes(session_id, from_node, to_node, time_range, state) do
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
    CacheManager.clear_all_caches()

    new_cache_stats = %{
      state_cache_size: 0,
      trace_cache_size: 0,
      evictions: state.cache_stats.evictions
    }

    new_state = %{state | cache_stats: new_cache_stats}
    {:reply, :ok, new_state}
  end

  # Private helper

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
end
