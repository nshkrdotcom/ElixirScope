defmodule ElixirScope.Capture.TemporalBridgeEnhancement.EventProcessor do
  @moduledoc """
  Event processing utilities for TemporalBridgeEnhancement.

  Handles event queries, filtering, enhancement, and correlation
  with AST information.
  """

  alias ElixirScope.Storage.EventStore
  alias ElixirScope.ASTRepository.RuntimeCorrelator

  @doc """
  Gets events for state reconstruction leading up to a timestamp.
  """
  @spec get_events_for_reconstruction(String.t(), non_neg_integer(), map()) ::
    {:ok, list(map())} | {:error, term()}
  def get_events_for_reconstruction(session_id, timestamp, state) do
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

  @doc """
  Gets events within a specific time range.
  """
  @spec get_events_in_range(String.t(), non_neg_integer(), non_neg_integer(), map()) ::
    {:ok, list(map())} | {:error, term()}
  def get_events_in_range(session_id, start_time, end_time, state) do
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

  @doc """
  Gets events associated with a specific AST node.
  """
  @spec get_events_for_ast_node(String.t(), String.t(), map()) ::
    {:ok, list(map())} | {:error, term()}
  def get_events_for_ast_node(session_id, ast_node_id, state) do
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

  @doc """
  Enhances events with AST correlation information.
  """
  @spec enhance_events_with_ast(list(map()), pid()) :: {:ok, list(map())}
  def enhance_events_with_ast(events, ast_repo) do
    enhanced_events = Enum.map(events, fn event ->
      case RuntimeCorrelator.enhance_event_with_ast(ast_repo, event) do
        {:ok, enhanced_event} -> enhanced_event
        {:error, _} ->
          # Fallback to original event with empty enhancement
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

  @doc """
  Finds events that occur between executions of two AST nodes.
  """
  @spec find_flow_events_between_nodes(list(map()), list(map()), tuple() | nil) ::
    {:ok, list(map())}
  def find_flow_events_between_nodes(from_events, to_events, time_range) do
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
        |> apply_time_range_filter(time_range)
        |> Enum.sort_by(fn event -> Map.get(event, :timestamp) end)

        {:ok, flow_events}

      _ ->
        {:ok, []}
    end
  end

  @doc """
  Builds execution paths from flow events.
  """
  @spec build_execution_paths_between_nodes(list(map())) :: list(map())
  def build_execution_paths_between_nodes(flow_events) do
    flow_events
    |> Enum.map(fn event ->
      %{
        ast_node_id: Map.get(event, :ast_node_id),
        timestamp: Map.get(event, :timestamp),
        event_type: Map.get(event, :event_type)
      }
    end)
  end

  # Private helpers

  defp apply_time_range_filter(events, nil), do: events
  defp apply_time_range_filter(events, {range_start, range_end}) do
    Enum.filter(events, fn event ->
      timestamp = Map.get(event, :timestamp)
      timestamp >= range_start and timestamp <= range_end
    end)
  end
end
