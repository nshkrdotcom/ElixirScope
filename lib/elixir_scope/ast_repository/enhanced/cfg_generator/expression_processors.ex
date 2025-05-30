defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors do
  @moduledoc """
  Main entry point for expression, assignment, and other non-control-flow construct processors.
  Delegates to specialized processor modules.

  Phase 2: Gradual Direct Usage (Optional)

  # Instead of:
  ```elixir
  ExpressionProcessors.process_assignment(pattern, expr, meta, state)
  ```

  # You can now use directly:
  ```elixir
  AssignmentProcessors.process_assignment(pattern, expr, meta, state)
  ```

  Phase 3: Module-Specific Imports (Optional)

  # Import only what you need
  ```elixir
  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors.{
    BasicProcessors,
    FunctionProcessors
  }
  ```
  """

  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors.{
    BasicProcessors,
    AssignmentProcessors,
    FunctionProcessors,
    DataStructureProcessors,
    ControlFlowProcessors
  }

  # Delegate basic expression processing
  defdelegate process_statement_sequence(statements, meta, state), to: BasicProcessors
  defdelegate process_simple_expression(ast, state), to: BasicProcessors
  defdelegate process_variable_reference(var_name, meta, state), to: BasicProcessors
  defdelegate process_literal_value(literal, state), to: BasicProcessors
  defdelegate process_binary_operation(op, left, right, meta, state), to: BasicProcessors
  defdelegate process_unary_operation(op, operand, meta, state), to: BasicProcessors

  # Delegate assignment processing
  defdelegate process_assignment(pattern, expression, meta, state), to: AssignmentProcessors

  # Delegate function-related processing
  defdelegate process_function_call(func_name, args, meta, state), to: FunctionProcessors
  defdelegate process_module_function_call(module, func_name, args, meta1, meta2, state), to: FunctionProcessors
  defdelegate process_anonymous_function(clauses, meta, state), to: FunctionProcessors
  defdelegate process_when_guard(expr, guard, meta, state), to: FunctionProcessors

  # Delegate data structure processing
  defdelegate process_tuple_construction(elements, meta, state), to: DataStructureProcessors
  defdelegate process_list_construction(list, state), to: DataStructureProcessors
  defdelegate process_map_construction(pairs, meta, state), to: DataStructureProcessors
  defdelegate process_map_update(map, updates, meta, state), to: DataStructureProcessors
  defdelegate process_struct_construction(struct_name, fields, meta, state), to: DataStructureProcessors
  defdelegate process_access_operation(container, key, meta1, meta2, state), to: DataStructureProcessors
  defdelegate process_attribute_access(attr, meta, state), to: DataStructureProcessors

  # Delegate control flow processing
  defdelegate process_comprehension(clauses, meta, state), to: ControlFlowProcessors
  defdelegate process_pipe_operation(left, right, meta, state), to: ControlFlowProcessors
  defdelegate process_raise_statement(args, meta, state), to: ControlFlowProcessors
  defdelegate process_throw_statement(value, meta, state), to: ControlFlowProcessors
  defdelegate process_exit_statement(reason, meta, state), to: ControlFlowProcessors
  defdelegate process_spawn_statement(args, meta, state), to: ControlFlowProcessors
  defdelegate process_send_statement(pid, message, meta, state), to: ControlFlowProcessors
end
