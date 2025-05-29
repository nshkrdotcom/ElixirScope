defmodule ElixirScope.Capture.EnhancedInstrumentation.BreakpointManager do
  @moduledoc """
  Manages structural and data flow breakpoints for enhanced instrumentation.

  This module handles the creation, validation, storage, and evaluation of
  breakpoints that trigger based on AST patterns and data flow conditions.
  """

  require Logger
  alias ElixirScope.Capture.EnhancedInstrumentation.{Storage, DebuggerInterface, Utils}

  @breakpoint_eval_timeout 100  # microseconds

  # Public API

  @doc """
  Sets a structural breakpoint that triggers on AST patterns.
  """
  @spec set_structural_breakpoint(map()) :: {:ok, String.t()} | {:error, term()}
  def set_structural_breakpoint(breakpoint_spec) do
    case create_structural_breakpoint(breakpoint_spec) do
      {:ok, breakpoint_id, breakpoint} ->
        Storage.store_breakpoint(breakpoint_id, {:structural, breakpoint})
        Logger.info("Structural breakpoint set: #{breakpoint_id}")
        {:ok, breakpoint_id}

      error ->
        error
    end
  end

  @doc """
  Sets a data flow breakpoint that triggers on variable flow.
  """
  @spec set_data_flow_breakpoint(map()) :: {:ok, String.t()} | {:error, term()}
  def set_data_flow_breakpoint(breakpoint_spec) do
    case create_data_flow_breakpoint(breakpoint_spec) do
      {:ok, breakpoint_id, breakpoint} ->
        Storage.store_breakpoint(breakpoint_id, {:data_flow, breakpoint})
        Logger.info("Data flow breakpoint set: #{breakpoint_id}")
        {:ok, breakpoint_id}

      error ->
        error
    end
  end

  @doc """
  Removes a breakpoint by ID.
  """
  @spec remove_breakpoint(String.t()) :: :ok
  def remove_breakpoint(breakpoint_id) do
    Storage.remove_breakpoint(breakpoint_id)
  end

  @doc """
  Lists all structural breakpoints.
  """
  @spec list_structural_breakpoints() :: map()
  def list_structural_breakpoints() do
    Storage.list_breakpoints_by_type(:structural)
  end

  @doc """
  Lists all data flow breakpoints.
  """
  @spec list_data_flow_breakpoints() :: map()
  def list_data_flow_breakpoints() do
    Storage.list_breakpoints_by_type(:data_flow)
  end

  @doc """
  Counts structural breakpoints.
  """
  @spec count_structural_breakpoints() :: non_neg_integer()
  def count_structural_breakpoints() do
    Storage.count_breakpoints_by_type(:structural)
  end

  @doc """
  Counts data flow breakpoints.
  """
  @spec count_data_flow_breakpoints() :: non_neg_integer()
  def count_data_flow_breakpoints() do
    Storage.count_breakpoints_by_type(:data_flow)
  end

  @doc """
  Evaluates structural breakpoints for a function call.
  """
  @spec evaluate_structural_breakpoints(module(), atom(), list(), String.t()) :: :ok
  def evaluate_structural_breakpoints(module, function, args, ast_node_id) do
    start_time = System.monotonic_time(:microsecond)

    # Get all structural breakpoints
    structural_breakpoints = Storage.get_breakpoints_by_type(:structural)

    Enum.each(structural_breakpoints, fn breakpoint ->
      if breakpoint.enabled and matches_structural_pattern?(module, function, args, breakpoint) do
        trigger_structural_breakpoint(breakpoint, ast_node_id)
      end
    end)

    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time

    if duration > @breakpoint_eval_timeout do
      Logger.warning("Structural breakpoint evaluation took #{duration}µs (target: #{@breakpoint_eval_timeout}µs)")
    end

    :ok
  end

  @doc """
  Evaluates data flow breakpoints for variable changes.
  """
  @spec evaluate_data_flow_breakpoints(map(), String.t()) :: :ok
  def evaluate_data_flow_breakpoints(variables, ast_node_id) do
    # Get all data flow breakpoints
    data_flow_breakpoints = Storage.get_breakpoints_by_type(:data_flow)

    Enum.each(data_flow_breakpoints, fn breakpoint ->
      if breakpoint.enabled and matches_data_flow_pattern?(variables, breakpoint) do
        trigger_data_flow_breakpoint(breakpoint, ast_node_id, variables)
      end
    end)

    :ok
  end

  @doc """
  Evaluates performance-based breakpoints.
  """
  @spec evaluate_performance_breakpoints(non_neg_integer(), String.t()) :: :ok
  def evaluate_performance_breakpoints(duration_ns, ast_node_id) do
    # Get performance-based breakpoints
    performance_breakpoints = Storage.get_performance_breakpoints()

    Enum.each(performance_breakpoints, fn breakpoint ->
      threshold = Map.get(breakpoint.metadata, :duration_threshold_ns, 1_000_000)  # 1ms default

      if duration_ns > threshold do
        trigger_performance_breakpoint(breakpoint, ast_node_id, duration_ns)
      end
    end)

    :ok
  end

  # Private Implementation

  defp create_structural_breakpoint(spec) do
    breakpoint_id = Map.get(spec, :id, Utils.generate_breakpoint_id("structural"))

    breakpoint = %{
      id: breakpoint_id,
      pattern: Map.get(spec, :pattern),
      condition: Map.get(spec, :condition, :any),
      ast_path: Map.get(spec, :ast_path, []),
      enabled: Map.get(spec, :enabled, true),
      hit_count: 0,
      created_at: System.system_time(:nanosecond),
      metadata: Map.get(spec, :metadata, %{})
    }

    case validate_structural_breakpoint(breakpoint) do
      :ok -> {:ok, breakpoint_id, breakpoint}
      error -> error
    end
  end

  defp create_data_flow_breakpoint(spec) do
    breakpoint_id = Map.get(spec, :id, Utils.generate_breakpoint_id("data_flow"))

    breakpoint = %{
      id: breakpoint_id,
      variable: Map.get(spec, :variable),
      ast_path: Map.get(spec, :ast_path, []),
      flow_conditions: Map.get(spec, :flow_conditions, [:any]),
      enabled: Map.get(spec, :enabled, true),
      hit_count: 0,
      created_at: System.system_time(:nanosecond),
      metadata: Map.get(spec, :metadata, %{})
    }

    case validate_data_flow_breakpoint(breakpoint) do
      :ok -> {:ok, breakpoint_id, breakpoint}
      error -> error
    end
  end

  defp matches_structural_pattern?(module, function, _args, breakpoint) do
    # Simple pattern matching - in practice this would be more sophisticated
    case breakpoint.ast_path do
      [] -> true  # Match any
      [target_module] -> module == String.to_atom(target_module)
      [target_module, target_function] ->
        module == String.to_atom(target_module) and function == String.to_atom(target_function)
      _ -> false
    end
  end

  defp matches_data_flow_pattern?(variables, breakpoint) do
    Map.has_key?(variables, breakpoint.variable)
  end

  defp trigger_structural_breakpoint(breakpoint, ast_node_id) do
    Logger.info("🔴 Structural breakpoint triggered: #{breakpoint.id} at #{ast_node_id}")

    # Update hit count
    updated_breakpoint = %{breakpoint | hit_count: breakpoint.hit_count + 1}
    Storage.update_breakpoint(breakpoint.id, {:structural, updated_breakpoint})

    # Trigger debugger break
    DebuggerInterface.trigger_debugger_break(:structural, breakpoint, ast_node_id)
  end

  defp trigger_data_flow_breakpoint(breakpoint, ast_node_id, variables) do
    Logger.info("🔵 Data flow breakpoint triggered: #{breakpoint.id} at #{ast_node_id}")
    Logger.info("Variable #{breakpoint.variable} = #{inspect(variables[breakpoint.variable])}")

    # Update hit count
    updated_breakpoint = %{breakpoint | hit_count: breakpoint.hit_count + 1}
    Storage.update_breakpoint(breakpoint.id, {:data_flow, updated_breakpoint})

    # Trigger debugger break
    DebuggerInterface.trigger_debugger_break(:data_flow, breakpoint, ast_node_id, variables)
  end

  defp trigger_performance_breakpoint(breakpoint, ast_node_id, duration_ns) do
    Logger.info("🟡 Performance breakpoint triggered: #{breakpoint.id} at #{ast_node_id}")
    Logger.info("Duration: #{duration_ns / 1_000_000}ms")

    # Trigger debugger break
    DebuggerInterface.trigger_debugger_break(:performance, breakpoint, ast_node_id, %{duration_ns: duration_ns})
  end

  # Validation Functions

  defp validate_structural_breakpoint(%{pattern: pattern}) when not is_nil(pattern), do: :ok
  defp validate_structural_breakpoint(_), do: {:error, :invalid_pattern}

  defp validate_data_flow_breakpoint(%{variable: variable}) when not is_nil(variable), do: :ok
  defp validate_data_flow_breakpoint(_), do: {:error, :invalid_variable}
end
