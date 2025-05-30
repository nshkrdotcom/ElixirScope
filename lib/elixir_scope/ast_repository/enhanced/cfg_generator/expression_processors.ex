defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.ExpressionProcessors do
  @moduledoc """
  Processors for expressions, assignments, and other non-control-flow constructs.
  """

  alias ElixirScope.ASTRepository.Enhanced.{CFGNode, CFGEdge}
  alias ElixirScope.ASTRepository.Enhanced.CFGGenerator.{
    StateManagerBehaviour, ASTUtilitiesBehaviour, ASTProcessorBehaviour
  }

  # Dependency injection functions - resolve at runtime for test flexibility
  defp state_manager do
    Application.get_env(:elixir_scope, :state_manager,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager)
  end

  defp ast_utilities do
    Application.get_env(:elixir_scope, :ast_utilities,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities)
  end

  defp ast_processor do
    Application.get_env(:elixir_scope, :ast_processor,
      ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor)
  end

  @doc """
  Processes a statement sequence (block).
  """
  def process_statement_sequence(statements, _meta, state) do
    # Process statements sequentially, connecting them in order
    {all_nodes, all_edges, final_exits, all_scopes, final_state} =
      Enum.reduce(statements, {%{}, [], [], %{}, state}, fn stmt, {nodes, edges, prev_exits, scopes, acc_state} ->
        {stmt_nodes, stmt_edges, stmt_exits, stmt_scopes, new_state} =
          ast_processor().process_ast_node(stmt, acc_state)

        # Connect previous statement exits to current statement entries
        connection_edges = if prev_exits == [] do
          # For the first statement, we'll connect it later in process_function_body
          []
        else
          stmt_entry_nodes = get_entry_nodes(stmt_nodes)
          if stmt_entry_nodes == [] do
            # If no entry nodes, create a direct connection from prev exits to stmt exits
            []
          else
            Enum.flat_map(prev_exits, fn prev_exit ->
              Enum.map(stmt_entry_nodes, fn stmt_entry ->
                %CFGEdge{
                  from_node_id: prev_exit,
                  to_node_id: stmt_entry,
                  type: :sequential,
                  condition: nil,
                  probability: 1.0,
                  metadata: %{}
                }
              end)
            end)
          end
        end

        merged_nodes = Map.merge(nodes, stmt_nodes)
        merged_edges = edges ++ stmt_edges ++ connection_edges
        merged_scopes = Map.merge(scopes, stmt_scopes)

        # Use stmt_exits as the new prev_exits for the next iteration
        new_prev_exits = if stmt_exits == [], do: prev_exits, else: stmt_exits

        {merged_nodes, merged_edges, new_prev_exits, merged_scopes, new_state}
      end)

    {all_nodes, all_edges, final_exits, all_scopes, final_state}
  end

  @doc """
  Processes an assignment operation.
  """
  def process_assignment(pattern, expression, meta, state) do
    {assign_id, updated_state} = state_manager().generate_node_id("assignment", state)

    # Create assignment node
    assign_node = %CFGNode{
      id: assign_id,
      type: :assignment,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:=, meta, [pattern, expression]},
      predecessors: [],
      successors: [],
      metadata: %{pattern: pattern, expression: expression}
    }

    # Process the expression being assigned first
    {expr_nodes, expr_edges, expr_exits, expr_scopes, expr_state} =
      ast_processor().process_ast_node(expression, updated_state)

    # If expression processing returned empty results, create a simple expression node
    {final_expr_nodes, final_expr_edges, final_expr_exits, final_expr_scopes, final_expr_state} =
      if map_size(expr_nodes) == 0 do
        # Create a simple expression node for the right-hand side
        {expr_node_id, expr_node_state} = state_manager().generate_node_id("expression", expr_state)
        expr_node = %CFGNode{
          id: expr_node_id,
          type: :expression,
          ast_node_id: ast_utilities().get_ast_node_id(meta),
          line: ast_utilities().get_line_number(meta),
          scope_id: state.current_scope,
          expression: expression,
          predecessors: [],
          successors: [],
          metadata: %{expression: expression}
        }
        {%{expr_node_id => expr_node}, [], [expr_node_id], %{}, expr_node_state}
      else
        {expr_nodes, expr_edges, expr_exits, expr_scopes, expr_state}
      end

    # Connect expression exits to assignment node
    expr_to_assign_edges = Enum.map(final_expr_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: assign_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{}
      }
    end)

    all_nodes = Map.put(final_expr_nodes, assign_id, assign_node)
    all_edges = final_expr_edges ++ expr_to_assign_edges

    {all_nodes, all_edges, [assign_id], final_expr_scopes, final_expr_state}
  end

  @doc """
  Processes a comprehension (for).
  """
  def process_comprehension(clauses, meta, state) do
    {comp_id, updated_state} = state_manager().generate_node_id("comprehension", state)

    # Count generators and filters for complexity
    {generators, filters} = ast_utilities().analyze_comprehension_clauses(clauses)

    # Comprehensions always add at least 1 complexity point due to iteration + filtering
    complexity_contribution = max(length(generators) + length(filters), 1)

    # Create comprehension node (decision point for filtering)
    comp_node = %CFGNode{
      id: comp_id,
      type: :comprehension,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: clauses,
      predecessors: [],
      successors: [],
      metadata: %{
        clauses: clauses,
        generators: generators,
        filters: filters,
        complexity_contribution: complexity_contribution
      }
    }

    nodes = %{comp_id => comp_node}
    {nodes, [], [comp_id], %{}, updated_state}
  end

  @doc """
  Processes a pipe operation.
  """
  def process_pipe_operation(left, right, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {pipe_id, updated_state} = state_manager().generate_node_id("pipe", state)

    # Process left side of pipe first
    {left_nodes, left_edges, left_exits, left_scopes, left_state} =
      ast_processor().process_ast_node(left, updated_state)

    # Process right side of pipe
    {right_nodes, right_edges, right_exits, right_scopes, right_state} =
      ast_processor().process_ast_node(right, left_state)

    # Create pipe operation node
    pipe_node = %CFGNode{
      id: pipe_id,
      type: :pipe_operation,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:|>, meta, [left, right]},
      predecessors: left_exits,
      successors: right_exits,
      metadata: %{left: left, right: right}
    }

    # Create edges: left -> pipe -> right
    left_to_pipe_edges = Enum.map(left_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: pipe_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{pipe_stage: :input}
      }
    end)

    pipe_to_right_edges = Enum.map(right_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: pipe_id,
        to_node_id: exit_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{pipe_stage: :output}
      }
    end)

    all_nodes = left_nodes
    |> Map.merge(right_nodes)
    |> Map.put(pipe_id, pipe_node)

    all_edges = left_edges ++ right_edges ++ left_to_pipe_edges ++ pipe_to_right_edges
    all_scopes = Map.merge(left_scopes, right_scopes)

    {all_nodes, all_edges, right_exits, all_scopes, right_state}
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

  @doc """
  Processes a raise statement.
  """
  def process_raise_statement(args, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {raise_id, updated_state} = state_manager().generate_node_id("raise", state)

    raise_node = %CFGNode{
      id: raise_id,
      type: :raise,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:raise, meta, args},
      predecessors: [],
      successors: [],
      metadata: %{args: args}
    }

    nodes = %{raise_id => raise_node}
    {nodes, [], [raise_id], %{}, updated_state}
  end

  @doc """
  Processes a throw statement.
  """
  def process_throw_statement(value, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {throw_id, updated_state} = state_manager().generate_node_id("throw", state)

    throw_node = %CFGNode{
      id: throw_id,
      type: :throw,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:throw, meta, [value]},
      predecessors: [],
      successors: [],
      metadata: %{value: value}
    }

    nodes = %{throw_id => throw_node}
    {nodes, [], [throw_id], %{}, updated_state}
  end

  @doc """
  Processes an exit statement.
  """
  def process_exit_statement(reason, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {exit_id, updated_state} = state_manager().generate_node_id("exit", state)

    exit_node = %CFGNode{
      id: exit_id,
      type: :exit_call,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:exit, meta, [reason]},
      predecessors: [],
      successors: [],
      metadata: %{reason: reason}
    }

    nodes = %{exit_id => exit_node}
    {nodes, [], [exit_id], %{}, updated_state}
  end

  @doc """
  Processes a spawn statement.
  """
  def process_spawn_statement(args, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {spawn_id, updated_state} = state_manager().generate_node_id("spawn", state)

    spawn_node = %CFGNode{
      id: spawn_id,
      type: :spawn,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:spawn, meta, args},
      predecessors: [],
      successors: [],
      metadata: %{args: args}
    }

    nodes = %{spawn_id => spawn_node}
    {nodes, [], [spawn_id], %{}, updated_state}
  end

  @doc """
  Processes a send statement.
  """
  def process_send_statement(pid, message, meta, state) do
    line = ast_utilities().get_line_number(meta)
    {send_id, updated_state} = state_manager().generate_node_id("send", state)

    send_node = %CFGNode{
      id: send_id,
      type: :send,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: line,
      scope_id: state.current_scope,
      expression: {:send, meta, [pid, message]},
      predecessors: [],
      successors: [],
      metadata: %{pid: pid, message: message}
    }

    nodes = %{send_id => send_node}
    {nodes, [], [send_id], %{}, updated_state}
  end

  @doc """
  Processes a binary operation.
  """
  def process_binary_operation(op, left, right, meta, state) do
    {op_id, updated_state} = state_manager().generate_node_id("binary_op", state)

    # Process left operand first
    {left_nodes, left_edges, left_exits, left_scopes, left_state} =
      ast_processor().process_ast_node(left, updated_state)

    # Process right operand
    {right_nodes, right_edges, right_exits, right_scopes, right_state} =
      ast_processor().process_ast_node(right, left_state)

    # Create binary operation node
    op_node = %CFGNode{
      id: op_id,
      type: :binary_operation,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {op, meta, [left, right]},
      predecessors: left_exits ++ right_exits,
      successors: [],
      metadata: %{operator: op, left: left, right: right}
    }

    # Create edges from operands to operation
    operand_edges = (Enum.map(left_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: op_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{operand: :left}
      }
    end) ++ Enum.map(right_exits, fn exit_id ->
      %CFGEdge{
        from_node_id: exit_id,
        to_node_id: op_id,
        type: :sequential,
        condition: nil,
        probability: 1.0,
        metadata: %{operand: :right}
      }
    end))

    all_nodes = left_nodes
    |> Map.merge(right_nodes)
    |> Map.put(op_id, op_node)

    all_edges = left_edges ++ right_edges ++ operand_edges
    all_scopes = Map.merge(left_scopes, right_scopes)

    {all_nodes, all_edges, [op_id], all_scopes, right_state}
  end

  @doc """
  Processes a unary operation.
  """
  def process_unary_operation(op, operand, meta, state) do
    {op_id, updated_state} = state_manager().generate_node_id("unary_op", state)

    op_node = %CFGNode{
      id: op_id,
      type: :unary_operation,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {op, meta, [operand]},
      predecessors: [],
      successors: [],
      metadata: %{operator: op, operand: operand}
    }

    nodes = %{op_id => op_node}
    {nodes, [], [op_id], %{}, updated_state}
  end

  @doc """
  Processes a variable reference.
  """
  def process_variable_reference(var_name, meta, state) do
    {var_id, updated_state} = state_manager().generate_node_id("variable", state)

    var_node = %CFGNode{
      id: var_id,
      type: :variable,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {var_name, meta, nil},
      predecessors: [],
      successors: [],
      metadata: %{variable: var_name}
    }

    nodes = %{var_id => var_node}
    {nodes, [], [var_id], %{}, updated_state}
  end

  @doc """
  Processes a literal value.
  """
  def process_literal_value(literal, state) do
    {literal_id, updated_state} = state_manager().generate_node_id("literal", state)

    literal_node = %CFGNode{
      id: literal_id,
      type: :literal,
      ast_node_id: nil,
      line: 1,
      scope_id: state.current_scope,
      expression: literal,
      predecessors: [],
      successors: [],
      metadata: %{value: literal, type: ast_utilities().get_literal_type(literal)}
    }

    nodes = %{literal_id => literal_node}
    {nodes, [], [literal_id], %{}, updated_state}
  end

  @doc """
  Processes tuple construction.
  """
  def process_tuple_construction(elements, meta, state) do
    {tuple_id, updated_state} = state_manager().generate_node_id("tuple", state)

    tuple_node = %CFGNode{
      id: tuple_id,
      type: :tuple,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:{}, meta, elements},
      predecessors: [],
      successors: [],
      metadata: %{elements: elements, size: length(elements)}
    }

    nodes = %{tuple_id => tuple_node}
    {nodes, [], [tuple_id], %{}, updated_state}
  end

  @doc """
  Processes list construction.
  """
  def process_list_construction(list, state) do
    {list_id, updated_state} = state_manager().generate_node_id("list", state)

    list_node = %CFGNode{
      id: list_id,
      type: :list,
      ast_node_id: nil,
      line: 1,
      scope_id: state.current_scope,
      expression: list,
      predecessors: [],
      successors: [],
      metadata: %{elements: list, size: length(list)}
    }

    nodes = %{list_id => list_node}
    {nodes, [], [list_id], %{}, updated_state}
  end

  @doc """
  Processes map construction.
  """
  def process_map_construction(pairs, meta, state) do
    {map_id, updated_state} = state_manager().generate_node_id("map", state)

    map_node = %CFGNode{
      id: map_id,
      type: :map,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:%{}, meta, pairs},
      predecessors: [],
      successors: [],
      metadata: %{pairs: pairs, size: length(pairs)}
    }

    nodes = %{map_id => map_node}
    {nodes, [], [map_id], %{}, updated_state}
  end

  @doc """
  Processes map update.
  """
  def process_map_update(map, updates, meta, state) do
    {update_id, updated_state} = state_manager().generate_node_id("map_update", state)

    update_node = %CFGNode{
      id: update_id,
      type: :map_update,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:%{}, meta, [map | updates]},
      predecessors: [],
      successors: [],
      metadata: %{map: map, updates: updates}
    }

    nodes = %{update_id => update_node}
    {nodes, [], [update_id], %{}, updated_state}
  end

  @doc """
  Processes struct construction.
  """
  def process_struct_construction(struct_name, fields, meta, state) do
    {struct_id, updated_state} = state_manager().generate_node_id("struct", state)

    struct_node = %CFGNode{
      id: struct_id,
      type: :struct,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:%, meta, [struct_name, fields]},
      predecessors: [],
      successors: [],
      metadata: %{struct_name: struct_name, fields: fields}
    }

    nodes = %{struct_id => struct_node}
    {nodes, [], [struct_id], %{}, updated_state}
  end

  @doc """
  Processes access operation.
  """
  def process_access_operation(container, key, meta1, meta2, state) do
    {access_id, updated_state} = state_manager().generate_node_id("access", state)

    access_node = %CFGNode{
      id: access_id,
      type: :access,
      ast_node_id: ast_utilities().get_ast_node_id(meta2),
      line: ast_utilities().get_line_number(meta2),
      scope_id: state.current_scope,
      expression: {{:., meta1, [Access, :get]}, meta2, [container, key]},
      predecessors: [],
      successors: [],
      metadata: %{container: container, key: key}
    }

    nodes = %{access_id => access_node}
    {nodes, [], [access_id], %{}, updated_state}
  end

  @doc """
  Processes attribute access.
  """
  def process_attribute_access(attr, meta, state) do
    {attr_id, updated_state} = state_manager().generate_node_id("attribute", state)

    attr_node = %CFGNode{
      id: attr_id,
      type: :attribute,
      ast_node_id: ast_utilities().get_ast_node_id(meta),
      line: ast_utilities().get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:@, meta, [attr]},
      predecessors: [],
      successors: [],
      metadata: %{attribute: attr}
    }

    nodes = %{attr_id => attr_node}
    {nodes, [], [attr_id], %{}, updated_state}
  end

  @doc """
  Processes a simple expression (fallback).
  """
  def process_simple_expression(ast, state) do
    {expr_id, updated_state} = state_manager().generate_node_id("expression", state)

    # Determine the expression type based on the AST structure
    expr_type = case ast do
      {:=, _, _} -> :assignment  # Assignment that didn't match the specific pattern
      {op, _, _} when op in [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=] -> :binary_operation
      {var, _, nil} when is_atom(var) -> :variable_reference
      _ -> :expression
    end

    expr_node = %CFGNode{
      id: expr_id,
      type: expr_type,
      ast_node_id: nil,
      line: 1,
      scope_id: state.current_scope,
      expression: ast,
      predecessors: [],
      successors: [],
      metadata: %{expression: ast, fallback: true}
    }

    nodes = %{expr_id => expr_node}
    {nodes, [], [expr_id], %{}, updated_state}
  end

  # Private helper functions

  defp get_entry_nodes(nodes) when map_size(nodes) == 0, do: []
  defp get_entry_nodes(nodes) do
    nodes
    |> Map.values()
    |> Enum.filter(fn node -> length(node.predecessors) == 0 end)
    |> Enum.map(& &1.id)
    |> case do
      [] -> [nodes |> Map.keys() |> List.first()]
      entry_nodes -> entry_nodes
    end
  end
end
