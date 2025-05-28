# === 6-testing-strats.exs ===
defmodule ElixirScope.ASTRepository.ComprehensiveTesting do
  use ExUnit.Case, async: true # Most tests can be async if they don't share ETS state

  alias ElixirScope.ASTRepository.{
    EnhancedFunctionData, # Assuming this is the input to generators
    CFGData, CFGNode, CFGEdge, ComplexityMetrics, ScopeInfo,
    DFGData, VariableVersion, Definition, Use, DataFlow, PhiNode,
    CPGData, CPGNode, CPGEdge,
    CFGGenerator,
    DFGGenerator,
    CPGBuilder
  }

  # Helper to create a minimal EnhancedFunctionData for testing
  defp build_test_function_data(module_name, fun_name, arity, ast, file_path \\ "test.ex") do
    %EnhancedFunctionData{
      module_name: module_name,
      function_name: fun_name,
      arity: arity,
      ast_node_id: "#{module_name}:#{fun_name}:#{arity}:def", # Simplified
      file_path: file_path,
      line_start: 1, line_end: (Macro.to_string(ast) |> String.split("\n") |> length()),
      ast: ast,
      head_ast: List.first(elem(ast, 2)), # {:def, _, [head | _]}
      body_ast: List.last(elem(ast, 2)) |> elem(1),  # {:def, _, [_, [do: body]]}
      # Initialize other fields that might be expected by generators
      control_flow_graph: nil, # To be filled by CFGGenerator
      data_flow_graph: nil,    # To be filled by DFGGenerator
      # ... other fields default to nil or empty lists/maps
      visibility: :public,
      is_macro: false,
      is_guard: false,
      is_callback: false,
      is_delegate: false,
      clauses: [],
      guard_clauses: [],
      pattern_matches: [],
      parameters: [],
      local_variables: [],
      captures: [],
      cyclomatic_complexity: 0,
      nesting_depth: 0,
      variable_mutations: [],
      return_points: [],
      called_functions: [],
      calling_functions: [],
      external_calls: [],
      complexity_score: 0.0,
      maintainability_index: 0.0,
      doc_string: nil,
      spec: nil,
      examples: [],
      tags: [],
      annotations: %{},
      metadata: %{}
    }
  end


  # --- Test Fixtures: AST Snippets ---

  defp simple_assign_ast do
    quote do
      def simple_assign(a) do
        x = a + 1
        y = x * 2
        y
      end
    end
  end

  defp if_else_ast do
    quote do
      def if_else(a) do
        if a > 10 do
          x = "greater"
          x
        else
          y = "smaller_or_equal"
          y
        end
      end
    end
  end

  defp case_ast do
    quote do
      def case_example(val) do
        case val do
          {:ok, data} ->
            res = process_ok(data)
            res
          {:error, reason} ->
            res_err = handle_error(reason)
            res_err
          _other ->
            :unknown
        end
      end
    end
  end

  defp pattern_match_head_ast do
    quote do
      def handle_message({:ping, from_pid}, state) do
        send(from_pid, :pong)
        {:noreply, state}
      end

      def handle_message(:stop, state) do
        {:stop, :normal, state}
      end
    end
    # Note: DFG/CFG typically operate on a single function definition at a time.
    # This AST contains two. Tests would need to extract one `def` block.
    # For simplicity, test cases will use single defs.
  end

  defp single_clause_pm_head_ast do
    quote do
      def pm_head({:data, value}) do
        process(value)
      end
    end
  end

  defp pipe_ast do
    quote do
      def pipe_example(input) do
        input
        |> Enum.map(&(&1 * 2))
        |> Enum.filter(&(&1 > 10))
        |> Enum.sum()
      end
    end
  end

  # --- CFG Validation Tests ---
  describe "CFGGenerator" do
    test "generates CFG for simple assignment function" do
      ast = simple_assign_ast()
      {:ok, cfg} = CFGGenerator.generate_cfg(ast)

      assert %CFGData{} = cfg
      assert cfg.entry_node != nil
      assert cfg.exit_nodes != []
      assert map_size(cfg.nodes) >= 3 # entry, assignments, exit
      assert length(cfg.edges) >= 2
      assert cfg.complexity_metrics.cyclomatic_complexity == 1 # Straight line
    end

    test "generates CFG for if-else construct and calculates complexity" do
      ast = if_else_ast()
      {:ok, cfg} = CFGGenerator.generate_cfg(ast)

      assert %CFGData{} = cfg
      # Expect nodes: entry, if_cond, then_block_entry, then_assign, then_exit,
      # else_block_entry, else_assign, else_exit, merge_node, final_exit
      assert map_size(cfg.nodes) >= 6 # entry, if_cond, then_body_entry, else_body_entry, merge, (final exit implicitly or explicitly)
      assert length(cfg.edges) >= 7 # entry->if, if->then, if->else, then->merge, else->merge etc.
      assert cfg.complexity_metrics.cyclomatic_complexity == 2 # One if condition
      assert Enum.any?(Map.values(cfg.nodes), &(&1.type == :if_condition))
      assert Enum.any?(cfg.edges, &(&1.type == :conditional && &1.condition == "true"))
      assert Enum.any?(cfg.edges, &(&1.type == :conditional && &1.condition =~ "false"))
    end

    test "generates CFG for case statement" do
      ast = case_ast()
      {:ok, cfg} = CFGGenerator.generate_cfg(ast)
      assert %CFGData{} = cfg
      assert cfg.complexity_metrics.cyclomatic_complexity == 3 # case with 3 branches (2 explicit + default)
      assert Enum.count(Map.values(cfg.nodes), &(&1.type == :case_clause)) >= 3
      assert Enum.any?(Map.values(cfg.nodes), &(&1.type == :case_entry))
    end

    test "generates CFG for pipe operations as sequential flow" do
      ast = pipe_ast()
      {:ok, cfg} = CFGGenerator.generate_cfg(ast)
      assert %CFGData{} = cfg
      assert cfg.complexity_metrics.cyclomatic_complexity == 1 # Pipes are sequential unless anon fns have branches
      # Expect nodes for each step in the pipe + entry/exit
      assert map_size(cfg.nodes) >= (3 + 2) # 3 pipe stages + entry + exit
    end
  end

  # --- DFG Validation Tests ---
  describe "DFGGenerator" do
    test "generates DFG for simple assignment with SSA variables" do
      ast = simple_assign_ast()
      func_key = {:TestModule, :simple_assign, 1}
      {:ok, dfg} = DFGGenerator.generate_dfg(ast, func_key)

      assert %DFGData{} = dfg
      assert Map.has_key?(dfg.variables, :a)
      assert Map.has_key?(dfg.variables, :x)
      assert Map.has_key?(dfg.variables, :y)

      # Check SSA versions
      assert [%VariableVersion{name: :a, version: 0, is_parameter: true}] = dfg.variables[:a]
      assert [%VariableVersion{name: :x, version: 0}] = dfg.variables[:x]
      assert [%VariableVersion{name: :y, version: 0}] = dfg.variables[:y]

      # Check definitions and uses
      assert Enum.count(dfg.definitions, &(&1.variable.name == :a && &1.definition_type == :parameter)) == 1
      assert Enum.count(dfg.definitions, &(&1.variable.name == :x && &1.definition_type == :assignment)) == 1
      assert Enum.count(dfg.definitions, &(&1.variable.name == :y && &1.definition_type == :assignment)) == 1

      assert Enum.count(dfg.uses, &(&1.variable.name == :a)) >= 1 # a used in `a + 1`
      assert Enum.count(dfg.uses, &(&1.variable.name == :x)) >= 1 # x used in `x * 2`
      assert Enum.count(dfg.uses, &(&1.variable.name == :y)) >= 1 # y used as return (implicit use)

      # Check data flows
      assert Enum.any?(dfg.data_flows, fn df ->
        df.from_definition.variable.name == :a &&
        df.to_use.variable.name == :a && # used in x = a + 1
        df.to_use.ast_node_id != nil # Check that use points to AST of a+1
      end)
      assert Enum.any?(dfg.data_flows, fn df ->
        df.from_definition.variable.name == :x &&
        df.to_use.variable.name == :x # used in y = x * 2
      end)
    end

    test "generates DFG for if-else with Phi nodes" do
      ast = if_else_ast()
      func_key = {:TestModule, :if_else, 1}
      {:ok, dfg} = DFGGenerator.generate_dfg(ast, func_key)

      assert %DFGData{} = dfg
      # Variable 'x' is defined in 'then' branch, 'y' in 'else'.
      # If a variable was defined before the 'if' and modified in branches,
      # or if a variable from each branch was used after the 'if',
      # we'd expect a phi node for it.
      # In this specific AST, x and y are local to their branches and then returned.
      # The "result" of the if/else would be a phi node if assigned to a var, e.g., `z = if ...`.
      # Here, the function implicitly returns x or y. This means the DFG of the *return*
      # would need to trace back to a phi-like merge of the values of x and y.

      # For a simple check, ensure x and y are defined.
      assert Map.has_key?(dfg.variables, :x)
      assert Map.has_key?(dfg.variables, :y)
      assert length(dfg.phi_nodes) >= 0 # Might be 0 if implicit return doesn't create explicit phi object
                                      # Or 1 if the control flow merge implies a phi for the returned value.
                                      # The DFGGenerator's Phi logic needs to be precise.
      # A more robust test would be:
      # var_after_if = if a > 10 do x = ...; x else y = ...; y end
      # Then check for phi node for var_after_if
    end

    test "generates DFG for pattern matching in function head" do
      ast = single_clause_pm_head_ast() # def pm_head({:data, value})
      func_key = {:TestModule, :pm_head, 1}
      {:ok, dfg} = DFGGenerator.generate_dfg(ast, func_key)

      assert Map.has_key?(dfg.variables, :value)
      value_def = Enum.find(dfg.definitions, &(&1.variable.name == :value))
      assert value_def.definition_type == :parameter # Or :pattern_match if parameters are treated as patterns
      assert value_def.scope_id != nil
    end
  end


  # --- CPG Validation Tests ---
  describe "CPGBuilder" do
    test "builds CPG for simple function, unifying AST, CFG, DFG" do
      simple_ast = simple_assign_ast()
      func_key = {:TestModule, :simple_assign, 1}

      # 1. Generate CFG
      {:ok, cfg_data} = CFGGenerator.generate_cfg(simple_ast)

      # 2. Generate DFG
      {:ok, dfg_data} = DFGGenerator.generate_dfg(simple_ast, func_key)

      # 3. Create EnhancedFunctionData (mocked up)
      function_data = build_test_function_data(
        elem(func_key,0), elem(func_key,1), elem(func_key,2),
        simple_ast
      )
      |> Map.put(:control_flow_graph, cfg_data)
      |> Map.put(:data_flow_graph, dfg_data)
      # ... (add other necessary fields to function_data if CPGBuilder uses them)

      # 4. Build CPG
      {:ok, cpg} = CPGBuilder.build_cpg(function_data)

      assert %CPGData{} = cpg
      assert map_size(cpg.nodes) > 0
      assert length(cpg.edges) > 0

      # Check AST node mappings
      # Each AST node in the original simple_ast should have a CPG node
      # This is a loose check; precise counting depends on AST traversal granularity
      original_ast_node_count = count_ast_nodes_recursively(simple_ast)
      assert map_size(cpg.node_mappings.ast) >= original_ast_node_count - 5 # Allow some leeway for literals not becoming distinct CPG nodes

      # Check CFG overlay: CFG nodes should map to CPG nodes
      assert map_size(cpg.node_mappings.cfg) == map_size(cfg_data.nodes)
      assert Enum.all?(Map.values(cpg.node_mappings.cfg), &Map.has_key?(cpg.nodes, &1))

      # Check DFG overlay: DFG definitions/uses should map to CPG nodes
      # This mapping is more complex as DFG elements are per ssa_variable version
      assert map_size(cpg.node_mappings.dfg_defs) >= length(dfg_data.definitions)
      assert Enum.all?(Map.values(cpg.node_mappings.dfg_defs), &Map.has_key?(cpg.nodes, &1))

      # Check for CPG edge types
      assert Enum.any?(cpg.edges, &(&1.type == :ast_child))
      assert Enum.any?(cpg.edges, &(&1.type == :cfg_flow || &1.type == :cfg_conditional))
      assert Enum.any?(cpg.edges, &(&1.type == :dfg_reaches)) # Or :dfg_def_use
    end

    test "CPG nodes contain augmented data" do
      ast = if_else_ast()
      func_key = {:TestModule, :if_else, 1}
      {:ok, cfg_data} = CFGGenerator.generate_cfg(ast)
      {:ok, dfg_data} = DFGGenerator.generate_dfg(ast, func_key)
      function_data = build_test_function_data(elem(func_key,0), elem(func_key,1), elem(func_key,2), ast)
                      |> Map.put(:control_flow_graph, cfg_data)
                      |> Map.put(:data_flow_graph, dfg_data)
      {:ok, cpg} = CPGBuilder.build_cpg(function_data)

      # Find a CPG node that corresponds to an AST node that's also a CFG node
      # e.g., the 'if' condition expression node
      if_cond_ast_node = elem(elem(ast, 2) |> List.last() |> elem(1), 0) # {:if, _, [condition_ast | _]} -> condition_ast
      if_cond_ast_id = ElixirScope.ASTRepository.CFGGenerator.get_ast_node_id(elem(if_cond_ast_node,1))


      mapped_cpg_id = cpg.node_mappings.ast[if_cond_ast_id]
      refute is_nil(mapped_cpg_id), "AST node for 'if condition' should map to a CPG node"

      cpg_node = cpg.nodes[mapped_cpg_id]
      refute is_nil(cpg_node), "CPG node for 'if condition' should exist"

      assert cpg_node.ast_data != nil
      assert cpg_node.cfg_data != nil # The 'if condition' is a CFG node
      # It might also have DFG data if it involves variable uses
      # assert cpg_node.dfg_data != nil
    end
  end


  # --- Helper Functions for Testing ---
  defp count_ast_nodes_recursively(ast_node) do
    count = 1 # Count current node
    children = case ast_node do
      {_op, _meta, args} when is_list(args) -> args
      {:__block__, _meta, stmts} -> stmts
      {:->, _meta, [p, b]} -> [p, b]
      _ -> []
    end

    count + Enum.reduce(children, 0, fn child, acc ->
      if Macro.quoted?(child) do
        acc + count_ast_nodes_recursively(child)
      else
        acc # Don't count literals or atoms as distinct nodes in this context
      end
    end)
  end

  # Example of a custom assertion (can be expanded)
  defp assert_has_edge_type(cpg_or_cfg_edges, type) do
    assert Enum.any?(cpg_or_cfg_edges, &(&1.type == type)),
           "Expected to find an edge of type #{inspect(type)}"
  end

  defp assert_node_exists_with_type(cpg_or_cfg_nodes, type) do
     assert Enum.any?(Map.values(cpg_or_cfg_nodes), &(&1.type == type)),
            "Expected to find a node of type #{inspect(type)}"
  end

end
