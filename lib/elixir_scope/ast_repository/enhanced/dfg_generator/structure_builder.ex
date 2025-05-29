defmodule ElixirScope.ASTRepository.Enhanced.DFGGenerator.StructureBuilder do
  @moduledoc """
  Builds the final DFG data structure from analyzed state.
  """

  alias ElixirScope.ASTRepository.Enhanced.DFGData
  alias ElixirScope.ASTRepository.Enhanced.DFGGenerator.{
    VariableTracker,
    OptimizationAnalyzer
  }

  @doc """
  Builds the final DFG data structure.
  """
  def build_dfg_data(final_state, ast, phi_nodes, optimization_hints) do
    # Create analysis results
    analysis_results = build_analysis_results(final_state, phi_nodes, optimization_hints)

    # Create DFG data structure
    %DFGData{
      # Core data
      variables: VariableTracker.extract_variable_names_list(final_state.variables),
      definitions: extract_definitions(final_state),
      uses: extract_uses(final_state),
      scopes: extract_scopes(final_state),
      data_flows: extract_data_flows(final_state),
      function_key: extract_function_key(ast),
      analysis_results: analysis_results,

      # Metadata
      metadata: %{
        generation_time: System.monotonic_time(:millisecond),
        generator_version: "1.0.0-modular",
        note: "Refactored modular implementation"
      },

      # Populate fields expected by tests
      nodes: Map.values(final_state.nodes),  # List for Enum.filter compatibility
      nodes_map: final_state.nodes,          # Map for map_size compatibility
      edges: final_state.edges,
      mutations: final_state.mutations,
      phi_nodes: phi_nodes,
      complexity_score: analysis_results.complexity_score,
      variable_lifetimes: VariableTracker.calculate_variable_lifetimes(final_state.variables),
      unused_variables: final_state.unused_variables,
      shadowed_variables: final_state.shadowing_info,  # Use collected shadowing info
      captured_variables: VariableTracker.detect_captured_variables(final_state),
      optimization_hints: optimization_hints,
      fan_in: OptimizationAnalyzer.calculate_complexity_metrics(final_state).fan_in,
      fan_out: OptimizationAnalyzer.calculate_complexity_metrics(final_state).fan_out,
      depth: OptimizationAnalyzer.calculate_complexity_metrics(final_state).depth,
      width: OptimizationAnalyzer.calculate_complexity_metrics(final_state).width,
      data_flow_complexity: OptimizationAnalyzer.calculate_complexity_metrics(final_state).data_flow_complexity,
      variable_complexity: OptimizationAnalyzer.calculate_complexity_metrics(final_state).variable_complexity
    }
  end

  @doc """
  Extracts function key from AST.
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

  # Private helper functions

  defp build_analysis_results(state, phi_nodes, optimization_hints) do
    complexity_metrics = OptimizationAnalyzer.calculate_complexity_metrics(state)

    %{
      complexity_score: complexity_metrics.data_flow_complexity,
      variable_count: map_size(state.variables),
      definition_count: count_definitions(state),
      use_count: count_uses(state),
      flow_count: length(state.edges),
      phi_count: length(phi_nodes),
      optimization_opportunities: optimization_hints,
      warnings: generate_warnings(state)
    }
  end

  defp extract_definitions(state) do
    state.nodes
    |> Map.values()
    |> Enum.filter(fn node -> node.type == :variable_definition end)
    |> Enum.map(&convert_node_to_definition/1)
  end

  defp extract_uses(state) do
    state.nodes
    |> Map.values()
    |> Enum.filter(fn node -> node.type in [:variable_reference, :variable_use] end)
    |> Enum.map(&convert_node_to_use/1)
  end

  defp extract_scopes(state) do
    # Extract scope information from variables
    scopes = state.variables
    |> Enum.map(fn {{_var_name, scope}, _var_info} -> scope end)
    |> Enum.uniq()

    # Convert to scope map
    scopes
    |> Enum.with_index()
    |> Enum.into(%{}, fn {scope, index} ->
      {scope_to_string(scope), %{
        id: scope_to_string(scope),
        type: extract_scope_type(scope),
        parent: extract_parent_scope(scope),
        variables: extract_scope_variables(state, scope),
        depth: calculate_scope_depth(scope)
      }}
    end)
  end

  defp extract_data_flows(state) do
    state.edges
    |> Enum.map(fn edge ->
      %{
        from: edge.from_node,
        to: edge.to_node,
        type: edge.type,
        label: edge.label,
        metadata: edge.metadata
      }
    end)
  end

  defp count_definitions(state) do
    state.nodes
    |> Map.values()
    |> Enum.count(fn node -> node.type == :variable_definition end)
  end

  defp count_uses(state) do
    state.variables
    |> Enum.map(fn {{_var_name, _scope}, var_info} -> length(var_info.uses) end)
    |> Enum.sum()
  end

  defp generate_warnings(state) do
    warnings = []

    # Add warnings for unused variables
    warnings = if length(state.unused_variables) > 0 do
      unused_warning = %{
        type: :unused_variables,
        message: "Found #{length(state.unused_variables)} unused variables",
        variables: state.unused_variables
      }
      [unused_warning | warnings]
    else
      warnings
    end

    # Add warnings for shadowed variables
    warnings = if length(state.shadowing_info) > 0 do
      shadow_warning = %{
        type: :variable_shadowing,
        message: "Found #{length(state.shadowing_info)} shadowed variables",
        count: length(state.shadowing_info)
      }
      [shadow_warning | warnings]
    else
      warnings
    end

    # Add warnings for potential mutations
    warnings = if length(state.mutations) > 0 do
      mutation_warning = %{
        type: :variable_mutations,
        message: "Found #{length(state.mutations)} variable mutations",
        count: length(state.mutations)
      }
      [mutation_warning | warnings]
    else
      warnings
    end

    warnings
  end

  defp convert_node_to_definition(node) do
    %{
      id: node.id,
      variable: extract_variable_name_from_node(node),
      line: node.line,
      type: extract_definition_type_from_node(node),
      scope: extract_scope_from_node(node)
    }
  end

  defp convert_node_to_use(node) do
    %{
      id: node.id,
      variable: extract_variable_name_from_node(node),
      line: node.line,
      type: :use,
      scope: extract_scope_from_node(node)
    }
  end

  defp extract_variable_name_from_node(node) do
    case node.variable do
      %{name: name} -> name
      nil ->
        case node.metadata do
          %{variable: var_name} -> to_string(var_name)
          _ -> "unknown"
        end
    end
  end

  defp extract_definition_type_from_node(node) do
    case node.metadata do
      %{definition_type: type} -> type
      _ -> :unknown
    end
  end

  defp extract_scope_from_node(node) do
    case node.metadata do
      %{scope_id: scope_id} -> scope_id
      _ -> "global"
    end
  end

  defp scope_to_string({:global, _id}), do: "global"
  defp scope_to_string({type, _id}), do: to_string(type)
  defp scope_to_string(:global), do: "global"
  defp scope_to_string(other), do: to_string(other)

  defp extract_scope_type(scope) do
    case scope do
      :global -> :global
      {type, _id} -> type
      _ -> :unknown
    end
  end

  defp extract_parent_scope(_scope) do
    # Simplified parent scope extraction
    "global"
  end

  defp extract_scope_variables(state, scope) do
    state.variables
    |> Enum.filter(fn {{_var_name, var_scope}, _var_info} -> var_scope == scope end)
    |> Enum.map(fn {{var_name, _scope}, _var_info} -> to_string(var_name) end)
  end

  defp calculate_scope_depth(scope) do
    case scope do
      :global -> 0
      {_type, _id} -> 1  # Simplified depth calculation
      _ -> 0
    end
  end
end
