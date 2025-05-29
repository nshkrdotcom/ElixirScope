defmodule ElixirScope.ASTRepository.QueryBuilder.Normalizer do
  @moduledoc """
  Normalizes query specifications into consistent internal format.
  """

  alias ElixirScope.ASTRepository.QueryBuilder.Types

  @doc """
  Normalizes a query specification from various input formats into a Types struct.
  """
  @spec normalize_query(map() | Types.query_t()) :: {:ok, Types.query_t()} | {:error, term()}
  def normalize_query(query_spec) when is_map(query_spec) do
    query = %Types{
      select: Map.get(query_spec, :select, :all),
      from: Map.get(query_spec, :from, :functions),
      where: Map.get(query_spec, :where, []),
      order_by: normalize_order_by(Map.get(query_spec, :order_by)),
      limit: Map.get(query_spec, :limit),
      offset: Map.get(query_spec, :offset, 0),
      group_by: Map.get(query_spec, :group_by),
      having: Map.get(query_spec, :having),
      joins: Map.get(query_spec, :joins)
    }

    {:ok, query}
  end

  def normalize_query(%Types{} = query), do: {:ok, query}
  def normalize_query(_), do: {:error, :invalid_query_format}

  @doc """
  Normalizes ORDER BY specifications into consistent format.
  """
  @spec normalize_order_by(term()) :: term()
  def normalize_order_by(nil), do: nil

  def normalize_order_by(order_by) when is_list(order_by) do
    Enum.map(order_by, fn
      {field, direction} -> {field, direction}
      other -> other
    end)
  end

  def normalize_order_by(order_by), do: order_by

  @doc """
  Normalizes WHERE conditions to ensure consistent format.
  """
  @spec normalize_where_conditions(list()) :: list()
  def normalize_where_conditions(conditions) when is_list(conditions) do
    Enum.map(conditions, &normalize_condition/1)
  end

  def normalize_where_conditions(conditions), do: conditions

  # Private helper functions

  defp normalize_condition({field, op, value}) when is_atom(field) and is_atom(op) do
    {field, op, value}
  end

  defp normalize_condition({field, op}) when is_atom(field) and op in [:not_nil, :nil] do
    {field, op}
  end

  defp normalize_condition({:and, conditions}) when is_list(conditions) do
    {:and, Enum.map(conditions, &normalize_condition/1)}
  end

  defp normalize_condition({:or, conditions}) when is_list(conditions) do
    {:or, Enum.map(conditions, &normalize_condition/1)}
  end

  defp normalize_condition({:not, condition}) do
    {:not, normalize_condition(condition)}
  end

  defp normalize_condition(condition), do: condition
end
