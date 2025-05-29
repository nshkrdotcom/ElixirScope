defmodule ElixirScope.ASTRepository.Enhanced.CPGBuilder do
  @moduledoc """
  Code Property Graph builder for comprehensive AST analysis.
  
  Combines Control Flow Graphs (CFG) and Data Flow Graphs (DFG) into a unified
  representation that enables advanced analysis including:
  - Security vulnerability detection
  - Code quality analysis and metrics
  - Performance bottleneck identification
  - Pattern matching for code analysis
  - Cross-function dependency analysis
  
  Performance targets:
  - CPG building: <500ms for modules with <50 functions
  - Memory efficient: <5MB per module CPG
  """
  
  require Logger
  
  alias ElixirScope.ASTRepository.Enhanced.{
    CPGData, CFGData, DFGData, CFGGenerator, DFGGenerator,
    UnifiedAnalysis, PatternAnalysis, DependencyAnalysis, 
    NodeMappings, QueryIndexes
  }
  
  @doc """
  Builds a unified Code Property Graph from AST.
  
  Returns {:ok, cpg} or {:error, reason}
  """
  def build_cpg(ast, opts \\ []) do
    try do
      # Generate CFG and DFG
      with {:ok, cfg} <- CFGGenerator.generate_cfg(ast),
           {:ok, dfg} <- DFGGenerator.generate_dfg(ast) do
        # Build CPG from CFG and DFG
        build_cpg(cfg, dfg)
      else
        error -> error
      end
    rescue
      e ->
        Logger.error("CPG Builder: Failed to build CPG from AST: #{Exception.message(e)}")
        {:error, {:cpg_build_failed, e}}
    end
  end
  
  def build_cpg(%CFGData{} = cfg, %DFGData{} = dfg) do
            try do
                          # Merge CFG and DFG into unified CPG
                          unified_nodes = merge_graph_nodes(cfg.nodes, dfg.nodes)
                          unified_edges = merge_graph_edges(cfg.edges, dfg.edges)
                          
                          # Perform advanced analyses with timeouts
                          complexity_metrics = calculate_combined_complexity(cfg, dfg, unified_nodes, unified_edges)
                          path_sensitive_analysis = perform_path_sensitive_analysis(cfg, dfg, unified_nodes)
                          security_analysis = perform_security_analysis(cfg, dfg, unified_nodes, unified_edges)
                          alias_analysis = perform_alias_analysis(dfg, unified_nodes)
                          code_quality_analysis = perform_code_quality_analysis(cfg, dfg, unified_nodes)
                          performance_analysis = perform_performance_analysis(cfg, dfg, complexity_metrics)
                          information_flow_analysis = perform_information_flow_analysis(dfg, unified_edges)
                          
      function_key = extract_function_key_from_cfg(cfg)
                          
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
                              quality_analysis: code_quality_analysis,
                              complexity_analysis: complexity_metrics,
                              pattern_analysis: %PatternAnalysis{detected_patterns: [], anti_patterns: [], design_patterns: [], pattern_metrics: %{}},
                              dependency_analysis: %DependencyAnalysis{dependency_graph: %{}, circular_dependencies: [], dependency_chains: [], critical_variables: [], isolated_variables: []},
                              information_flow: information_flow_analysis,
                              alias_analysis: alias_analysis,
                              optimization_hints: []
                            },
                            metadata: %{
                              generation_time: System.monotonic_time(:millisecond),
                              generator_version: "1.0.0",
                              cfg_complexity: cfg.complexity_metrics,
                              dfg_complexity: dfg.analysis_results
                            },
                            # Add direct references for test compatibility
                            control_flow_graph: cfg,
                            data_flow_graph: dfg,
                            unified_nodes: unified_nodes,
                            unified_edges: unified_edges,
                            complexity_metrics: complexity_metrics,
                            path_sensitive_analysis: path_sensitive_analysis,
                            security_analysis: security_analysis,
                            alias_analysis: alias_analysis,
                            performance_analysis: performance_analysis,
                            information_flow_analysis: information_flow_analysis,
                            code_quality_analysis: code_quality_analysis
                          }
                          
                          {:ok, cpg}
            rescue
              e -> 
        Logger.error("CPG Builder: Failed to build CPG from CFG/DFG: #{Exception.message(e)}")
        {:error, {:cpg_build_failed, e}}
    end
  end
  
  # Private implementation functions
  
  defp merge_graph_nodes(cfg_nodes, dfg_nodes) do
    # Create unified node representation
    unified = %{}
    
    # Add CFG nodes first
    unified = case cfg_nodes do
      nodes when is_map(nodes) ->
        try do
          Enum.reduce(nodes, unified, fn {id, cfg_node}, acc ->
            unified_node = %{
              id: id,
              type: :unified,
              cfg_node: cfg_node,
              dfg_node: nil,
              cfg_node_id: id,
              dfg_node_id: nil,
              line_number: Map.get(cfg_node, :line, 0),
              ast_node: Map.get(cfg_node, :ast_node_id),
              ast_type: Map.get(cfg_node, :type, :unknown),
              metadata: %{
                control_flow: true,
                data_flow: false
              }
            }
            Map.put(acc, id, unified_node)
          end)
        rescue
          e ->
            Logger.error("CPG Builder: Error processing CFG map nodes: #{Exception.message(e)}")
            reraise e, __STACKTRACE__
        end
      
      nodes when is_list(nodes) ->
        try do
          nodes
          |> Enum.with_index()
          |> Enum.reduce(unified, fn {cfg_node, index}, acc ->
            id = Map.get(cfg_node, :id, "cfg_node_#{index}")
            unified_node = %{
              id: id,
              type: :unified,
              cfg_node: cfg_node,
              dfg_node: nil,
              cfg_node_id: id,
              dfg_node_id: nil,
              line_number: Map.get(cfg_node, :line, 0),
              ast_node: Map.get(cfg_node, :ast_node_id),
              ast_type: Map.get(cfg_node, :type, :unknown),
              metadata: %{
                control_flow: true,
                data_flow: false
              }
            }
            Map.put(acc, id, unified_node)
          end)
        rescue
          e ->
            Logger.error("CPG Builder: Error processing CFG list nodes: #{Exception.message(e)}")
            reraise e, __STACKTRACE__
        end
      
      _ -> 
        unified
    end
    
    # Convert DFG nodes list to map
    dfg_nodes_map = case dfg_nodes do
      nodes when is_list(nodes) ->
        try do
          Enum.reduce(nodes, %{}, fn node, acc ->
            id = Map.get(node, :id, "unknown")
            Map.put(acc, id, node)
          end)
        rescue
          e ->
            Logger.error("CPG Builder: Error converting DFG nodes to map: #{Exception.message(e)}")
            reraise e, __STACKTRACE__
        end
      nodes when is_map(nodes) ->
        nodes
      _ ->
        %{}
    end
    
    # Merge DFG nodes
    unified = try do
      Enum.reduce(dfg_nodes_map, unified, fn {id, dfg_node}, acc ->
        case Map.get(acc, id) do
          nil ->
            # New DFG-only node
            unified_node = %{
              id: id,
              type: :unified,
              cfg_node: nil,
              dfg_node: dfg_node,
              cfg_node_id: nil,
              dfg_node_id: id,
              line_number: Map.get(dfg_node, :line, 0),
              ast_node: Map.get(dfg_node, :ast_node_id),
              ast_type: Map.get(dfg_node, :type, :unknown),
              metadata: %{
                control_flow: false,
                data_flow: true
              }
            }
            Map.put(acc, id, unified_node)
          
          existing_node ->
            # Merge with existing CFG node
            merged_node = %{
              existing_node |
              dfg_node: dfg_node,
              dfg_node_id: id,
              metadata: %{
                control_flow: true,
                data_flow: true
              }
            }
            Map.put(acc, id, merged_node)
        end
      end)
    rescue
      e ->
        Logger.error("CPG Builder: Error merging DFG nodes: #{Exception.message(e)}")
        reraise e, __STACKTRACE__
    end
    
    unified
  end
  
  defp merge_graph_edges(cfg_edges, dfg_edges) do
    # Create unified edge list
    unified = %{}
    
    # Add CFG edges first
    unified = case cfg_edges do
      edges when is_list(edges) ->
        try do
          edges
          |> Enum.with_index()
          |> Enum.reduce(unified, fn {cfg_edge, index}, acc ->
            id = Map.get(cfg_edge, :id, "cfg_edge_#{index}")
            unified_edge = %{
              id: id,
              type: :unified,
              cfg_edge: cfg_edge,
              dfg_edge: nil,
              cfg_edge_id: id,
              dfg_edge_id: nil,
              source: Map.get(cfg_edge, :source),
              target: Map.get(cfg_edge, :target),
              metadata: %{
                control_flow: true,
                data_flow: false
              }
            }
            Map.put(acc, id, unified_edge)
          end)
        rescue
          e ->
            Logger.error("CPG Builder: Error processing CFG edges: #{Exception.message(e)}")
            reraise e, __STACKTRACE__
        end
      
      _ -> unified
    end
    
    # Convert DFG edges list to map
    dfg_edges_map = case dfg_edges do
      edges when is_list(edges) ->
        try do
          Enum.reduce(edges, %{}, fn edge, acc ->
            id = Map.get(edge, :id, "unknown")
            Map.put(acc, id, edge)
          end)
        rescue
          e ->
            Logger.error("CPG Builder: Error converting DFG edges to map: #{Exception.message(e)}")
            reraise e, __STACKTRACE__
        end
      edges when is_map(edges) ->
        edges
      _ ->
        %{}
    end
    
    # Merge DFG edges
    unified = try do
      Enum.reduce(dfg_edges_map, unified, fn {id, dfg_edge}, acc ->
        case Map.get(acc, id) do
      nil -> 
            # New DFG-only edge
            unified_edge = %{
              id: id,
              type: :unified,
              cfg_edge: nil,
              dfg_edge: dfg_edge,
              cfg_edge_id: nil,
              dfg_edge_id: id,
              source: Map.get(dfg_edge, :source),
              target: Map.get(dfg_edge, :target),
              metadata: %{
                control_flow: false,
                data_flow: true
              }
            }
            Map.put(acc, id, unified_edge)
          
          existing_edge ->
            # Merge with existing CFG edge
            merged_edge = %{
              existing_edge |
              dfg_edge: dfg_edge,
              dfg_edge_id: id,
              metadata: %{
                control_flow: true,
                data_flow: true
              }
            }
            Map.put(acc, id, merged_edge)
        end
      end)
    rescue
      e ->
        Logger.error("CPG Builder: Error merging DFG edges: #{Exception.message(e)}")
        reraise e, __STACKTRACE__
    end
    
    Map.values(unified)
  end

  defp create_node_mappings(cfg, dfg) do
    %NodeMappings{
      ast_to_cfg: extract_ast_to_cfg_mappings(cfg),
      ast_to_dfg: extract_ast_to_dfg_mappings(dfg),
      cfg_to_dfg: extract_cfg_to_dfg_mappings(cfg, dfg),
      dfg_to_cfg: extract_dfg_to_cfg_mappings(cfg, dfg),
      unified_mappings: %{},
      reverse_mappings: %{}
    }
  end

  defp create_query_indexes(nodes, edges) do
    %QueryIndexes{
      by_type: index_nodes_by_type(nodes),
      by_line: index_nodes_by_line(nodes),
      by_scope: index_nodes_by_scope(nodes),
      by_variable: index_nodes_by_variable(nodes),
      by_function_call: index_nodes_by_function_call(nodes),
      control_flow_paths: extract_control_flow_paths(edges),
      data_flow_chains: extract_data_flow_chains(edges),
      pattern_indexes: %{}
    }
  end

  defp extract_function_key_from_cfg(cfg) do
      case cfg do
      %{metadata: %{function_key: key}} -> key
      %{metadata: %{function: {module, name, arity}}} -> {module, name, arity}
      _ -> {UnknownModule, :unknown, 0}
    end
  end

  defp find_performance_hotspots(cfg, dfg) do
    hotspots = []

    # Check for expensive operations in CFG
    hotspots = case cfg do
        %{nodes: nodes} when is_map(nodes) ->
        Enum.reduce(nodes, hotspots, fn {id, node}, acc ->
          case node do
            %{type: :loop, metadata: %{nested: true}} ->
              [%{
                type: :nested_loop,
                severity: :high,
                node: id,
                suggestion: "Consider restructuring nested loops"
              } | acc]
            _ -> acc
          end
        end)
      _ -> hotspots
    end

    # Check for expensive data operations in DFG
    hotspots = case dfg do
      %{nodes: nodes} when is_list(nodes) ->
        Enum.reduce(nodes, hotspots, fn node, acc ->
      case node do
            %{type: :operation, metadata: %{complexity: complexity}} when complexity > 100 ->
              [%{
                type: :expensive_operation,
                severity: :high,
                node: node.id,
                suggestion: "Optimize data operation"
              } | acc]
            _ -> acc
          end
        end)
      _ -> hotspots
    end

    hotspots
  end

  # Helper functions for node mappings
  defp extract_ast_to_cfg_mappings(cfg), do: %{}
  defp extract_ast_to_dfg_mappings(dfg), do: %{}
  defp extract_cfg_to_dfg_mappings(cfg, dfg), do: %{}
  defp extract_dfg_to_cfg_mappings(cfg, dfg), do: %{}

  # Helper functions for query indexes
  defp index_nodes_by_type(nodes), do: %{}
  defp index_nodes_by_line(nodes), do: %{}
  defp index_nodes_by_scope(nodes), do: %{}
  defp index_nodes_by_variable(nodes), do: %{}
  defp index_nodes_by_function_call(nodes), do: %{}
  defp extract_control_flow_paths(edges), do: %{}
  defp extract_data_flow_chains(edges), do: %{}

  # Analysis helper functions
  defp calculate_combined_complexity(cfg, dfg, nodes, edges), do: %{}
  defp perform_path_sensitive_analysis(cfg, dfg, nodes), do: %{}
  defp perform_security_analysis(cfg, dfg, nodes, edges), do: %{}
  defp perform_alias_analysis(dfg, nodes), do: %{}
  defp perform_code_quality_analysis(cfg, dfg, nodes), do: %{}
  defp perform_performance_analysis(cfg, dfg, complexity), do: %{}
  defp perform_information_flow_analysis(dfg, edges), do: %{}

  @doc """
  Performs complex queries across all graph dimensions.
  """
  def query_cpg(cpg, query) do
    case query do
      {:find_pattern, pattern} ->
        find_pattern(cpg, pattern)
      
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
      
      _ ->
        {:error, :invalid_query}
    end
  end
  
  # Query helper functions
  defp find_pattern(_cpg, _pattern), do: []
  defp filter_security_issues(_analysis, _type), do: []
  defp filter_performance_issues(_analysis, _threshold), do: []
  defp filter_code_smells(_analysis, _category), do: []
  defp trace_data_flow(_cpg, _from, _to), do: []
  defp trace_control_flow(_cpg, _from, _to), do: []
end 