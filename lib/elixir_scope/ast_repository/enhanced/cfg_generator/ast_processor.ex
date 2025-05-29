defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor do
  @moduledoc """
  Processes AST nodes to build the Control Flow Graph by dispatching to specialized handlers.
  """

  alias ElixirScope.ASTRepository.Enhanced.{
    # CFGNode, # No longer directly creating nodes here
    # CFGEdge, # No longer directly creating edges here
    # ScopeInfo, # No longer directly creating scopes here
    CFGGenerator.Utils,
    CFGGenerator.NodeBuilder,
    CFGGenerator.ConditionalHandler,
    CFGGenerator.ExceptionHandler,
    CFGGenerator.SequentialHandler,
    CFGGenerator.BinaryOperatorHandler
  }

  # Public API
  def process_ast_node(ast, state) do
    # The main AST node processor - delegates to specialized handlers
    # or NodeBuilder for simpler constructs.
    # The `ast_processor_func` argument for handlers is `&process_ast_node/2` itself.

    case ast do
      # --- Sequential Handlers ---
      {:__block__, meta, statements} ->
        SequentialHandler.handle_statement_sequence(statements, meta, state, &process_ast_node/2)

      {:=, meta, [pattern, expression]} ->
        SequentialHandler.handle_assignment(pattern, expression, meta, state, &process_ast_node/2)

      {:|>, meta, [left, right]} ->
        SequentialHandler.handle_pipe_operation(left, right, meta, state, &process_ast_node/2)
        
      # --- Conditional Handlers ---
      {:case, meta, [condition, [do: clauses]]} ->
        ConditionalHandler.handle_case_statement(condition, clauses, meta, state, &process_ast_node/2)

      {:if, meta, [condition, clauses]} when is_list(clauses) ->
        then_branch = Keyword.get(clauses, :do)
        else_clause = case Keyword.get(clauses, :else) do
          nil -> []
          else_branch -> [else: else_branch]
        end
        ConditionalHandler.handle_if_statement(condition, then_branch, else_clause, meta, state, &process_ast_node/2)

      {:unless, meta, [condition, clauses]} when is_list(clauses) ->
        ConditionalHandler.handle_unless_statement(condition, clauses, meta, state, &process_ast_node/2)

      {:cond, meta, [[do: clauses]]} -> # Note: [[do: clauses]] pattern from original
        ConditionalHandler.handle_cond_statement(clauses, meta, state, &process_ast_node/2)

      # --- Exception Handlers ---
      {:try, meta, blocks} ->
        ExceptionHandler.handle_try_statement(blocks, meta, state, &process_ast_node/2)

      {:with, meta, clauses} ->
        ExceptionHandler.handle_with_statement(clauses, meta, state, &process_ast_node/2)

      # --- Binary Operation Handler ---
      {op, meta, [left, right]} when op in [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=, :and, :or, :&&, :||] ->
        BinaryOperatorHandler.handle_binary_operation(op, left, right, meta, state, &process_ast_node/2)

      # --- NodeBuilder Delegations (Simpler Constructs) ---
      {:for, meta, clauses} ->
        NodeBuilder.build_comprehension_node(clauses, meta, state)

      {{:., meta1, [module, func_name]}, meta2, args} ->
        NodeBuilder.build_module_function_call_node(module, func_name, args, meta1, meta2, state)

      {func_name, meta, args} when is_atom(func_name) ->
        NodeBuilder.build_function_call_node(func_name, args, meta, state)

      {:when, meta, [expr, guard]} ->
        NodeBuilder.build_when_guard_node(expr, guard, meta, state)

      {:fn, meta, clauses} ->
        NodeBuilder.build_anonymous_function_node(clauses, meta, state)

      {:raise, meta, args} ->
        NodeBuilder.build_raise_node(args, meta, state)

      {:throw, meta, [value]} ->
        NodeBuilder.build_throw_node(value, meta, state)

      {:exit, meta, [reason]} ->
        NodeBuilder.build_exit_node(reason, meta, state)

      {:spawn, meta, args} ->
        NodeBuilder.build_spawn_node(args, meta, state)

      {:send, meta, [pid, message]} ->
        NodeBuilder.build_send_node(pid, message, meta, state)

      {op, meta, [operand]} when op in [:not, :!, :+, :-] ->
        NodeBuilder.build_unary_operation_node(op, operand, meta, state)

      {var_name, meta, nil} when is_atom(var_name) ->
        NodeBuilder.build_variable_reference_node(var_name, meta, state)

      literal when is_atom(literal) or is_number(literal) or is_binary(literal) or is_list(literal) ->
        NodeBuilder.build_literal_node(literal, state)

      nil ->
        {%{}, [], [], %{}, state} # Empty function body

      {:{}, meta, elements} ->
        NodeBuilder.build_tuple_node(elements, meta, state)

      list when is_list(list) ->
        NodeBuilder.build_list_node(list, state)

      {:%{}, meta, pairs} ->
        NodeBuilder.build_map_node(pairs, meta, state)

      {:%{}, meta, [map | updates]} ->
        NodeBuilder.build_map_update_node(map, updates, meta, state)

      {:%, meta, [struct_name, fields]} ->
        NodeBuilder.build_struct_node(struct_name, fields, meta, state)

      {{:., meta1, [Access, :get]}, meta2, [container, key]} ->
        NodeBuilder.build_access_node(container, key, meta1, meta2, state)

      {:@, meta, [attr]} ->
        NodeBuilder.build_attribute_access_node(attr, meta, state)
        
      # --- Receive Statement (Remains here as placeholder) ---
      {:receive, meta, clauses} ->
        process_receive_statement(clauses, meta, state)

      # --- Fallback (NodeBuilder) ---
      _ ->
        NodeBuilder.build_simple_expression_node(ast, state)
    end
  end

  # Placeholder for receive, as it was not fully implemented and not moved.
  # If this needs full processing, it could also be moved to a specialized handler.
  defp process_receive_statement(_clauses, _meta, state), do: {%{}, [], [], %{}, state}

  # Note: process_comprehension and analyze_comprehension_clauses were removed earlier when NodeBuilder was created.
  # process_unless_statement was moved to ConditionalHandler (and renamed handle_unless_statement there).
  # All other process_... functions for specific AST types have been moved to their respective handlers or NodeBuilder.
end