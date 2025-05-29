defmodule ElixirScope.ASTRepository.Enhanced.CPGBuilder.Helpers do
  @moduledoc """
  Utility functions for CPG building and analysis.

  Contains common helper functions used across different CPG builder modules
  including mathematical operations, AST processing, and data transformations.
  """

  @doc """
  Safely rounds a float value to specified precision, handling edge cases.
  """
  def safe_round(value, precision) do
    cond do
      not is_number(value) -> 0.0
      value != value -> 0.0  # NaN check
      true -> Float.round(value, precision)
    end
  end

  @doc """
  Extracts function key (module, name, arity) from AST.
  """
  def extract_function_key({:def, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {UnknownModule, name, arity}
  end

  def extract_function_key({:defp, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {UnknownModule, name, arity}
  end

  def extract_function_key(_), do: {UnknownModule, :unknown, 0}

  @doc """
  Estimates AST complexity for timeout calculation.
  """
  def estimate_ast_complexity(ast) do
    case ast do
      {:def, _, [_head, [do: body]]} -> count_nested_structures(body, 0)
      {:defp, _, [_head, [do: body]]} -> count_nested_structures(body, 0)
      _ -> count_nested_structures(ast, 0)
    end
  end

  @doc """
  Extracts variable name from expression.
  """
  def extract_variable_name(expr) do
    case expr do
      {var_name, _, nil} when is_atom(var_name) -> to_string(var_name)
      {var_name, _, _context} when is_atom(var_name) -> to_string(var_name)
      _ -> nil
    end
  end

  @doc """
  Extracts all variable names from unified nodes.
  """
  def extract_all_variable_names(nodes) do
    Enum.flat_map(nodes, fn {_id, node} ->
      case node do
        %{cfg_node: %{expression: expr}} -> extract_variables_from_expr(expr)
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  @doc """
  Extracts variables from an expression.
  """
  def extract_variables_from_expr(expr) do
    case expr do
      {var, _, nil} when is_atom(var) -> [to_string(var)]
      {:=, _, [target, source]} ->
        extract_variables_from_expr(target) ++ extract_variables_from_expr(source)
      {_, _, args} when is_list(args) ->
        Enum.flat_map(args, &extract_variables_from_expr/1)
      _ -> []
    end
  end

  @doc """
  Extracts function calls from expression.
  """
  def extract_function_calls(expr) do
    case expr do
      {func, _, args} when is_atom(func) and is_list(args) ->
        [{func, [], args}]
      {:__block__, _, exprs} when is_list(exprs) ->
        Enum.flat_map(exprs, &extract_function_calls/1)
      {:=, _, [_target, source]} ->
        extract_function_calls(source)
      _ -> []
    end
  end

  @doc """
  Extracts all function calls from expression recursively.
  """
  def extract_all_function_calls(expr) do
    case expr do
      {func, _, args} when is_atom(func) and is_list(args) ->
        [func] ++ Enum.flat_map(args, &extract_all_function_calls/1)
      {:__block__, _, exprs} when is_list(exprs) ->
        Enum.flat_map(exprs, &extract_all_function_calls/1)
      {:=, _, [_target, source]} ->
        extract_all_function_calls(source)
      {:+, _, [left, right]} ->
        extract_all_function_calls(left) ++ extract_all_function_calls(right)
      {:*, _, [left, right]} ->
        extract_all_function_calls(left) ++ extract_all_function_calls(right)
      {:for, _, [_generator, [do: body]]} ->
        extract_all_function_calls(body)
      {_op, _, args} when is_list(args) ->
        Enum.flat_map(args, &extract_all_function_calls/1)
      _ -> []
    end
  end

  @doc """
  Counts operators in an expression for complexity analysis.
  """
  def count_operators(expr) do
    case expr do
      {op, _, [left, right]} when op in [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=, :and, :or] ->
        1 + count_operators(left) + count_operators(right)
      {:=, _, [_target, source]} ->
        count_operators(source)
      {_func, _, args} when is_list(args) ->
        Enum.reduce(args, 0, fn arg, acc -> acc + count_operators(arg) end)
      list when is_list(list) ->
        Enum.reduce(list, 0, fn expr, acc -> acc + count_operators(expr) end)
      _ -> 0
    end
  end

  @doc """
  Checks if an expression is complex based on operator count.
  """
  def is_complex_expression(expr) do
    operator_count = count_operators(expr)
    operator_count >= 4
  end

  @doc """
  Extracts assignment alias from node for alias analysis.
  """
  def extract_assignment_alias(node) do
    case node do
      %{cfg_node: %{expression: {:=, _, [target, source]}}} ->
        target_var = extract_variable_name(target)
        source_var = extract_variable_name(source)
        if target_var && source_var && target_var != source_var do
          {target_var, source_var}
        else
          nil
        end
      _ -> nil
    end
  end

  @doc """
  Finds paths between nodes with depth and count limits.
  """
  def find_paths_between_nodes_limited(edges, start_node, end_node, visited, max_depth, max_paths) do
    if start_node == end_node do
      [[end_node]]
    else
      if start_node in visited or length(visited) >= max_depth do
        []
      else
        new_visited = [start_node | visited]
        successors = get_node_successors(edges, start_node)
        limited_successors = Enum.take(successors, 2)

        paths = Enum.flat_map(limited_successors, fn successor ->
          sub_paths = find_paths_between_nodes_limited(edges, successor, end_node, new_visited, max_depth, max_paths)
          Enum.map(sub_paths, fn path -> [start_node | path] end)
        end)

        Enum.take(paths, max_paths)
      end
    end
  end

  @doc """
  Gets successor nodes from edges for a given node.
  """
  def get_node_successors(edges, node_id) do
    edges
    |> Enum.filter(fn edge ->
      Map.get(edge, :from_node_id, Map.get(edge, :from_node)) == node_id
    end)
    |> Enum.map(fn edge ->
      Map.get(edge, :to_node_id, Map.get(edge, :to_node))
    end)
  end

  # Private helper functions

  defp count_nested_structures(ast, depth) do
    case ast do
      {:if, _, [_condition, [do: then_body, else: else_body]]} ->
        1 + count_nested_structures(then_body, depth + 1) + count_nested_structures(else_body, depth + 1)
      {:case, _, [_expr, [do: clauses]]} when is_list(clauses) ->
        1 + Enum.reduce(clauses, 0, fn clause, acc -> acc + count_nested_structures(clause, depth + 1) end)
      {:for, _, _} -> 2
      {:try, _, _} -> 2
      {:__block__, _, exprs} when is_list(exprs) ->
        Enum.reduce(exprs, 0, fn expr, acc -> acc + count_nested_structures(expr, depth) end)
      {_, _, args} when is_list(args) ->
        Enum.reduce(args, 0, fn arg, acc -> acc + count_nested_structures(arg, depth) end)
      list when is_list(list) ->
        Enum.reduce(list, 0, fn item, acc -> acc + count_nested_structures(item, depth) end)
      _ -> 0
    end
  end
end
