defmodule ElixirScope.Capture.EnhancedInstrumentation.ASTCorrelator do
  @moduledoc """
  Handles AST correlation for enhanced instrumentation events.

  This module manages the asynchronous correlation of runtime events
  with AST repository data to provide rich debugging context.
  """

  require Logger
  alias ElixirScope.ASTRepository.RuntimeCorrelator

  @correlation_timeout 50  # microseconds

  @doc """
  Asynchronously correlates an event with AST repository data.
  """
  @spec correlate_event_async(module(), map()) :: :ok
  def correlate_event_async(ast_repo, event) do
    Task.start(fn ->
      start_time = System.monotonic_time(:microsecond)

      case RuntimeCorrelator.correlate_event_to_ast(ast_repo, event) do
        {:ok, ast_context} ->
          end_time = System.monotonic_time(:microsecond)
          duration = end_time - start_time

          if duration > @correlation_timeout do
            Logger.warning("AST correlation took #{duration}µs (target: #{@correlation_timeout}µs)")
          end

          Logger.debug("AST correlation successful for event: #{event.event_type}")
          store_correlation_result(event, ast_context)

        {:error, reason} ->
          Logger.debug("AST correlation failed: #{inspect(reason)}")
          store_correlation_failure(event, reason)
      end
    end)

    :ok
  end

  @doc """
  Synchronously correlates an event with AST repository data.
  """
  @spec correlate_event_sync(module(), map()) :: {:ok, map()} | {:error, term()}
  def correlate_event_sync(ast_repo, event) do
    start_time = System.monotonic_time(:microsecond)

    result = RuntimeCorrelator.correlate_event_to_ast(ast_repo, event)

    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time

    if duration > @correlation_timeout do
      Logger.warning("Sync AST correlation took #{duration}µs (target: #{@correlation_timeout}µs)")
    end

    case result do
      {:ok, ast_context} ->
        store_correlation_result(event, ast_context)
        {:ok, ast_context}

      error ->
        store_correlation_failure(event, error)
        error
    end
  end

  # Private Implementation

  defp store_correlation_result(event, ast_context) do
    # Store successful correlation for potential later retrieval
    correlation_data = %{
      event: event,
      ast_context: ast_context,
      timestamp: System.system_time(:nanosecond),
      status: :success
    }

    # Could store in ETS or send to monitoring system
    Logger.debug("Stored correlation result for #{event.correlation_id || "unknown"}")
  end

  defp store_correlation_failure(event, reason) do
    # Store failed correlation for debugging
    failure_data = %{
      event: event,
      failure_reason: reason,
      timestamp: System.system_time(:nanosecond),
      status: :failure
    }

    # Could store in ETS or send to monitoring system
    Logger.debug("Stored correlation failure for #{event.correlation_id || "unknown"}: #{inspect(reason)}")
  end
end
