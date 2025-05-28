defmodule ElixirScope.ASTRepository.DFGGenerator do
  @moduledoc """
  Enhanced Data Flow Graph generator for Elixir functions.

  Uses Static Single Assignment (SSA) form to properly handle
  Elixir's immutable variable semantics and pattern matching.

  Key principles:
  1. Each variable assignment creates a new SSA version
  2. Pattern matching creates new variable bindings within scope
  3. Phi nodes merge different variable versions at scope boundaries
  4. Immutable semantics mean no traditional "mutations"
  """

  alias ElixirScope.ASTRepository.{
    DFGData, VariableVersion, Definition, Use, DataFlow, PhiNode, ScopeInfo
  }

  @doc """
  Generates a Data Flow Graph for an Elixir function using SSA form.

  ## Parameters
  - function_ast: The AST of the function to analyze
  - opts: Options for DFG generation

  ## Returns
  {:ok, DFGData.t()} | {:error, term()}
  """
  @spec generate_dfg(Macro.t(), keyword()) :: {:ok, DFGData.t()} | {:error, term()}
  def generate_dfg(function_ast, opts \\ []) do
    try do
      # Initialize SSA state with immutable variable tracking
      state = initialize_dfg_state(function_ast, opts)

      # Process function parameters first
      {param_state, parameter_defs} = process_function_parameters(function_ast, state)

      # Process function body with SSA transformation
      {final_state, body_analysis} = process_function_body_ssa(function_ast, param_state)

      # Build data flow edges
      data_flows = build_data_flow_edges(final_state)

      # Generate phi nodes for scope merges
      phi_nodes = generate_phi_nodes(final_state)

      # Perform data flow analysis
      analysis_results = perform_data_flow_analysis(final_state, data_flows)

      dfg = %DFGData{
        function_key: extract_function_key(function_ast),
        variables: final_state.variables,
        definitions: parameter_defs ++ body_analysis.definitions,
        uses: body_analysis.uses,
        data_flows: data_flows,
        phi_nodes: phi_nodes,
        scopes: final_state.scopes,
        analysis_results: analysis_results,
        metadata: %{
          generation_time: System.monotonic_time(:millisecond),
          options: opts,
          ssa_variable_count: final_state.next_version_id
        }
      }

      {:ok, dfg}
    rescue
      error -> {:error, {:dfg_generation_failed, error}}
    end
  end

  @doc """
  Traces a variable through its data flow within the function.

  Returns the complete data flow path for a variable from definition to all uses.
  """
  @spec trace_variable(DFGData.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def trace_variable(%DFGData{} = dfg, variable_name) do
    try do
      variable_versions = Map.get(dfg.variables, variable_name, [])

      trace_info = %{
        variable_name: variable_name,
        versions: length(variable_versions),
        definitions: find_variable_definitions(dfg, variable_name),
        uses: find_variable_uses(dfg, variable_name),
        flows: find_variable_flows(dfg, variable_name),
        phi_nodes: find_variable_phi_nodes(dfg, variable_name),
        scopes: find_variable_scopes(dfg, variable_name)
      }

      {:ok, trace_info}
    rescue
      error -> {:error, {:trace_failed, error}}
    end
  end

  # Private Implementation

  defp initialize_dfg_state(function_ast, opts) do
    %{
      # SSA state management
      variables: %{},              # %{var_name => [VariableVersion.t()]}
      next_version_id: 0,          # Global version counter

      # Scope management
      scopes: %{},                 # %{scope_id => ScopeInfo.t()}
      current_scope: :function_scope,
      scope_stack: [:function_scope],
      next_scope_id: 1,

      # Analysis tracking
      definitions: [],             # [Definition.t()]
      uses: [],                    # [Use.t()]
      pending_phi_nodes: [],       # Phi nodes to create at scope merges

      # Configuration
      options: opts,
      function_key: extract_function_key(function_ast)
    }
  end

  defp process_function_parameters({:def, _meta, [head | _]}, state) do
    case head do
      {_name, _meta, args} when is_list(args) ->
        # Process each parameter as an initial definition
        {final_state, parameter_definitions} =
          Enum.reduce(args, {state, []}, fn param, {acc_state, acc_defs} ->
            case extract_variable_from_pattern(param) do
              nil ->
                {acc_state, acc_defs}
              var_name ->
                # Create SSA version for parameter
                {var_version, new_state} = create_ssa_variable(var_name, acc_state, :parameter)

                # Create definition
                param_def = %Definition{
                  variable: var_version,
                  ast_node_id: get_ast_node_id_from_ast(param),
                  definition_type: :parameter,
                  source_expression: param,
                  line: 0,
                  scope_id: :function_scope,
                  reaching_definitions: [],
                  metadata: %{parameter_index: length(acc_defs)}
                }

                {new_state, [param_def | acc_defs]}
            end
          end)

        {final_state, Enum.reverse(parameter_definitions)}

      _ ->
        {state, []}
    end
  end

  defp process_function_body_ssa({:def, _meta, [_head, [do: body]]}, state) do
    process_ast_node_ssa(body, state)
  end

  defp process_ast_node_ssa(ast, state) do
    case ast do
      # Assignment - creates new SSA version
      {:=, meta, [pattern, expression]} ->
        process_assignment_ssa(pattern, expression, meta, state)

      # Case statement - creates new scope with pattern bindings
      {:case, meta, [condition | clauses]} ->
        process_case_statement_ssa(condition, clauses, meta, state)

      # Variable reference - creates use
      {var_name, meta, nil} when is_atom(var_name) ->
        process_variable_use_ssa(var_name, meta, state)

      # Function call - may use variables
      {func_name, meta, args} when is_atom(func_name) and is_list(args) ->
        process_function_call_ssa(func_name, args, meta, state)

      # Pipe operation - creates data flow chain
      {:|>, meta, [left, right]} ->
        process_pipe_operation_ssa(left, right, meta, state)

      # Block of statements
      {:__block__, _meta, statements} ->
        process_statement_sequence_ssa(statements, state)

      # List or tuple - may contain variable references
      list when is_list(list) ->
        process_list_ssa(list, state)

      # Literal values
      _ ->
        {state, %{definitions: [], uses: []}}
    end
  end

  defp process_assignment_ssa(pattern, expression, meta, state) do
    # First, process the right-hand side expression
    {expr_state, expr_analysis} = process_ast_node_ssa(expression, state)

    # Then, process the pattern on the left-hand side
    # This creates new variable bindings
    {final_state, pattern_defs} = process_pattern_ssa(pattern, meta, expr_state)

    # Create data flow from expression to pattern variables
    assignment_flows = create_assignment_flows(expr_analysis, pattern_defs, meta)

    analysis = %{
      definitions: expr_analysis.definitions ++ pattern_defs,
      uses: expr_analysis.uses,
      flows: assignment_flows
    }

    {final_state, analysis}
  end

  defp process_pattern_ssa(pattern, meta, state) do
    case pattern do
      # Simple variable
      {var_name, _meta, nil} when is_atom(var_name) ->
        {var_version, new_state} = create_ssa_variable(var_name, state, :assignment)

        definition = %Definition{
          variable: var_version,
          ast_node_id: get_ast_node_id_from_meta(meta),
          definition_type: :assignment,
          source_expression: pattern,
          line: get_line_number(meta),
          scope_id: state.current_scope,
          reaching_definitions: get_reaching_definitions(var_name, state),
          metadata: %{}
        }

        {new_state, [definition]}

      # Tuple pattern: {a, b}
      {:{}, _meta, elements} ->
        process_pattern_list_ssa(elements, meta, state)

      # List pattern: [h | t]
      [head | tail] ->
        {head_state, head_defs} = process_pattern_ssa(head, meta, state)
        {tail_state, tail_defs} = process_pattern_ssa(tail, meta, head_state)
        {tail_state, head_defs ++ tail_defs}

      # Map pattern: %{key: value}
      {:%{}, _meta, pairs} ->
        process_map_pattern_ssa(pairs, meta, state)

      # Literal or complex pattern
      _ ->
        {state, []}
    end
  end

  defp create_ssa_variable(var_name, state, definition_type) do
    current_versions = Map.get(state.variables, var_name, [])
    next_version = length(current_versions)

    var_version = %VariableVersion{
      name: var_name,
      version: next_version,
      ssa_name: "#{var_name}_#{next_version}",
      scope_id: state.current_scope,
      definition_node: nil,  # Will be set by caller
      type_info: nil,        # Could be inferred later
      is_parameter: definition_type == :parameter,
      is_captured: false,    # Would be determined by closure analysis
      metadata: %{definition_type: definition_type}
    }

    updated_versions = current_versions ++ [var_version]
    updated_variables = Map.put(state.variables, var_name, updated_versions)

    new_state = %{state |
      variables: updated_variables,
      next_version_id: state.next_version_id + 1
    }

    {var_version, new_state}
  end

  defp process_variable_use_ssa(var_name, meta, state) do
    case get_current_variable_version(var_name, state) do
      nil ->
        # Variable not found - potential error
        analysis = %{
          definitions: [],
          uses: [],
          errors: [{:undefined_variable, var_name, get_line_number(meta)}]
        }
        {state, analysis}

      var_version ->
        use_info = %Use{
          variable: var_version,
          ast_node_id: get_ast_node_id_from_meta(meta),
          use_type: :read,
          context: :expression,
          line: get_line_number(meta),
          scope_id: state.current_scope,
          reaching_definition: find_reaching_definition(var_version, state),
          metadata: %{}
        }

        analysis = %{
          definitions: [],
          uses: [use_info]
        }

        {state, analysis}
    end
  end

  defp process_case_statement_ssa(condition, clauses, meta, state) do
    # Process condition first
    {cond_state, cond_analysis} = process_ast_node_ssa(condition, state)

    # Process each case clause in its own scope
    {final_state, clause_analyses} =
      Enum.reduce(clauses, {cond_state, []}, fn clause, {acc_state, acc_analyses} ->
        # Create new scope for this clause
        clause_scope_id = create_new_scope(acc_state, :case_clause)
        clause_state = enter_scope(acc_state, clause_scope_id)

        # Process clause
        {clause_result_state, clause_analysis} = process_case_clause_ssa(clause, clause_state)

        # Exit scope
        final_clause_state = exit_scope(clause_result_state)

        {final_clause_state, [clause_analysis | acc_analyses]}
      end)

    # Merge analyses from all clauses
    merged_analysis = merge_clause_analyses([cond_analysis | clause_analyses])

    # Generate phi nodes for variables that have different versions across clauses
    phi_nodes = generate_case_phi_nodes(clauses, clause_analyses, final_state)

    final_analysis = Map.put(merged_analysis, :phi_nodes, phi_nodes)

    {final_state, final_analysis}
  end

  defp process_case_clause_ssa({:->, _meta, [pattern, body]}, state) do
    # Process pattern - creates new variable bindings
    {pattern_state, pattern_defs} = process_pattern_ssa(pattern, %{}, state)

    # Process body in the context of pattern bindings
    {body_state, body_analysis} = process_ast_node_ssa(body, pattern_state)

    analysis = %{
      definitions: pattern_defs ++ body_analysis.definitions,
      uses: body_analysis.uses
    }

    {body_state, analysis}
  end

  # Utility Functions

  defp get_current_variable_version(var_name, state) do
    case Map.get(state.variables, var_name) do
      nil -> nil
      [] -> nil
      versions -> List.last(versions)  # Get most recent version
    end
  end

  defp extract_variable_from_pattern({var_name, _meta, nil}) when is_atom(var_name) do
    var_name
  end
  defp extract_variable_from_pattern(_), do: nil

  defp get_ast_node_id_from_meta(meta) do
    Keyword.get(meta, :ast_node_id)
  end

  defp get_ast_node_id_from_ast(_ast) do
    # Would extract from AST metadata
    nil
  end

  defp get_line_number(meta) do
    Keyword.get(meta, :line, 0)
  end

  defp extract_function_key({:def, _meta, [{name, _meta2, args} | _]}) do
    arity = if is_list(args), do: length(args), else: 0
    {UnknownModule, name, arity}  # Module would be provided by caller
  end
  defp extract_function_key(_), do: {UnknownModule, :unknown, 0}

  defp create_new_scope(state, scope_type) do
    scope_id = "#{scope_type}_#{state.next_scope_id}"

    scope_info = %ScopeInfo{
      id: scope_id,
      type: scope_type,
      parent_scope: state.current_scope,
      child_scopes: [],
      variables: [],
      ast_node_id: nil,
      entry_points: [],
      exit_points: [],
      metadata: %{}
    }

    updated_scopes = Map.put(state.scopes, scope_id, scope_info)
    updated_state = %{state |
      scopes: updated_scopes,
      next_scope_id: state.next_scope_id + 1
    }

    scope_id
  end

  defp enter_scope(state, scope_id) do
    %{state |
      current_scope: scope_id,
      scope_stack: [scope_id | state.scope_stack]
    }
  end

  defp exit_scope(state) do
    [_current | parent_stack] = state.scope_stack
    parent_scope = case parent_stack do
      [] -> :function_scope
      [parent | _] -> parent
    end

    %{state |
      current_scope: parent_scope,
      scope_stack: parent_stack
    }
  end

  # Placeholder implementations for remaining functions
  defp get_reaching_definitions(_var_name, _state), do: []
  defp find_reaching_definition(_var_version, _state), do: nil
  defp process_function_call_ssa(_func_name, _args, _meta, state), do: {state, %{definitions: [], uses: []}}
  defp process_pipe_operation_ssa(_left, _right, _meta, state), do: {state, %{definitions: [], uses: []}}
  defp process_statement_sequence_ssa(_statements, state), do: {state, %{definitions: [], uses: []}}
  defp process_list_ssa(_list, state), do: {state, %{definitions: [], uses: []}}
  defp process_pattern_list_ssa(_elements, _meta, state), do: {state, []}
  defp process_map_pattern_ssa(_pairs, _meta, state), do: {state, []}
  defp create_assignment_flows(_expr_analysis, _pattern_defs, _meta), do: []
  defp merge_clause_analyses(analyses), do: %{definitions: [], uses: []}
  defp generate_case_phi_nodes(_clauses, _analyses, _state), do: []
  defp build_data_flow_edges(_state), do: []
  defp generate_phi_nodes(_state), do: []
  defp perform_data_flow_analysis(_state, _flows), do: %{}
  defp find_variable_definitions(_dfg, _var_name), do: []
  defp find_variable_uses(_dfg, _var_name), do: []
  defp find_variable_flows(_dfg, _var_name), do: []
  defp find_variable_phi_nodes(_dfg, _var_name), do: []
  defp find_variable_scopes(_dfg, _var_name), do: []
end
