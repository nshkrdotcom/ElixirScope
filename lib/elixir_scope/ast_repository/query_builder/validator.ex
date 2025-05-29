defmodule ElixirScope.ASTRepository.QueryBuilder.Validator do
  @moduledoc """
  Validates query structures for correctness and safety.
  """

  alias ElixirScope.ASTRepository.QueryBuilder.Types

  @doc """
  Validates a complete query structure.
  """
  @spec validate_query(Types.query_t()) :: {:ok, Types.query_t()} | {:error, term()}
  def validate_query(%Types{} = query) do
    with :ok <- validate_from_clause(query.from),
         :ok <- validate_select_clause(query.select),
         :ok <- validate_where_clause(query.where),
         :ok <- validate_order_by_clause(query.order_by) do
      {:ok, query}
    else
      error -> error
    end
  end

  @doc """
  Validates the FROM clause.
  """
  @spec validate_from_clause(atom()) :: :ok | {:error, :invalid_from_clause}
  def validate_from_clause(from) when from in [:functions, :modules, :patterns], do: :ok
  def validate_from_clause(_), do: {:error, :invalid_from_clause}

  @doc """
  Validates the SELECT clause.
  """
  @spec validate_select_clause(:all | list(atom())) :: :ok | {:error, :invalid_select_clause}
  def validate_select_clause(:all), do: :ok
  def validate_select_clause(fields) when is_list(fields), do: :ok
  def validate_select_clause(_), do: {:error, :invalid_select_clause}

  @doc """
  Validates WHERE conditions.
  """
  @spec validate_where_clause(list(Types.filter_condition())) :: :ok | {:error, :invalid_where_condition}
  def validate_where_clause(conditions) when is_list(conditions) do
    if Enum.all?(conditions, &valid_condition?/1) do
      :ok
    else
      {:error, :invalid_where_condition}
    end
  end

  @doc """
  Validates ORDER BY clause.
  """
  @spec validate_order_by_clause(term()) :: :ok | {:error, :invalid_order_by_clause}
  def validate_order_by_clause(nil), do: :ok
  def validate_order_by_clause({field, direction}) when is_atom(field) and direction in [:asc, :desc], do: :ok
  def validate_order_by_clause({direction, field}) when is_atom(field) and direction in [:asc, :desc], do: :ok
  def validate_order_by_clause(list) when is_list(list) do
    if Enum.all?(list, fn
      {field, direction} when is_atom(field) and direction in [:asc, :desc] -> true
      {direction, field} when is_atom(field) and direction in [:asc, :desc] -> true
      _ -> false
    end) do
      :ok
    else
      {:error, :invalid_order_by_clause}
    end
  end
  def validate_order_by_clause(_), do: {:error, :invalid_order_by_clause}

  # Private validation helpers

  defp valid_condition?({field, op, _value}) when is_atom(field) do
    op in [:eq, :ne, :gt, :lt, :gte, :lte, :in, :not_in, :contains, :not_contains, :matches, :similar_to, :not_nil, :nil]
  end

  defp valid_condition?({field, op}) when is_atom(field) and op in [:not_nil, :nil] do
    true
  end

  defp valid_condition?({op, _value}) when op in [:similar_to, :matches] do
    true
  end

  defp valid_condition?({special_field, _value}) when special_field in [:similarity_threshold] do
    true
  end

  defp valid_condition?({:and, conditions}) when is_list(conditions) do
    Enum.all?(conditions, &valid_condition?/1)
  end

  defp valid_condition?({:or, conditions}) when is_list(conditions) do
    Enum.all?(conditions, &valid_condition?/1)
  end

  defp valid_condition?({:not, condition}) do
    valid_condition?(condition)
  end

  defp valid_condition?(_), do: false
end
