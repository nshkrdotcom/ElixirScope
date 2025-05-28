defmodule ElixirScope.ASTRepository.ASTAnalyzer do
  @moduledoc """
  Performs comprehensive AST analysis for Elixir modules and functions.
  Extracts metadata, dependencies, complexity metrics, and structural information.
  This module is responsible for populating the detailed fields in
  `EnhancedModuleData` and `EnhancedFunctionData`.
  """

  alias ElixirScope.ASTRepository.{
    EnhancedModuleData,
    EnhancedFunctionData,
    VariableData, # Assuming these are defined as per specifications
    # CallData, PatternData, ParameterData, GuardData, etc. would be here
    ComplexityMetrics # From cfg_data.ex or a shared location
  }
  # Note: Specific struct definitions for CallData, PatternData etc. are assumed from
  # the schema documents. For brevity, they are not re-defined here.

  @type function_analysis_result :: %{
    functions: [map()], # Simplified for now, would be EnhancedFunctionData stub
    dependencies: %{imports: list, aliases: list, requires: list, uses: list},
    attributes: map(),
    behaviours: list(atom),
    protocols: list(atom), # Protocols implemented by the module
    complexity: map(), # Module-level complexity
    patterns: list(map()), # Detected module-level patterns
    risks: list(map()) # Detected module-level risks
  }

  @type individual_function_analysis_result :: %{
    complexity: ComplexityMetrics.t(),
    variables: [VariableData.t()],
    calls: [map()], # Would be CallData.t()
    patterns: [map()], # Would be PatternData.t() for pattern matches
    guards: [Macro.t()],
    control_structures: [map()] # Info about if/case/cond etc.
    # data_flow_summary: map(), # High-level DFG insights
    # control_flow_summary: map() # High-level CFG insights
  }

  @doc """
  Performs comprehensive analysis of a module's AST.
  """
  @spec analyze_module_ast(Macro.t(), module_name :: atom(), file_path :: String.t(), opts :: keyword()) ::
          {:ok, EnhancedModuleData.t()} | {:error, term()}
  def analyze_module_ast(module_ast, module_name, file_path, opts \\ []) do
    try
      ast_node_id_prefix = "#{module_name}" # Simplified prefix for function AST node IDs

      functions_data = extract_functions_with_analysis(module_ast, module_name, file_path, ast_node_id_prefix, opts)
      dependencies = extract_module_dependencies(module_ast)
      attributes = extract_module_attributes(module_ast)
      behaviours_used = extract_behaviour_usage(module_ast) # `use MyBehaviour`
      protocols_implemented = extract_protocol_implementations(module_ast) # `defimpl MyProtocol, for: MyModule`
      module_complexity = calculate_module_complexity(module_ast, functions_data) # Aggregate from functions + module structure
      # patterns = detect_module_patterns(module_ast, opts) # e.g., GenServer, Supervisor
      # risks = detect_module_risks(module_ast, opts)

      enhanced_module_data = %EnhancedModuleData{
        module_name: module_name,
        file_path: file_path,
        file_hash: :crypto.hash(:sha256, Macro.to_string(module_ast)) |> Base.encode16(),
        ast: module_ast,
        ast_size: count_ast_nodes(module_ast),
        ast_depth: calculate_ast_depth(module_ast),
        functions: functions_data,
        macros: extract_macros(module_ast, module_name, file_path, ast_node_id_prefix, opts), # Similar to functions
        module_attributes: attributes,
        typespecs: extract_typespecs(module_ast),
        imports: dependencies.imports,
        aliases: dependencies.aliases,
        requires: dependencies.requires,
        uses: behaviours_used, # Assuming uses captures `use SomeModule`
        behaviours: protocols_implemented, # `behaviours` field in schema often means protocols implemented by this module
        callbacks_implemented: [], # Needs more advanced logic to map functions to behaviour callbacks
        child_specs: [], # Specific to supervisors
        complexity_metrics: module_complexity,
        code_smells: [], # Placeholder
        security_risks: [], # Placeholder
        last_modified: DateTime.utc_now(), # Or from file system
        last_analyzed: DateTime.utc_now(),
        metadata: %{analysis_options: opts}
      }
      {:ok, enhanced_module_data}
    rescue
      error -> {:error, {:module_analysis_failed, error, __STACKTRACE__}}
  end


  @doc """
  Performs deep analysis of a single function's AST.
  This is typically called by `analyze_module_ast` for each function.
  """
  @spec analyze_function_ast(fun_ast :: Macro.t(), module_name :: atom(), fun_name :: atom(), arity :: non_neg_integer(), file_path :: String.t(), ast_node_id_prefix :: String.t(), opts :: keyword()) ::
          {:ok, EnhancedFunctionData.t()} | {:error, term()}
  def analyze_function_ast(function_ast, module_name, fun_name, arity, file_path, ast_node_id_prefix, opts \\ []) do
    try
      # function_ast here is the {:def | :defp, meta, [head, [do: body]]} block
      head_ast = get_function_head(function_ast)
      body_ast = get_function_body(function_ast)
      meta = get_function_meta(function_ast)
      line_start = Keyword.get(meta, :line, 0)
      # line_end requires traversing the whole function_ast, or using last line of body
      line_end = line_start + (Macro.to_string(function_ast) |> String.split("\n") |> length() |> Kernel.-(1))

      ast_node_id = "#{ast_node_id_prefix}:#{fun_name}:#{arity}:#{Keyword.get(meta, :line, "unknown")}" # More robust ID needed

      variables = extract_variables_from_function(function_ast, ast_node_id) # Includes params and locals
      parameters = extract_parameters_from_head(head_ast, ast_node_id)
      calls = extract_function_calls_from_body(body_ast, module_name)
      patterns = extract_pattern_matches(function_ast) # From head and body (case, fn clauses)
      guards = extract_guards_from_clauses(function_ast) # From head clauses
      complexity_metrics = calculate_function_complexity_metrics(function_ast) # Basic complexity from AST shape
      # control_structures = extract_control_structures_info(body_ast) # Details about if/case/cond

      # Note: CFGData and DFGData are generated by their respective generators,
      # not directly by this ASTAnalyzer. This analyzer focuses on direct AST properties.
      # They would be added to EnhancedFunctionData later.

      enhanced_function_data = %EnhancedFunctionData{
        module_name: module_name,
        function_name: fun_name,
        arity: arity,
        ast_node_id: ast_node_id,
        file_path: file_path,
        line_start: line_start,
        line_end: line_end,
        column_start: Keyword.get(meta, :column, 0), # If available
        column_end: 0, # Needs more work
        ast: function_ast,
        head_ast: head_ast,
        body_ast: body_ast,
        visibility: if(elem(function_ast, 0) == :defp, do: :private, else: :public),
        is_macro: elem(function_ast, 0) in [:defmacro, :defmacrop],
        is_guard: false, # This field in schema refers to 'is this function a guard function itself?' not 'does it have guards'
        is_callback: false, # Needs pattern recognizer to determine
        is_delegate: false, # Needs analysis of `defdelegate`
        clauses: extract_clauses_data(function_ast), # For multi-clause functions
        guard_clauses: guards, # List of guard ASTs
        pattern_matches: patterns, # List of PatternData
        parameters: parameters, # List of ParameterData
        local_variables: variables -- parameters, # Simplified
        captures: extract_captures(body_ast), # For anonymous functions
        # These are typically from CFG/DFG:
        cyclomatic_complexity: complexity_metrics.cyclomatic_complexity,
        nesting_depth: complexity_metrics.nesting_depth,
        # control_flow_graph: %CFGData{}, # Filled by CFGGenerator
        # data_flow_graph: %DFGData{},   # Filled by DFGGenerator
        variable_mutations: [], # Elixir is immutable, this refers to rebinding patterns
        return_points: extract_return_points(body_ast),
        called_functions: calls,
        calling_functions: [], # Reverse index, built later
        external_calls: Enum.filter(calls, &(&1.module != module_name && &1.module != nil)),
        complexity_score: calculate_overall_complexity_score(complexity_metrics),
        maintainability_index: 0.0, # Placeholder
        test_coverage: nil,
        performance_profile: nil,
        doc_string: extract_doc_string(function_ast, module_name),
        spec: extract_spec(function_ast, module_name, fun_name, arity),
        examples: [], # From docs
        tags: [],
        annotations: %{},
        metadata: %{ast_type: elem(function_ast,0)}
      }

      {:ok, enhanced_function_data}
    rescue
      error -> {:error, {:function_analysis_failed, {module_name, fun_name, arity}, error, __STACKTRACE__}}
  end


  # --- Extraction Helpers for Module Analysis ---

  defp extract_functions_with_analysis(module_ast, module_name, file_path, ast_node_id_prefix, opts) do
    module_body = get_module_body(module_ast)
    Macro.traverse(module_body, [], fn
      ({:def, meta, [{{fun_name, _, args}, _} | _] = head_and_body} = fun_ast, acc)
      when is_atom(fun_name) and is_list(args) ->
        arity = length(args)
        case analyze_function_ast(fun_ast, module_name, fun_name, arity, file_path, ast_node_id_prefix, opts) do
          {:ok, fun_data} -> {fun_ast, [fun_data | acc]}
          {:error, _err} -> {fun_ast, acc} # Log error
        end
      ({:defp, meta, [{{fun_name, _, args}, _} | _] = head_and_body} = fun_ast, acc)
      when is_atom(fun_name) and is_list(args) ->
        arity = length(args)
        case analyze_function_ast(fun_ast, module_name, fun_name, arity, file_path, ast_node_id_prefix, opts) do
          {:ok, fun_data} -> {fun_ast, [fun_data | acc]}
          {:error, _err} -> {fun_ast, acc} # Log error
        end
      (other_ast, acc) ->
        {other_ast, acc}
    end, fn node, acc -> {node, acc} end)
    |> elem(1) # Get accumulated function data
    |> Enum.reverse()
  end

  defp extract_macros(module_ast, module_name, file_path, ast_node_id_prefix, opts) do
    # Similar to extract_functions_with_analysis, but for :defmacro and :defmacrop
    # For brevity, implementation is omitted but would mirror function extraction.
    []
  end

  defp get_module_body({:defmodule, _meta, [do: block]}) when is_list(block), do: block
  defp get_module_body({:defmodule, _meta, block_content_tuple}) when is_tuple(block_content_tuple), do: elem(block_content_tuple, 1) # {:__block__, [], expressions}
  defp get_module_body(_), do: []

  defp extract_module_dependencies(module_ast) do
    imports = []
    aliases = []
    requires = []
    uses = [] # For `use MyModule`

    module_body = get_module_body(module_ast)
    Macro.traverse(module_body, %{i: [], a: [], r: [], u: []}, fn
      ({:import, _, [target | _]}, acc) -> {nil, Map.update!(acc, :i, &[target | &1])}
      ({:alias, _, [{:__aliases__, _, _} = target | _]}, acc) -> {nil, Map.update!(acc, :a, &[target | &1])}
      ({:require, _, [target | _]}, acc) -> {nil, Map.update!(acc, :r, &[target | &1])}
      ({:use, _, [target | _]}, acc) -> {nil, Map.update!(acc, :u, &[target | &1])}
      (node, acc) -> {node, acc}
    end, fn node, acc -> {node, acc} end)
    |> elem(1) # final accumulator
    |> then(fn %{i: i, a: a, r: r, u: u} ->
      %{
        imports: Enum.map(Enum.reverse(i), &format_module_ref/1),
        aliases: Enum.map(Enum.reverse(a), &format_module_ref/1),
        requires: Enum.map(Enum.reverse(r), &format_module_ref/1),
        uses: Enum.map(Enum.reverse(u), &format_module_ref/1) # These are Behaviours or other modules `use`d
      }
    end)
  end
  defp format_module_ref({:__aliases__, _, parts}), do: Module.concat(parts)
  defp format_module_ref(atom) when is_atom(atom), do: atom
  defp format_module_ref(_other), do: nil


  defp extract_module_attributes(module_ast) do
    module_body = get_module_body(module_ast)
    Macro.traverse(module_body, %{}, fn
      ({:@, _, [{attr_name, _, _}, value_ast]}, acc) when is_atom(attr_name) ->
        # Try to evaluate value_ast if it's simple, otherwise store AST
        value = try do Code.eval_quoted(value_ast) |> elem(0) rescue _ -> value_ast end
        {nil, Map.put(acc, attr_name, value)}
      (node, acc) -> {node, acc}
    end, fn node, acc -> {node, acc} end)
    |> elem(1)
  end

  defp extract_behaviour_usage(module_ast) do
    # Captured by extract_module_dependencies's :uses key
    extract_module_dependencies(module_ast).uses
    |> Enum.map(fn mod_ref -> %{behaviour: mod_ref, opts: []} end) # Simplified: BehaviourUsage.t()
  end

  defp extract_protocol_implementations(module_ast) do
    # Looks for `defimpl ProtocolName, for: MyDataType do ... end`
    protocols = []
    module_body = get_module_body(module_ast)
    Macro.traverse(module_body, [], fn
      ({:defimpl, _, [protocol_name_ast, _for_clause, _do_block]}, acc) ->
        protocol_name = format_module_ref(protocol_name_ast)
        {[protocol_name | acc], acc} # Add protocol_name
      (node, acc) -> {node, acc}
    end, fn node, acc -> {node, acc} end)
    |> elem(0) # collected items are first element of tuple from traverse
    |> Enum.uniq()
  end

  defp extract_typespecs(module_ast) do
    # Placeholder: traverse for @type, @opaque, @spec
    []
  end

  defp calculate_module_complexity(module_ast, functions_data_list) do
    # Aggregate complexity from functions, plus structural complexity of module itself.
    total_fun_cyclomatic = Enum.sum(Enum.map(functions_data_list, &(&1.cyclomatic_complexity || 0)))
    num_functions = length(functions_data_list)
    # Could add other metrics like coupling, cohesion based on dependencies.
    %ComplexityMetrics{ # Using the structure from CFGData.ex
      cyclomatic_complexity: total_fun_cyclomatic + 1, # Base 1 for module itself
      essential_complexity: 0, # Placeholder
      cognitive_complexity: total_fun_cyclomatic / num_functions * 2, # Very rough estimate
      pattern_complexity: 0,
      guard_complexity: 0,
      pipe_chain_length: 0,
      nesting_depth: calculate_ast_depth(module_ast), # Or max function nesting
      total_paths: 0, unreachable_paths: 0, critical_path_length: 0,
      error_prone_patterns: 0, performance_risks: 0, maintainability_score: 0
    }
  end

  # --- Extraction Helpers for Function Analysis ---
  defp get_function_head({:def, _, [head | _]}), do: head
  defp get_function_head({:defp, _, [head | _]}), do: head
  defp get_function_head({:defmacro, _, [head | _]}), do: head
  defp get_function_head({:defmacrop, _, [head | _]}), do: head
  defp get_function_head(_), do: nil

  defp get_function_body({_, _, [_, [do: body] | _]}), do: body # for def ... do end
  defp get_function_body({_, _, [_, kw_list]}) when is_list(kw_list), do: Keyword.get(kw_list, :do) # for def ..., do: ...
  defp get_function_body(_), do: nil

  defp get_function_meta({type, meta, _}) when type in [:def, :defp, :defmacro, :defmacrop], do: meta
  defp get_function_meta(_), do: []


  defp extract_variables_from_function(function_ast, function_ast_id_prefix) do
    # Simple version: collect all atoms that look like variables.
    # A proper DFG/SSA would be much more accurate for scopes and versions.
    vars = %{} # {name, scope_id} => VariableData
    scope_counter = 0

    # Helper to create a scope id, could be more sophisticated
    current_scope_id_fn = fn ast_node_for_scope ->
      scope_counter = scope_counter + 1
      "#{function_ast_id_prefix}:scope_#{scope_counter}"
    end

    # This needs a proper traversal that understands lexical scoping.
    # For now, very simplified.
    Macro.postwalk(function_ast, fn
      # Parameter in function head
      ({var_name, meta, nil} = ast_node) when is_atom(var_name) and (context = Keyword.get(meta, :context)) && context != Elixir -> # Parameter
        scope_id = current_scope_id_fn.(function_ast) # Function scope for params
        vars = Map.put_new(vars, {var_name, scope_id}, %VariableData{
          name: var_name, ast_node_id: ElixirScope.ASTRepository.CFGGenerator.get_ast_node_id(meta) || "var_#{var_name}",
          scope_id: scope_id, scope_type: :function,
          line: Keyword.get(meta, :line, 0), column: 0,
          is_parameter: true, is_pinned: false, is_unused: true, # Mark unused initially
          definition_point: %{line: Keyword.get(meta, :line, 0)}, usage_points: []
        })
        ast_node
      # Assignment LHS
      {:=, _, [{var_name, meta, nil} = ast_node, _rhs]} when is_atom(var_name) ->
        scope_id = current_scope_id_fn.(ast_node) # Scope of the assignment
        vars = Map.put(vars, {var_name, scope_id}, %VariableData{
          name: var_name, ast_node_id: ElixirScope.ASTRepository.CFGGenerator.get_ast_node_id(meta) || "var_#{var_name}",
          scope_id: scope_id, scope_type: :block, # Or more specific
          line: Keyword.get(meta, :line, 0), column: 0,
          is_parameter: false, is_pinned: false, is_unused: true,
          definition_point: %{line: Keyword.get(meta, :line, 0)}, usage_points: []
        })
        ast_node
      # Variable Usage
      ({var_name, meta, nil} = ast_node) when is_atom(var_name) and is_nil(Keyword.get(meta, :context)) -> # Usage
        # Find definition in current or parent scope to mark as used. Very complex.
        # For now, just note its existence.
        ast_node
      ast_node ->
        ast_node
    end)
    Map.values(vars)
  end

  defp extract_parameters_from_head(head_ast, function_ast_id_prefix) do
    # head_ast is like {fun_name, meta, args_ast_list} or just args_ast_list for `fn`
    args_ast_list = case head_ast do
      {_name, _meta, args} when is_list(args) -> args
      args when is_list(args) -> args
      _ -> []
    end

    Enum.flat_map(args_ast_list, fn param_ast ->
      # param_ast can be {var, meta, context}, or a pattern e.g. {p1, p2}, %{k:v}
      collect_vars_from_pattern(param_ast, function_ast_id_prefix, :parameter)
    end)
    |> Enum.map(fn var_data -> %{var_data | is_parameter: true} end) # Simplified ParameterData
  end

  defp collect_vars_from_pattern(pattern_ast, scope_id_prefix, scope_type) do
    # Similar to extract_vars_from_pattern in DFGGenerator
    vars = []
    Macro.traverse(pattern_ast, %{}, fn
      ({var_name, meta, nil}=node_ast, acc) when is_atom(var_name) and not Atom.to_string(var_name) =~ ~r"^[A-Z]" and var_name != :_ ->
        var_data = %VariableData{
            name: var_name,
            ast_node_id: ElixirScope.ASTRepository.CFGGenerator.get_ast_node_id(meta) || "var_#{var_name}_#{length(vars)}",
            scope_id: scope_id_prefix, # This needs proper scoping
            scope_type: scope_type,
            line: Keyword.get(meta, :line, 0), column: 0,
            is_parameter: (scope_type == :parameter),
            is_pinned: false, is_unused: true, # Initial assumption
            definition_point: %{line: Keyword.get(meta, :line, 0)},
            usage_points: [],
            metadata: %{pattern_source_ast: node_ast}
          }
        {[var_data | vars], acc}
      (node, acc) -> {node, acc}
    end, fn node, acc -> {node, acc} end)
    |> elem(0) |> Enum.reverse()
  end


  defp extract_function_calls_from_body(body_ast, current_module_name) do
    calls = []
    Macro.postwalk(body_ast, fn
      # Local call: my_fun(...) or just my_fun()
      {fun_name, meta, args_ast_list} = call_ast when is_atom(fun_name) and is_list(args_ast_list) and not Keyword.has_key?(meta, :context) ->
        arity = length(args_ast_list)
        # Simplified CallData
        calls = [%{
          module: nil, # Implies local or imported
          function: fun_name,
          arity: arity,
          args: args_ast_list, # Store AST of args
          line: Keyword.get(meta, :line, 0),
          ast_node_id: ElixirScope.ASTRepository.CFGGenerator.get_ast_node_id(meta),
          type: :local_or_imported
        } | calls]
        call_ast
      # Remote call: MyModule.my_fun(...)
      {{:., _, [module_ast, fun_name]}, meta, args_ast_list} = call_ast when is_atom(fun_name) and is_list(args_ast_list) ->
        module_resolved_name = resolve_module_alias(module_ast, current_module_name) # Needs alias resolution context
        arity = length(args_ast_list)
        calls = [%{
          module: module_resolved_name,
          function: fun_name,
          arity: arity,
          args: args_ast_list,
          line: Keyword.get(meta, :line, 0),
          ast_node_id: ElixirScope.ASTRepository.CFGGenerator.get_ast_node_id(meta),
          type: :remote
        } | calls]
        call_ast
      ast_node ->
        ast_node
    end)
    Enum.reverse(calls)
  end
  defp resolve_module_alias({:__aliases__, _, parts}, _current_mod), do: Module.concat(parts)
  defp resolve_module_alias(atom, _current_mod) when is_atom(atom), do: atom
  defp resolve_module_alias(_, current_mod), do: current_mod # Fallback for unknown alias structure, assume local context

  defp extract_pattern_matches(function_ast) do
    # Traverse for case clauses, fn clauses, function head patterns
    [] # Placeholder for PatternData.t() list
  end

  defp extract_guards_from_clauses(function_ast) do
    # Multi-clause functions: {:def, meta, [{head1_with_guard, body1}, {head2_with_guard, body2}]}
    # Single-clause: {:def, meta, [head_with_guard, body]}
    clauses_asts = case function_ast do
      {_type, _meta, clause_list} when is_list(clause_list) and List.first(clause_list) |> is_tuple() -> clause_list # def with multiple clauses
      {_type, _meta, [head_ast, _body_do_block]} -> [head_ast] # single clause def
      _ -> []
    end

    Enum.flat_map(clauses_asts, fn clause_or_head_ast ->
      # Clause: {{fun_name, meta, args}, guard_list_or_nil, body_do_block}
      # Head: {fun_name, meta, args} or possibly {{fun_name, meta, args}, guard_list_or_nil}
      case clause_or_head_ast do
        # Function head with guards: def my_fun(a) when a > 0 do ...
        # The head is { {name, meta, args}, [when: guard_ast] }
        { {_, _, _}, [when: guard_ast] } -> [guard_ast]
        # For multi-clause functions, each clause is a tuple:
        # { {:fun_name, meta_head, args_head}, meta_clause, body_block }
        # where meta_clause might contain :guard
        { _head, meta_clause, _body } when is_list(meta_clause) ->
          Keyword.get_values(meta_clause, :guard) # Returns list of guards or empty list
        _ -> []
      end
    end)
  end

  defp calculate_function_complexity_metrics(function_ast) do
    # This is a simplified AST-based complexity. True cyclomatic needs CFG.
    decision_points = count_ast_decision_points(function_ast)
    nesting = calculate_ast_nesting(function_ast)
    %ComplexityMetrics{
      cyclomatic_complexity: decision_points + 1,
      nesting_depth: nesting
      # ... other metrics can be approximated or filled by CFG/DFG later
    }
  end
  defp count_ast_decision_points(ast) do
    count = 0
    Macro.traverse(ast, 0, fn
      ({:if, _, _}, acc) -> {nil, acc + 1}
      ({:case, _, _}, acc) -> {nil, acc + 1}
      ({:cond, _, _}, acc) -> {nil, acc + (length(elem(ast,2) |> List.first() |> elem(1)) -1)} # each cond clause except first is a decision
      ({:try, _, clauses}, acc) -> {nil, acc + (Enum.count(clauses, fn c -> Keyword.has_key?(c, :rescue) or Keyword.has_key?(c, :catch) end))}
      # Guards are harder from raw AST without clause separation. Better from CFG or clause analysis.
      (node, acc) -> {node, acc}
    end, fn node, acc -> {node, acc} end)
    |> elem(1)
  end
  defp calculate_ast_nesting(ast) do
    # Max depth of nested control structures (if, case, cond, fn, try)
    # Simplified: max depth of AST itself can be a proxy
    calculate_ast_depth(ast)
  end


  defp extract_clauses_data(function_ast) do
    # For multi-clause functions, extract data per clause
    [] # Placeholder for list of ClauseData.t()
  end

  defp extract_captures(body_ast) do
    # Find variables used in anonymous functions but defined in outer scopes
    [] # Placeholder for list of CaptureData.t()
  end

  defp extract_return_points(body_ast) do
    # Identify all expressions that could be the return value.
    # In Elixir, this is typically the last expression of a block.
    # More complex with explicit `return` or exceptions.
    [] # Placeholder for list of ReturnPoint.t()
  end

  defp calculate_overall_complexity_score(complexity_metrics_struct) do
    # Combine various metrics into a single score
    (complexity_metrics_struct.cyclomatic_complexity || 0) * 0.5 +
    (complexity_metrics_struct.nesting_depth || 0) * 0.3
    # ... add cognitive, etc.
  end

  defp extract_doc_string(function_ast, _module_name) do
    # Search for @doc attribute preceding the function def
    # This requires looking at the module's AST list of expressions.
    # Passed function_ast is usually just the def itself.
    # This function would need more context or be called at module level.
    nil
  end

  defp extract_spec(function_ast, _module_name, _fun_name, _arity) do
    # Similar to extract_doc_string, search for @spec
    nil
  end

  # --- General AST Utilities ---
  defp count_ast_nodes(ast) do
    count = 0
    Macro.traverse(ast, 0, fn _node, acc -> {nil, acc + 1} end, fn node, acc -> {node, acc} end)
    |> elem(1)
  end

  defp calculate_ast_depth(ast) do
    max_depth_seen = 1
    do_calc_depth = fn ast_node, current_depth, acc_fn ->
      max_depth_seen = max(max_depth_seen, current_depth)
      children = case ast_node do
        {_, _, args} when is_list(args) -> args
        {:__block__, _, stmts} -> stmts
        _ -> []
      end
      Enum.each(children, fn child -> if Macro.quoted?(child), do: acc_fn.(child, current_depth + 1, acc_fn) end)
      ast_node # return node for traversal
    end
    do_calc_depth.(ast, 1, do_calc_depth)
    max_depth_seen
  end
end
