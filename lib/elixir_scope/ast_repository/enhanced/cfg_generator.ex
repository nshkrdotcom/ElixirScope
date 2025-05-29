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
    CFGData,
    CFGNode,
    CFGEdge,
    ComplexityMetrics,
    ScopeInfo,
    PathAnalysis,
    LoopAnalysis,
    BranchCoverage,
    CFGGenerator.Utils,
    CFGGenerator.PathAnalyzer,
    CFGGenerator.ComplexityCalculator,
    CFGGenerator.ASTProcessor
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
      case validate_ast_structure(function_ast) do
        :ok ->
          state = initialize_state(function_ast, opts)

          case process_function_body(function_ast, state) do
            {:error, _reason} ->
              {:error, :invalid_ast}

            {nodes, edges, exits, scopes, _final_state} ->
              # Calculate complexity metrics
              complexity_metrics = ComplexityCalculator.calculate_complexity_metrics(nodes, edges, scopes)

              # Analyze paths
              entry_nodes = Utils.get_entry_nodes(nodes)
              entry_node = case entry_nodes do
                [first | _] -> first
                [] -> state.entry_node
              end
              path_analysis = PathAnalyzer.analyze_paths(nodes, edges, [state.entry_node], exits, opts)

              cfg = %CFGData{
                function_key: Keyword.get(opts, :function_key, Utils.extract_function_key(function_ast)),
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
        # Consider logging the error: Logger.error("CFG Generation failed: #{inspect(error)}")
        {:error, :invalid_ast} # Ensure this is a specific error tuple
    catch
      :error, _reason ->
        # Consider logging the reason: Logger.error("CFG Generation caught error: #{inspect(reason)}")
        {:error, :invalid_ast} # Ensure this is a specific error tuple
    end
  end

  # Add AST validation function
  defp validate_ast_structure(ast) do
    case ast do
      {:def, _meta, [_head, [do: _body]]} -> :ok
      {:defp, _meta, [_head, [do: _body]]} -> :ok
      _ -> {:error, :invalid_ast_structure}
    end
  end

  # Private implementation using research-based approach

  defp initialize_state(function_ast, opts) do
    entry_node_id = Utils.generate_node_id("entry")

    %{
      entry_node: entry_node_id,
      next_node_id: 1,
      nodes: %{},
      edges: [],
      scopes: %{},
      current_scope: "function_scope",
      scope_counter: 1,
      options: opts,
      function_key: Keyword.get(opts, :function_key, Utils.extract_function_key(function_ast))
    }
  end

  defp process_function_body({:def, meta, [head, [do: body]]}, state) do
    process_function_body({:defp, meta, [head, [do: body]]}, state)
  end

  defp process_function_body({:defp, meta, [head, [do: body]]}, state) do
    line = Utils.get_line_number(meta)

    # Extract function parameters and check for guards
    {function_params, guard_ast} = case head do
      {:when, _, [func_head, guard]} ->
        # Function has a guard
        {Utils.extract_function_parameters(func_head), guard}
      func_head ->
        # No guard
        {Utils.extract_function_parameters(func_head), nil}
    end

    # Create function scope
    function_scope = %ScopeInfo{
      id: state.current_scope,
      type: :function,
      parent_scope: nil,
      child_scopes: [],
      variables: function_params,
      ast_node_id: Utils.get_ast_node_id(meta),
      entry_points: [state.entry_node],
      exit_points: [],
      metadata: %{function_head: head, guard: guard_ast}
    }

    # Create entry node
    entry_node = %CFGNode{
      id: state.entry_node,
      type: :entry,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: head,
      predecessors: [],
      successors: [],
      metadata: %{function_head: head, guard: guard_ast}
    }

    initial_state = %{state | nodes: %{state.entry_node => entry_node}}

    # Process guard if present
    {guard_nodes, guard_edges, guard_exits, guard_scopes, guard_state} =
      if guard_ast do
        ASTProcessor.process_ast_node(guard_ast, initial_state)
      else
        {%{}, [], [state.entry_node], %{}, initial_state}
      end

    # Process function body
    {body_nodes, body_edges, body_exits, body_scopes, updated_state} =
      ASTProcessor.process_ast_node(body, guard_state)

    # Connect entry to guard (if guard exists) or directly to body
    entry_connections = if guard_ast do
      # Connect entry to guard
      guard_entry_nodes = Utils.get_entry_nodes(guard_nodes)
      Enum.map(guard_entry_nodes, fn node_id ->
        %CFGEdge{
          from_node_id: state.entry_node,
          to_node_id: node_id,
          type: :sequential,
          condition: nil,
          probability: 1.0,
          metadata: %{connection: :entry_to_guard}
        }
      end)
    else
      # Connect entry directly to body
      body_entry_nodes = Utils.get_entry_nodes(body_nodes)
      if body_entry_nodes == [] do
        # Empty function body - no body nodes to connect to
        # We'll connect entry to exit later
        []
      else
        Enum.map(body_entry_nodes, fn node_id ->
          %CFGEdge{
            from_node_id: state.entry_node,
            to_node_id: node_id,
            type: :sequential,
            condition: nil,
            probability: 1.0,
            metadata: %{connection: :entry_to_body}
          }
        end)
      end
    end

    # Connect guard to body (if guard exists)
    guard_to_body_edges = if guard_ast do
      body_entry_nodes = Utils.get_entry_nodes(body_nodes)
      Enum.flat_map(guard_exits, fn guard_exit ->
        Enum.map(body_entry_nodes, fn body_entry ->
          %CFGEdge{
            from_node_id: guard_exit,
            to_node_id: body_entry,
            type: :sequential,
            condition: nil,
            probability: 1.0,
            metadata: %{connection: :guard_to_body}
          }
        end)
      end)
    else
      []
    end

    # Create exit node
    {exit_node_id, final_state} = Utils.generate_node_id("exit", updated_state)
    exit_node = %CFGNode{
      id: exit_node_id,
      type: :exit,
      ast_node_id: nil,
      line: line,
      scope_id: state.current_scope,
      expression: nil,
      predecessors: body_exits,
      successors: [],
      metadata: %{}
    }

    # Connect body exits to function exit
    exit_edges = Enum.map(body_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: exit_node_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    # Handle empty function body case - connect entry directly to exit
    direct_entry_to_exit_edges = if body_exits == [] and guard_exits == [state.entry_node] do
      # Empty function body with no guard, or guard that doesn't produce nodes
      [%CFGEdge{
        from_node_id: state.entry_node,
        to_node_id: exit_node_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{connection: :entry_to_exit_direct}
      }]
    else
      []
    end

    all_nodes = guard_nodes
    |> Map.merge(body_nodes)
    |> Map.put(state.entry_node, entry_node)
    |> Map.put(exit_node_id, exit_node)

    all_edges = entry_connections ++ guard_edges ++ guard_to_body_edges ++ body_edges ++ exit_edges ++ direct_entry_to_exit_edges
    all_scopes = Map.merge(guard_scopes, body_scopes)
    |> Map.put(state.current_scope, function_scope)

    {all_nodes, all_edges, [exit_node_id], all_scopes, final_state}
  end

  defp process_function_body(malformed_ast, _state) do
    # Handle any malformed or unexpected AST structure
    {:error, {:cfg_generation_failed, "Invalid AST structure: #{inspect(malformed_ast)}"}}
  end
end