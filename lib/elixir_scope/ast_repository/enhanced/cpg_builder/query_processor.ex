defmodule ElixirScope.ASTRepository.Enhanced.CPGBuilder.QueryProcessor do
  @moduledoc """
  Query processing for CPG including pattern detection and analysis queries.

  Handles complex queries across all graph dimensions, pattern matching,
  and result filtering for CPG analysis.
  """

  alias ElixirScope.ASTRepository.Enhanced.{CFGGenerator, DFGGenerator}
  alias ElixirScope.ASTRepository.Enhanced.CPGBuilder.PatternDetector

  @doc """
  Performs complex queries across all graph dimensions.
  """
  def query_cpg(cpg, query) do
    case query do
      {:find_pattern, pattern} ->
        PatternDetector.find_pattern(cpg, pattern)

      {:security_vulnerabilities, type} ->
        filter_security_issues(cpg.security_analysis, type)

      {:performance_issues, threshold} ->
        filter_performance_issues(cpg.performance_analysis, threshold)

      {:code_smells, category} ->
        filter_code_smells(cpg.code_quality_analysis, category)

      {:data_flow, from_var, to_var} ->
        trace_data_flow(cpg, from_var, to_var)

      {:control_flow, from_node, to_node} ->
        trace_control_flow(cpg, from_node, to_node)

      {:complexity_hotspots, limit} ->
        find_complexity_hotspots(cpg, limit)

      _ ->
        {:error, :unsupported_query}
    end
  end

  # Private implementation

  defp filter_security_issues(security_analysis, type) do
    case type do
      :all -> security_analysis.potential_vulnerabilities
      :injection -> security_analysis.injection_risks
      :unsafe_operations -> security_analysis.unsafe_operations
      :information_leaks -> security_analysis.information_leaks
      _ -> []
    end
  end

  defp filter_performance_issues(performance_analysis, threshold) do
    Enum.filter(performance_analysis.complexity_issues, fn issue ->
      severity_to_number(issue.severity) >= threshold
    end)
  end

  defp filter_code_smells(quality_analysis, category) do
    Enum.filter(quality_analysis.code_smells, fn smell ->
      smell.type == category
    end)
  end

  defp trace_data_flow(cpg, from_var, _to_var) do
    DFGGenerator.trace_variable(cpg.data_flow_graph, from_var)
  end

  defp trace_control_flow(cpg, from_node, to_node) do
    CFGGenerator.find_paths(cpg.control_flow_graph, from_node, [to_node])
  end

  defp find_complexity_hotspots(cpg, limit) do
    complexity_scores = calculate_node_complexities(cpg)

    complexity_scores
    |> Enum.sort_by(fn {_node, complexity} -> complexity end, :desc)
    |> Enum.take(limit)
  end

  defp calculate_node_complexities(cpg) do
    Enum.map(cpg.unified_nodes, fn {node_id, node} ->
      complexity = calculate_node_complexity(node, cpg)
      {node_id, complexity}
    end)
  end

  defp calculate_node_complexity(node, cpg) do
    base_complexity = case node.ast_type do
      :conditional -> 2.0
      :loop -> 3.0
      :exception -> 2.5
      :function_call -> 1.5
      :assignment -> 1.0
      _ -> 0.5
    end

    # Add complexity based on connections
    connection_complexity = count_node_connections(node.id, cpg.unified_edges) * 0.1

    base_complexity + connection_complexity
  end

  defp count_node_connections(node_id, edges) do
    Enum.count(edges, fn edge ->
      edge.from_node == node_id or edge.to_node == node_id
    end)
  end

  defp severity_to_number(severity) do
    case severity do
      :low -> 1
      :medium -> 2
      :high -> 3
      :critical -> 4
      _ -> 0
    end
  end
end
