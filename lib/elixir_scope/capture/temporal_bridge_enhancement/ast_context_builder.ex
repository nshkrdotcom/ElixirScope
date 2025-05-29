defmodule ElixirScope.Capture.TemporalBridgeEnhancement.ASTContextBuilder do
  @moduledoc """
  AST context building utilities for TemporalBridgeEnhancement.

  Handles building AST contexts, structural information, execution paths,
  and variable flow tracking from events.
  """

  alias ElixirScope.ASTRepository.RuntimeCorrelator

  @doc """
  Builds AST context for a state from events.
  """
  @spec build_ast_context_for_state(list(map()), pid()) :: {:ok, map() | nil}
  def build_ast_context_for_state(events, ast_repo) do
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

  @doc """
  Extracts structural information for a state.
  """
  @spec extract_structural_info_for_state(map() | nil, list(map())) :: {:ok, map()}
  def extract_structural_info_for_state(ast_context, events) do
    structural_info = %{
      current_ast_node: extract_current_ast_node(ast_context),
      call_depth: calculate_call_depth(events),
      execution_context: extract_execution_context(events),
      control_flow_state: determine_control_flow_state(ast_context, events)
    }

    {:ok, structural_info}
  end

  @doc """
  Builds execution path from events and AST repository.
  """
  @spec build_execution_path(list(map()), pid()) :: {:ok, list(map())}
  def build_execution_path(events, _ast_repo) do
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

  @doc """
  Builds variable flow tracking for a state.
  """
  @spec build_variable_flow_for_state(list(map())) :: {:ok, map()}
  def build_variable_flow_for_state(events) do
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

  # Private utility functions

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

  defp calculate_time_span(events) do
    if length(events) < 2 do
      0
    else
      timestamps = Enum.map(events, fn event -> Map.get(event, :timestamp) end)
      Enum.max(timestamps) - Enum.min(timestamps)
    end
  end
end
