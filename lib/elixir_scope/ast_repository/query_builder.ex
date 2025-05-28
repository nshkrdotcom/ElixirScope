defmodule ElixirScope.ASTRepository.QueryBuilder do
  @moduledoc """
  Advanced query builder for the Enhanced AST Repository.
  
  Provides powerful querying capabilities with:
  - Complex filters for complexity, patterns, dependencies
  - Query optimization using available indexes
  - Result caching and performance monitoring
  - Support for semantic, structural, performance, and security queries
  
  ## Query Types
  
  - **Semantic queries**: Find functions similar to a given one
  - **Structural queries**: Find specific AST patterns (e.g., GenServer implementations)
  - **Performance queries**: Find functions with specific complexity characteristics
  - **Security queries**: Identify potential security vulnerabilities
  - **Dependency queries**: Find modules using specific functions or patterns
  
  ## Performance Targets
  
  - Simple queries: <50ms
  - Complex queries: <200ms
  - Memory usage: <50MB for query execution
  
  ## Examples
  
      # Complex function query
      {:ok, functions} = QueryBuilder.execute_query(repo, %{
        select: [:module, :function, :complexity, :performance_profile],
        from: :functions,
        where: [
          {:complexity, :gt, 15},
          {:calls, :contains, {Ecto.Repo, :all, 1}},
          {:performance_profile, :not_nil}
        ],
        order_by: {:desc, :complexity},
        limit: 20
      })
      
      # Semantic similarity query
      {:ok, similar} = QueryBuilder.execute_query(repo, %{
        select: [:module, :function, :similarity_score],
        from: :functions,
        where: [
          {:similar_to, {MyModule, :my_function, 2}},
          {:similarity_threshold, 0.8}
        ],
        order_by: {:desc, :similarity_score}
      })
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.ASTRepository.EnhancedRepository
  alias ElixirScope.ASTRepository.Enhanced.{
    EnhancedFunctionData,
    EnhancedModuleData
  }
  
  @table_name :query_cache
  @index_table :query_indexes
  @performance_table :query_performance
  
  # Query cache TTL in milliseconds (5 minutes)
  @cache_ttl 300_000
  
  # Performance thresholds
  @simple_query_threshold 50
  @complex_query_threshold 200
  
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
  
  # GenServer API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    # Create ETS tables for caching and indexing
    :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    :ets.new(@index_table, [:named_table, :public, :bag, {:read_concurrency, true}])
    :ets.new(@performance_table, [:named_table, :public, :set, {:read_concurrency, true}])
    
    # Schedule cache cleanup
    Process.send_after(self(), :cleanup_cache, @cache_ttl)
    
    state = %{
      cache_stats: %{hits: 0, misses: 0},
      query_stats: %{total: 0, avg_time: 0},
      opts: opts
    }
    
    Logger.info("QueryBuilder started with caching enabled")
    {:ok, state}
  end
  
  def handle_info(:cleanup_cache, state) do
    cleanup_expired_cache()
    Process.send_after(self(), :cleanup_cache, @cache_ttl)
    {:noreply, state}
  end
  
  def handle_call({:execute_query, repo, query_spec}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    case execute_query_internal(repo, query_spec) do
      {:ok, result} ->
        end_time = System.monotonic_time(:millisecond)
        execution_time = end_time - start_time
        
        # Update performance stats
        updated_state = update_performance_stats(state, execution_time)
        
        # Add metadata to result
        result_with_metadata = add_execution_metadata(result, execution_time, query_spec)
        
        {:reply, {:ok, result_with_metadata}, updated_state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:build_query, query_spec}, _from, state) do
    case build_query_internal(query_spec) do
      {:ok, query} ->
        {:reply, {:ok, query}, state}
      
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call(:get_cache_stats, _from, state) do
    {:reply, {:ok, state.cache_stats}, state}
  end
  
  def handle_call(:clear_cache, _from, state) do
    :ets.delete_all_objects(@table_name)
    updated_stats = %{state.cache_stats | hits: 0, misses: 0}
    {:reply, :ok, %{state | cache_stats: updated_stats}}
  end
  
  # Public API
  
  @doc """
  Builds a query structure from keyword options.
  
  ## Parameters
  
  - `query_spec` - Map or keyword list with query specifications
  
  ## Examples
  
      iex> QueryBuilder.build_query(%{
      ...>   select: [:module, :function, :complexity],
      ...>   from: :functions,
      ...>   where: [{:complexity, :gt, 10}],
      ...>   order_by: {:desc, :complexity},
      ...>   limit: 20
      ...> })
      {:ok, %QueryBuilder{...}}
  """
  @spec build_query(map() | keyword()) :: {:ok, query_t()} | {:error, term()}
  def build_query(query_spec) do
    GenServer.call(__MODULE__, {:build_query, query_spec})
  end
  
  @doc """
  Executes a query against the Enhanced Repository with optimization.
  
  ## Parameters
  
  - `repo` - The Enhanced Repository process
  - `query_spec` - Query specification map or QueryBuilder struct
  
  ## Returns
  
  - `{:ok, query_result()}` - Successful execution with results and metadata
  - `{:error, term()}` - Error during execution
  """
  @spec execute_query(pid() | atom(), map() | query_t()) :: {:ok, query_result()} | {:error, term()}
  def execute_query(repo, query_spec) do
    GenServer.call(__MODULE__, {:execute_query, repo, query_spec}, 30_000)
  end
  
  @doc """
  Gets cache statistics for monitoring performance.
  """
  @spec get_cache_stats() :: {:ok, map()}
  def get_cache_stats() do
    GenServer.call(__MODULE__, :get_cache_stats)
  end
  
  @doc """
  Clears the query cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache() do
    GenServer.call(__MODULE__, :clear_cache)
  end
  
  # Public functions for testing
  
  @doc false
  def evaluate_condition(item, condition) do
    evaluate_condition_internal(item, condition)
  end
  
  @doc false
  def apply_ordering(data, order_spec) do
    apply_ordering_internal(data, order_spec)
  end
  
  @doc false
  def apply_limit_offset(data, limit, offset) do
    apply_limit_offset_internal(data, limit, offset)
  end
  
  @doc false
  def apply_select(data, fields) do
    apply_select_internal(data, fields)
  end
  
  # Private Implementation
  
  defp execute_query_internal(repo, query_spec) do
    with {:ok, query} <- normalize_query(query_spec),
         {:ok, optimized_query} <- optimize_query(query),
         {:ok, result} <- execute_optimized_query(repo, optimized_query) do
      {:ok, result}
    else
      error -> error
    end
  end
  
  defp build_query_internal(query_spec) do
    with {:ok, query} <- normalize_query(query_spec),
         {:ok, validated_query} <- validate_query(query),
         {:ok, optimized_query} <- optimize_query(validated_query) do
      {:ok, optimized_query}
    else
      error -> error
    end
  end
  
  defp normalize_query(query_spec) when is_map(query_spec) do
    query = %__MODULE__{
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
  
  defp normalize_order_by(nil), do: nil
  defp normalize_order_by(order_by) when is_list(order_by) do
    # Convert keyword list to list of tuples if needed
    Enum.map(order_by, fn
      {field, direction} -> {field, direction}
      other -> other
    end)
  end
  defp normalize_order_by(order_by), do: order_by
  
  defp normalize_query(%__MODULE__{} = query), do: {:ok, query}
  defp normalize_query(_), do: {:error, :invalid_query_format}
  
  defp validate_query(%__MODULE__{} = query) do
    with :ok <- validate_from_clause(query.from),
         :ok <- validate_select_clause(query.select),
         :ok <- validate_where_clause(query.where),
         :ok <- validate_order_by_clause(query.order_by) do
      {:ok, query}
    else
      error -> error
    end
  end
  
  defp validate_from_clause(from) when from in [:functions, :modules, :patterns], do: :ok
  defp validate_from_clause(_), do: {:error, :invalid_from_clause}
  
  defp validate_select_clause(:all), do: :ok
  defp validate_select_clause(fields) when is_list(fields), do: :ok
  defp validate_select_clause(_), do: {:error, :invalid_select_clause}
  
  defp validate_where_clause(conditions) when is_list(conditions) do
    if Enum.all?(conditions, &valid_condition?/1) do
      :ok
    else
      {:error, :invalid_where_condition}
    end
  end
  
  defp validate_order_by_clause(nil), do: :ok
  defp validate_order_by_clause({field, direction}) when is_atom(field) and direction in [:asc, :desc], do: :ok
  defp validate_order_by_clause({direction, field}) when is_atom(field) and direction in [:asc, :desc], do: :ok
  defp validate_order_by_clause(list) when is_list(list) do
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
  defp validate_order_by_clause(_), do: {:error, :invalid_order_by_clause}
  
  defp valid_condition?({field, op, _value}) when is_atom(field) do
    op in [:eq, :ne, :gt, :lt, :gte, :lte, :in, :not_in, :contains, :not_contains, :matches, :similar_to, :not_nil, :nil]
  end
  defp valid_condition?({field, op}) when is_atom(field) and op in [:not_nil, :nil] do
    # Support 2-tuple format for operators that don't need a value
    true
  end
  defp valid_condition?({op, _value}) when op in [:similar_to, :matches] do
    # Handle special cases like {:similar_to, {module, function, arity}}
    true
  end
  defp valid_condition?({special_field, _value}) when special_field in [:similarity_threshold] do
    # Handle special query parameters
    true
  end
  defp valid_condition?({:and, conditions}) when is_list(conditions) do
    Enum.all?(conditions, fn condition ->
      valid_condition?(condition)
    end)
  end
  defp valid_condition?({:or, conditions}) when is_list(conditions) do
    Enum.all?(conditions, &valid_condition?/1)
  end
  defp valid_condition?({:not, condition}) do
    valid_condition?(condition)
  end
  defp valid_condition?(_), do: false
  
  defp optimize_query(%__MODULE__{} = query) do
    optimized_query = query
    |> add_cache_key()
    |> estimate_cost()
    |> generate_optimization_hints()
    |> apply_optimizations()
    
    {:ok, optimized_query}
  end
  
  defp add_cache_key(%__MODULE__{} = query) do
    cache_key = :crypto.hash(:md5, :erlang.term_to_binary(query)) |> Base.encode16()
    %{query | cache_key: cache_key}
  end
  
  defp estimate_cost(%__MODULE__{} = query) do
    base_cost = case query.from do
      :functions -> 60  # Increased from 50
      :modules -> 35    # Increased from 25
      :patterns -> 120  # Increased from 100
    end
    
    # Adjust for where conditions
    where_cost = length(query.where || []) * 20  # Increased from 15
    
    # Adjust for joins
    join_cost = length(query.joins || []) * 40  # Increased from 30
    
    # Adjust for complex operations
    complex_ops_count = count_complex_operations(query.where || [])
    complex_cost = complex_ops_count * 80  # Increased from 75
    
    # Adjust for order_by complexity
    order_cost = case query.order_by do
      nil -> 0
      list when is_list(list) -> length(list) * 15  # Increased from 10
      _ -> 8  # Increased from 5
    end
    
    total_cost = base_cost + where_cost + join_cost + complex_cost + order_cost
    
    %{query | estimated_cost: total_cost}
  end
  
  defp count_complex_operations(conditions) do
    Enum.reduce(conditions, 0, fn condition, acc ->
      case condition do
        {_field, :similar_to, _value} -> 
          acc + 1
        {:similar_to, _value} -> 
          acc + 1
        {_field, :matches, _value} -> 
          acc + 1
        {:matches, _value} -> 
          acc + 1
        {:and, sub_conditions} -> 
          acc + count_complex_operations(sub_conditions)
        {:or, sub_conditions} -> 
          acc + count_complex_operations(sub_conditions)
        {:not, condition} -> 
          acc + count_complex_operations([condition])
        _ -> 
          acc
      end
    end)
  end
  
  defp generate_optimization_hints(%__MODULE__{} = query) do
    hints = []
    
    # Suggest adding limits for large result sets
    hints = if is_nil(query.limit) and query.estimated_cost > 80 do
      ["Consider adding a LIMIT clause to reduce memory usage" | hints]
    else
      hints
    end
    
    # Suggest indexing for complex where conditions (lowered from > 3 to >= 3)
    hints = if length(query.where || []) >= 3 do
      ["Complex WHERE conditions detected - ensure proper indexing" | hints]
    else
      hints
    end
    
    # Suggest caching for expensive queries (lowered from > 200 to > 120)
    hints = if query.estimated_cost > 120 do
      ["High-cost query detected - results will be cached" | hints]
    else
      hints
    end
    
    %{query | optimization_hints: hints}
  end
  
  defp apply_optimizations(%__MODULE__{} = query) do
    query
    |> apply_index_optimization()
    |> apply_limit_optimization()
    |> apply_order_optimization()
  end
  
  defp apply_index_optimization(%__MODULE__{} = query) do
    # Reorder WHERE conditions to use most selective filters first
    optimized_where = optimize_where_conditions(query.where || [])
    %{query | where: optimized_where}
  end
  
  defp apply_limit_optimization(%__MODULE__{} = query) do
    # Add default limit for expensive queries without one
    if is_nil(query.limit) and query.estimated_cost > 120 do
      %{query | limit: 1000}
    else
      query
    end
  end
  
  defp apply_order_optimization(%__MODULE__{} = query) do
    # Optimize ORDER BY to use available indexes
    query
  end
  
  defp optimize_where_conditions(conditions) do
    # Sort conditions by selectivity (most selective first)
    Enum.sort(conditions, &condition_selectivity/2)
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
  
  defp condition_selectivity({:and, _conditions1}, {:or, _conditions2}) do
    selectivity_score(:and) >= selectivity_score(:or)
  end
  
  defp condition_selectivity({:or, _conditions1}, {:and, _conditions2}) do
    selectivity_score(:or) >= selectivity_score(:and)
  end
  
  defp condition_selectivity({:and, _conditions1}, {:and, _conditions2}) do
    true  # Equal selectivity
  end
  
  defp condition_selectivity({:or, _conditions1}, {:or, _conditions2}) do
    true  # Equal selectivity
  end
  
  defp condition_selectivity({:not, _condition1}, {:not, _condition2}) do
    true  # Equal selectivity
  end
  
  defp condition_selectivity(_condition1, _condition2) do
    true  # Default case for unknown conditions
  end
  
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
  defp selectivity_score(:and), do: 7  # AND is quite selective
  defp selectivity_score(:or), do: 3   # OR is less selective
  defp selectivity_score(:not), do: 2  # NOT is moderately selective
  defp selectivity_score(_), do: 0
  
  defp execute_optimized_query(repo, %__MODULE__{} = query) do
    # Check cache first
    case check_cache(query.cache_key) do
      {:hit, cached_result} ->
        {:ok, Map.put(cached_result, :cache_hit, true)}
      
      :miss ->
        case execute_query_against_repo(repo, query) do
          {:ok, result} ->
            # Cache the result
            cache_result(query.cache_key, result)
            {:ok, Map.put(result, :cache_hit, false)}
          
          error -> error
        end
    end
  end
  
  defp execute_query_against_repo(repo, %__MODULE__{} = query) do
    case query.from do
      :functions -> execute_function_query(repo, query)
      :modules -> execute_module_query(repo, query)
      :patterns -> execute_pattern_query(repo, query)
    end
  end
  
  defp execute_function_query(repo, %__MODULE__{} = query) do
    # Get all functions from repository
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
  
  defp execute_module_query(repo, %__MODULE__{} = query) do
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
  
  defp execute_pattern_query(_repo, %__MODULE__{} = _query) do
    # Pattern queries will be handled by PatternMatcher
    {:error, :pattern_queries_not_implemented}
  end
  
  defp get_all_functions(repo) do
    # Validate repository before attempting to query
    case validate_repository(repo) do
      :ok ->
        # This would integrate with the Enhanced Repository to get all functions
        # For now, return a placeholder for valid repositories
        {:ok, []}
      error -> error
    end
  end
  
  defp get_all_modules(repo) do
    # Validate repository before attempting to query
    case validate_repository(repo) do
      :ok ->
        # This would integrate with the Enhanced Repository to get all modules
        # For now, return a placeholder for valid repositories
        {:ok, []}
      error -> error
    end
  end
  
  defp validate_repository(repo) when is_pid(repo) do
    # Check if the process is alive
    if Process.alive?(repo) do
      :ok
    else
      {:error, :repository_not_available}
    end
  end
  
  defp validate_repository(repo) when is_atom(repo) do
    # Check if it's a registered process
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
  
  defp validate_repository(_repo) do
    {:error, :invalid_repository}
  end
  
  defp apply_where_filters(data, []), do: data
  defp apply_where_filters(data, conditions) do
    Enum.filter(data, fn item ->
      evaluate_conditions(item, conditions)
    end)
  end
  
  defp evaluate_conditions(item, conditions) do
    Enum.all?(conditions, fn condition ->
      evaluate_condition(item, condition)
    end)
  end
  
  defp evaluate_condition_internal(item, {field, :eq, value}) do
    Map.get(item, field) == value
  end
  
  defp evaluate_condition_internal(item, {field, :ne, value}) do
    Map.get(item, field) != value
  end
  
  defp evaluate_condition_internal(item, {field, :gt, value}) do
    case Map.get(item, field) do
      nil -> false
      item_value -> item_value > value
    end
  end
  
  defp evaluate_condition_internal(item, {field, :lt, value}) do
    case Map.get(item, field) do
      nil -> false
      item_value -> item_value < value
    end
  end
  
  defp evaluate_condition_internal(item, {field, :gte, value}) do
    case Map.get(item, field) do
      nil -> false
      item_value -> item_value >= value
    end
  end
  
  defp evaluate_condition_internal(item, {field, :lte, value}) do
    case Map.get(item, field) do
      nil -> false
      item_value -> item_value <= value
    end
  end
  
  defp evaluate_condition_internal(item, {field, :in, values}) when is_list(values) do
    case Map.get(item, field) do
      list when is_list(list) -> 
        # Check if any value in the field list is in the condition values
        Enum.any?(list, &(&1 in values))
      single_value -> 
        # Check if the single field value is in the condition values
        single_value in values
    end
  end
  
  defp evaluate_condition_internal(item, {field, :not_in, values}) when is_list(values) do
    case Map.get(item, field) do
      list when is_list(list) -> 
        # Check if no value in the field list is in the condition values
        not Enum.any?(list, &(&1 in values))
      single_value -> 
        # Check if the single field value is not in the condition values
        single_value not in values
    end
  end
  
  defp evaluate_condition_internal(item, {field, :contains, value}) do
    case Map.get(item, field) do
      list when is_list(list) -> value in list
      string when is_binary(string) -> String.contains?(string, to_string(value))
      _ -> false
    end
  end
  
  defp evaluate_condition_internal(item, {field, :not_contains, value}) do
    not evaluate_condition_internal(item, {field, :contains, value})
  end
  
  defp evaluate_condition_internal(item, {field, :matches, pattern}) do
    case Map.get(item, field) do
      string when is_binary(string) ->
        case Regex.compile(pattern) do
          {:ok, regex} -> Regex.match?(regex, string)
          _ -> false
        end
      _ -> false
    end
  end
  
  defp evaluate_condition_internal(item, {field, :similar_to, {module, function, arity}}) do
    # Placeholder for semantic similarity - would integrate with AI analysis
    case Map.get(item, field) do
      {^module, ^function, ^arity} -> true
      _ -> false
    end
  end
  
  defp evaluate_condition_internal(item, {field, :not_nil, _value}) do
    Map.get(item, field) != nil
  end
  
  defp evaluate_condition_internal(item, {field, :not_nil}) do
    Map.get(item, field) != nil
  end
  
  defp evaluate_condition_internal(item, {field, :nil, _value}) do
    Map.get(item, field) == nil
  end
  
  defp evaluate_condition_internal(item, {field, :nil}) do
    Map.get(item, field) == nil
  end
  
  defp evaluate_condition_internal(item, {:similar_to, {module, function, arity}}) do
    # Handle special case where similar_to is the first element
    # This would typically compare the entire item/function to the target
    case Map.get(item, :mfa) || {Map.get(item, :module), Map.get(item, :function), Map.get(item, :arity)} do
      {^module, ^function, ^arity} -> true
      _ -> false
    end
  end
  
  defp evaluate_condition_internal(item, {:similarity_threshold, threshold}) do
    # Handle similarity threshold - would integrate with AI analysis
    case Map.get(item, :similarity_score) do
      nil -> false
      score -> score >= threshold
    end
  end
  
  defp evaluate_condition_internal(item, {:and, conditions}) do
    Enum.all?(conditions, &evaluate_condition_internal(item, &1))
  end
  
  defp evaluate_condition_internal(item, {:or, conditions}) do
    Enum.any?(conditions, &evaluate_condition_internal(item, &1))
  end
  
  defp evaluate_condition_internal(item, {:not, condition}) do
    not evaluate_condition_internal(item, condition)
  end
  
  defp evaluate_condition_internal(_item, _condition), do: false
  
  defp apply_ordering_internal(data, nil), do: data
  defp apply_ordering_internal(data, {field, :asc}) do
    Enum.sort_by(data, &Map.get(&1, field, 0))
  end
  defp apply_ordering_internal(data, {field, :desc}) do
    Enum.sort_by(data, &Map.get(&1, field, 0), :desc)
  end
  defp apply_ordering_internal(data, {:asc, field}) do
    Enum.sort_by(data, &Map.get(&1, field, 0))
  end
  defp apply_ordering_internal(data, {:desc, field}) do
    Enum.sort_by(data, &Map.get(&1, field, 0), :desc)
  end
  defp apply_ordering_internal(data, order_specs) when is_list(order_specs) do
    Enum.reduce(order_specs, data, fn order_spec, acc ->
      apply_ordering_internal(acc, order_spec)
    end)
  end
  
  defp apply_limit_offset_internal(data, nil, 0), do: data
  defp apply_limit_offset_internal(data, nil, offset), do: Enum.drop(data, offset)
  defp apply_limit_offset_internal(data, limit, 0), do: Enum.take(data, limit)
  defp apply_limit_offset_internal(data, limit, offset) do
    data |> Enum.drop(offset) |> Enum.take(limit)
  end
  
  defp apply_select_internal(data, :all), do: data
  defp apply_select_internal(data, fields) when is_list(fields) do
    Enum.map(data, fn item ->
      Map.take(item, fields)
    end)
  end
  
  defp check_cache(cache_key) do
    case :ets.lookup(@table_name, cache_key) do
      [{^cache_key, result, timestamp}] ->
        if System.monotonic_time(:millisecond) - timestamp < @cache_ttl do
          {:hit, result}
        else
          :ets.delete(@table_name, cache_key)
          :miss
        end
      
      [] -> :miss
    end
  end
  
  defp cache_result(cache_key, result) do
    timestamp = System.monotonic_time(:millisecond)
    :ets.insert(@table_name, {cache_key, result, timestamp})
  end
  
  defp cleanup_expired_cache() do
    current_time = System.monotonic_time(:millisecond)
    
    :ets.foldl(fn {key, _result, timestamp}, acc ->
      if current_time - timestamp >= @cache_ttl do
        :ets.delete(@table_name, key)
      end
      acc
    end, nil, @table_name)
  end
  
  defp update_performance_stats(state, execution_time) do
    current_stats = state.query_stats
    new_total = current_stats.total + 1
    new_avg = (current_stats.avg_time * current_stats.total + execution_time) / new_total
    
    updated_stats = %{
      total: new_total,
      avg_time: new_avg
    }
    
    %{state | query_stats: updated_stats}
  end
  
  defp add_execution_metadata(result, execution_time, query) do
    performance_score = cond do
      execution_time <= @simple_query_threshold -> :excellent
      execution_time <= @complex_query_threshold -> :good
      execution_time <= @complex_query_threshold * 2 -> :fair
      true -> :poor
    end
    
    metadata = %{
      execution_time_ms: execution_time,
      cache_hit: Map.get(result, :cache_hit, false),
      optimization_applied: query.optimization_hints || [],
      performance_score: performance_score,
      estimated_cost: query.estimated_cost
    }
    
    Map.put(result, :metadata, metadata)
  end
end 