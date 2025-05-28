## === 4.md ===
defmodule ElixirScope.ASTRepository.DFGGenerator do
  @moduledoc """
  Enhanced Data Flow Graph generator for Elixir functions.

  Uses Static Single Assignment (SSA) form to properly handle
  Elixir's immutable variable semantics and pattern matching.

  Key principles:
  1. Each variable assignment creates a new SSA version (e.g., x_0, x_1).
  2. Pattern matching creates new variable bindings (definitions) within its scope.
  3. Phi nodes merge different variable versions at control flow merge points.
  4. Elixir's immutability means variables are "rebound" rather than "mutated".
  """

  alias ElixirScope.ASTRepository.{
    DFGData, VariableVersion, Definition, Use, DataFlow, PhiNode, ScopeInfo
  }

  @doc """
  Generates a Data Flow Graph for an Elixir function using SSA form.

  ## Parameters
  - function_ast: The AST of the function to analyze. The AST should ideally have unique
                  node IDs assigned (e.g., via ElixirScope.ASTRepository.Parser).
  - function_key: A tuple like {module_atom, function_atom, arity} identifying the function.
  - opts: Options for DFG generation.

  ## Returns
  {:ok, DFGData.t()} | {:error, term()}
  """
  @spec generate_dfg(Macro.t(), {atom(), atom(), non_neg_integer()}, keyword()) :: {:ok, DFGData.t()} | {:error, term()}
  def generate_dfg(function_ast, function_key, opts \\ []) do
    try do
      state = initialize_dfg_state(function_ast, function_key, opts)

      {final_state, _body_analysis} = process_function_definition(function_ast, state)

      data_flows = build_data_flow_edges(final_state.definitions, final_state.uses, final_state)
      phi_nodes = finalize_phi_nodes(final_state) # Process pending phi nodes

      dfg = %DFGData{
        function_key: function_key,
        variables: final_state.variables_versions, # Store all versions created
        definitions: final_state.definitions,
        uses: final_state.uses,
        data_flows: data_flows,
        phi_nodes: phi_nodes,
        scopes: final_state.scopes,
        analysis_results: perform_data_flow_analysis(final_state, data_flows, phi_nodes),
        metadata: %{
          generation_time: System.monotonic_time(:millisecond) - final_state.start_time,
          options: opts,
          ssa_variable_count: map_size(final_state.variables_versions) # Count of unique original var names
        }
      }
      {:ok, dfg}
    rescue
      error -> {:error, {:dfg_generation_failed, error, __STACKTRACE__}}
    end
  end


  defp initialize_dfg_state(function_ast, function_key, opts) do
    function_scope_id = create_scope_id_value("function", 0, nil)
    initial_scope = %ScopeInfo{
      id: function_scope_id, type: :function, parent_scope: nil, child_scopes: [],
      variables: [], ast_node_id: get_ast_node_id_from_ast(function_ast)
    }
    %{
      # SSA state: current version of each variable in the current scope
      # {var_name_atom, scope_id} -> VariableVersion.t()
      current_versions: %{},
      # All versions ever created: %{original_var_name_atom => [VariableVersion.t()]}
      variables_versions: %{},
      # Global counter for SSA versions (across all variables)
      # Or could be per variable: {var_name, scope_id} -> next_version_num
      # Simpler: next_ssa_suffix: 0,

      # Scope management
      scopes: %{function_scope_id => initial_scope},
      current_scope_id: function_scope_id,
      scope_id_counter: 1, # For generating unique scope IDs

      # Analysis tracking
      definitions: [],
      uses: [],
      # Stores potential phi nodes: %{merge_node_ast_id => %{var_name => [incoming_versions]}}
      pending_phi_nodes: %{},

      # Config
      options: opts,
      function_key: function_key,
      start_time: System.monotonic_time(:millisecond)
    }
  end

  defp process_function_definition({:def, meta, [head_ast, [do: body_ast]]}, state) do
    # 1. Process function parameters - they are the first definitions in the function scope
    {state_after_params, _param_defs} = process_function_parameters(head_ast, meta, state)

    # 2. Process function body
    process_ast_node_ssa(body_ast, state_after_params)
  end
  defp process_function_definition({:defp, meta, [head_ast, [do: body_ast]]}, state), do: process_function_definition({:def, meta, [head_ast, [do: body_ast]]}, state)
  # Add defmacro, defmacrop if needed, they have similar structure

  defp process_function_parameters(head_ast, fun_meta, state) do
    # head_ast is like {func_name, meta, args_ast_list} or just args_ast_list for `fn`
    args_ast_list = case head_ast do
      {_name, _meta, args} when is_list(args) -> args
      args when is_list(args) -> args # For fn clauses
      _ -> []
    end

    Enum.reduce(args_ast_list, {state, []}, fn param_ast, {acc_state, acc_defs} ->
      # Each param_ast can be a variable, a pattern, or default value expr.
      # For DFG, parameters are definitions.
      # We need to extract all variables defined by the parameter pattern.
      vars_defined = extract_vars_from_pattern(param_ast) # Returns list of var_name_atoms

      {new_state, new_defs} = Enum.reduce(vars_defined, {acc_state, []}, fn var_name, {s, defs} ->
        {var_version, s_after_var} = create_definition_ssa(var_name, param_ast, :parameter, get_ast_node_id_from_ast(param_ast), get_line_number_from_ast(param_ast), s)
        {s_after_var, [var_version.definition | defs]} # Add the Definition struct
      end)
      {new_state, acc_defs ++ Enum.reverse(new_defs)}
    end)
  end


  defp process_ast_node_ssa(ast, state) do
    # Each AST node might define variables, use variables, or both.
    # It also exists within a scope.
    current_ast_id = get_ast_node_id_from_ast(ast)
    current_line = get_line_number_from_ast(ast)

    case ast do
      # Assignment: LHS defines variables, RHS uses variables.
      {:=, meta, [lhs_ast, rhs_ast]} ->
        # Process RHS first to get uses and its resulting state
        {state_after_rhs, rhs_defs, rhs_uses} = process_ast_node_ssa(rhs_ast, state)
        # Process LHS (pattern) to create new definitions using state_after_rhs
        vars_defined_in_lhs = extract_vars_from_pattern(lhs_ast)
        {state_after_lhs, lhs_new_defs_structs} =
          Enum.reduce(vars_defined_in_lhs, {state_after_rhs, []}, fn var_name, {s, defs} ->
            {var_version, s_after_var} = create_definition_ssa(var_name, lhs_ast, :assignment, get_ast_node_id_from_ast(lhs_ast) || current_ast_id, get_line_number(meta) || current_line, s, rhs_ast)
            {s_after_var, [var_version.definition | defs]}
          end)
        all_defs = rhs_defs ++ Enum.reverse(lhs_new_defs_structs)
        {state_after_lhs, all_defs, rhs_uses}

      # Variable reference: A use.
      {var_name, meta, nil} when is_atom(var_name) and not is_nil(var_name) ->
        {use_version, updated_state} = get_or_create_use_ssa(var_name, ast, :read, current_ast_id, get_line_number(meta) || current_line, state)
        {updated_state, [], [use_version.use_struct]} # No new defs, one use

      # Function call: Uses variables in args, func_name itself can be a var.
      # The result of the call might be assigned, handled by parent {:=, ...} node.
      {func_expr, meta, args_ast_list} when is_list(args_ast_list) ->
        # Process func_expr (it could be a variable e.g. `my_fun.()`)
        {state_after_func_expr, func_expr_defs, func_expr_uses} =
          if is_atom(func_expr) and not Keyword.has_key?(meta, :context) do # Likely a function name literal, not a var
            {state, [], []}
          else
            process_ast_node_ssa(func_expr, state) # If it's like {Mod, :fun} or a var
          end

        # Process arguments
        {state_after_args, args_defs, args_uses} =
          Enum.reduce(args_ast_list, {state_after_func_expr, [], []}, fn arg_ast, {s, acc_defs, acc_uses} ->
            {s_after_arg, arg_def_list, arg_use_list} = process_ast_node_ssa(arg_ast, s)
            {s_after_arg, acc_defs ++ arg_def_list, acc_uses ++ arg_use_list}
          end)
        all_defs = func_expr_defs ++ args_defs
        all_uses = func_expr_uses ++ args_uses
        # If the call itself represents a value (e.g. not piped, not assigned), it's a complex use
        # For now, focus on args. The call result DFG is harder without knowing if it's used.
        {state_after_args, all_defs, all_uses}

      # Block of statements: Process sequentially, threading state.
      {:__block__, _meta, statements_ast} ->
        Enum.reduce(statements_ast, {state, [], []}, fn stmt_ast, {s, acc_defs, acc_uses} ->
          {s_after_stmt, stmt_def_list, stmt_use_list} = process_ast_node_ssa(stmt_ast, s)
          {s_after_stmt, acc_defs ++ stmt_def_list, acc_uses ++ stmt_use_list}
        end)

      # Case statement: New scopes for each clause, potential phi nodes at merge.
      {:case, meta, [condition_ast | clauses_ast]} ->
        # Process condition
        {state_after_cond, cond_defs, cond_uses} = process_ast_node_ssa(condition_ast, state)

        # Track variable versions before entering clauses for phi nodes
        vars_at_case_entry = get_scoped_vars(state_after_cond)
        merge_point_id = current_ast_id # AST ID of the case statement itself

        # Process each clause in a new scope
        {final_state_after_clauses, clauses_defs_uses_list} =
          Enum.map_reduce(clauses_ast, state_after_cond, fn clause_ast, acc_state_clauses ->
            {:->, clause_meta, [pattern_ast, body_ast]} = clause_ast
            {clause_scope_id, state_with_clause_scope} = create_new_scope(acc_state_clauses, :case_clause, get_ast_node_id_from_ast(clause_ast))
            state_in_clause = enter_scope(state_with_clause_scope, clause_scope_id)

            # Pattern defines variables in the new scope
            vars_in_pattern = extract_vars_from_pattern(pattern_ast)
            {state_after_pattern, pattern_defs_structs} =
              Enum.reduce(vars_in_pattern, {state_in_clause, []}, fn v_name, {s, defs} ->
                {v_ver, s_after_v} = create_definition_ssa(v_name, pattern_ast, :pattern_match, get_ast_node_id_from_ast(pattern_ast), get_line_number(clause_meta), s)
                {s_after_v, [v_ver.definition | defs]}
              end)

            {state_after_body, body_defs, body_uses} = process_ast_node_ssa(body_ast, state_after_pattern)

            # Record versions exiting this clause for phi nodes
            vars_exiting_clause = get_scoped_vars(state_after_body)
            state_with_phi_pending = add_phi_inputs(state_after_body, merge_point_id, vars_at_case_entry, vars_exiting_clause)

            state_exited_scope = exit_scope(state_with_phi_pending) # Exit to parent scope of case
            all_clause_defs = Enum.reverse(pattern_defs_structs) ++ body_defs
            {{state_exited_scope, {all_clause_defs, body_uses}}, state_exited_scope} # Map_reduce: {result_for_list, new_accumulator}
          end)

        all_clauses_defs = Enum.flat_map(clauses_defs_uses_list, fn {d, _u} -> d end)
        all_clauses_uses = Enum.flat_map(clauses_defs_uses_list, fn {_d, u} -> u end)

        # Create phi definitions for vars modified in branches
        state_with_phis = define_phi_outputs(final_state_after_clauses, merge_point_id, vars_at_case_entry, current_line)

        {state_with_phis, cond_defs ++ all_clauses_defs ++ state_with_phis.newly_defined_phi_vars, cond_uses ++ all_clauses_uses}

      # `if` statement: Similar to case with two branches.
      {:if, meta, [condition_ast, [do: then_ast, else: else_ast]]} ->
        # Process condition
        {state_after_cond, cond_defs, cond_uses} = process_ast_node_ssa(condition_ast, state)
        vars_at_if_entry = get_scoped_vars(state_after_cond)
        merge_point_id = current_ast_id

        # Then branch
        {then_scope_id, state_with_then_scope} = create_new_scope(state_after_cond, :if_branch, get_ast_node_id_from_ast(then_ast))
        state_in_then = enter_scope(state_with_then_scope, then_scope_id)
        {state_after_then_body, then_defs, then_uses} = process_ast_node_ssa(then_ast, state_in_then)
        vars_exiting_then = get_scoped_vars(state_after_then_body)
        state_after_then_phi = add_phi_inputs(state_after_then_body, merge_point_id, vars_at_if_entry, vars_exiting_then)
        state_exited_then = exit_scope(state_after_then_phi)

        # Else branch
        {else_scope_id, state_with_else_scope} = create_new_scope(state_exited_then, :if_branch, get_ast_node_id_from_ast(else_ast))
        state_in_else = enter_scope(state_with_else_scope, else_scope_id)
        {state_after_else_body, else_defs, else_uses} = process_ast_node_ssa(else_ast, state_in_else)
        vars_exiting_else = get_scoped_vars(state_after_else_body)
        state_after_else_phi = add_phi_inputs(state_after_else_body, merge_point_id, vars_at_if_entry, vars_exiting_else)
        state_exited_else = exit_scope(state_after_else_phi) # Final state after processing both branches

        # Create phi definitions
        state_with_phis = define_phi_outputs(state_exited_else, merge_point_id, vars_at_if_entry, current_line)
        {state_with_phis, cond_defs ++ then_defs ++ else_defs ++ state_with_phis.newly_defined_phi_vars, cond_uses ++ then_uses ++ else_uses}

      # Anonymous function `fn ... end`
      {:fn, meta, fn_clauses_ast} ->
        # The `fn` itself is an expression. Its body forms new scopes.
        # Processing its internal DFG is complex and might be a separate DFG generation.
        # For the outer DFG, we need to identify captured variables (uses).
        # And the `fn` itself can be considered defined here.
        {fn_scope_id, state_with_fn_scope} = create_new_scope(state, :anonymous_function, current_ast_id)
        state_in_fn = enter_scope(state_with_fn_scope, fn_scope_id)

        # Identify captured variables (free variables in fn body)
        # This requires analyzing fn_clauses_ast against variables defined *outside* state_in_fn
        # For now, let's assume all free variables in fn_clauses_ast are captured.
        # A more precise way is to find all vars used in fn_clauses_ast that are not defined within it.
        free_vars_used_in_fn = find_free_variables(fn_clauses_ast, state_in_fn) # Needs complex implementation
        {state_after_captures, capture_uses} =
          Enum.reduce(free_vars_used_in_fn, {state_in_fn, []}, fn {var_name, use_ast}, {s, uses} ->
            {use_ver, s_after_use} = get_or_create_use_ssa(var_name, use_ast, :closure_capture, get_ast_node_id_from_ast(use_ast), get_line_number_from_ast(use_ast), s)
            # Mark var_version in outer scope as captured
            s_marked_capture = mark_variable_as_captured(s_after_use, use_ver.var_version)
            {s_marked_capture, [use_ver.use_struct | uses]}
          end)

        # Process fn clauses internally (this could be a recursive call to generate_dfg for the fn body)
        # For this DFG, we don't delve deep into the fn's own DFG, just its interface.
        state_exited_fn_scope = exit_scope(state_after_captures)
        {state_exited_fn_scope, [], Enum.reverse(capture_uses)}


      # Literals and other simple constructs (no defs/uses relevant to DFG here)
      _ when is_number(ast) or (is_atom(ast) and Keyword.has_key?(meta, :context)) -> {state, [], []} # context usually means it's part of a call or struct
      _ when is_binary(ast) or is_boolean(ast) -> {state, [], []}
      _ ->
        # Unhandled or complex expression. Try to recurse if it's a tuple with args.
        # This is a fallback, specific handlers are better.
        case ast do
          {_op, _m, args} when is_list(args) ->
            Enum.reduce(args, {state, [], []}, fn child_ast, {s, acc_defs, acc_uses} ->
              {s_after_child, child_defs, child_uses} = process_ast_node_ssa(child_ast, s)
              {s_after_child, acc_defs ++ child_defs, acc_uses ++ child_uses}
            end)
          _ -> {state, [], []} # Truly unhandled
        end
    end
  end

  # --- SSA and Definition/Use Helpers ---
  defp create_definition_ssa(var_name_atom, def_ast, def_type, ast_node_id, line, state, source_expr_ast \\ nil) do
    # Get current list of versions for this original variable name
    existing_versions = Map.get(state.variables_versions, var_name_atom, [])
    new_version_suffix = length(existing_versions)
    ssa_name = "#{var_name_atom}_#{new_version_suffix}"

    var_version = %VariableVersion{
      name: var_name_atom, version: new_version_suffix, ssa_name: ssa_name,
      scope_id: state.current_scope_id,
      definition_node: ast_node_id, # AST ID of the node defining this version
      type_info: nil, is_parameter: def_type == :parameter, is_captured: false
    }

    definition_struct = %Definition{
      variable: var_version, ast_node_id: ast_node_id, definition_type: def_type,
      source_expression: source_expr_ast || def_ast, # AST of RHS or pattern
      line: line, scope_id: state.current_scope_id, reaching_definitions: [] # TODO: Proper Reaching Defs
    }
    var_version_with_def = %{var_version | definition: definition_struct}


    # Update state:
    # 1. Add this new version to the list of all versions for var_name_atom
    updated_all_versions = Map.put(state.variables_versions, var_name_atom, existing_versions ++ [var_version_with_def])
    # 2. Set this as the current version for var_name_atom in the current scope
    updated_current_versions = Map.put(state.current_versions, {var_name_atom, state.current_scope_id}, var_version_with_def)
    # 3. Add to the list of definitions for the DFG
    updated_definitions_list = [definition_struct | state.definitions]

    new_state = %{state |
      variables_versions: updated_all_versions,
      current_versions: updated_current_versions,
      definitions: updated_definitions_list
    }
    {var_version_with_def, new_state}
  end

  defp get_or_create_use_ssa(var_name_atom, use_ast, use_type, ast_node_id, line, state) do
    # Find the current SSA version of var_name_atom visible in this scope or parent scopes
    current_var_version = find_visible_variable_version(var_name_atom, state.current_scope_id, state)

    if current_var_version do
      use_struct = %Use{
        variable: current_var_version, ast_node_id: ast_node_id, use_type: use_type,
        context: nil, line: line, scope_id: state.current_scope_id,
        reaching_definition: current_var_version.definition # The definition of the version being used
      }
      updated_uses_list = [use_struct | state.uses]
      new_state = %{state | uses: updated_uses_list}
      {{:ok, current_var_version, use_struct}, new_state}
    else
      # Variable used before definition in accessible scopes (error or global/module attribute)
      # For now, create a "phantom" definition or mark as unresolved
      # Let's assume it's an error for simplicity here / needs external resolution
      phantom_var_version = %VariableVersion{name: var_name_atom, version: -1, ssa_name: "#{var_name_atom}_unresolved", scope_id: state.current_scope_id, definition_node: nil}
      use_struct = %Use{variable: phantom_var_version, ast_node_id: ast_node_id, use_type: use_type, line: line, scope_id: state.current_scope_id, reaching_definition: nil}
      updated_uses_list = [use_struct | state.uses]
      new_state = %{state | uses: updated_uses_list}
      {{:error_unresolved, phantom_var_version, use_struct}, new_state}
    end
  end

  defp find_visible_variable_version(var_name_atom, scope_id, state) do
    case Map.get(state.current_versions, {var_name_atom, scope_id}) do
      nil -> # Not in current scope, try parent
        current_scope_info = state.scopes[scope_id]
        if current_scope_info && current_scope_info.parent_scope do
          find_visible_variable_version(var_name_atom, current_scope_info.parent_scope, state)
        else
          nil # No parent or top-level scope reached
        end
      found_version -> found_version
    end
  end


  # --- Scope Management Helpers ---
  defp create_new_scope(state, scope_type_atom, ast_node_id_of_scope_creator) do
    new_scope_id_val = state.scope_id_counter + 1
    new_scope_id = create_scope_id_value(Atom.to_string(scope_type_atom), new_scope_id_val, state.current_scope_id)

    new_scope_info = %ScopeInfo{
      id: new_scope_id, type: scope_type_atom, parent_scope: state.current_scope_id,
      child_scopes: [], variables: [], ast_node_id: ast_node_id_of_scope_creator
    }
    # Add this new scope as a child of the current scope
    parent_scope_info = state.scopes[state.current_scope_id]
    updated_parent_scope_info = %{parent_scope_info | child_scopes: [new_scope_id | parent_scope_info.child_scopes]}

    updated_scopes_map = state.scopes
                         |> Map.put(state.current_scope_id, updated_parent_scope_info)
                         |> Map.put(new_scope_id, new_scope_info)

    new_state = %{state | scopes: updated_scopes_map, scope_id_counter: new_scope_id_val}
    {new_scope_id, new_state}
  end
  defp create_scope_id_value(prefix_str, id_val, parent_id_str_or_nil) do
    "#{prefix_str}_#{id_val}_parent_#{parent_id_str_or_nil || "root"}"
  end

  defp enter_scope(state, new_scope_id) do
    # When entering a new scope, variables from parent scope are visible
    # but new definitions will be scoped to new_scope_id.
    # current_versions map uses {var_name, scope_id} so it inherently handles this.
    %{state | current_scope_id: new_scope_id}
  end

  defp exit_scope(state) do
    parent_scope_id = state.scopes[state.current_scope_id].parent_scope
    # Important: When exiting a scope, current_versions for variables defined *within*
    # this scope are no longer the "current" ones for the parent scope.
    # The find_visible_variable_version correctly handles lookup by traversing parent scopes.
    # No explicit cleanup of state.current_versions needed here due to its {var,scope} key.
    %{state | current_scope_id: parent_scope_id}
  end

  # --- Phi Node Helpers ---
  defp get_scoped_vars(state) do
    # Get all var_names that have a version in the current_scope_id
    state.current_versions
    |> Enum.filter(fn {{_var, scope_id}, _ver} -> scope_id == state.current_scope_id end)
    |> Enum.map(fn {{var_name, _scope_id}, var_version} -> {var_name, var_version} end)
    |> Map.new() # Map of {var_name => var_version} for current scope
  end

  defp add_phi_inputs(state, merge_point_id, vars_at_entry, vars_exiting_branch) do
    # For each variable that was live at entry OR defined in branch:
    # Add its exiting version from this branch as an input to a potential phi node.
    relevant_var_names = Map.keys(vars_at_entry) ++ Map.keys(vars_exiting_branch) |> Enum.uniq()

    new_pending_phi_nodes = Enum.reduce(relevant_var_names, state.pending_phi_nodes,
      fn var_name, acc_phis ->
        # Get the version of var_name exiting this specific branch
        version_from_branch = Map.get(vars_exiting_branch, var_name) ||
                              find_visible_variable_version(var_name, state.current_scope_id, state) # If not redefined in branch, use visible one

        if version_from_branch do
          # Get existing inputs for this var at this merge point
          current_inputs_for_var = acc_phis
                                  |> Map.get(merge_point_id, %{})
                                  |> Map.get(var_name, [])
          # Add this branch's version
          updated_inputs_for_var = [version_from_branch | current_inputs_for_var]
          # Update pending_phi_nodes
          merge_point_map = Map.get(acc_phis, merge_point_id, %{})
          updated_merge_point_map = Map.put(merge_point_map, var_name, updated_inputs_for_var |> Enum.uniq_by(&(&1.ssa_name)))
          Map.put(acc_phis, merge_point_id, updated_merge_point_map)
        else
          acc_phis # Variable was not visible/defined
        end
    end)
    %{state | pending_phi_nodes: new_pending_phi_nodes}
  end

  defp define_phi_outputs(state_after_branches_processed, merge_point_id, vars_at_entry_map, merge_line) do
    # After all branches feeding into merge_point_id have been processed:
    # For each variable in pending_phi_nodes[merge_point_id], if there are multiple
    # distinct incoming versions, create a new SSA version (phi_result_var)
    # and a PhiNode struct. Update state to reflect this new definition.
    phi_var_definitions = [] # To collect new Definition structs for phi results

    new_current_versions =
      Map.get(state_after_branches_processed.pending_phi_nodes, merge_point_id, %{})
      |> Enum.reduce(state_after_branches_processed.current_versions,
          fn {var_name, incoming_versions_list}, acc_curr_vers ->
            unique_incoming_versions = Enum.uniq_by(incoming_versions_list, &(&1.ssa_name))

            if length(unique_incoming_versions) > 1 do
              # Create phi node and new SSA version for var_name
              # The new SSA version is defined *at the merge point* in the parent scope
              parent_scope_of_merge = state_after_branches_processed.scopes[state_after_branches_processed.current_scope_id].parent_scope || state_after_branches_processed.current_scope_id

              # Temporarily switch to parent scope for defining phi result
              temp_state_for_phi_def = %{state_after_branches_processed | current_scope_id: parent_scope_of_merge}
              {phi_result_var_version, _s_after_phi_def} = create_definition_ssa(var_name, {:phi, [], unique_incoming_versions}, :phi_assignment, merge_point_id, merge_line, temp_state_for_phi_def)
              # Add to phi_var_definitions
              phi_var_definitions = [phi_result_var_version.definition | phi_var_definitions]


              phi_node_struct = %PhiNode{
                target_variable: phi_result_var_version,
                source_variables: unique_incoming_versions,
                merge_point: merge_point_id, # AST ID of case/if
                conditions: [], # Conditions for each path leading to this version (from CFG) - COMPLEX
                scope_id: parent_scope_of_merge
              }
              # Add phi_node_struct to state.phi_nodes (or a temporary list)
              # Update state.definitions with the new phi_result_var_version's Definition
              # Update state.current_versions in parent_scope_of_merge for var_name to phi_result_var_version
              Map.put(acc_curr_vers, {var_name, parent_scope_of_merge}, phi_result_var_version)
            else
              # Only one version, or no versions. No phi needed.
              # The version from the single path (or original if no change) remains current.
              # If unique_incoming_versions is empty, var might not be live.
              # If one, make that current in parent scope.
              case unique_incoming_versions do
                [single_version] ->
                  parent_scope_of_merge = state_after_branches_processed.scopes[state_after_branches_processed.current_scope_id].parent_scope || state_after_branches_processed.current_scope_id
                  Map.put(acc_curr_vers, {var_name, parent_scope_of_merge}, single_version)
                _ -> acc_curr_vers
              end
            end
        end)

    # Need to get the newly created phi definitions (VariableVersion structs) into the main definitions list
    # The create_definition_ssa already adds to state.definitions.
    # So, the state returned by it (captured as _s_after_phi_def) would have it.
    # This part is tricky with Enum.reduce.
    # It's better if create_definition_ssa returns {var_version, new_def_struct, new_state}
    # For now, we collect them separately and add later or assume create_definition_ssa handles it.
    # Let's assume state_after_branches_processed already contains these defs from create_definition_ssa calls.
    %{state_after_branches_processed | current_versions: new_current_versions, newly_defined_phi_vars: phi_var_definitions} # Track new defs for merging
  end

  defp finalize_phi_nodes(state) do
    # This function should iterate over state.pending_phi_nodes if define_phi_outputs
    # was only populating state.pending_phi_nodes.
    # However, our define_phi_outputs tries to create PhiNode structs directly.
    # So, this might be about collecting them from a temporary list populated by define_phi_outputs.
    # Let's assume `define_phi_outputs` adds to a `state.phi_nodes_built` list.
    state.phi_nodes_built || [] # If define_phi_outputs builds them and puts them in a list in state
  end

  # --- Utility & Placeholder Helpers ---
  defp extract_vars_from_pattern(pattern_ast) do
    # Simplified: traverse pattern and collect all var atoms.
    # Needs to handle _, pinned vars ^, map/struct patterns, etc.
    vars = []
    Macro.traverse(pattern_ast, %{}, fn
      {var_name, _meta, nil}, acc when is_atom(var_name) and not Atom.to_string(var_name) =~ ~r"^[A-Z]" and var_name != :_ ->
        {[var_name | acc], acc} # Collect variable
      ast_node, acc ->
        {ast_node, acc} # Continue traversal for others
    end, fn node, acc -> {node, acc} end) # postwalk
    |> elem(0) # Get the collected variables
    |> Enum.uniq()
  end

  defp get_ast_node_id_from_ast({_op, meta, _args}) when is_list(meta), do: Keyword.get(meta, :ast_node_id)
  defp get_ast_node_id_from_ast({atom_var, meta, nil}) when is_list(meta), do: Keyword.get(meta, :ast_node_id)
  defp get_ast_node_id_from_ast(_other), do: nil # Needs a unique ID if not present

  defp get_line_number_from_ast({_op, meta, _args}) when is_list(meta), do: Keyword.get(meta, :line, 0)
  defp get_line_number_from_ast({atom_var, meta, nil}) when is_list(meta), do: Keyword.get(meta, :line, 0)
  defp get_line_number_from_ast(_other), do: 0

  defp find_free_variables(_fn_clauses_ast, _state_in_fn), do: [] # Complex: find all uses not defined within fn scope
  defp mark_variable_as_captured(state, _var_version_to_mark) do
    # Find var_version_to_mark in state.variables_versions and update its is_captured flag
    state # Placeholder
  end


  defp build_data_flow_edges(definitions, uses, _state) do
    # For each use, find its reaching definition(s) and create DataFlow edges.
    # In SSA, each use has exactly one reaching definition (the current SSA version).
    Enum.map(uses, fn use_struct ->
      # use_struct.reaching_definition should be the Definition struct of the var_version used
      if def_struct = use_struct.reaching_definition do
        %DataFlow{
          from_definition: def_struct,
          to_use: use_struct,
          flow_type: :direct, # Could be more specific based on context
          path_condition: nil, # From CFG if conditional
          probability: 1.0
        }
      else
        nil # Use of unresolved variable
      end
    end) |> Enum.reject(&is_nil/1)
  end

  defp perform_data_flow_analysis(_state, _flows, _phi_nodes) do
    # Placeholder for more advanced analyses like:
    # - Liveness analysis
    # - Reaching definitions (more robustly than current simple linking)
    # - Uninitialized variable checks
    # - Constant propagation
    %{
      liveness: %{},
      uninitialized_warnings: []
    }
  end
end
