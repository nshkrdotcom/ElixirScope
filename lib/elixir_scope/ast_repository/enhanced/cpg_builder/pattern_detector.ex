defmodule ElixirScope.ASTRepository.Enhanced.CPGBuilder.PatternDetector do
  @moduledoc """
  Pattern detection for CPG analysis including code patterns and anti-patterns.

  Handles detection of various code patterns, anti-patterns, and custom
  pattern matching for code analysis.
  """

  alias ElixirScope.ASTRepository.Enhanced.DFGGenerator
  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator

  @doc """
  Finds code patterns for analysis.
  """
  def find_pattern(cpg, pattern) do
    case pattern do
      :uninitialized_variables ->
        find_uninitialized_variables(cpg)

      :unused_variables ->
        find_unused_variables(cpg)

      :dead_code ->
        find_dead_code(cpg)

      :complex_functions ->
        find_complex_functions(cpg)

      :security_risks ->
        find_security_risks(cpg)

      :performance_bottlenecks ->
        find_performance_bottlenecks(cpg)

      {:custom_pattern, matcher} ->
        find_custom_pattern(cpg, matcher)

      _ ->
        {:error, :unknown_pattern}
    end
  end

  # Private implementation

  defp find_uninitialized_variables(cpg) do
    case DFGGenerator.find_uninitialized_uses(cpg.data_flow_graph) do
      {:ok, uninitialized} -> {:ok, uninitialized}
      {:error, reason} -> {:error, reason}
      uninitialized when is_list(uninitialized) -> {:ok, uninitialized}
      _ -> {:ok, []}
    end
  end

  defp find_unused_variables(cpg) do
    unused = case cpg.data_flow_graph do
      %{unused_variables: unused_vars} when is_list(unused_vars) -> unused_vars
      _ -> []
    end

    {:ok, unused}
  end

  defp find_dead_code(cpg) do
    case CFGGenerator.detect_unreachable_code(cpg.control_flow_graph) do
      {:ok, dead_code} -> {:ok, dead_code}
      {:error, reason} -> {:error, reason}
      dead_code when is_list(dead_code) -> {:ok, dead_code}
      _ -> {:ok, []}
    end
  end

  defp find_complex_functions(cpg) do
    threshold = 10

    complex_functions = if cpg.complexity_metrics.combined_complexity > threshold do
      [%{
        type: :complex_function,
        complexity: cpg.complexity_metrics.combined_complexity,
        threshold: threshold,
        suggestion: "Consider breaking down this function"
      }]
    else
      []
    end

    {:ok, complex_functions}
  end

  defp find_security_risks(cpg) do
    risks = case cpg.security_analysis do
      %{potential_vulnerabilities: vulnerabilities} when is_list(vulnerabilities) ->
        vulnerabilities
      _ -> []
    end

    {:ok, risks}
  end

  defp find_performance_bottlenecks(cpg) do
    bottlenecks = case cpg.performance_analysis do
      %{performance_hotspots: hotspots} when is_list(hotspots) -> hotspots
      _ -> []
    end

    {:ok, bottlenecks}
  end

  defp find_custom_pattern(cpg, matcher) when is_function(matcher) do
    try do
      results = cpg.unified_nodes
      |> Enum.filter(fn {_id, node} -> matcher.(node) end)
      |> Enum.map(fn {id, node} -> %{node_id: id, node: node} end)

      {:ok, results}
    rescue
      e -> {:error, "Custom pattern matcher failed: #{Exception.message(e)}"}
    end
  end

  defp find_custom_pattern(_cpg, _matcher) do
    {:error, "Custom pattern matcher must be a function"}
  end
end
