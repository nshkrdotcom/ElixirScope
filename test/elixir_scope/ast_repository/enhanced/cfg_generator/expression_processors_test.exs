defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessorsTest do
  use ExUnit.Case, async: true

  import Mox

  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors
  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors.{
    BasicProcessors,
    AssignmentProcessors,
    FunctionProcessors,
    ControlFlowProcessors
  }

  # Setup mocks
  setup :verify_on_exit!

  setup do
    # Configure mocks for this test
    Application.put_env(:elixir_scope, :state_manager, ElixirScope.MockStateManager)
    Application.put_env(:elixir_scope, :ast_utilities, ElixirScope.MockASTUtilities)
    Application.put_env(:elixir_scope, :ast_processor, ElixirScope.MockASTProcessor)

    on_exit(fn ->
      # Reset to real modules after test
      Application.put_env(:elixir_scope, :state_manager,
        ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager)
      Application.put_env(:elixir_scope, :ast_utilities,
        ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities)
      Application.put_env(:elixir_scope, :ast_processor,
        ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor)
    end)

    :ok
  end

  describe "process_literal_value/2" do
    test "creates a literal node for atom values" do
      initial_state = %{
        entry_node: "entry_1",
        next_node_id: 1,
        nodes: %{},
        edges: [],
        scopes: %{},
        current_scope: "function_scope",
        scope_counter: 1,
        options: [],
        function_key: {:unknown_module_placeholder, :test_function, 0}
      }

      updated_state = %{initial_state | next_node_id: 2}

      # Mock StateManager.generate_node_id/2
      ElixirScope.MockStateManager
      |> expect(:generate_node_id, fn "literal", ^initial_state ->
        {"literal_1", updated_state}
      end)

      # Mock ASTUtilities.get_literal_type/1
      ElixirScope.MockASTUtilities
      |> expect(:get_literal_type, fn :ok -> :atom end)

      # Execute the function using BasicProcessors directly
      {nodes, _edges, exits, _scopes, new_state} =
        BasicProcessors.process_literal_value(:ok, initial_state)

      # Verify results
      assert map_size(nodes) == 1
      assert Map.has_key?(nodes, "literal_1")

      literal_node = nodes["literal_1"]
      assert literal_node.id == "literal_1"
      assert literal_node.type == :literal
      assert literal_node.expression == :ok
      assert literal_node.metadata.value == :ok
      assert literal_node.metadata.type == :atom
      assert literal_node.scope_id == "function_scope"

      assert exits == ["literal_1"]
      assert new_state.next_node_id == 2
    end

    test "creates a literal node for string values" do
      initial_state = %{
        entry_node: "entry_1",
        next_node_id: 5,
        nodes: %{},
        edges: [],
        scopes: %{},
        current_scope: "test_scope",
        scope_counter: 1,
        options: [],
        function_key: {:unknown_module_placeholder, :test_function, 1}
      }

      updated_state = %{initial_state | next_node_id: 6}

      # Mock StateManager.generate_node_id/2
      ElixirScope.MockStateManager
      |> expect(:generate_node_id, fn "literal", ^initial_state ->
        {"literal_5", updated_state}
      end)

      # Mock ASTUtilities.get_literal_type/1
      ElixirScope.MockASTUtilities
      |> expect(:get_literal_type, fn "hello" -> :string end)

      # Execute the function using BasicProcessors directly
      {nodes, _edges, exits, _scopes, new_state} =
        BasicProcessors.process_literal_value("hello", initial_state)

      # Verify results
      assert map_size(nodes) == 1
      literal_node = nodes["literal_5"]
      assert literal_node.expression == "hello"
      assert literal_node.metadata.value == "hello"
      assert literal_node.metadata.type == :string
      assert literal_node.scope_id == "test_scope"

      assert exits == ["literal_5"]
      assert new_state.next_node_id == 6
    end
  end

  describe "process_function_call/4" do
    test "creates a function call node" do
      initial_state = %{
        entry_node: "entry_1",
        next_node_id: 3,
        nodes: %{},
        edges: [],
        scopes: %{},
        current_scope: "test_scope",
        scope_counter: 1,
        options: [],
        function_key: {:unknown_module_placeholder, :test_function, 1}
      }

      updated_state = %{initial_state | next_node_id: 4}
      meta = [line: 42, ast_node_id: "ast_123"]
      args = [:arg1, :arg2]

      # Mock StateManager.generate_node_id/2
      ElixirScope.MockStateManager
      |> expect(:generate_node_id, fn "function_call", ^initial_state ->
        {"function_call_3", updated_state}
      end)

      # Mock ASTUtilities functions
      ElixirScope.MockASTUtilities
      |> expect(:get_line_number, fn ^meta -> 42 end)
      |> expect(:get_ast_node_id, fn ^meta -> "ast_123" end)

      # Execute the function using FunctionProcessors directly
      {nodes, _edges, exits, _scopes, new_state} =
        FunctionProcessors.process_function_call(:some_function, args, meta, initial_state)

      # Verify results
      assert map_size(nodes) == 1
      call_node = nodes["function_call_3"]

      assert call_node.id == "function_call_3"
      assert call_node.type == :function_call
      assert call_node.ast_node_id == "ast_123"
      assert call_node.line == 42
      assert call_node.scope_id == "test_scope"
      assert call_node.expression == {:some_function, meta, args}
      assert call_node.metadata.function == :some_function
      assert call_node.metadata.args == args
      assert call_node.metadata.is_guard == false

      assert exits == ["function_call_3"]
      assert new_state.next_node_id == 4
    end

    test "recognizes guard functions and sets guard type" do
      initial_state = %{
        entry_node: "entry_1",
        next_node_id: 1,
        nodes: %{},
        edges: [],
        scopes: %{},
        current_scope: "guard_scope",
        scope_counter: 1,
        options: [],
        function_key: {:unknown_module_placeholder, :test_function, 1}
      }

      updated_state = %{initial_state | next_node_id: 2}
      meta = [line: 10]
      args = [:value]

      # Mock StateManager.generate_node_id/2
      ElixirScope.MockStateManager
      |> expect(:generate_node_id, fn "function_call", ^initial_state ->
        {"function_call_1", updated_state}
      end)

      # Mock ASTUtilities functions
      ElixirScope.MockASTUtilities
      |> expect(:get_line_number, fn ^meta -> 10 end)
      |> expect(:get_ast_node_id, fn ^meta -> nil end)

      # Execute the function with a guard function using FunctionProcessors directly
      {nodes, _edges, _exits, _scopes, _new_state} =
        FunctionProcessors.process_function_call(:is_atom, args, meta, initial_state)

      # Verify guard function is recognized
      call_node = nodes["function_call_1"]
      assert call_node.type == :guard_check
      assert call_node.metadata.is_guard == true
      assert call_node.metadata.function == :is_atom
    end
  end

  describe "process_assignment/4" do
    test "creates assignment node and processes expression" do
      initial_state = %{
        entry_node: "entry_1",
        next_node_id: 1,
        nodes: %{},
        edges: [],
        scopes: %{},
        current_scope: "function_scope",
        scope_counter: 1,
        options: [],
        function_key: {:unknown_module_placeholder, :test_function, 1}
      }

      pattern = {:x, [line: 5], nil}
      expression = 42
      meta = [line: 5, ast_node_id: "assign_123"]

      # Mock StateManager.generate_node_id/2 calls
      ElixirScope.MockStateManager
      |> expect(:generate_node_id, fn "assignment", ^initial_state ->
        {"assignment_1", %{initial_state | next_node_id: 2}}
      end)
      |> expect(:generate_node_id, fn "expression", state ->
        {"expression_2", %{state | next_node_id: 3}}
      end)

      # Mock ASTUtilities functions
      ElixirScope.MockASTUtilities
      |> expect(:get_ast_node_id, 2, fn ^meta -> "assign_123" end)
      |> expect(:get_line_number, 2, fn ^meta -> 5 end)

      # Mock ASTProcessor.process_ast_node/2 to return empty (triggering expression node creation)
      ElixirScope.MockASTProcessor
      |> expect(:process_ast_node, fn ^expression, state ->
        {%{}, [], [], %{}, state}
      end)

      # Execute the function using AssignmentProcessors directly
      {nodes, edges, exits, _scopes, new_state} =
        AssignmentProcessors.process_assignment(pattern, expression, meta, initial_state)

      # Verify results
      assert map_size(nodes) == 2
      assert Map.has_key?(nodes, "assignment_1")
      assert Map.has_key?(nodes, "expression_2")

      # Check assignment node
      assign_node = nodes["assignment_1"]
      assert assign_node.type == :assignment
      assert assign_node.metadata.pattern == pattern
      assert assign_node.metadata.expression == expression

      # Check expression node (created because ASTProcessor returned empty)
      expr_node = nodes["expression_2"]
      assert expr_node.type == :expression
      assert expr_node.expression == expression

      # Check edges (expression -> assignment)
      assert length(edges) == 1
      edge = hd(edges)
      assert edge.from_node_id == "expression_2"
      assert edge.to_node_id == "assignment_1"
      assert edge.type == :sequential

      assert exits == ["assignment_1"]
      assert new_state.next_node_id == 3
    end
  end

  describe "process_comprehension/3" do
    test "creates comprehension node with complexity analysis" do
      initial_state = %{
        entry_node: "entry_1",
        next_node_id: 10,
        nodes: %{},
        edges: [],
        scopes: %{},
        current_scope: "function_scope",
        scope_counter: 1,
        options: [],
        function_key: {:unknown_module_placeholder, :test_function, 1}
      }

      clauses = [
        {:<-, [], [:item, :list]},
        {:>, [], [:item, 0]}
      ]
      meta = [line: 15, ast_node_id: "comp_456"]

      # Mock StateManager.generate_node_id/2
      ElixirScope.MockStateManager
      |> expect(:generate_node_id, fn "comprehension", ^initial_state ->
        {"comprehension_10", %{initial_state | next_node_id: 11}}
      end)

      # Mock ASTUtilities functions
      ElixirScope.MockASTUtilities
      |> expect(:get_ast_node_id, fn ^meta -> "comp_456" end)
      |> expect(:get_line_number, fn ^meta -> 15 end)
      |> expect(:analyze_comprehension_clauses, fn ^clauses ->
        {[{:<-, [], [:item, :list]}], [{:>, [], [:item, 0]}]}
      end)

      # Execute the function using ControlFlowProcessors directly
      {nodes, _edges, exits, _scopes, new_state} =
        ControlFlowProcessors.process_comprehension(clauses, meta, initial_state)

      # Verify results
      assert map_size(nodes) == 1
      comp_node = nodes["comprehension_10"]

      assert comp_node.id == "comprehension_10"
      assert comp_node.type == :comprehension
      assert comp_node.ast_node_id == "comp_456"
      assert comp_node.line == 15
      assert comp_node.expression == clauses

      # Check metadata for complexity analysis
      assert comp_node.metadata.clauses == clauses
      assert length(comp_node.metadata.generators) == 1
      assert length(comp_node.metadata.filters) == 1
      assert comp_node.metadata.complexity_contribution == 2  # 1 generator + 1 filter

      assert exits == ["comprehension_10"]
      assert new_state.next_node_id == 11
    end
  end

  describe "delegation tests" do
    test "main module delegates to correct processors" do
      # These tests verify that the main ExpressionProcessors module correctly delegates
      # to the appropriate sub-modules. We'll use a simple integration test approach.

      initial_state = %{
        entry_node: "entry_1",
        next_node_id: 1,
        nodes: %{},
        edges: [],
        scopes: %{},
        current_scope: "function_scope",
        scope_counter: 1,
        options: [],
        function_key: {:unknown_module_placeholder, :test_function, 0}
      }

      # Test literal value delegation
      ElixirScope.MockStateManager
      |> expect(:generate_node_id, fn "literal", ^initial_state ->
        {"literal_1", %{initial_state | next_node_id: 2}}
      end)

      ElixirScope.MockASTUtilities
      |> expect(:get_literal_type, fn :test -> :atom end)

      {nodes, _edges, exits, _scopes, _state} =
        ExpressionProcessors.process_literal_value(:test, initial_state)

      assert map_size(nodes) == 1
      assert exits == ["literal_1"]
      assert nodes["literal_1"].type == :literal
    end
  end
end
