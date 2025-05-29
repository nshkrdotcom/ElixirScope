defmodule ElixirScope.Capture.TemporalBridgeEnhancement.StateManager do
  @moduledoc """
  State management for TemporalBridgeEnhancement.

  Handles AST-enhanced state reconstruction, building AST contexts,
  and managing state-related operations.
  """

  alias ElixirScope.Capture.TemporalBridge
  alias ElixirScope.Capture.TemporalBridgeEnhancement.{
    CacheManager,
    EventProcessor,
    ASTContextBuilder,
    Types
  }

  @type ast_enhanced_state :: Types.ast_enhanced_state()

  @doc """
  Reconstructs state at a specific timestamp with AST context.
  """
  @spec reconstruct_state_with_ast(String.t(), non_neg_integer(), pid() | nil, map()) ::
    {:ok, ast_enhanced_state()} | {:error, term()}
  def reconstruct_state_with_ast(session_id, timestamp, ast_repo, state) do
    if not state.enabled do
      # Fall back to standard reconstruction without AST
      fallback_reconstruction(session_id, timestamp, state)
    else
      # Check cache first
      case CacheManager.get_cached_state(session_id, timestamp) do
        {:hit, enhanced_state} ->
          {:ok, enhanced_state}

        {:miss, _reason} ->
          reconstruct_state_fresh(session_id, timestamp, ast_repo, state)
      end
    end
  end

  @doc """
  Gets all states associated with a specific AST node.
  """
  @spec get_states_for_ast_node(String.t(), String.t(), map()) ::
    {:ok, list(ast_enhanced_state())} | {:error, term()}
  def get_states_for_ast_node(session_id, ast_node_id, state) do
    with {:ok, events} <- EventProcessor.get_events_for_ast_node(session_id, ast_node_id, state),
         {:ok, states} <- reconstruct_states_for_events(session_id, events, state) do
      {:ok, states}
    else
      error -> error
    end
  end

  @doc """
  Reconstructs states for a list of events.
  """
  @spec reconstruct_states_for_events(String.t(), list(map()), map()) ::
    {:ok, list(ast_enhanced_state())} | {:error, term()}
  def reconstruct_states_for_events(session_id, events, state) do
    timestamps = events
    |> Enum.map(fn event -> Map.get(event, :timestamp) end)
    |> Enum.uniq()

    states = Enum.map(timestamps, fn timestamp ->
      case reconstruct_state_with_ast(session_id, timestamp, state.ast_repo, state) do
        {:ok, enhanced_state} -> enhanced_state
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)

    {:ok, states}
  end

  # Private functions

  defp fallback_reconstruction(session_id, timestamp, state) do
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
         {:ok, events} <- EventProcessor.get_events_for_reconstruction(session_id, timestamp, state),
         {:ok, ast_context} <- ASTContextBuilder.build_ast_context_for_state(events, ast_repo),
         {:ok, structural_info} <- ASTContextBuilder.extract_structural_info_for_state(ast_context, events),
         {:ok, execution_path} <- ASTContextBuilder.build_execution_path(events, ast_repo),
         {:ok, variable_flow} <- ASTContextBuilder.build_variable_flow_for_state(events) do

      enhanced_state = %{
        original_state: original_state,
        ast_context: ast_context,
        structural_info: structural_info,
        execution_path: execution_path,
        variable_flow: variable_flow,
        timestamp: timestamp
      }

      # Cache the result
      CacheManager.cache_state(session_id, timestamp, enhanced_state)

      {:ok, enhanced_state}
    else
      error -> error
    end
  end
end
