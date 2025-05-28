# === 5-cpg_builder.ex ===
defmodule ElixirScope.ASTRepository.CPGBuilder do
  @moduledoc """
  Builds a Code Property Graph (CPG) by unifying AST, CFG, and DFG information.
  The CPG provides a rich, queryable representation of code for advanced analysis.
  """

  alias ElixirScope.ASTRepository.{
    EnhancedFunctionData,
    CFGData, # CFGNode, CFGEdge are defined within CFGData module in previous files
    DFGData, # Definition, Use, DataFlow, PhiNode, VariableVersion are in DFGData
    # The CPG specific structs:
    CPGData,
    CPGNode,
    CPGEdge
  }

  # Assuming CPGData, CPGNode, CPGEdge are defined as per
  # AST_REPOSITORY_DATA_SCHEMAS_AND_SPECIFICATIONS.md
  # For brevity in this generated file, we'll assume they are accessible.
  # In a real project, they would be in e.g. `lib/elixir_scope/ast_repository/schemas/cpg_data.ex`

  @doc """
  Builds a Code Property Graph for a given function.

  The CPG unifies AST structure, control flow (CFG), and data flow (DFG)
  into a single graph.

  Nodes in the CPG are primarily derived from AST nodes, augmented with
  CFG and DFG information. Synthetic nodes may be created for elements
  like Phi functions that don't directly correspond to AST nodes.
  """
  @spec build_cpg(EnhancedFunctionData.t(), keyword()) ::
          {:ok, CPGData.t()} | {:error, term()}
  def build_cpg(%EnhancedFunctionData{} = function_data, _opts \\ []) do
    try do
      # Initialize CPG state
      cpg_state = %{
        nodes: %{}, # %{cpg_node_id => CPGNode.t()}
        edges: [],  # [CPGEdge.t()]
        node_mappings: %{ast: %{}, cfg: %{}, dfg_defs: %{}, dfg_uses: %{}, dfg_phis: %{}}, # ast_id/cfg_id/dfg_id => cpg_id
        next_cpg_node_id_counter: 0,
        function_key: {function_data.module_name, function_data.function_name, function_data.arity}
      }

      # Phase 1: Create CPG nodes from AST nodes and build AST edges
      {cpg_state, ast_root_cpg_node_id} = process_ast_to_cpg_nodes(function_data.ast, nil, cpg_state)

      # Phase 2: Overlay CFG information
      cpg_state = process_cfg_to_cpg_edges(function_data.control_flow_graph, cpg_state)

      # Phase 3: Overlay DFG information (including Phi nodes)
      cpg_state = process_dfg_to_cpg_elements(function_data.data_flow_graph, cpg_state)

      # Phase 4: Create inter-procedural call edges (simplified for now)
      cpg_state = process_call_edges(function_data, cpg_state)

      # Phase 5: Build query indexes (basic example)
      query_indexes = build_basic_query_indexes(cpg_state.nodes)

      final_cpg = %CPGData{
        function_key: cpg_state.function_key,
        nodes: cpg_state.nodes,
        edges: cpg_state.edges,
        node_mappings: cpg_state.node_mappings,
        query_indexes: query_indexes,
        metadata: %{
          source_file: function_data.file_path,
          ast_node_count: map_size(cpg_state.node_mappings.ast), # Number of AST nodes mapped
          cfg_node_count: map_size(cpg_state.node_mappings.cfg),
          dfg_elements_count: map_size(cpg_state.node_mappings.dfg_defs) + map_size(cpg_state.node_mappings.dfg_uses)
        }
      }
      {:ok, final_cpg}
    rescue
      error -> {:error, {:cpg_build_failed, error, __STACKTRACE__}}
    end
  end


  # --- Phase 1: AST to CPG Nodes & Edges ---
  defp process_ast_to_cpg_nodes(ast_node, parent_cpg_node_id, cpg_state) do
    # Generate a CPG node for the current AST node
    {cpg_node, cpg_state} = create_cpg_node_from_ast(ast_node, cpg_state)
    current_cpg_node_id = cpg_node.id

    # Add AST edge if there's a parent
    cpg_state = if parent_cpg_node_id do
      ast_edge = %CPGEdge{
        from_node_id: parent_cpg_node_id,
        to_node_id: current_cpg_node_id,
        type: :ast_child,
        label: "child"
      }
      %{cpg_state | edges: [ast_edge | cpg_state.edges]}
    else
      cpg_state # Root AST node for this function/traversal
    end

    # Recursively process children of the AST node
    # Macro.traverse/4 can be used here for more robust traversal.
    # Simplified traversal for common Elixir AST structure:
    children_asts = case ast_node do
      {_op, _meta, args} when is_list(args) -> args
      {:__block__, _meta, stmts} -> stmts
      # Handle other specific AST structures like case, if, fn, etc.
      # For clauses like {:->, _, [pattern, body]}, both pattern and body are children.
      {:->, _meta, [p, b]} -> [p, b]
      # Default: no children to traverse further for CPG structure (leaf or opaque)
      _ -> []
    end

    cpg_state_after_children =
      Enum.reduce(children_asts, cpg_state, fn child_ast, acc_state ->
        # Check if child_ast is itself a quoted expression (node) or a literal
        if Macro.quoted?(child_ast) do
          {state_after_child, _child_id} = process_ast_to_cpg_nodes(child_ast, current_cpg_node_id, acc_state)
          state_after_child
        else
          # Literal or non-node element, potentially add as property to parent cpg_node
          acc_state
        end
      end)

    {cpg_state_after_children, current_cpg_node_id}
  end

  defp create_cpg_node_from_ast(ast_node, cpg_state) do
    ast_node_id_attr = ElixirScope.ASTRepository.CFGGenerator.get_ast_node_id(extract_meta(ast_node)) # Reuse helper
    line = ElixirScope.ASTRepository.CFGGenerator.get_line_number(extract_meta(ast_node)) # Reuse helper

    cpg_node_id = generate_cpg_node_id("ast", ast_node_id_attr || "node_#{cpg_state.next_cpg_node_id_counter}", cpg_state)
    label = ast_label(ast_node)

    cpg_node = %CPGNode{
      id: cpg_node_id,
      type: :ast, # Primary type
      label: label,
      ast_data: %{original_ast: ast_node, kind: Macro.type(ast_node)}, # Store actual AST snippet or its type
      cfg_data: nil, # To be populated later
      dfg_data: nil, # To be populated later
      line: line,
      source_text: Macro.to_string(ast_node) |> String.slice(0, 100), # Truncate for brevity
      metadata: %{ast_node_id_attr: ast_node_id_attr}
    }

    updated_mappings = Map.put(cpg_state.node_mappings.ast, ast_node_id_attr, cpg_node_id)
    new_cpg_state = %{cpg_state |
      nodes: Map.put(cpg_state.nodes, cpg_node_id, cpg_node),
      node_mappings: %{cpg_state.node_mappings | ast: updated_mappings},
      next_cpg_node_id_counter: cpg_state.next_cpg_node_id_counter + 1
    }
    {cpg_node, new_cpg_state}
  end

  defp ast_label(ast_node) do
    case ast_node do
      {op, _meta, _args} when is_atom(op) -> Atom.to_string(op)
      {var, _meta, context} when is_atom(var) and not is_nil(context) -> "var:#{var}"
      {alias_name, _, _} when is_atom(alias_name) and Atom.to_string(alias_name) =~ ~r"^[A-Z]" -> "alias:#{alias_name}"
      n when is_atom(n) or is_number(n) or is_binary(n) -> "literal:#{inspect(n)}"
      other -> "node:#{Macro.type(other)}"
    end
  end

  defp extract_meta({_op, meta, _args}) when is_list(meta), do: meta
  defp extract_meta({_var, meta, _context}) when is_list(meta), do: meta
  defp extract_meta(_), do: []

  # --- Phase 2: CFG to CPG Edges ---
  defp process_cfg_to_cpg_edges(%CFGData{} = cfg_data, cpg_state) do
    # First, ensure all CFG nodes have corresponding CPG nodes or mappings
    cpg_state_with_cfg_nodes =
      Enum.reduce(Map.values(cfg_data.nodes), cpg_state, fn cfg_node_struct, acc_state ->
        # Try to find existing CPG node via AST ID mapping
        mapped_cpg_node_id = Map.get(acc_state.node_mappings.ast, cfg_node_struct.ast_node_id)

        if mapped_cpg_node_id && acc_state.nodes[mapped_cpg_node_id] do
          # Augment existing CPG node (which was from AST)
          existing_cpg_node = acc_state.nodes[mapped_cpg_node_id]
          updated_cpg_node = %{existing_cpg_node |
            cfg_data: (existing_cpg_node.cfg_data || %{}) |> Map.merge(%{type: cfg_node_struct.type, id: cfg_node_struct.id}),
            label: existing_cpg_node.label <> " (CFG:#{cfg_node_struct.type})" # Example augmentation
          }
          new_nodes = Map.put(acc_state.nodes, mapped_cpg_node_id, updated_cpg_node)
          new_mappings_cfg = Map.put(acc_state.node_mappings.cfg, cfg_node_struct.id, mapped_cpg_node_id)
          %{acc_state | nodes: new_nodes, node_mappings: %{acc_state.node_mappings | cfg: new_mappings_cfg}}
        else
          # CFG node doesn't map to an existing AST-derived CPG node (e.g. synthetic CFG node like a merge)
          # Create a new CPG node for it
          {new_cpg_node_for_cfg, new_acc_state} = create_cpg_node_from_cfg_node(cfg_node_struct, acc_state)
          new_mappings_cfg = Map.put(new_acc_state.node_mappings.cfg, cfg_node_struct.id, new_cpg_node_for_cfg.id)
          %{new_acc_state | node_mappings: %{new_acc_state.node_mappings | cfg: new_mappings_cfg}}
        end
      end)

    # Then, create CPG edges from CFG edges
    new_cfg_cpg_edges = Enum.map(cfg_data.edges, fn cfg_edge_struct ->
      from_cpg_id = Map.get(cpg_state_with_cfg_nodes.node_mappings.cfg, cfg_edge_struct.from_node_id)
      to_cpg_id = Map.get(cpg_state_with_cfg_nodes.node_mappings.cfg, cfg_edge_struct.to_node_id)

      if from_cpg_id && to_cpg_id do
        %CPGEdge{
          from_node_id: from_cpg_id,
          to_node_id: to_cpg_id,
          type: cfg_edge_type_to_cpg_type(cfg_edge_struct.type),
          label: cfg_edge_struct.condition || Atom.to_string(cfg_edge_struct.type),
          properties: %{condition: cfg_edge_struct.condition, probability: cfg_edge_struct.probability}
        }
      else
        # Should log a warning: CFG edge connects unmapped nodes
        nil
      end
    end) |> Enum.reject(&is_nil/1)

    %{cpg_state_with_cfg_nodes | edges: new_cfg_cpg_edges ++ cpg_state_with_cfg_nodes.edges}
  end

  defp create_cpg_node_from_cfg_node(cfg_node_struct, cpg_state) do
    cpg_node_id = generate_cpg_node_id("cfg", cfg_node_struct.id, cpg_state)
    cpg_node = %CPGNode{
      id: cpg_node_id,
      type: :cfg, # Or :synthetic_cfg
      label: "CFG:#{cfg_node_struct.type}:#{cfg_node_struct.id}",
      ast_data: if ast_id = cfg_node_struct.ast_node_id, do: %{original_ast_id: ast_id}, else: nil,
      cfg_data: %{type: cfg_node_struct.type, id: cfg_node_struct.id, expression: cfg_node_struct.expression},
      line: cfg_node_struct.line,
      metadata: %{}
    }
    new_cpg_state = %{cpg_state |
      nodes: Map.put(cpg_state.nodes, cpg_node_id, cpg_node),
      next_cpg_node_id_counter: cpg_state.next_cpg_node_id_counter + 1
    }
    {cpg_node, new_cpg_state}
  end

  defp cfg_edge_type_to_cpg_type(cfg_type) do
    case cfg_type do
      :sequential -> :cfg_flow
      :conditional -> :cfg_conditional # Could be split based on condition if known
      :pattern_match -> :cfg_pattern_match
      :guard_success -> :cfg_guard_true
      :guard_failure -> :cfg_guard_false
      :exception -> :cfg_exception_flow
      :loop_back -> :cfg_loop_back
      :loop_exit -> :cfg_loop_exit
      _ -> :cfg_flow # Default
    end
  end

  # --- Phase 3: DFG to CPG Elements (Nodes & Edges) ---
  defp process_dfg_to_cpg_elements(%DFGData{} = dfg_data, cpg_state) do
    # Process Definitions: Augment existing CPG nodes or create new ones
    cpg_state_after_defs =
      Enum.reduce(dfg_data.definitions, cpg_state, fn %{variable: var_ver, ast_node_id: def_ast_id} = dfg_def, acc_state ->
        mapped_cpg_node_id = Map.get(acc_state.node_mappings.ast, def_ast_id)
        if mapped_cpg_node_id && acc_state.nodes[mapped_cpg_node_id] do
          # Augment existing CPG node
          cpg_node = acc_state.nodes[mapped_cpg_node_id]
          dfg_info = Map.get(cpg_node.dfg_data, :definitions, []) ++ [dfg_def]
          updated_cpg_node = %{cpg_node | dfg_data: Map.put(cpg_node.dfg_data || %{}, :definitions, dfg_info)}
          new_nodes = Map.put(acc_state.nodes, mapped_cpg_node_id, updated_cpg_node)
          new_mappings_dfg = Map.put(acc_state.node_mappings.dfg_defs, {var_ver.ssa_name, def_ast_id}, mapped_cpg_node_id)
          %{acc_state | nodes: new_nodes, node_mappings: %{acc_state.node_mappings | dfg_defs: new_mappings_dfg}}
        else
          # Potentially create a new CPG node if the definition point is not a primary AST node (e.g. implicit param def)
          # For now, assume definitions map to existing AST CPG nodes.
          acc_state
        end
      end)

    # Process Uses: Augment existing CPG nodes
    cpg_state_after_uses =
      Enum.reduce(dfg_data.uses, cpg_state_after_defs, fn %{variable: var_ver, ast_node_id: use_ast_id} = dfg_use, acc_state ->
        mapped_cpg_node_id = Map.get(acc_state.node_mappings.ast, use_ast_id)
        if mapped_cpg_node_id && acc_state.nodes[mapped_cpg_node_id] do
          cpg_node = acc_state.nodes[mapped_cpg_node_id]
          dfg_info = Map.get(cpg_node.dfg_data, :uses, []) ++ [dfg_use]
          updated_cpg_node = %{cpg_node | dfg_data: Map.put(cpg_node.dfg_data || %{}, :uses, dfg_info)}
          new_nodes = Map.put(acc_state.nodes, mapped_cpg_node_id, updated_cpg_node)
          new_mappings_dfg = Map.put(acc_state.node_mappings.dfg_uses, {var_ver.ssa_name, use_ast_id}, mapped_cpg_node_id)
          %{acc_state | nodes: new_nodes, node_mappings: %{acc_state.node_mappings | dfg_uses: new_mappings_dfg}}
        else
          acc_state
        end
      end)

    # Process DataFlow edges: Create CPG edges
    new_dfg_cpg_edges = Enum.map(dfg_data.data_flows, fn %{from_definition: dfg_def, to_use: dfg_use, flow_type: dfg_flow_type} = _df_struct ->
      # dfg_def is a Definition struct, to_use is a Use struct
      # Need to map these to CPG node IDs
      from_cpg_id = Map.get(cpg_state_after_uses.node_mappings.dfg_defs, {dfg_def.variable.ssa_name, dfg_def.ast_node_id})
      to_cpg_id = Map.get(cpg_state_after_uses.node_mappings.dfg_uses, {dfg_use.variable.ssa_name, dfg_use.ast_node_id})

      if from_cpg_id && to_cpg_id do
        %CPGEdge{
          from_node_id: from_cpg_id,
          to_node_id: to_cpg_id,
          type: :dfg_reaches, # or :dfg_def_use
          label: "dataflow:#{dfg_def.variable.ssa_name}",
          properties: %{variable: dfg_def.variable.ssa_name, flow_type: dfg_flow_type}
        }
      else
        nil
      end
    end) |> Enum.reject(&is_nil/1)

    cpg_state_after_flows = %{cpg_state_after_uses | edges: new_dfg_cpg_edges ++ cpg_state_after_uses.edges}

    # Process PhiNodes: Create synthetic CPG nodes and edges
    Enum.reduce(dfg_data.phi_nodes, cpg_state_after_flows, fn %{target_variable: target_var_ver, source_variables: source_var_vers, merge_point: merge_ast_id} = phi_node_struct, acc_state ->
      # Create a synthetic CPG node for the Phi function
      {phi_cpg_node, state_after_phi_node} = create_cpg_node_for_phi(phi_node_struct, merge_ast_id, acc_state)
      phi_cpg_id = phi_cpg_node.id

      # Edges from source variable definitions to Phi node
      phi_source_edges = Enum.map(source_var_vers, fn source_var_ver ->
        # Find CPG node for the definition of source_var_ver
        source_def_cpg_id = Map.get(state_after_phi_node.node_mappings.dfg_defs, {source_var_ver.ssa_name, source_var_ver.definition_node})
        if source_def_cpg_id do
          %CPGEdge{from_node_id: source_def_cpg_id, to_node_id: phi_cpg_id, type: :dfg_phi_input, label: "phi_in:#{source_var_ver.ssa_name}"}
        else nil end
      end) |> Enum.reject(&is_nil/1)

      # Edge from Phi node to the CPG node where the target_variable is "defined" (the merge point AST node)
      target_def_ast_node_cpg_id = Map.get(state_after_phi_node.node_mappings.ast, merge_ast_id) # Phi result is conceptually at merge point
      phi_target_edge = if target_def_ast_node_cpg_id do
        # Also, the target_var_ver should have a definition. Map that definition to a CPG node.
        # The target_var_ver is a new definition.
        target_var_def_cpg_id = Map.get(state_after_phi_node.node_mappings.dfg_defs, {target_var_ver.ssa_name, target_var_ver.definition_node}) || target_def_ast_node_cpg_id

        [%CPGEdge{from_node_id: phi_cpg_id, to_node_id: target_var_def_cpg_id, type: :dfg_phi_output, label: "phi_out:#{target_var_ver.ssa_name}"}]
      else [] end

      %{state_after_phi_node | edges: phi_source_edges ++ phi_target_edge ++ state_after_phi_node.edges}
    end)
  end

  defp create_cpg_node_for_phi(phi_node_struct, merge_ast_id, cpg_state) do
    phi_cpg_id_base = phi_node_struct.target_variable.ssa_name
    cpg_node_id = generate_cpg_node_id("phi", phi_cpg_id_base, cpg_state)
    cpg_node = %CPGNode{
      id: cpg_node_id,
      type: :synthetic, # Or :dfg_phi
      label: "Φ(#{phi_node_struct.target_variable.name})",
      ast_data: %{merge_point_ast_id: merge_ast_id},
      dfg_data: %{phi_info: phi_node_struct},
      metadata: %{comment: "Phi function"}
    }
    # Add mapping for this phi node if needed, e.g., for its target variable definition
    new_mappings_dfg_phis = Map.put(cpg_state.node_mappings.dfg_phis, phi_node_struct.target_variable.ssa_name, cpg_node_id)

    new_cpg_state = %{cpg_state |
      nodes: Map.put(cpg_state.nodes, cpg_node_id, cpg_node),
      node_mappings: %{cpg_state.node_mappings | dfg_phis: new_mappings_dfg_phis},
      next_cpg_node_id_counter: cpg_state.next_cpg_node_id_counter + 1
    }
    {cpg_node, new_cpg_state}
  end

  # --- Phase 4: Call Edges ---
  defp process_call_edges(%EnhancedFunctionData{calls: function_calls_data_list} = _f_data, cpg_state) do
    # function_calls_data_list is from EnhancedFunctionData, assumed to be a list of CallData structs
    # CallData might have {caller_ast_node_id, target_mfa, args_ast_node_ids}
    new_call_edges = Enum.map(function_calls_data_list || [], fn call_data_item ->
      # Assuming call_data_item is a map like %{caller_node_id: "ast_id_of_call_expr", target: {M,F,A}, ...}
      caller_cpg_node_id = Map.get(cpg_state.node_mappings.ast, call_data_item.caller_node_id)

      if caller_cpg_node_id do
        target_mfa_string = "#{call_data_item.target_module}.#{call_data_item.target_function}/#{call_data_item.target_arity}"
        # We don't have the CPG ID of the target function here, so edge points to a symbolic target.
        # A later linking phase could resolve these.
        %CPGEdge{
          from_node_id: caller_cpg_node_id,
          to_node_id: "func_target:#{target_mfa_string}", # Symbolic ID for target
          type: :call_edge,
          label: "calls #{target_mfa_string}",
          properties: %{target_mfa: call_data_item.target}
        }
      else
        nil
      end
    end) |> Enum.reject(&is_nil/1)
    %{cpg_state | edges: new_call_edges ++ cpg_state.edges}
  end

  # --- Phase 5: Query Indexes ---
  defp build_basic_query_indexes(cpg_nodes_map) do
    nodes_by_type = cpg_nodes_map
                    |> Map.values()
                    |> Enum.group_by(&(&1.type), &(&1.id))

    nodes_by_label_prefix = cpg_nodes_map
                            |> Map.values()
                            |> Enum.group_by(fn node -> String.split(node.label || "", ":") |> List.first() end, &(&1.id))
    %{
      by_type: nodes_by_type,
      by_label_prefix: nodes_by_label_prefix
      # More sophisticated indexes can be added, e.g., by line number ranges, specific properties
    }
  end

  # --- Utility ---
  defp generate_cpg_node_id(type_prefix, original_id_suffix, cpg_state) do
    func_prefix = cpg_state.function_key |> Tuple.to_list() |> Enum.join("_")
    # Ensure original_id_suffix is string and simple
    safe_suffix = to_string(original_id_suffix) |> String.replace(~r/[^A-Za-z0-9_-]/, "_")
    "cpg_#{func_prefix}_#{type_prefix}_#{safe_suffix}_#{cpg_state.next_cpg_node_id_counter}"
  end

end
