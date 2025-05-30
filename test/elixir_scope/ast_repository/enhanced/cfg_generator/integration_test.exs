defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.IntegrationTest do
  use ExUnit.Case, async: true

  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors

  @moduletag :integration

  describe "integration tests with real modules" do
    setup do
      # Ensure real modules are configured (this should already be done in test_helper.exs)
      Application.put_env(:elixir_scope, :state_manager,
        ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager)
      Application.put_env(:elixir_scope, :ast_utilities,
        ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities)
      Application.put_env(:elixir_scope, :ast_processor,
        ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor)

      :ok
    end

    test "process_literal_value works with real dependencies" do
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

      # Execute with real modules
      {nodes, edges, exits, scopes, new_state} =
        ExpressionProcessors.process_literal_value(:ok, initial_state)

      # Verify real behavior
      assert map_size(nodes) == 1
      [node_id] = Map.keys(nodes)
      assert String.starts_with?(node_id, "literal_")

      literal_node = nodes[node_id]
      assert literal_node.type == :literal
      assert literal_node.expression == :ok
      assert literal_node.metadata.value == :ok
      assert literal_node.metadata.type == :atom
      assert literal_node.scope_id == "function_scope"

      assert edges == []
      assert exits == [node_id]
      assert scopes == %{}
      assert new_state.next_node_id == 2
    end

    test "process_function_call works with real dependencies" do
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

      meta = [line: 42, ast_node_id: "ast_123"]
      args = [:arg1, :arg2]

      # Execute with real modules
      {nodes, edges, exits, scopes, new_state} =
        ExpressionProcessors.process_function_call(:some_function, args, meta, initial_state)

      # Verify real behavior
      assert map_size(nodes) == 1
      [node_id] = Map.keys(nodes)
      assert String.starts_with?(node_id, "function_call_")

      call_node = nodes[node_id]
      assert call_node.type == :function_call
      assert call_node.ast_node_id == "ast_123"
      assert call_node.line == 42
      assert call_node.scope_id == "test_scope"
      assert call_node.expression == {:some_function, meta, args}
      assert call_node.metadata.function == :some_function
      assert call_node.metadata.args == args
      assert call_node.metadata.is_guard == false

      assert edges == []
      assert exits == [node_id]
      assert scopes == %{}
      assert new_state.next_node_id == 4
    end

    test "process_function_call recognizes guard functions with real dependencies" do
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

      meta = [line: 10]
      args = [:value]

      # Execute with real modules
      {nodes, _edges, _exits, _scopes, _new_state} =
        ExpressionProcessors.process_function_call(:is_atom, args, meta, initial_state)

      # Verify guard function is recognized
      [node_id] = Map.keys(nodes)
      call_node = nodes[node_id]
      assert call_node.type == :guard_check
      assert call_node.metadata.is_guard == true
      assert call_node.metadata.function == :is_atom
    end
  end

  describe "dependency injection verification" do
    test "uses configured modules from application environment" do
      # This test verifies that the module correctly reads from Application config
      state_manager_module = Application.get_env(:elixir_scope, :state_manager)
      ast_utilities_module = Application.get_env(:elixir_scope, :ast_utilities)
      ast_processor_module = Application.get_env(:elixir_scope, :ast_processor)

      # These should be the real modules
      assert state_manager_module == ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager
      assert ast_utilities_module == ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities
      assert ast_processor_module == ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor
    end
  end
end
