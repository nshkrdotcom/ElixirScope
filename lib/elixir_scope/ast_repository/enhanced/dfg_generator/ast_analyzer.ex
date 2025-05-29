defmodule ElixirScope.ASTRepository.Enhanced.DFGGenerator.ASTAnalyzer do
  @moduledoc """
  Analyzes AST structures for data flow patterns.
  """

  alias ElixirScope.ASTRepository.Enhanced.DFGGenerator.{
    StateManager,
    PatternAnalyzer,
    VariableTracker,
    NodeCreator,
    EdgeCreator
  }

  @doc """
  Main entry point for AST analysis.
  """
  def analyze_ast_for_data_flow(ast, state) do
    case ast do
      {:def, meta, [head, body]} ->
        analyze_function_data_flow(head, body, meta, state)

      {:defp, meta, [head, body]} ->
        analyze_function_data_flow(head, body, meta, state)

      other ->
        analyze_expression_data_flow(other, state)
    end
  end

  @doc """
  Analyzes function definitions.
  """
  def analyze_function_data_flow(head, body, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Enter function scope
    state = StateManager.enter_scope(state, :function)

    # Analyze function parameters
    state = analyze_function_parameters(head, line, state)

    # Extract the actual body from the keyword list
    actual_body = case body do
      [do: body_ast] -> body_ast
      body_ast -> body_ast  # fallback for direct AST
    end

    # Analyze function body
    state = analyze_expression_data_flow(actual_body, state)

    # Exit function scope
    StateManager.exit_scope(state)
  end

  @doc """
  Analyzes expressions for data flow.
  """
  def analyze_expression_data_flow(expr, state) do
    case expr do
      # Variable assignment
      {:=, meta, [left, right]} ->
        analyze_assignment(left, right, meta, state)

      # Pipe operator
      {:|>, meta, [left, right]} ->
        analyze_pipe_operation(left, right, meta, state)

      # Control structures (must come before function calls)
      {:if, meta, [condition, branches]} ->
        analyze_conditional_data_flow(condition, branches, meta, state)

      {:case, meta, [expr, [do: clauses]]} ->
        analyze_case_data_flow(expr, clauses, meta, state)

      {:case, meta, [expr, clauses]} when is_list(clauses) ->
        case Keyword.get(clauses, :do) do
          nil ->
            state
          do_clauses ->
            analyze_case_data_flow(expr, do_clauses, meta, state)
        end

      {:try, meta, blocks} ->
        analyze_try_data_flow(blocks, meta, state)

      {:with, meta, clauses} ->
        analyze_with_data_flow(clauses, meta, state)

      # Anonymous functions (must come before function calls)
      {:fn, meta, clauses} ->
        analyze_anonymous_function_data_flow(clauses, meta, state)

      # Comprehensions (must come before function calls)
      {:for, meta, clauses} ->
        analyze_comprehension_data_flow(clauses, meta, state)

      # List comprehensions (alternative pattern)
      {:lc, meta, clauses} ->
        analyze_comprehension_data_flow(clauses, meta, state)

      # Binary comprehensions
      {:bc, meta, clauses} ->
        analyze_comprehension_data_flow(clauses, meta, state)

      # Function calls (must come after control structures, anonymous functions, and comprehensions)
      {func, meta, args} when is_atom(func) and is_list(args) ->
        analyze_function_call(func, args, meta, state)

      # Variable references
      {var_name, meta, nil} when is_atom(var_name) ->
        analyze_variable_reference(var_name, meta, state)

      # Block expressions
      {:__block__, meta, statements} ->
        analyze_block_data_flow(statements, meta, state)

      # Literals and other expressions
      literal when is_atom(literal) or is_number(literal) or is_binary(literal) or is_list(literal) ->
        state  # Literals don't affect data flow

      # Default case
      _ ->
        state
    end
  end

  # Private helper functions

  defp analyze_function_parameters({_func_name, _meta, args}, line, state) when is_list(args) do
    Enum.reduce(args, state, fn arg, acc_state ->
      PatternAnalyzer.analyze_parameter_pattern(arg, line, acc_state)
    end)
  end
  defp analyze_function_parameters(_, _, state), do: state

  defp analyze_assignment(left, right, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # First analyze the right-hand side
    state = analyze_expression_data_flow(right, state)

    # Then analyze the left-hand side pattern
    PatternAnalyzer.analyze_assignment_pattern(left, right, line, state)
  end

  defp analyze_pipe_operation(left, right, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Analyze left side
    state = analyze_expression_data_flow(left, state)

    # Create pipe data flow
    {state, pipe_node_id} = NodeCreator.create_dfg_node(state, :pipe_operation, line, %{
      left: left,
      right: right
    })

    # Analyze right side with pipe input
    state = analyze_expression_data_flow(right, state)

    # Create pipe flow edge from left to right through pipe
    state = EdgeCreator.create_data_flow_edge(left, right, :pipe_flow, line, state)

    # Also create a pipe flow edge from left to pipe node
    state = EdgeCreator.create_data_flow_edge(left, pipe_node_id, :pipe_flow, line, state)

    # And from pipe node to right
    EdgeCreator.create_data_flow_edge(pipe_node_id, right, :pipe_flow, line, state)
  end

  defp analyze_function_call(func, args, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Analyze all arguments
    state = Enum.reduce(args, state, fn arg, acc_state ->
      analyze_expression_data_flow(arg, acc_state)
    end)

    # Create function call node
    {state, _call_node_id} = NodeCreator.create_dfg_node(state, :call, line, %{
      function: func,
      arguments: args,
      arity: length(args)
    })

    # Create data flow edges from arguments to call
    Enum.reduce(args, state, fn arg, acc_state ->
      EdgeCreator.create_data_flow_edge(arg, func, :call_flow, line, acc_state)
    end)
  end

  defp analyze_variable_reference(var_name, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Record variable use
    state = VariableTracker.record_variable_use(var_name, line, state)

    # Create variable reference node
    {state, _ref_node_id} = NodeCreator.create_dfg_node(state, :variable_reference, line, %{
      variable: var_name
    })

    state
  end

  defp analyze_conditional_data_flow(condition, branches, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Analyze condition
    state = analyze_expression_data_flow(condition, state)

    # Create conditional node
    {state, _cond_node_id} = NodeCreator.create_dfg_node(state, :conditional, line, %{
      condition: condition
    })

    # Analyze branches and create conditional flow edges
    state = Enum.reduce(branches, state, fn
      {:do, then_branch}, acc_state ->
        # Enter separate scope for then branch
        acc_state = StateManager.enter_scope(acc_state, :then_branch)
        acc_state = analyze_expression_data_flow(then_branch, acc_state)
        # Create conditional flow edge from condition to then branch
        acc_state = EdgeCreator.create_data_flow_edge(condition, then_branch, :conditional_flow, line, acc_state)
        # Exit then branch scope
        StateManager.exit_scope(acc_state)

      {:else, else_branch}, acc_state ->
        # Enter separate scope for else branch
        acc_state = StateManager.enter_scope(acc_state, :else_branch)
        acc_state = analyze_expression_data_flow(else_branch, acc_state)
        # Create conditional flow edge from condition to else branch
        acc_state = EdgeCreator.create_data_flow_edge(condition, else_branch, :conditional_flow, line, acc_state)
        # Exit else branch scope
        StateManager.exit_scope(acc_state)

      _, acc_state -> acc_state
    end)

    state
  end

  defp analyze_case_data_flow(expr, clauses, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Analyze case expression
    state = analyze_expression_data_flow(expr, state)

    # Create case node
    {state, _case_node_id} = NodeCreator.create_dfg_node(state, :case, line, %{
      expression: expr,
      branches: length(clauses)
    })

    # Analyze each clause and create pattern nodes
    Enum.reduce(clauses, state, fn {:->, clause_meta, [pattern, body]}, acc_state ->
      clause_line = Keyword.get(clause_meta, :line, line)

      # Create pattern matching node
      {acc_state, _pattern_node_id} = NodeCreator.create_dfg_node(acc_state, :pattern_match, clause_line, %{
        pattern: pattern,
        case_expression: expr
      })

      # Extract the actual pattern from the clause structure
      # Case patterns can be wrapped in lists and may have guards
      actual_pattern = case pattern do
        # Pattern with guard: {:when, [], [actual_pattern, guard]}
        {:when, _, [actual_pattern, _guard]} -> actual_pattern
        # Pattern wrapped in a list (common in case clauses)
        [single_pattern] ->
          case single_pattern do
            {:when, _, [actual_pattern, _guard]} -> actual_pattern
            other -> other
          end
        # Simple pattern
        other -> other
      end

      # Analyze pattern in the current scope (don't create separate scope)
      # This allows pattern variables to be tracked in the main function scope
      acc_state = PatternAnalyzer.analyze_assignment_pattern(actual_pattern, expr, clause_line, acc_state)

      # Analyze body in a separate scope to avoid variable conflicts
      acc_state = StateManager.enter_scope(acc_state, :case_clause)
      acc_state = analyze_expression_data_flow(body, acc_state)
      StateManager.exit_scope(acc_state)
    end)
  end

  defp analyze_try_data_flow(blocks, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Create try node
    {state, _try_node_id} = NodeCreator.create_dfg_node(state, :try_expression, line, %{})

    # Analyze try body
    state = case Keyword.get(blocks, :do) do
      nil -> state
      try_body -> analyze_expression_data_flow(try_body, state)
    end

    # Analyze rescue clauses
    state = case Keyword.get(blocks, :rescue) do
      nil -> state
      rescue_clauses ->
        Enum.reduce(rescue_clauses, state, fn {:->, _, [pattern, body]}, acc_state ->
          acc_state = StateManager.enter_scope(acc_state, :rescue_clause)
          acc_state = PatternAnalyzer.analyze_assignment_pattern(pattern, :exception, line, acc_state)
          acc_state = analyze_expression_data_flow(body, acc_state)
          StateManager.exit_scope(acc_state)
        end)
    end

    # Analyze catch clauses
    state = case Keyword.get(blocks, :catch) do
      nil -> state
      catch_clauses ->
        Enum.reduce(catch_clauses, state, fn {:->, _, [pattern, body]}, acc_state ->
          acc_state = StateManager.enter_scope(acc_state, :catch_clause)
          acc_state = PatternAnalyzer.analyze_assignment_pattern(pattern, :thrown_value, line, acc_state)
          acc_state = analyze_expression_data_flow(body, acc_state)
          StateManager.exit_scope(acc_state)
        end)
    end

    # Analyze after clause
    case Keyword.get(blocks, :after) do
      nil -> state
      after_body -> analyze_expression_data_flow(after_body, state)
    end
  end

  defp analyze_with_data_flow(clauses, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Create with node
    {state, _with_node_id} = NodeCreator.create_dfg_node(state, :with_expression, line, %{})

    # Process with clauses
    Enum.reduce(clauses, state, fn
      {:do, body}, acc_state ->
        analyze_expression_data_flow(body, acc_state)

      {:else, else_clauses}, acc_state ->
        Enum.reduce(else_clauses, acc_state, fn {:->, _, [pattern, body]}, clause_state ->
          clause_state = StateManager.enter_scope(clause_state, :with_else)
          clause_state = PatternAnalyzer.analyze_assignment_pattern(pattern, :with_mismatch, line, clause_state)
          clause_state = analyze_expression_data_flow(body, clause_state)
          StateManager.exit_scope(clause_state)
        end)

      {:<-, pattern, expr}, acc_state ->
        acc_state = analyze_expression_data_flow(expr, acc_state)
        PatternAnalyzer.analyze_assignment_pattern(pattern, expr, line, acc_state)

      _, acc_state -> acc_state
    end)
  end

  defp analyze_block_data_flow(statements, _meta, state) do
    Enum.reduce(statements, state, fn stmt, acc_state ->
      analyze_expression_data_flow(stmt, acc_state)
    end)
  end

  defp analyze_comprehension_data_flow(clauses, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Track variables from outer scope that might be captured
    outer_variables = VariableTracker.extract_variable_names_list(state.variables)

    # Create comprehension node
    {state, comp_node_id} = NodeCreator.create_dfg_node(state, :comprehension, line, %{
      type: :for_comprehension
    })

    # Enter comprehension scope
    state = StateManager.enter_scope(state, :comprehension)

    # Analyze comprehension clauses
    state = Enum.reduce(clauses, state, fn
      {:<-, pattern, enumerable}, acc_state ->
        acc_state = analyze_expression_data_flow(enumerable, acc_state)
        PatternAnalyzer.analyze_assignment_pattern(pattern, enumerable, line, acc_state)

      # Handle keyword list with do clause
      keyword_list, acc_state when is_list(keyword_list) ->
        case Keyword.get(keyword_list, :do) do
          nil ->
            acc_state
          body ->
            # Analyze the body and detect captured variables
            acc_state = analyze_expression_data_flow(body, acc_state)

            # Find variables used in body that are from outer scope
            body_variables = extract_variables_from_expression(body)

            captured = Enum.filter(body_variables, fn var -> var in outer_variables end)

            # Add captured variables to state
            acc_state = %{acc_state | captures: acc_state.captures ++ captured}

            # Create capture edges for each captured variable
            Enum.reduce(captured, acc_state, fn captured_var, edge_state ->
              EdgeCreator.create_data_flow_edge({:captured_variable, captured_var}, comp_node_id, :capture, line, edge_state)
            end)
        end

      {:do, body}, acc_state ->
        # Analyze the body and detect captured variables
        acc_state = analyze_expression_data_flow(body, acc_state)

        # Find variables used in body that are from outer scope
        body_variables = extract_variables_from_expression(body)

        captured = Enum.filter(body_variables, fn var -> var in outer_variables end)

        # Add captured variables to state
        acc_state = %{acc_state | captures: acc_state.captures ++ captured}

        # Create capture edges for each captured variable
        Enum.reduce(captured, acc_state, fn captured_var, edge_state ->
          EdgeCreator.create_data_flow_edge({:captured_variable, captured_var}, comp_node_id, :capture, line, edge_state)
        end)

      filter_expr, acc_state ->
        analyze_expression_data_flow(filter_expr, acc_state)
    end)

    # Exit scope
    StateManager.exit_scope(state)
  end

  defp analyze_anonymous_function_data_flow(clauses, meta, state) do
    line = Keyword.get(meta, :line, 1)

    # Create anonymous function node
    {state, fn_node_id} = NodeCreator.create_dfg_node(state, :anonymous_function, line, %{
      clauses: length(clauses)
    })

    # Track variables from outer scope that might be captured
    outer_variables = VariableTracker.extract_variable_names_list(state.variables)

    # Analyze each clause
    state = Enum.reduce(clauses, state, fn clause, acc_state ->
      case clause do
        {:->, clause_meta, [args, body]} ->
          clause_line = Keyword.get(clause_meta, :line, line)

          # Enter function clause scope
          acc_state = StateManager.enter_scope(acc_state, :function_clause)

          # Analyze parameters
          acc_state = Enum.reduce(args, acc_state, fn arg, param_state ->
            PatternAnalyzer.analyze_parameter_pattern(arg, clause_line, param_state)
          end)

          # Analyze body and detect captured variables
          acc_state = analyze_expression_data_flow(body, acc_state)

          # Find variables used in body that are from outer scope
          body_variables = extract_variables_from_expression(body)

          captured = Enum.filter(body_variables, fn var -> var in outer_variables end)

          # Add captured variables to state
          acc_state = %{acc_state | captures: acc_state.captures ++ captured}

          # Create capture edges for each captured variable
          acc_state = Enum.reduce(captured, acc_state, fn captured_var, edge_state ->
            EdgeCreator.create_data_flow_edge({:captured_variable, captured_var}, fn_node_id, :capture, clause_line, edge_state)
          end)

          # Exit scope
          StateManager.exit_scope(acc_state)

        _other ->
          acc_state
      end
    end)

    state
  end

  # Add helper to extract variables from expressions
  defp extract_variables_from_expression(expr) do
    case expr do
      # Handle function calls and operators first (they have args to recurse into)
      {_op, _, args} when is_list(args) ->
        Enum.flat_map(args, &extract_variables_from_expression/1)

      # Handle variables with nil context
      {var_name, _, nil} when is_atom(var_name) ->
        [to_string(var_name)]

      # Handle variables with context (like module context)
      {var_name, _, _context} when is_atom(var_name) ->
        if is_variable_name?(var_name) do
          [to_string(var_name)]
        else
          []
        end

      # Handle block expressions
      {:__block__, _, statements} ->
        Enum.flat_map(statements, &extract_variables_from_expression/1)

      # Handle lists
      list when is_list(list) ->
        Enum.flat_map(list, &extract_variables_from_expression/1)

      # Default case
      _ ->
        []
    end
  end

  # Helper to determine if an atom is a variable name vs function name
  defp is_variable_name?(atom) do
    # Variables typically start with lowercase or underscore
    # Single letter variables like a, b, c, x, y, z are almost always variables
    atom_str = to_string(atom)
    case atom_str do
      "_" <> _ -> true  # underscore variables
      <<first::utf8>> when first >= ?a and first <= ?z ->
        # Single letter - almost always a variable
        true
      <<first::utf8, _rest::binary>> when first >= ?a and first <= ?z ->
        # Multi-letter lowercase - could be variable, but exclude known functions
        not is_known_function?(atom)
      _ -> false
    end
  end

  # Helper to identify known function names that should not be treated as variables
  defp is_known_function?(atom) do
    atom in [:combine, :process, :transform, :input, :output, :expensive_computation,
             :+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=, :and, :or, :not, :++, :--, :|>, :=,
             :def, :defp, :if, :case, :cond, :try, :receive, :for, :with, :fn]
  end
end
