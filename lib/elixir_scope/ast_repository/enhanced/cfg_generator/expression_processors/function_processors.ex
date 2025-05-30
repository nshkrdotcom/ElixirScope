defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors.FunctionProcessors do
  @moduledoc """
  Processors for function calls, guards, and anonymous functions.
  """

  alias ElixirScope.ASTRepository.Enhanced.CFGNode

  # Get dependencies from application config for testability
  defp state_manager do
    Application.get_env(:elixir_scope, :state_manager,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager)
  end

  defp ast_utilities do
    Application.get_env(:elixir_scope, :ast_utilities,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities)
  end

  @doc """
  Processes a function call.
  """
  def process_function_call(func_name, args, meta, state) do
    line = ast_utilities().get_line_number(meta)

    # Check if this is a guard function
    node_type = if func_name in [:is_map, :is_list, :is_atom, :is_binary, :is_integer, :is_float, :is_number, :is_boolean, :is_tuple, :is_pid, :is_reference, :is_function] do
      :guard_check
    else
      :function_call
    end

    {call_id, updated_state} = state_manager().generate_node_id("function_call", state)

    call_node = %CFGNode{
      id: call_id,
      type: node_type,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {func_name, meta, args},
      predecessors: [],
      successors: [],
      metadata: %{function: func_name, args: args, is_guard: node_type == :guard_check}
    }

    nodes = %{call_id => call_node}
    {nodes, [], [call_id], %{}, updated_state}
  end

  @doc """
  Processes a module function call.
  """
  def process_module_function_call(module, func_name, args, meta1, meta2, state) do
    line = ast_utilities().get_line_number(meta2)
    {call_id, updated_state} = state_manager().generate_node_id("module_call", state)

    call_node = %CFGNode{
      id: call_id,
      type: :function_call,
      ast_node_id: ast_utilities().get_ast_node_id(meta2),
      line: line,
      scope_id: state.current_scope,
      expression: {{:., meta1, [module, func_name]}, meta2, args},
      predecessors: [],
      successors: [],
      metadata: %{module: module, function: func_name, args: args}
    }

    nodes = %{call_id => call_node}
    {nodes, [], [call_id], %{}, updated_state}
  end

  @doc """
  Processes a when guard expression.
  """
  def process_when_guard(expr, guard, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {guard_id, updated_state} = state_manager().generate_node_id("guard", state)

    guard_node = %CFGNode{
      id: guard_id,
      type: :guard_check,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:when, meta, [expr, guard]},
      predecessors: [],
      successors: [],
      metadata: %{expression: expr, guard: guard}
    }

    nodes = %{guard_id => guard_node}
    {nodes, [], [guard_id], %{}, updated_state}
  end

  @doc """
  Processes an anonymous function.
  """
  def process_anonymous_function(clauses, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {fn_id, updated_state} = state_manager().generate_node_id("anonymous_fn", state)

    fn_node = %CFGNode{
      id: fn_id,
      type: :anonymous_function,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:fn, meta, clauses},
      predecessors: [],
      successors: [],
      metadata: %{clauses: clauses}
    }

    nodes = %{fn_id => fn_node}
    {nodes, [], [fn_id], %{}, updated_state}
  end
end
