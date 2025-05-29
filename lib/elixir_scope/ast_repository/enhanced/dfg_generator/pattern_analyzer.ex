defmodule ElixirScope.ASTRepository.Enhanced.DFGGenerator.PatternAnalyzer do
  @moduledoc """
  Analyzes pattern matching structures in Elixir AST.
  """

  alias ElixirScope.ASTRepository.Enhanced.DFGGenerator.{
    VariableTracker,
    EdgeCreator
  }

  @doc """
  Analyzes parameter patterns in function definitions.
  """
  def analyze_parameter_pattern(pattern, line, state) do
    case pattern do
      {var_name, _, nil} when is_atom(var_name) ->
        # Simple parameter
        VariableTracker.create_variable_definition(var_name, line, :parameter, pattern, state)

      {var_name, _, _context} when is_atom(var_name) ->
        # Parameter with context
        VariableTracker.create_variable_definition(var_name, line, :parameter, pattern, state)

      {:%{}, _, fields} ->
        # Map destructuring
        Enum.reduce(fields, state, fn
          {key, {var_name, _, nil}}, acc_state when is_atom(var_name) ->
            VariableTracker.create_variable_definition(var_name, line, :destructured_parameter, {key, var_name}, acc_state)
          _, acc_state -> acc_state
        end)

      {:{}, _, elements} ->
        # Tuple destructuring
        elements
        |> Enum.with_index()
        |> Enum.reduce(state, fn
          {{var_name, _, nil}, index}, acc_state when is_atom(var_name) ->
            VariableTracker.create_variable_definition(var_name, line, :destructured_parameter, {index, var_name}, acc_state)
          _, acc_state -> acc_state
        end)

      [head | tail] ->
        # List destructuring
        state = analyze_parameter_pattern(head, line, state)
        analyze_parameter_pattern(tail, line, state)

      _ ->
        state
    end
  end

  @doc """
  Analyzes assignment patterns (left-hand side of assignments).
  """
  def analyze_assignment_pattern(pattern, source_expr, line, state) do
    case pattern do
      {var_name, _, nil} when is_atom(var_name) ->
        # Simple variable assignment
        state = VariableTracker.create_variable_definition(var_name, line, :assignment, source_expr, state)
        EdgeCreator.create_data_flow_edge(source_expr, var_name, :assignment, line, state)

      {var_name, _, _context} when is_atom(var_name) ->
        # Variable with context
        state = VariableTracker.create_variable_definition(var_name, line, :assignment, source_expr, state)
        EdgeCreator.create_data_flow_edge(source_expr, var_name, :assignment, line, state)

      # Two-element tuple pattern like {:ok, x} or {a, b}
      {left_elem, right_elem} ->
        state = analyze_assignment_pattern(left_elem, {:tuple_access, source_expr, 0}, line, state)
        analyze_assignment_pattern(right_elem, {:tuple_access, source_expr, 1}, line, state)

      # Keyword list pattern like [ok: x] (which is how {:ok, x} appears in case clauses)
      keyword_list when is_list(keyword_list) ->
        Enum.reduce(keyword_list, state, fn
          {key, value}, acc_state when is_atom(key) ->
            analyze_assignment_pattern(value, {:keyword_access, source_expr, key}, line, acc_state)
          _, acc_state -> acc_state
        end)

      {:%{}, _, fields} ->
        # Map pattern matching
        Enum.reduce(fields, state, fn
          {key, {var_name, _, nil}}, acc_state when is_atom(var_name) ->
            acc_state = VariableTracker.create_variable_definition(var_name, line, :pattern_match, {key, source_expr}, acc_state)
            EdgeCreator.create_data_flow_edge(source_expr, var_name, :destructuring, line, acc_state)

          {key, value}, acc_state ->
            analyze_assignment_pattern(value, {:map_access, source_expr, key}, line, acc_state)
        end)

      {:{}, _, elements} ->
        # Tuple pattern matching
        elements
        |> Enum.with_index()
        |> Enum.reduce(state, fn {element, index}, acc_state ->
          analyze_assignment_pattern(element, {:tuple_access, source_expr, index}, line, acc_state)
        end)

      [head | tail] ->
        # List pattern matching
        state = analyze_assignment_pattern(head, {:list_head, source_expr}, line, state)
        analyze_assignment_pattern(tail, {:list_tail, source_expr}, line, state)

      _ ->
        state
    end
  end

  @doc """
  Extracts pattern variables from case expressions.
  """
  def extract_pattern_variables_from_case(expr) do
    case expr do
      {var_name, _, nil} when is_atom(var_name) -> [to_string(var_name)]
      _ -> ["result"]  # Default phi variable for case results
    end
  end

  @doc """
  Analyzes complex pattern structures like guards.
  """
  def analyze_guarded_pattern(pattern, guard, source_expr, line, state) do
    # First analyze the pattern itself
    state = analyze_assignment_pattern(pattern, source_expr, line, state)

    # Then analyze variables used in the guard
    guard_variables = extract_variables_from_guard(guard)

    # Create dependencies from guard variables to the pattern
    Enum.reduce(guard_variables, state, fn guard_var, acc_state ->
      EdgeCreator.create_data_flow_edge(guard_var, pattern, :guard_dependency, line, acc_state)
    end)
  end

  @doc """
  Extracts variables from guard expressions.
  """
  def extract_variables_from_guard(guard) do
    case guard do
      {var_name, _, nil} when is_atom(var_name) ->
        [to_string(var_name)]

      {_op, _, args} when is_list(args) ->
        Enum.flat_map(args, &extract_variables_from_guard/1)

      _ ->
        []
    end
  end

  @doc """
  Analyzes pin operator patterns (^var).
  """
  def analyze_pin_pattern({:^, _meta, [{var_name, _, nil}]}, source_expr, line, state) when is_atom(var_name) do
    # Pin operator creates a dependency on the existing variable
    EdgeCreator.create_data_flow_edge(var_name, source_expr, :pin_match, line, state)
  end
  def analyze_pin_pattern(pattern, source_expr, line, state) do
    # Not a pin pattern, analyze normally
    analyze_assignment_pattern(pattern, source_expr, line, state)
  end
end
