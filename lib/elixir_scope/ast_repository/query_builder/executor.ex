defmodule ElixirScope.ASTRepository.QueryBuilder.Executor do
  @moduledoc """
  Executes queries against the repository with filtering, ordering, and selection.
  """

  alias ElixirScope.ASTRepository.QueryBuilder.Types

  @doc """
  Executes a query against the repository.
  """
  @spec execute_query(pid() | atom(), Types.query_t()) :: {:ok, Types.query_result()} | {:error, term()}
  def execute_query(repo, %Types{} = query) do
    case query.from do
      :functions -> execute_function_query(repo, query)
      :modules -> execute_module_query(repo, query)
      :patterns -> execute_pattern_query(repo, query)
    end
  end

  @doc """
  Validates that a repository is accessible.
  """
  @spec validate_repository(pid() | atom()) :: :ok | {:error, term()}
  def validate_repository(repo) when is_pid(repo) do
    if Process.alive?(repo) do
      :ok
    else
      {:error, :repository_not_available}
    end
  end

  def validate_repository(repo) when is_atom(repo) do
    case Process.whereis(repo) do
      nil -> {:error, :repository_not_found}
      pid when is_pid(pid) ->
        if Process.alive?(pid) do
          :ok
        else
          {:error, :repository_not_available}
        end
    end
  end

  def validate_repository(_repo) do
    {:error, :invalid_repository}
  end

  @doc """
  Applies WHERE conditions to filter data.
  """
  @spec apply_where_filters(list(map()), list(Types.filter_condition())) :: list(map())
  def apply_where_filters(data, []), do: data
  def apply_where_filters(data, conditions) do
    Enum.filter(data, fn item ->
      evaluate_conditions(item, conditions)
    end)
  end

  @doc """
  Applies ordering to data.
  """
  @spec apply_ordering(list(map()), term()) :: list(map())
  def apply_ordering(data, nil), do: data
  def apply_ordering(data, {field, :asc}) do
    Enum.sort_by(data, &Map.get(&1, field, 0))
  end
  def apply_ordering(data, {field, :desc}) do
    Enum.sort_by(data, &Map.get(&1, field, 0), :desc)
  end
  def apply_ordering(data, {:asc, field}) do
    Enum.sort_by(data, &Map.get(&1, field, 0))
  end
  def apply_ordering(data, {:desc, field}) do
    Enum.sort_by(data, &Map.get(&1, field, 0), :desc)
  end
  def apply_ordering(data, order_specs) when is_list(order_specs) do
    Enum.reduce(order_specs, data, fn order_spec, acc ->
      apply_ordering(acc, order_spec)
    end)
  end

  @doc """
  Applies LIMIT and OFFSET to data.
  """
  @spec apply_limit_offset(list(map()), pos_integer() | nil, non_neg_integer()) :: list(map())
  def apply_limit_offset(data, nil, 0), do: data
  def apply_limit_offset(data, nil, offset), do: Enum.drop(data, offset)
  def apply_limit_offset(data, limit, 0), do: Enum.take(data, limit)
  def apply_limit_offset(data, limit, offset) do
    data |> Enum.drop(offset) |> Enum.take(limit)
  end

  @doc """
  Applies SELECT to choose specific fields.
  """
  @spec apply_select(list(map()), :all | list(atom())) :: list(map())
  def apply_select(data, :all), do: data
  def apply_select(data, fields) when is_list(fields) do
    Enum.map(data, fn item ->
      Map.take(item, fields)
    end)
  end

  @doc """
  Evaluates a single condition against an item.
  """
  @spec evaluate_condition(map(), Types.filter_condition()) :: boolean()
  def evaluate_condition(item, {field, :eq, value}) do
    Map.get(item, field) == value
  end

  def evaluate_condition(item, {field, :ne, value}) do
    Map.get(item, field) != value
  end

  def evaluate_condition(item, {field, :gt, value}) do
    case Map.get(item, field) do
      nil -> false
      item_value -> item_value > value
    end
  end

  def evaluate_condition(item, {field, :lt, value}) do
    case Map.get(item, field) do
      nil -> false
      item_value -> item_value < value
    end
  end

  def evaluate_condition(item, {field, :gte, value}) do
    case Map.get(item, field) do
      nil -> false
      item_value -> item_value >= value
    end
  end

  def evaluate_condition(item, {field, :lte, value}) do
    case Map.get(item, field) do
      nil -> false
      item_value -> item_value <= value
    end
  end

  def evaluate_condition(item, {field, :in, values}) when is_list(values) do
    case Map.get(item, field) do
      list when is_list(list) ->
        Enum.any?(list, &(&1 in values))
      single_value ->
        single_value in values
    end
  end

  def evaluate_condition(item, {field, :not_in, values}) when is_list(values) do
    case Map.get(item, field) do
      list when is_list(list) ->
        not Enum.any?(list, &(&1 in values))
      single_value ->
        single_value not in values
    end
  end

  def evaluate_condition(item, {field, :contains, value}) do
    case Map.get(item, field) do
      list when is_list(list) -> value in list
      string when is_binary(string) -> String.contains?(string, to_string(value))
      _ -> false
    end
  end

  def evaluate_condition(item, {field, :not_contains, value}) do
    not evaluate_condition(item, {field, :contains, value})
  end

  def evaluate_condition(item, {field, :matches, pattern}) do
    case Map.get(item, field) do
      string when is_binary(string) ->
        case Regex.compile(pattern) do
          {:ok, regex} -> Regex.match?(regex, string)
          _ -> false
        end
      _ -> false
    end
  end

  def evaluate_condition(item, {field, :similar_to, {module, function, arity}}) do
    case Map.get(item, field) do
      {^module, ^function, ^arity} -> true
      _ -> false
    end
  end

  def evaluate_condition(item, {field, :not_nil}) do
    Map.get(item, field) != nil
  end

  def evaluate_condition(item, {field, :nil}) do
    Map.get(item, field) == nil
  end

  def evaluate_condition(item, {:similar_to, {module, function, arity}}) do
    case Map.get(item, :mfa) || {Map.get(item, :module), Map.get(item, :function), Map.get(item, :arity)} do
      {^module, ^function, ^arity} -> true
      _ -> false
    end
  end

  def evaluate_condition(item, {:similarity_threshold, threshold}) do
    case Map.get(item, :similarity_score) do
      nil -> false
      score -> score >= threshold
    end
  end

  def evaluate_condition(item, {:and, conditions}) do
    Enum.all?(conditions, &evaluate_condition(item, &1))
  end

  def evaluate_condition(item, {:or, conditions}) do
    Enum.any?(conditions, &evaluate_condition(item, &1))
  end

  def evaluate_condition(item, {:not, condition}) do
    not evaluate_condition(item, condition)
  end

  def evaluate_condition(_item, _condition), do: false

  # Private helper functions

  defp execute_function_query(repo, %Types{} = query) do
    case get_all_functions(repo) do
      {:ok, functions} ->
        filtered_functions = apply_where_filters(functions, query.where || [])
        ordered_functions = apply_ordering(filtered_functions, query.order_by)
        limited_functions = apply_limit_offset(ordered_functions, query.limit, query.offset || 0)
        selected_data = apply_select(limited_functions, query.select)

        result = %{
          data: selected_data,
          total_count: length(filtered_functions)
        }

        {:ok, result}

      error -> error
    end
  end

  defp execute_module_query(repo, %Types{} = query) do
    case get_all_modules(repo) do
      {:ok, modules} ->
        filtered_modules = apply_where_filters(modules, query.where || [])
        ordered_modules = apply_ordering(filtered_modules, query.order_by)
        limited_modules = apply_limit_offset(ordered_modules, query.limit, query.offset || 0)
        selected_data = apply_select(limited_modules, query.select)

        result = %{
          data: selected_data,
          total_count: length(filtered_modules)
        }

        {:ok, result}

      error -> error
    end
  end

  defp execute_pattern_query(_repo, %Types{} = _query) do
    {:error, :pattern_queries_not_implemented}
  end

  defp get_all_functions(repo) do
    case validate_repository(repo) do
      :ok -> {:ok, []}  # Placeholder - would integrate with Enhanced Repository
      error -> error
    end
  end

  defp get_all_modules(repo) do
    case validate_repository(repo) do
      :ok -> {:ok, []}  # Placeholder - would integrate with Enhanced Repository
      error -> error
    end
  end

  defp evaluate_conditions(item, conditions) do
    Enum.all?(conditions, fn condition ->
      evaluate_condition(item, condition)
    end)
  end
end
