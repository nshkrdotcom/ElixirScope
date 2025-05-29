defmodule ElixirScope.Capture.TemporalBridgeEnhancement.TraceBuilder do
  @moduledoc """
  Execution trace building for TemporalBridgeEnhancement.

  Handles building AST-aware execution traces, analyzing structural patterns,
  and creating execution flows between AST nodes.
  """

  alias ElixirScope.Capture.TemporalBridgeEnhancement.{
    CacheManager,
    EventProcessor,
    StateManager,
    Types
  }

  @type ast_execution_trace :: Types.ast_execution_trace()

  @doc """
  Gets an AST-aware execution trace for a time range.
  """
  @spec get_ast_execution_trace(String.t(), non_neg_integer(), non_neg_integer(), map()) ::
    {:ok, ast_execution_trace()} | {:error, term()}
  def get_ast_execution_trace(session_id, start_time, end_time, state) do
    # Check cache first
    case CacheManager.get_cached_trace(session_id, start_time, end_time) do
      {:hit, trace} ->
        {:ok, trace}

      {:miss, _reason} ->
        build_ast_execution_trace(session_id, start_time, end_time, state)
    end
  end

  @doc """
  Gets execution flow between two AST nodes.
  """
  @spec get_execution_flow_between_nodes(String.t(), String.t(), String.t(), tuple() | nil, map()) ::
    {:ok, map()} | {:error, term()}
  def get_execution_flow_between_nodes(session_id, from_node, to_node, time_range, state) do
    with {:ok, from_events} <- EventProcessor.get_events_for_ast_node(session_id, from_node, state),
         {:ok, to_events} <- EventProcessor.get_events_for_ast_node(session_id, to_node, state),
         {:ok, flow_events} <- EventProcessor.find_flow_events_between_nodes(from_events, to_events, time_range),
         {:ok, flow_states} <- StateManager.reconstruct_states_for_events(session_id, flow_events, state) do

      flow = %{
        from_ast_node_id: from_node,
        to_ast_node_id: to_node,
        flow_events: flow_events,
        flow_states: flow_states,
        execution_paths: EventProcessor.build_execution_paths_between_nodes(flow_events),
        time_range: time_range
      }

      {:ok, flow}
    else
      error -> error
    end
  end

  # Private functions

  defp build_ast_execution_trace(session_id, start_time, end_time, state) do
    with {:ok, events} <- EventProcessor.get_events_in_range(session_id, start_time, end_time, state),
         {:ok, enhanced_events} <- EventProcessor.enhance_events_with_ast(events, state.ast_repo),
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
      CacheManager.cache_trace(session_id, start_time, end_time, trace)

      {:ok, trace}
    else
      error -> error
    end
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
      case StateManager.reconstruct_state_with_ast(session_id, timestamp, state.ast_repo, state) do
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

  # Utility functions

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
end
