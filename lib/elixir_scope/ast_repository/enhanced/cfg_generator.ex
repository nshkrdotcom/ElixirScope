defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator do
  @moduledoc """
  Enhanced Control Flow Graph generator for Elixir functions.

  Uses research-based approach with:
  - Decision POINTS complexity calculation (not edges)
  - Sophisticated CFGData structures with path analysis
  - Proper Elixir semantics (pattern matching, guards, pipes)
  - SSA-compatible scope management
  - Comprehensive complexity metrics

  Performance targets:
  - CFG generation: <100ms for functions with <100 AST nodes
  - Memory efficient: <1MB per function CFG
  """

  alias ElixirScope.ASTRepository.Enhanced.{
    CFGData, CFGNode, CFGEdge, ComplexityMetrics, ScopeInfo,
    PathAnalysis, LoopAnalysis, BranchCoverage
  }

  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.{
    ASTProcessor,
    ComplexityCalculator,
    PathAnalyzer,
    StateManager,
    Validators
  }

  @doc """
  Generates a control flow graph from function AST using research-based approach.

  ## Parameters
  - function_ast: The AST of the function to analyze
  - opts: Options for CFG generation
    - :function_key - {module, function, arity} tuple
    - :include_path_analysis - whether to perform path analysis (default: true)
    - :max_paths - maximum paths to analyze (default: 1000)

  ## Returns
  {:ok, CFGData.t()} | {:error, term()}
  """
  @spec generate_cfg(Macro.t(), keyword()) :: {:ok, CFGData.t()} | {:error, term()}
  def generate_cfg(function_ast, opts \\ []) do
    try do
      # Validate AST structure first
      case Validators.validate_ast_structure(function_ast) do
        :ok ->
          state = StateManager.initialize_state(function_ast, opts)

          case ASTProcessor.process_function_body(function_ast, state) do
            {:error, _reason} ->
              {:error, :invalid_ast}

            {nodes, edges, exits, scopes, _final_state} ->
              # Calculate complexity metrics
              complexity_metrics = ComplexityCalculator.calculate_complexity_metrics(nodes, edges, scopes)

              # Analyze paths
              entry_nodes = get_entry_nodes(nodes)
              entry_node = case entry_nodes do
                [first | _] -> first
                [] -> state.entry_node
              end
              path_analysis = PathAnalyzer.analyze_paths(nodes, edges, [state.entry_node], exits, opts)

              cfg = %CFGData{
                function_key: Keyword.get(opts, :function_key, extract_function_key(function_ast)),
                entry_node: entry_node,
                exit_nodes: exits,
                nodes: nodes,
                edges: edges,
                scopes: scopes,
                complexity_metrics: complexity_metrics,
                path_analysis: path_analysis,
                metadata: %{
                  generated_at: DateTime.utc_now(),
                  generator_version: "1.0.0"
                }
              }

              {:ok, cfg}
          end

        {:error, _reason} ->
          {:error, :invalid_ast}
      end
    rescue
      _error ->
        {:error, :invalid_ast}
    catch
      :error, _reason ->
        {:error, :invalid_ast}
    end
  end

  # Utility functions that are used by multiple modules
  defp get_entry_nodes(nodes) when map_size(nodes) == 0, do: []
  defp get_entry_nodes(nodes) do
    # Find nodes with no predecessors
    nodes
    |> Map.values()
    |> Enum.filter(fn node -> length(node.predecessors) == 0 end)
    |> Enum.map(& &1.id)
    |> case do
      [] -> [nodes |> Map.keys() |> List.first()]  # Fallback to first node
      entry_nodes -> entry_nodes
    end
  end

  defp extract_function_key({:def, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {UnknownModule, name, arity}
  end

  defp extract_function_key({:defp, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {UnknownModule, name, arity}
  end

  defp extract_function_key(_), do: {UnknownModule, :unknown, 0}
end
