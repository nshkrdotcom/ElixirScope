defmodule ElixirScope.ASTRepository.QueryBuilder do
  @moduledoc """
  Provides a fluent API or helper functions to construct query specifications
  for the AST Repository and the main ElixirScope Query Engine.

  This module helps in building complex queries for AST, CFG, DFG, and CPG data,
  as well as correlated static-dynamic queries.

  The output of this builder is a query map/struct that can be processed by
  `ASTRepository.QueryExecutor` or `ElixirScope.QueryEngine.ASTExtensions`.
  """

  # Define common query types or structures if not already globally defined
  # These might align with `ElixirScope.QueryEngine.ASTExtensions.ast_query()`

  @type query_target :: :functions | :modules | :cpg_nodes | :cpg_edges | :variables | :calls
  @type filter_op :: :eq | :neq | :gt | :gte | :lt | :lte | :in | :nin | :contains | :starts_with | :ends_with | :matches_regex
  @type sort_direction :: :asc | :desc

  @type filter_condition :: %{
    field: atom() | String.t(), # e.g., :complexity_score, "node.label"
    op: filter_op(),
    value: any()
  }

  @type join_condition :: %{
    from_target: query_target(), # Or specific table/collection name
    from_field: atom() | String.t(),
    to_target: query_target(), # Or specific table/collection name
    to_field: atom() | String.t(),
    type: :inner | :left # Default inner
  }

  @type ast_repo_query_spec :: %{
    select: [:all | [atom() | String.t()]], # Fields to return, or :all for full structs
    from: query_target(),
    where: [filter_condition()] | nil, # List of conditions (ANDed by default)
                                       # Could support nested {:and, [...]}, {:or, [...]}
    joins: [join_condition()] | nil,
    group_by: [atom() | String.t()] | nil,
    order_by: [{atom() | String.t(), sort_direction()}] | nil,
    limit: non_neg_integer() | nil,
    offset: non_neg_integer() | nil,
    # AST/CPG specific extensions
    cpg_pattern: map() | nil, # DSL for CPG graph patterns
    data_flow_trace: %{variable: String.t(), start_node_id: String.t()} | nil,
    control_flow_path: %{from_node_id: String.t(), to_node_id: String.t()} | nil,
    # Metadata for query execution
    query_engine_hint: :ast_repository | :main_query_engine | :correlated,
    cache_opts: keyword() # E.g., [ttl: 300, use_cache: true]
  }


  @doc """
  Starts building a query for functions.
  """
  @spec find_functions() :: ast_repo_query_spec()
  def find_functions do
    %{
      select: :all,
      from: :functions,
      where: [],
      joins: [],
      order_by: [],
      limit: nil,
      offset: nil,
      query_engine_hint: :ast_repository
    }
  end

  @doc """
  Starts building a query for modules.
  """
  @spec find_modules() :: ast_repo_query_spec()
  def find_modules do
    %{
      select: :all,
      from: :modules,
      where: [],
      joins: [],
      order_by: [],
      limit: nil,
      offset: nil,
      query_engine_hint: :ast_repository
    }
  end

  @doc """
  Starts building a query for CPG nodes.
  """
  @spec find_cpg_nodes() :: ast_repo_query_spec()
  def find_cpg_nodes do
     %{
      select: :all,
      from: :cpg_nodes,
      where: [],
      joins: [],
      order_by: [],
      limit: nil,
      offset: nil,
      query_engine_hint: :ast_repository
    }
  end


  # --- Filter Operations ---

  @doc """
  Adds a filter condition to the query.
  Example: `where(query, :complexity_score, :gt, 10)`
           `where(query, "module_data.module_name", :eq, MyApp.MyModule)`
  """
  @spec where(query :: ast_repo_query_spec(), field :: atom() | String.t(), op :: filter_op(), value :: any()) :: ast_repo_query_spec()
  def where(query, field, op, value) do
    new_filter = %{field: field, op: op, value: value}
    %{query | where: [new_filter | (query.where || [])]}
  end

  @doc "Adds a list of ANDed filter conditions."
  def where_all(query, conditions :: [filter_condition()]) do
     %{query | where: (query.where || []) ++ conditions} # Simplified, assumes top-level AND
  end

  # --- Selection ---
  @doc "Specifies which fields to select."
  @spec select(query :: ast_repo_query_spec(), fields :: :all | [atom() | String.t()]) :: ast_repo_query_spec()
  def select(query, fields) do
    %{query | select: fields}
  end

  # --- Sorting ---
  @doc "Adds a sort order."
  @spec order_by(query :: ast_repo_query_spec(), field :: atom() | String.t(), direction :: sort_direction()) :: ast_repo_query_spec()
  def order_by(query, field, direction \\ :asc) do
    new_order = {field, direction}
    %{query | order_by: [new_order | (query.order_by || [])]} # Prepends; executor should reverse or handle order
  end

  # --- Limiting and Offset ---
  @doc "Sets the result limit."
  @spec limit(query :: ast_repo_query_spec(), count :: non_neg_integer()) :: ast_repo_query_spec()
  def limit(query, count) do
    %{query | limit: count}
  end

  @doc "Sets the result offset."
  @spec offset(query :: ast_repo_query_spec(), count :: non_neg_integer()) :: ast_repo_query_spec()
  def offset(query, count) do
    %{query | offset: count}
  end

  # --- AST/CPG Specific Builders ---

  @doc """
  Builds a query to find functions by complexity.
  Example: `by_complexity(:cyclomatic, :gt, 10)`
  """
  @spec by_complexity(query :: ast_repo_query_spec(), metric :: atom(), op :: filter_op(), value :: number()) :: ast_repo_query_spec()
  def by_complexity(query, metric \\ :cyclomatic_complexity, op, value) do
    # Assumes complexity metrics are fields on the function data structure
    # or can be accessed via a path like "complexity_metrics.cyclomatic_complexity"
    field_name = if Map.has_key?(ElixirScope.ASTRepository.ComplexityMetrics.__struct__(), metric) do
      # If it's a direct field in ComplexityMetrics, path might be needed
      # For simplicity, assume it's directly queryable or `metric` itself is the field name
      metric
    else
      metric # Fallback to raw metric name
    end
    where(query, field_name, op, value)
  end

  @doc """
  Builds a query to find functions that call a specific MFA.
  """
  @spec calls_mfa(query :: ast_repo_query_spec(), target_mfa :: {module :: atom(), fun :: atom(), arity :: non_neg_integer()}) :: ast_repo_query_spec()
  def calls_mfa(query, target_mfa) do
    # This implies a filter on a field like `called_functions` or a join with a call graph table.
    # For `ASTRepository.query_functions`, it might be a specific parameter.
    # Let's make it a generic filter on a conceptual `calls` field.
    where(query, :called_functions, :contains, target_mfa) # 'contains' op needs to be implemented by executor
    |> Map.put(:query_engine_hint, :ast_repository) # Hint for Repository's query_functions
  end

  @doc """
  Builds a query to find callers of a specific MFA.
  """
  @spec callers_of_mfa(query :: ast_repo_query_spec(), target_mfa :: {module :: atom(), fun :: atom(), arity :: non_neg_integer()}) :: ast_repo_query_spec()
  def callers_of_mfa(query, target_mfa) do
    # This typically uses an inverted index (`@calls_by_target_index`).
    # The query structure here might be simpler, directly passing the target MFA.
    # For consistency with the filter approach, we can model it as:
    %{query | from: :call_references, where: [%{field: :target_mfa, op: :eq, value: target_mfa}]}
    |> Map.put(:query_engine_hint, :ast_repository)
  end

  @doc """
  Builds a query for CPG graph pattern matching.
  The `pattern_dsl` is a map representing the graph pattern.
  Example: `%{nodes: [%{label_prefix: "var:", type: :ast}], edges: [%{type: :dfg_reaches, from_node_index: 0, to_node_index: 0}]}`
  """
  @spec match_cpg_pattern(query :: ast_repo_query_spec(), pattern_dsl :: map()) :: ast_repo_query_spec()
  def match_cpg_pattern(query, pattern_dsl) do
    %{query | from: :cpg_graph, cpg_pattern: pattern_dsl, query_engine_hint: :ast_repository}
  end

  # --- Correlated Query Building (Conceptual) ---
  @doc """
  Builds a specification for a correlated query, combining a static AST query
  with a runtime event query template.
  """
  @spec build_correlated_query(
    static_query_spec :: ast_repo_query_spec(),
    runtime_query_template :: map(), # Template for ElixirScope.QueryEngine.execute_event_query
    join_on :: {static_field :: atom(), runtime_field :: atom()}
  ) :: map()
  def build_correlated_query(static_query_spec, runtime_query_template, join_on) do
    %{
      type: :correlated_static_dynamic,
      static_query: static_query_spec,
      runtime_template: runtime_query_template,
      join_condition: join_on,
      query_engine_hint: :main_query_engine # Main engine orchestrates this
    }
  end


  # --- Example Usage ---
  @doc false
  def example_usage do
    # Find top 10 most complex public functions in MyModule
    query1 = find_functions()
             |> where(:module_name, :eq, MyApp.MyModule)
             |> where(:visibility, :eq, :public)
             |> by_complexity(:cyclomatic_complexity, :gt, 5)
             |> order_by(:cyclomatic_complexity, :desc)
             |> limit(10)
             |> select([:module_name, :function_name, :arity, :cyclomatic_complexity])

    # Find CPG nodes representing variable assignments in a specific function
    query2 = find_cpg_nodes()
             |> where("cpg_data.function_key", :eq, {MyApp.MyModule, :my_func, 1}) # Assuming function_key is accessible
             |> where(:label, :starts_with, "assign:") # Assuming labels are like "assign:x"
             |> limit(5)

    # Build a correlated query:
    # Find runtime errors for functions identified by query1
    static_q = find_functions() |> by_complexity(:cyclomatic_complexity, :gt, 20) |> select([:function_key])
    runtime_template = %{
      event_type: :error,
      time_range: {:last_minutes, 60}
    }
    correlated_query = build_correlated_query(static_q, runtime_template, join_on: {:function_key, :function_key})

    [query1, query2, correlated_query]
  end

end
