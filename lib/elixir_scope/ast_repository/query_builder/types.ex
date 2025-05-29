defmodule ElixirScope.ASTRepository.QueryBuilder.Types do
  @moduledoc """
  Type definitions and structs for the QueryBuilder system.
  """

  defstruct [
    :select,
    :from,
    :where,
    :order_by,
    :limit,
    :offset,
    :group_by,
    :having,
    :joins,
    :cache_key,
    :estimated_cost,
    :optimization_hints
  ]

  @type query_t :: %__MODULE__{
    select: list(atom()) | :all,
    from: :functions | :modules | :patterns,
    where: list(filter_condition()),
    order_by: {atom(), :asc | :desc} | list({atom(), :asc | :desc}),
    limit: pos_integer() | nil,
    offset: non_neg_integer() | nil,
    group_by: list(atom()) | nil,
    having: list(filter_condition()) | nil,
    joins: list(join_spec()) | nil,
    cache_key: String.t() | nil,
    estimated_cost: non_neg_integer() | nil,
    optimization_hints: list(String.t()) | nil
  }

  @type filter_condition ::
    {atom(), :eq | :ne | :gt | :lt | :gte | :lte | :in | :not_in | :contains | :not_contains | :matches | :similar_to, any()} |
    {:and, list(filter_condition())} |
    {:or, list(filter_condition())} |
    {:not, filter_condition()}

  @type join_spec :: {atom(), atom(), atom(), atom()}

  @type query_result :: %{
    data: list(map()),
    metadata: %{
      total_count: non_neg_integer(),
      execution_time_ms: non_neg_integer(),
      cache_hit: boolean(),
      optimization_applied: list(String.t()),
      performance_score: :excellent | :good | :fair | :poor
    }
  }

  # Performance thresholds
  @simple_query_threshold 50
  @complex_query_threshold 200

  def simple_query_threshold, do: @simple_query_threshold
  def complex_query_threshold, do: @complex_query_threshold
end
