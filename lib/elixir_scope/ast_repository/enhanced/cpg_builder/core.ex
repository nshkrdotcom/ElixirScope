defmodule ElixirScope.ASTRepository.Enhanced.CPGBuilder.Core do
  @moduledoc """
  Core CPG building orchestration module.

  Handles the main CPG building process, timeout management, and coordination
  between different analysis components.
  """

  require Logger

  alias ElixirScope.ASTRepository.Enhanced.{
    CPGData, CFGData, DFGData, CFGGenerator, DFGGenerator,
    UnifiedAnalysis, PatternAnalysis, DependencyAnalysis,
    NodeMappings, QueryIndexes
  }

  alias ElixirScope.ASTRepository.Enhanced.CPGBuilder.{
    Validator, GraphMerger, ComplexityAnalyzer, SecurityAnalyzer,
    PerformanceAnalyzer, QualityAnalyzer, Helpers
  }

  @doc """
  Builds a unified Code Property Graph from AST.

  Returns {:ok, cpg} or {:error, reason}
  """
  def build_cpg(ast, opts \\ []) do
    timeout = calculate_timeout(ast)

    task = Task.async(fn ->
      build_cpg_impl(ast, opts)
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :cpg_generation_timeout}
    end
  end

  @doc """
  Updates CPG with modified AST (incremental analysis).
  """
  def update_cpg(original_cpg, modified_ast, opts \\ []) do
    case build_cpg(modified_ast, opts) do
      {:ok, new_cpg} ->
        merged_cpg = merge_cpgs(original_cpg, new_cpg)
        {:ok, merged_cpg}
      error -> error
    end
  end

  # Private implementation

  defp build_cpg_impl(ast, opts) do
    with :ok <- Validator.validate_ast(ast),
         false <- Validator.check_for_interprocedural_analysis(ast),
         {:ok, cfg} <- CFGGenerator.generate_cfg(ast, opts),
         {:ok, dfg} <- generate_dfg_with_checks(ast, opts) do

      build_unified_cpg(ast, cfg, dfg, opts)
    else
      {:error, reason} = error ->
        Logger.error("CPG Builder: Generation failed: #{inspect(reason)}")
        error
      true ->
        {:error, :interprocedural_not_implemented}
    end
  rescue
    e ->
      Logger.error("CPG Builder: Exception caught: #{Exception.message(e)}")
      Logger.error("CPG Builder: Exception stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
      {:error, {:cpg_generation_failed, Exception.message(e)}}
  end

  defp generate_dfg_with_checks(ast, opts) do
    case Validator.check_for_dfg_issues(ast) do
      true -> {:error, :dfg_generation_failed}
      false ->
        case DFGGenerator.generate_dfg(ast, opts) do
          {:error, :circular_dependency} -> {:error, :dfg_generation_failed}
          result -> result
        end
    end
  end

  defp build_unified_cpg(ast, cfg, dfg, _opts) do
    # Merge graphs
    unified_nodes = GraphMerger.merge_nodes(cfg.nodes, dfg.nodes)
    unified_edges = GraphMerger.merge_edges(cfg.edges, dfg.edges)

    # Perform analyses
    complexity_metrics = ComplexityAnalyzer.calculate_combined_complexity(cfg, dfg, unified_nodes, unified_edges)
    path_analysis = ComplexityAnalyzer.perform_path_sensitive_analysis(cfg, dfg, unified_nodes)
    security_analysis = SecurityAnalyzer.perform_analysis(cfg, dfg, unified_nodes, unified_edges)
    performance_analysis = PerformanceAnalyzer.perform_analysis(cfg, dfg, complexity_metrics)
    quality_analysis = QualityAnalyzer.perform_analysis(cfg, dfg, unified_nodes)

    # Build CPG structure
    function_key = Helpers.extract_function_key(ast)

    cpg = %CPGData{
      function_key: function_key,
      nodes: unified_nodes,
      edges: unified_edges,
      node_mappings: create_node_mappings(cfg, dfg),
      query_indexes: create_query_indexes(unified_nodes, unified_edges),
      source_graphs: %{cfg: cfg, dfg: dfg},
      unified_analysis: %UnifiedAnalysis{
        security_analysis: security_analysis,
        performance_analysis: performance_analysis,
        quality_analysis: quality_analysis,
        complexity_analysis: complexity_metrics,
        pattern_analysis: %PatternAnalysis{
          detected_patterns: [],
          anti_patterns: [],
          design_patterns: [],
          pattern_metrics: %{}
        },
        dependency_analysis: %DependencyAnalysis{
          dependency_graph: %{},
          circular_dependencies: [],
          dependency_chains: [],
          critical_variables: [],
          isolated_variables: []
        },
        information_flow: security_analysis.information_flow,
        alias_analysis: security_analysis.alias_analysis,
        optimization_hints: performance_analysis.optimization_suggestions
      },
      metadata: build_metadata(cfg, dfg),
      # Direct references for test compatibility
      control_flow_graph: cfg,
      data_flow_graph: dfg,
      unified_nodes: unified_nodes,
      unified_edges: unified_edges,
      complexity_metrics: complexity_metrics,
      path_sensitive_analysis: path_analysis,
      security_analysis: security_analysis,
      alias_analysis: security_analysis.alias_analysis,
      performance_analysis: performance_analysis,
      information_flow_analysis: security_analysis.information_flow,
      code_quality_analysis: quality_analysis
    }

    {:ok, cpg}
  end

  defp calculate_timeout(ast) do
    complexity = Helpers.estimate_ast_complexity(ast)
    case complexity do
      c when c > 100 -> 60_000  # 60 seconds
      c when c > 50 -> 30_000   # 30 seconds
      c when c > 20 -> 20_000   # 20 seconds
      _ -> 10_000               # 10 seconds
    end
  end

  defp build_metadata(cfg, dfg) do
    %{
      generation_time: System.monotonic_time(:millisecond),
      generator_version: "1.0.0",
      cfg_complexity: cfg.complexity_metrics,
      dfg_complexity: dfg.analysis_results
    }
  end

  defp create_node_mappings(_cfg, _dfg) do
    %NodeMappings{
      ast_to_cfg: %{},
      ast_to_dfg: %{},
      cfg_to_dfg: %{},
      dfg_to_cfg: %{},
      unified_mappings: %{},
      reverse_mappings: %{}
    }
  end

  defp create_query_indexes(_unified_nodes, _unified_edges) do
    %QueryIndexes{
      by_type: %{},
      by_line: %{},
      by_scope: %{},
      by_variable: %{},
      by_function_call: %{},
      control_flow_paths: %{},
      data_flow_chains: %{},
      pattern_indexes: %{}
    }
  end

  defp merge_cpgs(_original_cpg, new_cpg) do
    # Simplified CPG merging - in practice this would be more sophisticated
    new_cpg
  end
end
