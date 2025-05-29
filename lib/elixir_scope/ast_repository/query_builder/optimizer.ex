defmodule ElixirScope.ASTRepository.QueryBuilder.Optimizer do
  @moduledoc """
  Optimizes queries for better performance through cost estimation,
  hint generation, and query transformation.
  """

  alias ElixirScope.ASTRepository.QueryBuilder.Types

  @doc """
  Optimizes a query by adding cache key, estimating cost, and applying optimizations.
  """
  @spec optimize_query(Types.query_t()) :: {:ok, Types.query_t()}
  def optimize_query(%Types{} = query) do
    optimized_query = query
    |> add_cache_key()
    |> estimate_cost()
    |> generate_optimization_hints()
    |> apply_optimizations()

    {:ok, optimized_query}
  end

  @doc """
  Adds a cache key based on the query structure.
  """
  @spec add_cache_key(Types.query_t()) :: Types.query_t()
  def add_cache_key(%Types{} = query) do
    cache_key = :crypto.hash(:md5, :erlang.term_to_binary(query)) |> Base.encode16()
    %{query | cache_key: cache_key}
  end

  @doc """
  Estimates the computational cost of executing a query.
  """
  @spec estimate_cost(Types.query_t()) :: Types.query_t()
  def estimate_cost(%Types{} = query) do
    base_cost = case query.from do
      :functions -> 60
      :modules -> 35
      :patterns -> 120
    end

    where_cost = length(query.where || []) * 20
    join_cost = length(query.joins || []) * 40
    complex_ops_count = count_complex_operations(query.where || [])
    complex_cost = complex_ops_count * 80

    order_cost = case query.order_by do
      nil -> 0
      list when is_list(list) -> length(list) * 15
      _ -> 8
    end

    total_cost = base_cost + where_cost + join_cost + complex_cost + order_cost
    %{query | estimated_cost: total_cost}
  end

  @doc """
  Generates optimization hints based on query characteristics.
  """
  @spec generate_optimization_hints(Types.query_t()) :: Types.query_t()
  def generate_optimization_hints(%Types{} = query) do
    hints = []

    hints = if is_nil(query.limit) and query.estimated_cost > 80 do
      ["Consider adding a LIMIT clause to reduce memory usage" | hints]
    else
      hints
    end

    hints = if length(query.where || []) >= 3 do
      ["Complex WHERE conditions detected - ensure proper indexing" | hints]
    else
      hints
    end

    hints = if query.estimated_cost > 120 do
      ["High-cost query detected - results will be cached" | hints]
    else
      hints
    end

    %{query | optimization_hints: hints}
  end

  @doc """
  Applies various optimizations to the query.
  """
  @spec apply_optimizations(Types.query_t()) :: Types.query_t()
  def apply_optimizations(%Types{} = query) do
    query
    |> apply_index_optimization()
    |> apply_limit_optimization()
    |> apply_order_optimization()
  end

  @doc """
  Optimizes WHERE conditions for better selectivity.
  """
  @spec optimize_where_conditions(list(Types.filter_condition())) :: list(Types.filter_condition())
  def optimize_where_conditions(conditions) do
    Enum.sort(conditions, &condition_selectivity/2)
  end

  # Private helper functions

  defp count_complex_operations(conditions) do
    Enum.reduce(conditions, 0, fn condition, acc ->
      case condition do
        {_field, :similar_to, _value} -> acc + 1
        {:similar_to, _value} -> acc + 1
        {_field, :matches, _value} -> acc + 1
        {:matches, _value} -> acc + 1
        {:and, sub_conditions} -> acc + count_complex_operations(sub_conditions)
        {:or, sub_conditions} -> acc + count_complex_operations(sub_conditions)
        {:not, condition} -> acc + count_complex_operations([condition])
        _ -> acc
      end
    end)
  end

  defp apply_index_optimization(%Types{} = query) do
    optimized_where = optimize_where_conditions(query.where || [])
    %{query | where: optimized_where}
  end

  defp apply_limit_optimization(%Types{} = query) do
    if is_nil(query.limit) and query.estimated_cost > 120 do
      %{query | limit: 1000}
    else
      query
    end
  end

  defp apply_order_optimization(%Types{} = query) do
    # Future: Optimize ORDER BY to use available indexes
    query
  end

  defp condition_selectivity({_field1, op1, _value1}, {_field2, op2, _value2}) do
    selectivity_score(op1) >= selectivity_score(op2)
  end

  defp condition_selectivity({:and, _conditions1}, {_field2, op2, _value2}) do
    selectivity_score(:and) >= selectivity_score(op2)
  end

  defp condition_selectivity({_field1, op1, _value1}, {:and, _conditions2}) do
    selectivity_score(op1) >= selectivity_score(:and)
  end

  defp condition_selectivity({:or, _conditions1}, {_field2, op2, _value2}) do
    selectivity_score(:or) >= selectivity_score(op2)
  end

  defp condition_selectivity({_field1, op1, _value1}, {:or, _conditions2}) do
    selectivity_score(op1) >= selectivity_score(:or)
  end

  defp condition_selectivity({:not, _condition1}, {_field2, op2, _value2}) do
    selectivity_score(:not) >= selectivity_score(op2)
  end

  defp condition_selectivity({_field1, op1, _value1}, {:not, _condition2}) do
    selectivity_score(op1) >= selectivity_score(:not)
  end

  defp condition_selectivity(_, _), do: true

  defp selectivity_score(:eq), do: 10
  defp selectivity_score(:in), do: 8
  defp selectivity_score(:gt), do: 6
  defp selectivity_score(:lt), do: 6
  defp selectivity_score(:gte), do: 5
  defp selectivity_score(:lte), do: 5
  defp selectivity_score(:contains), do: 4
  defp selectivity_score(:matches), do: 3
  defp selectivity_score(:similar_to), do: 2
  defp selectivity_score(:ne), do: 1
  defp selectivity_score(:and), do: 7
  defp selectivity_score(:or), do: 3
  defp selectivity_score(:not), do: 2
  defp selectivity_score(_), do: 0
end
