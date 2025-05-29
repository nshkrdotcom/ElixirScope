defmodule ElixirScope.Capture.EnhancedInstrumentation.EventHandler do
  @moduledoc """
  Handles enhanced instrumentation events with AST correlation.

  This module processes function entry/exit events and variable snapshots,
  applying AST correlation and triggering breakpoint/watchpoint evaluations.
  """

  require Logger

  alias ElixirScope.Capture.InstrumentationRuntime
  alias ElixirScope.ASTRepository.RuntimeCorrelator
  alias ElixirScope.Capture.EnhancedInstrumentation.{
    BreakpointManager,
    WatchpointManager,
    ASTCorrelator
  }

  @doc """
  Handles enhanced function entry events.
  """
  @spec handle_function_entry(module(), atom(), list(), String.t(), String.t(), map()) :: :ok
  def handle_function_entry(module, function, args, correlation_id, ast_node_id, state) do
    if state.ast_correlation_enabled do
      # Evaluate structural breakpoints
      BreakpointManager.evaluate_structural_breakpoints(module, function, args, ast_node_id)

      # Report to standard instrumentation with AST correlation
      InstrumentationRuntime.report_ast_function_entry_with_node_id(
        module, function, args, correlation_id, ast_node_id
      )

      # Correlate with AST repository if available
      if state.ast_repo do
        ASTCorrelator.correlate_event_async(state.ast_repo, %{
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

    :ok
  end

  @doc """
  Handles enhanced function exit events.
  """
  @spec handle_function_exit(String.t(), term(), non_neg_integer(), String.t(), map()) :: :ok
  def handle_function_exit(correlation_id, return_value, duration_ns, ast_node_id, state) do
    if state.ast_correlation_enabled do
      # Report to standard instrumentation with AST correlation
      InstrumentationRuntime.report_ast_function_exit_with_node_id(
        correlation_id, return_value, duration_ns, ast_node_id
      )

      # Evaluate performance-based breakpoints
      BreakpointManager.evaluate_performance_breakpoints(duration_ns, ast_node_id)

      # Correlate with AST repository if available
      if state.ast_repo do
        ASTCorrelator.correlate_event_async(state.ast_repo, %{
          event_type: :function_exit,
          correlation_id: correlation_id,
          return_value: return_value,
          duration_ns: duration_ns,
          ast_node_id: ast_node_id,
          timestamp: System.monotonic_time(:nanosecond)
        })
      end
    else
      # Standard reporting without AST correlation
      InstrumentationRuntime.report_function_exit(correlation_id, return_value, duration_ns)
    end

    :ok
  end

  @doc """
  Handles enhanced variable snapshot events.
  """
  @spec handle_variable_snapshot(String.t(), map(), non_neg_integer(), String.t(), map()) :: :ok
  def handle_variable_snapshot(correlation_id, variables, line, ast_node_id, state) do
    if state.ast_correlation_enabled do
      # Evaluate semantic watchpoints
      WatchpointManager.evaluate_semantic_watchpoints(variables, ast_node_id)

      # Evaluate data flow breakpoints
      BreakpointManager.evaluate_data_flow_breakpoints(variables, ast_node_id)

      # Report to standard instrumentation with AST correlation
      InstrumentationRuntime.report_ast_variable_snapshot(correlation_id, variables, line, ast_node_id)

      # Correlate with AST repository if available
      if state.ast_repo do
        ASTCorrelator.correlate_event_async(state.ast_repo, %{
          event_type: :variable_snapshot,
          correlation_id: correlation_id,
          variables: sanitize_variables_for_correlation(variables),
          line: line,
          ast_node_id: ast_node_id,
          timestamp: System.monotonic_time(:nanosecond)
        })
      end
    else
      # Standard reporting without AST correlation
      InstrumentationRuntime.report_local_variable_snapshot(correlation_id, variables, line)
    end

    :ok
  end

  @doc """
  Handles exception events with AST correlation.
  """
  @spec handle_exception(String.t(), Exception.t(), list(), String.t(), map()) :: :ok
  def handle_exception(correlation_id, exception, stacktrace, ast_node_id, state) do
    if state.ast_correlation_enabled do
      # Log exception with AST context
      Logger.error("Exception in AST node #{ast_node_id}: #{inspect(exception)}")

      # Evaluate exception-based breakpoints
      evaluate_exception_breakpoints(exception, ast_node_id)

      # Report to standard instrumentation with AST correlation
      InstrumentationRuntime.report_ast_exception(correlation_id, exception, stacktrace, ast_node_id)

      # Correlate with AST repository if available
      if state.ast_repo do
        ASTCorrelator.correlate_event_async(state.ast_repo, %{
          event_type: :exception,
          correlation_id: correlation_id,
          exception: exception,
          ast_node_id: ast_node_id,
          timestamp: System.monotonic_time(:nanosecond)
        })
      end
    else
      # Standard exception reporting
      Logger.error("Exception: #{inspect(exception)}")
    end

    :ok
  end

  # Private Implementation

  defp sanitize_variables_for_correlation(variables) do
    # Remove or truncate large variables to avoid memory issues in correlation
    variables
    |> Enum.map(fn {key, value} ->
      sanitized_value = case value do
        val when is_binary(val) and byte_size(val) > 1000 ->
          String.slice(val, 0, 1000) <> "... [truncated]"

        val when is_list(val) and length(val) > 50 ->
          Enum.take(val, 50) ++ ["... [truncated]"]

        val when is_map(val) and map_size(val) > 20 ->
          val
          |> Enum.take(20)
          |> Enum.into(%{})
          |> Map.put("__truncated__", true)

        val -> val
      end

      {key, sanitized_value}
    end)
    |> Enum.into(%{})
  end

  defp evaluate_exception_breakpoints(exception, ast_node_id) do
    # This would evaluate breakpoints that trigger on specific exception types
    # For now, we'll just log the exception with context
    Logger.debug("Evaluating exception breakpoints for #{inspect(exception)} at #{ast_node_id}")

    # Could implement sophisticated exception pattern matching here
    # e.g., break on specific exception types, exception messages, etc.
    :ok
  end
end
