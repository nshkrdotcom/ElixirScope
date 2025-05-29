defmodule ElixirScope.ASTRepository.Enhanced.DFGGenerator.DependencyAnalyzer do
  @moduledoc """
  Analyzes dependencies and detects circular references in data flow.
  """

  @doc """
  Gets all dependencies for a variable.
  """
  def get_dependencies(dfg, variable_name) do
    # Find the variable in our variables map
    case find_variable_by_name(dfg, variable_name) do
      nil -> []
      {_key, var_info} ->
        # Extract direct dependencies from the variable's source
        direct_deps = extract_dependent_variables(var_info.source)
        # Get transitive dependencies
        get_transitive_dependencies(dfg, direct_deps, [variable_name])
    end
  end

  @doc """
  Detects circular dependencies in variable assignments.
  """
  def detect_circular_dependencies(state) do
    # Check for circular dependencies in variable assignments
    variables = state.variables

    # Build a dependency graph and check for cycles, but only for variables in the same scope
    dependency_graph = build_dependency_graph_same_scope(variables)

    # Check for cycles using DFS
    case find_cycle_in_graph(dependency_graph) do
      nil -> :ok
      _cycle -> {:error, :circular_dependency}
    end
  end

  @doc """
  Analyzes variable dependency chains.
  """
  def analyze_dependency_chains(state) do
    variables = state.variables

    # Build dependency chains for each variable
    Enum.reduce(variables, %{}, fn {{var_name, _scope}, var_info}, acc ->
      dependencies = extract_dependent_variables(var_info.source)
      chain = build_dependency_chain(variables, var_name, dependencies, [])
      Map.put(acc, to_string(var_name), chain)
    end)
  end

  @doc """
  Finds variables that depend on a given variable.
  """
  def find_dependents(state, target_variable) do
    target_str = to_string(target_variable)

    state.variables
    |> Enum.filter(fn {{_var_name, _scope}, var_info} ->
      dependencies = extract_dependent_variables(var_info.source)
      target_str in dependencies
    end)
    |> Enum.map(fn {{var_name, _scope}, _var_info} -> to_string(var_name) end)
  end

  @doc """
  Calculates dependency depth for variables.
  """
  def calculate_dependency_depth(state) do
    variables = state.variables

    Enum.reduce(variables, %{}, fn {{var_name, _scope}, var_info}, acc ->
      depth = calculate_variable_dependency_depth(variables, var_name, var_info, [])
      Map.put(acc, to_string(var_name), depth)
    end)
  end

  @doc """
  Identifies potential optimization points based on dependencies.
  """
  def identify_optimization_points(state) do
    # Find variables with complex dependency chains
    dependency_chains = analyze_dependency_chains(state)

    complex_chains = dependency_chains
    |> Enum.filter(fn {_var_name, chain} -> length(chain) > 3 end)
    |> Enum.map(fn {var_name, chain} ->
      %{
        type: :complex_dependency_chain,
        variable: var_name,
        chain_length: length(chain),
        suggestion: "Consider simplifying dependency chain"
      }
    end)

    # Find variables with many dependents
    high_usage_vars = find_high_usage_variables(state)

    high_usage_hints = Enum.map(high_usage_vars, fn {var_name, dependent_count} ->
      %{
        type: :high_usage_variable,
        variable: var_name,
        dependent_count: dependent_count,
        suggestion: "Consider caching or memoization"
      }
    end)

    complex_chains ++ high_usage_hints
  end

  # Private helper functions

  # Get transitive dependencies recursively
  defp get_transitive_dependencies(dfg, deps, visited) do
    Enum.reduce(deps, deps, fn dep, acc ->
      if dep in visited do
        acc  # Avoid cycles
      else
        case find_variable_by_name(dfg, dep) do
          nil -> acc
          {_key, var_info} ->
            transitive_deps = extract_dependent_variables(var_info.source)
            new_deps = get_transitive_dependencies(dfg, transitive_deps, [dep | visited])
            (acc ++ new_deps) |> Enum.uniq()
        end
      end
    end)
  end

  # Helper to find variable by name in the DFG
  defp find_variable_by_name(dfg, variable_name) do
    # Look through the variables in the DFG data
    # Since we don't have direct access to the variables map in DFGData,
    # we need to reconstruct dependencies from the nodes
    variable_nodes = dfg.nodes
    |> Enum.filter(fn node ->
      case node do
        %{type: :variable_definition, variable: %{name: ^variable_name}} -> true
        %{type: :variable_definition, metadata: %{variable: var}} when is_atom(var) ->
          to_string(var) == variable_name
        %{type: :variable_definition, metadata: %{variable: var}} when is_binary(var) ->
          var == variable_name
        _ -> false
      end
    end)

    case variable_nodes do
      [node | _] ->
        # Extract source from node metadata
        source = case node.metadata do
          %{source: source_expr} -> source_expr
          _ -> nil
        end
        {variable_name, %{source: source}}
      [] -> nil
    end
  end

  defp build_dependency_graph_same_scope(variables) do
    # Group variables by scope first
    variables_by_scope = Enum.group_by(variables, fn {{_var_name, scope}, _var_info} -> scope end)

    # Only check for cycles within the same scope
    Enum.reduce(variables_by_scope, %{}, fn {_scope, scope_variables}, graph ->
      scope_graph = Enum.reduce(scope_variables, %{}, fn {{var_name, _scope}, var_info}, scope_acc ->
        var_name_str = to_string(var_name)
        dependencies = extract_dependent_variables(var_info.source)

        # Filter out self-dependencies for mutations
        # If a variable depends on itself, it's likely a mutation (x = x + 1)
        # rather than a true circular dependency
        filtered_deps = case var_info.type do
          :assignment ->
            # For assignments, exclude self-dependencies as they represent mutations
            Enum.filter(dependencies, fn dep -> dep != var_name_str end)
          :parameter ->
            # Parameters don't create circular dependencies
            []
          _ ->
            # For other types, keep dependencies but filter carefully
            Enum.filter(dependencies, fn dep -> dep != var_name_str end)
        end

        # Only include dependencies that are in the same scope
        # This excludes closure captures which reference outer scope variables
        same_scope_deps = Enum.filter(filtered_deps, fn dep ->
          Enum.any?(scope_variables, fn {{other_var, _}, _} -> to_string(other_var) == dep end)
        end)

        Map.put(scope_acc, var_name_str, same_scope_deps)
      end)

      Map.merge(graph, scope_graph)
    end)
  end

  defp find_cycle_in_graph(graph) do
    # Use DFS to detect cycles
    result = Enum.find_value(Map.keys(graph), fn start_node ->
      case dfs_find_cycle(graph, start_node, [], []) do
        nil ->
          nil
        cycle ->
          cycle
      end
    end)

    result
  end

  defp dfs_find_cycle(graph, current, path, visited) do
    cond do
      current in path ->
        # Found a cycle
        cycle = [current | path]
        cycle

      current in visited ->
        # Already visited this node in another path
        nil

      true ->
        # Continue DFS
        new_path = [current | path]
        new_visited = [current | visited]

        dependencies = Map.get(graph, current, [])

        Enum.find_value(dependencies, fn dep ->
          dfs_find_cycle(graph, dep, new_path, new_visited)
        end)
    end
  end

  # Extract variables that an expression depends on
  defp extract_dependent_variables(expr) do
    case expr do
      {_op, _, args} when is_list(args) and length(args) > 0 ->
        # Extract variables from arguments only
        Enum.flat_map(args, &extract_dependent_variables/1)
      {var_name, _, nil} when is_atom(var_name) ->
        # Only treat as variable if it's not a known function/operator and not a parameter reference
        if is_variable_name?(var_name) and not is_parameter_reference?(var_name) do
          [to_string(var_name)]
        else
          []
        end
      {var_name, _, _context} when is_atom(var_name) ->
        # Only treat as variable if it's not a known function/operator and not a parameter reference
        if is_variable_name?(var_name) and not is_parameter_reference?(var_name) do
          [to_string(var_name)]
        else
          []
        end
      # Special handling for tuple access and other destructuring patterns
      {:tuple_access, _source, _index} -> []
      {:map_access, _source, _key} -> []
      {:list_head, _source} -> []
      {:list_tail, _source} -> []
      {:keyword_access, _source, _key} -> []
      _ ->
        []
    end
  end

  # Helper to identify parameter references that shouldn't be treated as dependencies
  defp is_parameter_reference?(atom) do
    # Common parameter names that appear in AST contexts
    atom in [:tuple, :list, :map, :binary, :atom, :integer, :float, :string]
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

  defp build_dependency_chain(variables, var_name, dependencies, visited) do
    if to_string(var_name) in visited do
      visited  # Avoid infinite recursion
    else
      new_visited = [to_string(var_name) | visited]

      Enum.reduce(dependencies, dependencies, fn dep, acc ->
        # Find the variable info for this dependency
        dep_var_info = Enum.find_value(variables, fn {{dep_var_name, _scope}, var_info} ->
          if to_string(dep_var_name) == dep, do: var_info, else: nil
        end)

        case dep_var_info do
          nil -> acc
          var_info ->
            sub_deps = extract_dependent_variables(var_info.source)
            chain = build_dependency_chain(variables, dep, sub_deps, new_visited)
            (acc ++ chain) |> Enum.uniq()
        end
      end)
    end
  end

  defp calculate_variable_dependency_depth(variables, var_name, var_info, visited) do
    if to_string(var_name) in visited do
      0  # Avoid infinite recursion
    else
      dependencies = extract_dependent_variables(var_info.source)

      if Enum.empty?(dependencies) do
        1  # Base case: no dependencies
      else
        new_visited = [to_string(var_name) | visited]

        max_depth = dependencies
        |> Enum.map(fn dep ->
          dep_var_info = Enum.find_value(variables, fn {{dep_var_name, _scope}, var_info} ->
            if to_string(dep_var_name) == dep, do: var_info, else: nil
          end)

          case dep_var_info do
            nil -> 1
            var_info -> calculate_variable_dependency_depth(variables, dep, var_info, new_visited)
          end
        end)
        |> Enum.max(fn -> 1 end)

        max_depth + 1
      end
    end
  end

  defp find_high_usage_variables(state) do
    # Count how many variables depend on each variable
    dependency_counts = Enum.reduce(state.variables, %{}, fn {{_var_name, _scope}, var_info}, acc ->
      dependencies = extract_dependent_variables(var_info.source)

      Enum.reduce(dependencies, acc, fn dep, inner_acc ->
        Map.update(inner_acc, dep, 1, &(&1 + 1))
      end)
    end)

    # Filter to variables with high usage (more than 2 dependents)
    dependency_counts
    |> Enum.filter(fn {_var_name, count} -> count > 2 end)
    |> Enum.sort_by(fn {_var_name, count} -> count end, :desc)
  end
end
