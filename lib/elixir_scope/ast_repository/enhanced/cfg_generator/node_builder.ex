defmodule ElixirScope.ASTRepository.Enhanced.CFGGenerator.NodeBuilder do
  @moduledoc """
  Builds CFG nodes for simpler AST constructs.
  """

  alias ElixirScope.ASTRepository.Enhanced.{
    CFGNode,
    CFGGenerator.Utils
  }

  # --- Comprehension ---
  def build_comprehension_node(clauses, meta, state) do
    {comp_id, updated_state} = Utils.generate_node_id("comprehension", state)

    # Count generators and filters for complexity
    {generators, filters} = analyze_comprehension_clauses(clauses)

    # Comprehensions always add at least 1 complexity point due to iteration + filtering
    complexity_contribution = max(length(generators) + length(filters), 1)

    # Create comprehension node (decision point for filtering)
    comp_node = %CFGNode{
      id: comp_id,
      type: :comprehension,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: Utils.get_line_number(meta),
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

  defp analyze_comprehension_clauses(clauses) do
    Enum.reduce(clauses, {[], []}, fn clause, {generators, filters} ->
      case clause do
        {:<-, _, [_pattern, _enumerable]} ->
          # Generator clause
          {[clause | generators], filters}
        [do: _body] ->
          # Body clause - not a decision point
          {generators, filters}
        _ ->
          # Filter clause (any other expression)
          {generators, [clause | filters]}
      end
    end)
  end

  # --- Simple Expression (Fallback) ---
  def build_simple_expression_node(ast, state) do
    {expr_id, updated_state} = Utils.generate_node_id("expression", state)

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
      line: 1, # Fallback, might not be accurate
      scope_id: state.current_scope,
      expression: ast,
      predecessors: [],
      successors: [],
      metadata: %{expression: ast, fallback: true}
    }

    nodes = %{expr_id => expr_node}
    {nodes, [], [expr_id], %{}, updated_state}
  end

  # --- Module Function Call ---
  def build_module_function_call_node(module, func_name, args, meta1, meta2, state) do
    line = Utils.get_line_number(meta2)
    {call_id, updated_state} = Utils.generate_node_id("module_call", state)

    call_node = %CFGNode{
      id: call_id,
      type: :function_call,
      ast_node_id: Utils.get_ast_node_id(meta2),
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

  # --- Function Call ---
  def build_function_call_node(func_name, args, meta, state) do
    line = Utils.get_line_number(meta)

    # Check if this is a guard function
    node_type = if func_name in [:is_map, :is_list, :is_atom, :is_binary, :is_integer, :is_float, :is_number, :is_boolean, :is_tuple, :is_pid, :is_reference, :is_function] do
      :guard_check
    else
      :function_call
    end

    {call_id, updated_state} = Utils.generate_node_id("function_call", state)

    call_node = %CFGNode{
      id: call_id,
      type: node_type,
      ast_node_id: Utils.get_ast_node_id(meta),
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

  # --- When Guard ---
  def build_when_guard_node(expr, guard, meta, state) do
    line = Utils.get_line_number(meta)
    {guard_id, updated_state} = Utils.generate_node_id("guard", state)

    guard_node = %CFGNode{
      id: guard_id,
      type: :guard_check,
      ast_node_id: Utils.get_ast_node_id(meta),
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

  # --- Anonymous Function ---
  def build_anonymous_function_node(clauses, meta, state) do
    line = Utils.get_line_number(meta)
    {fn_id, updated_state} = Utils.generate_node_id("anonymous_fn", state)

    fn_node = %CFGNode{
      id: fn_id,
      type: :anonymous_function,
      ast_node_id: Utils.get_ast_node_id(meta),
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

  # --- Raise Statement ---
  def build_raise_node(args, meta, state) do
    line = Utils.get_line_number(meta)
    {raise_id, updated_state} = Utils.generate_node_id("raise", state)

    raise_node = %CFGNode{
      id: raise_id,
      type: :raise,
      ast_node_id: Utils.get_ast_node_id(meta),
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

  # --- Throw Statement ---
  def build_throw_node(value, meta, state) do
    line = Utils.get_line_number(meta)
    {throw_id, updated_state} = Utils.generate_node_id("throw", state)

    throw_node = %CFGNode{
      id: throw_id,
      type: :throw,
      ast_node_id: Utils.get_ast_node_id(meta),
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

  # --- Exit Statement ---
  def build_exit_node(reason, meta, state) do
    line = Utils.get_line_number(meta)
    {exit_id, updated_state} = Utils.generate_node_id("exit", state)

    exit_node = %CFGNode{
      id: exit_id,
      type: :exit_call,
      ast_node_id: Utils.get_ast_node_id(meta),
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

  # --- Spawn Statement ---
  def build_spawn_node(args, meta, state) do
    line = Utils.get_line_number(meta)
    {spawn_id, updated_state} = Utils.generate_node_id("spawn", state)

    spawn_node = %CFGNode{
      id: spawn_id,
      type: :spawn,
      ast_node_id: Utils.get_ast_node_id(meta),
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

  # --- Send Statement ---
  def build_send_node(pid, message, meta, state) do
    line = Utils.get_line_number(meta)
    {send_id, updated_state} = Utils.generate_node_id("send", state)

    send_node = %CFGNode{
      id: send_id,
      type: :send,
      ast_node_id: Utils.get_ast_node_id(meta),
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

  # --- Unary Operation ---
  def build_unary_operation_node(op, operand, meta, state) do
    {op_id, updated_state} = Utils.generate_node_id("unary_op", state)

    op_node = %CFGNode{
      id: op_id,
      type: :unary_operation,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: Utils.get_line_number(meta),
      scope_id: state.current_scope,
      expression: {op, meta, [operand]},
      predecessors: [],
      successors: [],
      metadata: %{operator: op, operand: operand}
    }

    nodes = %{op_id => op_node}
    {nodes, [], [op_id], %{}, updated_state}
  end

  # --- Variable Reference ---
  def build_variable_reference_node(var_name, meta, state) do
    {var_id, updated_state} = Utils.generate_node_id("variable", state)

    var_node = %CFGNode{
      id: var_id,
      type: :variable,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: Utils.get_line_number(meta),
      scope_id: state.current_scope,
      expression: {var_name, meta, nil},
      predecessors: [],
      successors: [],
      metadata: %{variable: var_name}
    }

    nodes = %{var_id => var_node}
    {nodes, [], [var_id], %{}, updated_state}
  end

  # --- Literal Value ---
  def build_literal_node(literal, state) do # meta is not available for all literals
    {literal_id, updated_state} = Utils.generate_node_id("literal", state)

    literal_node = %CFGNode{
      id: literal_id,
      type: :literal,
      ast_node_id: nil, # Literals don't always have a distinct AST node ID
      line: 1, # Placeholder, as meta is not always available
      scope_id: state.current_scope,
      expression: literal,
      predecessors: [],
      successors: [],
      metadata: %{value: literal, type: Utils.get_literal_type(literal)}
    }

    nodes = %{literal_id => literal_node}
    {nodes, [], [literal_id], %{}, updated_state}
  end

  # --- Tuple Construction ---
  def build_tuple_node(elements, meta, state) do
    {tuple_id, updated_state} = Utils.generate_node_id("tuple", state)

    tuple_node = %CFGNode{
      id: tuple_id,
      type: :tuple,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: Utils.get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:{}, meta, elements},
      predecessors: [],
      successors: [],
      metadata: %{elements: elements, size: length(elements)}
    }

    nodes = %{tuple_id => tuple_node}
    {nodes, [], [tuple_id], %{}, updated_state}
  end

  # --- List Construction ---
  def build_list_node(list, state) do # meta is not available for all lists in AST
    {list_id, updated_state} = Utils.generate_node_id("list", state)

    list_node = %CFGNode{
      id: list_id,
      type: :list,
      ast_node_id: nil, # Lists don't always have a distinct AST node ID
      line: 1, # Placeholder, as meta is not always available
      scope_id: state.current_scope,
      expression: list,
      predecessors: [],
      successors: [],
      metadata: %{elements: list, size: length(list)}
    }

    nodes = %{list_id => list_node}
    {nodes, [], [list_id], %{}, updated_state}
  end

  # --- Map Construction ---
  def build_map_node(pairs, meta, state) do
    {map_id, updated_state} = Utils.generate_node_id("map", state)

    map_node = %CFGNode{
      id: map_id,
      type: :map,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: Utils.get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:%{}, meta, pairs},
      predecessors: [],
      successors: [],
      metadata: %{pairs: pairs, size: length(pairs)}
    }

    nodes = %{map_id => map_node}
    {nodes, [], [map_id], %{}, updated_state}
  end

  # --- Map Update ---
  def build_map_update_node(map, updates, meta, state) do
    {update_id, updated_state} = Utils.generate_node_id("map_update", state)

    update_node = %CFGNode{
      id: update_id,
      type: :map_update,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: Utils.get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:%{}, meta, [map | updates]},
      predecessors: [],
      successors: [],
      metadata: %{map: map, updates: updates}
    }

    nodes = %{update_id => update_node}
    {nodes, [], [update_id], %{}, updated_state}
  end

  # --- Struct Construction ---
  def build_struct_node(struct_name, fields, meta, state) do
    {struct_id, updated_state} = Utils.generate_node_id("struct", state)

    struct_node = %CFGNode{
      id: struct_id,
      type: :struct,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: Utils.get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:%, meta, [struct_name, fields]},
      predecessors: [],
      successors: [],
      metadata: %{struct_name: struct_name, fields: fields}
    }

    nodes = %{struct_id => struct_node}
    {nodes, [], [struct_id], %{}, updated_state}
  end

  # --- Access Operation ---
  def build_access_node(container, key, meta1, meta2, state) do
    {access_id, updated_state} = Utils.generate_node_id("access", state)

    access_node = %CFGNode{
      id: access_id,
      type: :access,
      ast_node_id: Utils.get_ast_node_id(meta2),
      line: Utils.get_line_number(meta2),
      scope_id: state.current_scope,
      expression: {{:., meta1, [Access, :get]}, meta2, [container, key]},
      predecessors: [],
      successors: [],
      metadata: %{container: container, key: key}
    }

    nodes = %{access_id => access_node}
    {nodes, [], [access_id], %{}, updated_state}
  end

  # --- Attribute Access ---
  def build_attribute_access_node(attr, meta, state) do
    {attr_id, updated_state} = Utils.generate_node_id("attribute", state)

    attr_node = %CFGNode{
      id: attr_id,
      type: :attribute,
      ast_node_id: Utils.get_ast_node_id(meta),
      line: Utils.get_line_number(meta),
      scope_id: state.current_scope,
      expression: {:@, meta, [attr]},
      predecessors: [],
      successors: [],
      metadata: %{attribute: attr}
    }

    nodes = %{attr_id => attr_node}
    {nodes, [], [attr_id], %{}, updated_state}
  end
end 