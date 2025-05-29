defmodule ElixirScope.Capture.EnhancedInstrumentation.WatchpointManager do
  @moduledoc """
  Manages semantic watchpoints for enhanced instrumentation.

  This module handles the creation, validation, storage, and evaluation of
  watchpoints that track variables through AST structure and execution flow.
  """

  require Logger
  alias ElixirScope.Capture.EnhancedInstrumentation.{Storage, Utils}

  # Public API

  @doc """
  Sets a semantic watchpoint that tracks variables through AST structure.
  """
  @spec set_semantic_watchpoint(map()) :: {:ok, String.t()} | {:error, term()}
  def set_semantic_watchpoint(watchpoint_spec) do
    case create_semantic_watchpoint(watchpoint_spec) do
      {:ok, watchpoint_id, watchpoint} ->
        Storage.store_watchpoint(watchpoint_id, watchpoint)
        Logger.info("Semantic watchpoint set: #{watchpoint_id}")
        {:ok, watchpoint_id}

      error ->
        error
    end
  end

  @doc """
  Removes a watchpoint by ID.
  """
  @spec remove_watchpoint(String.t()) :: :ok
  def remove_watchpoint(watchpoint_id) do
    Storage.remove_watchpoint(watchpoint_id)
  end

  @doc """
  Lists all watchpoints.
  """
  @spec list_watchpoints() :: map()
  def list_watchpoints() do
    Storage.list_watchpoints()
  end

  @doc """
  Counts active watchpoints.
  """
  @spec count_watchpoints() :: non_neg_integer()
  def count_watchpoints() do
    Storage.count_watchpoints()
  end

  @doc """
  Evaluates semantic watchpoints for variable changes.
  """
  @spec evaluate_semantic_watchpoints(map(), String.t()) :: :ok
  def evaluate_semantic_watchpoints(variables, ast_node_id) do
    # Get all semantic watchpoints
    watchpoints = Storage.get_all_watchpoints()

    Enum.each(watchpoints, fn {_id, watchpoint} ->
      if watchpoint.enabled and Map.has_key?(variables, watchpoint.variable) do
        update_semantic_watchpoint(watchpoint, variables[watchpoint.variable], ast_node_id)
      end
    end)

    :ok
  end

  @doc """
  Gets the value history for a specific watchpoint.
  """
  @spec get_watchpoint_history(String.t()) :: {:ok, list()} | {:error, :not_found}
  def get_watchpoint_history(watchpoint_id) do
    case Storage.get_watchpoint(watchpoint_id) do
      {:ok, watchpoint} -> {:ok, watchpoint.value_history}
      error -> error
    end
  end

  @doc """
  Clears the value history for a specific watchpoint.
  """
  @spec clear_watchpoint_history(String.t()) :: :ok | {:error, :not_found}
  def clear_watchpoint_history(watchpoint_id) do
    case Storage.get_watchpoint(watchpoint_id) do
      {:ok, watchpoint} ->
        updated_watchpoint = %{watchpoint | value_history: []}
        Storage.update_watchpoint(watchpoint_id, updated_watchpoint)
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Enables or disables a watchpoint.
  """
  @spec toggle_watchpoint(String.t(), boolean()) :: :ok | {:error, :not_found}
  def toggle_watchpoint(watchpoint_id, enabled) do
    case Storage.get_watchpoint(watchpoint_id) do
      {:ok, watchpoint} ->
        updated_watchpoint = %{watchpoint | enabled: enabled}
        Storage.update_watchpoint(watchpoint_id, updated_watchpoint)
        Logger.info("Watchpoint #{watchpoint_id} #{if enabled, do: "enabled", else: "disabled"}")
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  # Private Implementation

  defp create_semantic_watchpoint(spec) do
    watchpoint_id = Map.get(spec, :id, Utils.generate_watchpoint_id())

    watchpoint = %{
      id: watchpoint_id,
      variable: Map.get(spec, :variable),
      track_through: Map.get(spec, :track_through, [:all]),
      ast_scope: Map.get(spec, :ast_scope),
      enabled: Map.get(spec, :enabled, true),
      value_history: [],
      created_at: System.system_time(:nanosecond),
      metadata: Map.get(spec, :metadata, %{})
    }

    case validate_semantic_watchpoint(watchpoint) do
      :ok -> {:ok, watchpoint_id, watchpoint}
      error -> error
    end
  end

  defp update_semantic_watchpoint(watchpoint, value, ast_node_id) do
    # Add value to history
    value_entry = %{
      value: value,
      timestamp: System.monotonic_time(:nanosecond),
      ast_node_id: ast_node_id
    }

    updated_history = [value_entry | watchpoint.value_history]
    |> Enum.take(100)  # Keep last 100 values

    updated_watchpoint = %{watchpoint | value_history: updated_history}
    Storage.update_watchpoint(watchpoint.id, updated_watchpoint)

    Logger.debug("📊 Semantic watchpoint updated: #{watchpoint.id} = #{inspect(value)}")

    # Check for significant changes that might trigger alerts
    check_for_watchpoint_alerts(watchpoint, value_entry)
  end

  defp check_for_watchpoint_alerts(watchpoint, value_entry) do
    # Check for patterns that might indicate issues
    case analyze_value_pattern(watchpoint.value_history, value_entry) do
      {:alert, reason} ->
        Logger.warning("⚠️  Watchpoint alert: #{watchpoint.id} - #{reason}")
        trigger_watchpoint_alert(watchpoint, reason, value_entry)

      :ok ->
        :ok
    end
  end

  defp analyze_value_pattern(history, current_entry) when length(history) < 3 do
    # Not enough history to analyze patterns
    :ok
  end

  defp analyze_value_pattern(history, current_entry) do
    recent_values = Enum.take(history, 3)

    cond do
      # Check for rapid changes
      rapid_changes?(recent_values, current_entry) ->
        {:alert, "rapid value changes detected"}

      # Check for nil/error patterns
      error_pattern?(recent_values, current_entry) ->
        {:alert, "error value pattern detected"}

      # Check for memory growth pattern (if tracking size)
      memory_growth_pattern?(recent_values, current_entry) ->
        {:alert, "potential memory growth detected"}

      true ->
        :ok
    end
  end

  defp rapid_changes?(history, _current) when length(history) < 2, do: false
  defp rapid_changes?([prev | _], current) do
    time_diff = current.timestamp - prev.timestamp
    # Alert if changes happen faster than 1ms
    time_diff < 1_000_000
  end

  defp error_pattern?(history, current) do
    # Check if current value is an error and if there's a pattern
    case current.value do
      {:error, _} ->
        error_count = Enum.count(history, fn entry ->
          match?({:error, _}, entry.value)
        end)
        error_count >= 2  # Alert if 2+ recent errors

      nil ->
        nil_count = Enum.count(history, fn entry ->
          is_nil(entry.value)
        end)
        nil_count >= 2  # Alert if 2+ recent nils

      _ -> false
    end
  end

  defp memory_growth_pattern?(history, current) do
    # Simple heuristic for detecting memory growth
    if is_binary(current.value) or is_list(current.value) or is_map(current.value) do
      current_size = estimate_size(current.value)

      sizes = Enum.map(history, fn entry -> estimate_size(entry.value) end)
      avg_size = if Enum.empty?(sizes), do: 0, else: Enum.sum(sizes) / length(sizes)

      # Alert if current size is significantly larger than average
      current_size > avg_size * 2 and current_size > 1000
    else
      false
    end
  end

  defp estimate_size(value) when is_binary(value), do: byte_size(value)
  defp estimate_size(value) when is_list(value), do: length(value)
  defp estimate_size(value) when is_map(value), do: map_size(value)
  defp estimate_size(_), do: 0

  defp trigger_watchpoint_alert(watchpoint, reason, value_entry) do
    alert = %{
      type: :watchpoint_alert,
      watchpoint_id: watchpoint.id,
      reason: reason,
      value: value_entry.value,
      timestamp: value_entry.timestamp,
      ast_node_id: value_entry.ast_node_id
    }

    # Store alert for later retrieval
    Storage.store_alert(alert)

    # Could also send to monitoring system
    # MonitoringSystem.send_alert(alert)
  end

  # Validation Functions

  defp validate_semantic_watchpoint(%{variable: variable}) when not is_nil(variable), do: :ok
  defp validate_semantic_watchpoint(_), do: {:error, :invalid_variable}
end
