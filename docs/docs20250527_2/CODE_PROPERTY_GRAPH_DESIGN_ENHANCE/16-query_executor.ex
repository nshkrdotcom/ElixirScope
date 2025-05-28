defmodule ElixirScope.ASTRepository.QueryExecutor do
  @moduledoc """
  Executes query specifications against the AST Repository.

  This module takes a query built by `QueryBuilder` and interacts with
  `ASTRepository.Repository` (and its underlying ETS tables) to fetch,
  filter, sort, and limit data according to the query.
  """

  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.ASTRepository.QueryBuilder # For @type ast_repo_query_spec

  # For direct ETS operations if needed, though ideally Repository API is used.
  # alias ElixirScope.ASTRepository.Repository, as: RepoETS # Access to table names

  @doc """
  Executes a prepared query specification against the AST Repository.
  """
  @spec execute_query(query_spec :: ElixirScope.ASTRepository.QueryBuilder.ast_repo_query_spec(), repo_pid :: pid() | atom()) ::
          {:ok, results :: list()} | {:error, term()}
  def execute_query(
        %{} = query_spec, # Should match QueryBuilder.ast_repo_query_spec()
        repo_pid \\ Repository
      ) do
    start_time = System.monotonic_time()

    # Phase 1: Initial data retrieval based on `from` target
    case initial_data_fetch(query_spec.from, repo_pid, query_spec) do
      {:ok, initial_data} ->
        # Phase 2: Apply filters (where clauses)
        filtered_data = apply_filters(initial_data, query_spec.where)

        # Phase 3: Apply joins (conceptual for now, as ETS joins are manual)
        joined_data = apply_joins(filtered_data, query_spec.joins, repo_pid)

        # Phase 4: Apply CPG pattern matching if specified
        pattern_matched_data = apply_cpg_pattern(joined_data, query_spec.cpg_pattern, repo_pid, query_spec.from)

        # Phase 5: Apply grouping (conceptual for now)
        grouped_data = apply_group_by(pattern_matched_data, query_spec.group_by)

        # Phase 6: Apply sorting
        sorted_data = apply_sorting(grouped_data, query_spec.order_by)

        # Phase 7: Apply offset and limit
        final_data = apply_offset_limit(sorted_data, query_spec.offset, query_spec.limit)

        # Phase 8: Apply selection (projection)
        projected_data = apply_selection(final_data, query_spec.select)

        duration_ms = System.monotonic_time() - start_time |> System.convert_time_unit(:native, :millisecond)
        Logger.debug("Query executed in #{duration_ms}ms. Spec: #{inspect(query_spec)}. Results: #{length(projected_data)}")
        {:ok, projected_data}

      {:error, reason} ->
        {:error, {:initial_fetch_failed, reason}}
    end
  rescue
    exception ->
      stacktrace = __STACKTRACE__
      Logger.error("Query execution failed: #{inspect(exception)}\nQuery: #{inspect(query_spec)}\n#{Exception.format_stacktrace(stacktrace)}")
      {:error, {:execution_exception, exception}}
  end


  # --- Query Execution Phases ---

  defp initial_data_fetch(:functions, repo_pid, query_spec) do
    # If query_spec has highly selective filters (e.g., on module_name),
    # use a more specific Repository function.
    # This is a simplified version of what ASTRepository.Repository.query_functions would do.
    # It's better if the Repository itself handles complex filtering.
    if module_filter = get_module_filter(query_spec.where) do
      Repository.get_functions_for_module(repo_pid, module_filter)
    else
      # Fallback to listing all - potentially very large!
      # Repository.list_all_functions(repo_pid) - assuming this exists
      # This demonstrates the need for Repository to handle more filtering.
      {:ok, :ets.tab2list(ElixirScope.ASTRepository.Repository.ast_functions_table()) |> Enum.map(&elem(&1, 1))}
    end
  end
  defp initial_data_fetch(:modules, repo_pid, _query_spec) do
    Repository.list_modules(repo_pid)
  end
  defp initial_data_fetch(:cpg_nodes, repo_pid, query_spec) do
    # Needs to fetch CPGs first, then extract nodes. Complex.
    # Or, if CPG nodes are stored globally, query them.
    # Assume for now it means "nodes from CPGs matching function_key filter".
    if function_key = get_function_key_filter(query_spec.where) do
      case Repository.get_cpg(repo_pid, elem(function_key,0), elem(function_key,1), elem(function_key,2)) do
        {:ok, %ElixirScope.ASTRepository.CPGData{nodes: nodes_map}} -> {:ok, Map.values(nodes_map)}
        error -> error
      end
    else
      {:error, :cpg_nodes_query_requires_function_key_filter}
    end
  end
  defp initial_data_fetch(:call_references, repo_pid, query_spec) do
    # This target is specific for `callers_of_mfa` type queries.
    if target_mfa_filter = get_mfa_filter(query_spec.where, :target_mfa) do
      Repository.find_callers_of_mfa(repo_pid, target_mfa_filter)
    else
       {:error, :call_references_query_requires_target_mfa_filter}
    end
  end
  defp initial_data_fetch(other_target, _repo_pid, _query_spec) do
    Logger.warn("QueryExecutor: Initial data fetch for target '#{other_target}' not fully implemented.")
    {:ok, []} # Placeholder
  end

  # --- Filter Helpers ---
  defp get_module_filter(nil), do: nil
  defp get_module_filter(where_clauses) do
    Enum.find_value(where_clauses, fn
      %{field: :module_name, op: :eq, value: mod_name} -> mod_name
      %{field: "module_data.module_name", op: :eq, value: mod_name} -> mod_name # if path based
      _ -> nil
    end)
  end
  defp get_function_key_filter(nil), do: nil
  defp get_function_key_filter(where_clauses) do
    Enum.find_value(where_clauses, fn
      %{field: :function_key, op: :eq, value: fk} -> fk
      %{field: "cpg_data.function_key", op: :eq, value: fk} -> fk
      _ -> nil
    end)
  end
  defp get_mfa_filter(nil, _key_name), do: nil
  defp get_mfa_filter(where_clauses, key_name) do
     Enum.find_value(where_clauses, fn
      %{field: ^key_name, op: :eq, value: mfa} -> mfa
      _ -> nil
    end)
  end


  defp apply_filters(data, nil), do: data
  defp apply_filters(data, []), do: data
  defp apply_filters(data, where_clauses) do
    Enum.filter(data, fn item ->
      # Assuming top-level AND for all clauses
      Enum.all?(where_clauses, &match_filter_condition?(item, &1))
    end)
  end

  defp match_filter_condition?(item, %{field: field, op: op, value: filter_value}) do
    item_value = get_field_value(item, field)

    case op do
      :eq -> item_value == filter_value
      :neq -> item_value != filter_value
      :gt -> is_number(item_value) && is_number(filter_value) && item_value > filter_value
      :gte -> is_number(item_value) && is_number(filter_value) && item_value >= filter_value
      :lt -> is_number(item_value) && is_number(filter_value) && item_value < filter_value
      :lte -> is_number(item_value) && is_number(filter_value) && item_value <= filter_value
      :in -> Enum.member?(List.wrap(filter_value), item_value)
      :nin -> not Enum.member?(List.wrap(filter_value), item_value)
      :contains ->
        cond do
          is_list(item_value) && is_list(filter_value) -> Enum.any?(filter_value, &Enum.member?(item_value, &1)) # list contains any of filter_value
          is_list(item_value) -> Enum.member?(item_value, filter_value)
          is_binary(item_value) && is_binary(filter_value) -> String.contains?(item_value, filter_value)
          true -> false
        end
      :starts_with -> is_binary(item_value) && is_binary(filter_value) && String.starts_with?(item_value, filter_value)
      :ends_with -> is_binary(item_value) && is_binary(filter_value) && String.ends_with?(item_value, filter_value)
      :matches_regex -> is_binary(item_value) && Regex.match?(~r/#{filter_value}/, item_value)
      _ -> false # Unknown operator
    end
  end

  # Helper to get value from struct or map, potentially nested via "dot.path" string
  defp get_field_value(item, field_path) when is_binary(field_path) do
    field_path |> String.split(".") |> Enum.reduce(item, fn key, acc ->
      if is_map(acc) || is_struct(acc), do: Map.get(acc, String.to_atom(key)), else: nil
    end)
  end
  defp get_field_value(item, field_atom) when is_atom(field_atom) do
    Map.get(item, field_atom)
  end


  defp apply_joins(data, nil, _repo_pid), do: data
  defp apply_joins(data, [], _repo_pid), do: data
  defp apply_joins(_data, _join_clauses, _repo_pid) do
    # ETS joins are complex and typically done via multiple lookups or match_spec.
    # A true generic join implementation here would be very involved.
    # Placeholder: This would require fetching data from `join_condition.to_target`
    # and merging it with `data` based on `from_field` and `to_field`.
    Logger.warn("QueryExecutor: Joins are not fully implemented yet.")
    _data # Return original data for now
  end

  defp apply_cpg_pattern(data, nil, _repo_pid, _from_target), do: data
  defp apply_cpg_pattern(data, cpg_pattern_dsl, repo_pid, :cpg_graph) do
    # If the initial fetch was intended to be a CPG graph query, it should happen there.
    # If `data` is a list of CPGData structs, we'd iterate and query each.
    # This is a placeholder. A real CPG pattern match would be complex.
    # It would likely call a specialized function in Repository or CPGBuilder.
    Logger.warn("QueryExecutor: CPG pattern matching from generic data list not fully implemented. Assumes `data` is already matched or `from` was :cpg_graph.")
    # Example: if `data` is a list of CPGData, and we need to filter nodes:
    # Enum.flat_map(data, fn cpg -> ElixirScope.ASTRepository.CPGBuilder.query_cpg_nodes_by_pattern(cpg, cpg_pattern_dsl) end)
    data # No-op for now if not from :cpg_graph
  end
  defp apply_cpg_pattern(data, _cpg_pattern_dsl, _repo_pid, _from_target), do: data # Only apply if from :cpg_graph


  defp apply_group_by(data, nil), do: data
  defp apply_group_by(data, group_by_fields) do
    # Placeholder for grouping logic.
    # Example: Enum.group_by(data, &Map.take(&1, List.wrap(group_by_fields)))
    Logger.warn("QueryExecutor: Group By not fully implemented yet.")
    data
  end

  defp apply_sorting(data, nil), do: data
  defp apply_sorting(data, []), do: data
  defp apply_sorting(data, order_by_clauses) do
    # Apply sorting in reverse order of specification for stable multi-field sort
    Enum.reduce(Enum.reverse(order_by_clauses), data, fn {field, direction}, acc_data ->
      Enum.sort_by(acc_data, &get_field_value(&1, field), if(direction == :desc, do: :desc, else: :asc))
    end)
  end

  defp apply_offset_limit(data, offset, limit) do
    data
    |> (fn d -> if offset && offset > 0, do: Enum.drop(d, offset), else: d end).()
    |> (fn d -> if limit && limit > 0, do: Enum.take(d, limit), else: d end).()
  end

  defp apply_selection(data, :all), do: data
  defp apply_selection(data, nil), do: data # Default to all
  defp apply_selection(data, fields) when is_list(fields) do
    Enum.map(data, fn item ->
      Map.take(item, Enum.map(fields, &to_atom_if_string/1)) # Ensure fields are atoms for Map.take on structs
    end)
  end

  defp to_atom_if_string(s) when is_binary(s), do: String.to_atom(s)
  defp to_atom_if_string(a) when is_atom(a), do: a
end
