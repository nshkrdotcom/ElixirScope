defmodule ElixirScope.ASTRepository.RuntimeCorrelator.TraceBuilder do
  @moduledoc """
  Execution trace building for the RuntimeCorrelator.

  Creates comprehensive execution traces that combine runtime events
  with AST structure information, variable flow, and performance data.
  """

  alias ElixirScope.ASTRepository.RuntimeCorrelator.{Types, EventCorrelator, ContextBuilder}

  @doc """
  Builds an AST-aware execution trace from runtime events.

  Creates comprehensive execution traces that show both
  runtime behavior and underlying AST structure.
  """
  @spec build_execution_trace(pid() | atom(), list(map())) :: {:ok, Types.execution_trace()} | {:error, term()}
  def build_execution_trace(repo, events) do
    with {:ok, enhanced_events} <- enhance_events_batch(repo, events),
         {:ok, ast_flow} <- build_ast_flow(enhanced_events),
         {:ok, variable_flow} <- build_variable_flow(enhanced_events),
         {:ok, structural_patterns} <- identify_structural_patterns(enhanced_events),
         {:ok, performance_correlation} <- correlate_performance_data(enhanced_events) do

      trace = %{
        events: enhanced_events,
        ast_flow: ast_flow,
        variable_flow: variable_flow,
        structural_patterns: structural_patterns,
        performance_correlation: performance_correlation,
        trace_metadata: %{
          trace_id: generate_trace_id(),
          created_at: System.system_time(:nanosecond),
          event_count: length(events),
          correlation_version: "1.0"
        }
      }

      {:ok, trace}
    else
      error -> error
    end
  end

  @doc """
  Builds a lightweight trace with only essential information.
  """
  @spec build_lightweight_trace(pid() | atom(), list(map())) :: {:ok, map()} | {:error, term()}
  def build_lightweight_trace(repo, events) do
    with {:ok, enhanced_events} <- enhance_events_batch(repo, events),
         {:ok, ast_flow} <- build_ast_flow(enhanced_events) do

      trace = %{
        event_count: length(events),
        ast_flow: ast_flow,
        trace_metadata: %{
          trace_id: generate_trace_id(),
          created_at: System.system_time(:nanosecond),
          trace_type: :lightweight
        }
      }

      {:ok, trace}
    else
      error -> error
    end
  end

  @doc """
  Merges multiple execution traces into a single comprehensive trace.
  """
  @spec merge_traces(list(Types.execution_trace())) :: {:ok, Types.execution_trace()} | {:error, term()}
  def merge_traces([single_trace]), do: {:ok, single_trace}
  def merge_traces(traces) when length(traces) > 1 do
    merged_events = traces |> Enum.flat_map(& &1.events) |> Enum.sort_by(&ContextBuilder.extract_timestamp(&1.original_event))
    merged_ast_flow = traces |> Enum.flat_map(& &1.ast_flow) |> Enum.sort_by(& &1.timestamp)

    merged_variable_flow = traces
    |> Enum.map(& &1.variable_flow)
    |> Enum.reduce(%{}, &merge_variable_flows/2)

    merged_trace = %{
      events: merged_events,
      ast_flow: merged_ast_flow,
      variable_flow: merged_variable_flow,
      structural_patterns: merge_structural_patterns(traces),
      performance_correlation: merge_performance_data(traces),
      trace_metadata: %{
        trace_id: generate_trace_id(),
        created_at: System.system_time(:nanosecond),
        event_count: length(merged_events),
        correlation_version: "1.0",
        merged_from: Enum.map(traces, & &1.trace_metadata.trace_id)
      }
    }

    {:ok, merged_trace}
  end
  def merge_traces([]), do: {:error, :no_traces_provided}

  # Private Functions

  defp enhance_events_batch(repo, events) do
    # Create a minimal state structure for internal calls
    minimal_state = %{
      correlation_stats: %{
        events_correlated: 0,
        context_lookups: 0,
        cache_hits: 0,
        cache_misses: 0
      }
    }

    enhanced_events = Enum.map(events, fn event ->
      case EventCorrelator.enhance_event_with_ast(repo, event, minimal_state) do
        {:ok, enhanced_event} -> enhanced_event
        {:error, _} ->
          # Fallback to original event if enhancement fails
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

  defp build_ast_flow(enhanced_events) do
    ast_flow = enhanced_events
    |> Enum.filter(fn event -> not is_nil(event.ast_context) end)
    |> Enum.map(fn event ->
      %{
        ast_node_id: event.ast_context.ast_node_id,
        timestamp: ContextBuilder.extract_timestamp(event.original_event),
        structural_info: event.structural_info
      }
    end)
    |> Enum.sort_by(& &1.timestamp)

    {:ok, ast_flow}
  end

  defp build_variable_flow(enhanced_events) do
    variable_flow = enhanced_events
    |> Enum.reduce(%{}, fn event, acc ->
      case event.ast_context do
        nil ->
          # Handle events without ast_context but with variables in original event
          case Map.get(event.original_event, :variables) do
            vars when is_map(vars) and map_size(vars) > 0 ->
              # Create a synthetic ast_node_id for variable tracking
              module = Map.get(event.original_event, :module, "Unknown")
              function = Map.get(event.original_event, :function, "unknown")
              synthetic_ast_node_id = "#{module}.#{function}:variable_snapshot"

              Enum.reduce(vars, acc, fn {var_name, var_value}, var_acc ->
                var_history = Map.get(var_acc, var_name, [])
                var_entry = %{
                  value: var_value,
                  timestamp: ContextBuilder.extract_timestamp(event.original_event),
                  ast_node_id: synthetic_ast_node_id,
                  line_number: Map.get(event.original_event, :line, 0)
                }
                Map.put(var_acc, var_name, [var_entry | var_history])
              end)
            _ -> acc
          end
        context ->
          # Safely get local variables from variable_scope
          local_variables = case Map.get(context, :variable_scope, %{}) do
            %{local_variables: vars} when is_map(vars) -> vars
            vars when is_map(vars) -> vars
            _ -> %{}
          end

          Enum.reduce(local_variables, acc, fn {var_name, var_value}, var_acc ->
            var_history = Map.get(var_acc, var_name, [])
            var_entry = %{
              value: var_value,
              timestamp: ContextBuilder.extract_timestamp(event.original_event),
              ast_node_id: context.ast_node_id,
              line_number: context.line_number
            }
            Map.put(var_acc, var_name, [var_entry | var_history])
          end)
      end
    end)
    |> Enum.map(fn {var_name, history} ->
      {var_name, Enum.reverse(history)}
    end)
    |> Enum.into(%{})

    {:ok, variable_flow}
  end

  defp identify_structural_patterns(enhanced_events) do
    patterns = enhanced_events
    |> Enum.filter(fn event ->
      not is_nil(event.structural_info) and Map.has_key?(event.structural_info, :ast_node_type)
    end)
    |> Enum.group_by(fn event -> event.structural_info.ast_node_type end)
    |> Enum.map(fn {pattern_type, events} ->
      %{
        pattern_type: pattern_type,
        occurrences: length(events),
        first_occurrence: ContextBuilder.extract_timestamp(hd(events).original_event),
        last_occurrence: ContextBuilder.extract_timestamp(List.last(events).original_event)
      }
    end)

    {:ok, patterns}
  end

  defp correlate_performance_data(enhanced_events) do
    performance_data = enhanced_events
    |> Enum.filter(fn event ->
      Map.has_key?(event.original_event, :duration_ns) and not is_nil(event.ast_context)
    end)
    |> Enum.map(fn event ->
      %{
        ast_node_id: event.ast_context.ast_node_id,
        duration_ns: event.original_event.duration_ns,
        complexity: event.ast_context.ast_metadata.complexity,
        timestamp: ContextBuilder.extract_timestamp(event.original_event)
      }
    end)
    |> Enum.group_by(& &1.ast_node_id)
    |> Enum.map(fn {ast_node_id, measurements} ->
      durations = Enum.map(measurements, & &1.duration_ns)
      complexity = hd(measurements).complexity

      {ast_node_id, %{
        avg_duration: Enum.sum(durations) / length(durations),
        min_duration: Enum.min(durations),
        max_duration: Enum.max(durations),
        call_count: length(measurements),
        complexity: complexity,
        performance_ratio: calculate_performance_ratio(durations, complexity)
      }}
    end)
    |> Enum.into(%{})

    {:ok, performance_data}
  end

  defp merge_variable_flows(flow1, flow2) do
    Map.merge(flow1, flow2, fn _var_name, history1, history2 ->
      (history1 ++ history2)
      |> Enum.sort_by(& &1.timestamp)
      |> Enum.dedup_by(&{&1.timestamp, &1.value})
    end)
  end

  defp merge_structural_patterns(traces) do
    traces
    |> Enum.flat_map(& &1.structural_patterns)
    |> Enum.group_by(& &1.pattern_type)
    |> Enum.map(fn {pattern_type, patterns} ->
      total_occurrences = Enum.sum(Enum.map(patterns, & &1.occurrences))
      first_occurrence = patterns |> Enum.map(& &1.first_occurrence) |> Enum.min()
      last_occurrence = patterns |> Enum.map(& &1.last_occurrence) |> Enum.max()

      %{
        pattern_type: pattern_type,
        occurrences: total_occurrences,
        first_occurrence: first_occurrence,
        last_occurrence: last_occurrence
      }
    end)
  end

  defp merge_performance_data(traces) do
    traces
    |> Enum.flat_map(fn trace -> Map.to_list(trace.performance_correlation) end)
    |> Enum.group_by(fn {ast_node_id, _data} -> ast_node_id end)
    |> Enum.map(fn {ast_node_id, node_data_list} ->
      merged_data = merge_performance_measurements(Enum.map(node_data_list, &elem(&1, 1)))
      {ast_node_id, merged_data}
    end)
    |> Enum.into(%{})
  end

  defp merge_performance_measurements(measurements) do
    all_durations = measurements |> Enum.flat_map(fn m ->
      List.duplicate(m.avg_duration, m.call_count)
    end)

    total_calls = Enum.sum(Enum.map(measurements, & &1.call_count))
    avg_duration = Enum.sum(all_durations) / length(all_durations)
    min_duration = measurements |> Enum.map(& &1.min_duration) |> Enum.min()
    max_duration = measurements |> Enum.map(& &1.max_duration) |> Enum.max()
    complexity = hd(measurements).complexity

    %{
      avg_duration: avg_duration,
      min_duration: min_duration,
      max_duration: max_duration,
      call_count: total_calls,
      complexity: complexity,
      performance_ratio: calculate_performance_ratio(all_durations, complexity)
    }
  end

  defp calculate_performance_ratio(durations, complexity) do
    avg_duration = Enum.sum(durations) / length(durations)
    avg_duration / max(complexity, 1)
  end

  defp generate_trace_id() do
    "trace_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
  end
end
