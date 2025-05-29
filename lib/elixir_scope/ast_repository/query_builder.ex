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

  alias ElixirScope.ASTRepository.QueryBuilder.{
    Types,
    Normalizer,
    Validator,
    Optimizer,
    Executor,
    Cache
  }

  defstruct [
    :cache_pid,
    :opts
  ]

  # GenServer API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Ensure the cache is available - either already started or start it now
    ensure_cache_started()

    state = %__MODULE__{
      cache_pid: nil,  # We'll use the named process
      opts: opts
    }

    Logger.info("QueryBuilder started with caching enabled")
    {:ok, state}
  end

  def handle_call({:execute_query, repo, query_spec}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    case execute_query_internal(repo, query_spec) do
      {:ok, result} ->
        end_time = System.monotonic_time(:millisecond)
        execution_time = end_time - start_time

        # Record performance
        Cache.record_performance(execution_time)

        # Add metadata to result
        result_with_metadata = add_execution_metadata(result, execution_time, query_spec)

        {:reply, {:ok, result_with_metadata}, state}

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
    case Cache.get_stats() do
      {:ok, %{cache: cache_stats, performance: _perf_stats}} ->
        {:reply, {:ok, cache_stats}, state}
      {:ok, stats} ->
        {:reply, {:ok, stats}, state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:clear_cache, _from, state) do
    case Cache.clear() do
      :ok -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
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
      {:ok, %Types{...}}
  """
  @spec build_query(map() | keyword()) :: {:ok, Types.query_t()} | {:error, term()}
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
  @spec execute_query(pid() | atom(), map() | Types.query_t()) :: {:ok, Types.query_result()} | {:error, term()}
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

  # Public functions for testing and direct access

  @doc false
  def evaluate_condition(item, condition) do
    Executor.evaluate_condition(item, condition)
  end

  @doc false
  def apply_ordering(data, order_spec) do
    Executor.apply_ordering(data, order_spec)
  end

  @doc false
  def apply_limit_offset(data, limit, offset) do
    Executor.apply_limit_offset(data, limit, offset)
  end

  @doc false
  def apply_select(data, fields) do
    Executor.apply_select(data, fields)
  end

  # Private Implementation

  defp ensure_cache_started() do
    case Process.whereis(Cache) do
      nil ->
        # Cache not started, try to start it
        case Cache.start_link() do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          error -> error
        end
      _pid ->
        # Cache already running
        :ok
    end
  end

  defp execute_query_internal(repo, query_spec) do
    with {:ok, query} <- Normalizer.normalize_query(query_spec),
         {:ok, validated_query} <- Validator.validate_query(query),
         {:ok, optimized_query} <- Optimizer.optimize_query(validated_query),
         {:ok, result} <- execute_optimized_query(repo, optimized_query) do
      {:ok, result}
    else
      error -> error
    end
  end

  defp build_query_internal(query_spec) do
    with {:ok, query} <- Normalizer.normalize_query(query_spec),
         {:ok, validated_query} <- Validator.validate_query(query),
         {:ok, optimized_query} <- Optimizer.optimize_query(validated_query) do
      {:ok, optimized_query}
    else
      error -> error
    end
  end

  defp execute_optimized_query(repo, %Types{} = query) do
    # Check cache first if we have a cache key
    case query.cache_key do
      nil ->
        # No cache key, execute directly
        execute_against_repo(repo, query)

      cache_key ->
        case Cache.get(cache_key) do
          {:hit, cached_result} ->
            {:ok, Map.put(cached_result, :cache_hit, true)}

          :miss ->
            case execute_against_repo(repo, query) do
              {:ok, result} ->
                # Cache the result
                Cache.put(cache_key, result)
                {:ok, Map.put(result, :cache_hit, false)}

              error -> error
            end
        end
    end
  end

  defp execute_against_repo(repo, %Types{} = query) do
    Executor.execute_query(repo, query)
  end

  defp add_execution_metadata(result, execution_time, query_spec) do
    # Determine performance score based on execution time
    performance_score = cond do
      execution_time <= Types.simple_query_threshold() -> :excellent
      execution_time <= Types.complex_query_threshold() -> :good
      execution_time <= Types.complex_query_threshold() * 2 -> :fair
      true -> :poor
    end

    # Extract optimization hints and estimated cost from query if it's a Types struct
    {optimization_hints, estimated_cost} = case query_spec do
      %Types{optimization_hints: hints, estimated_cost: cost} -> {hints || [], cost}
      _ -> {[], nil}
    end

    metadata = %{
      execution_time_ms: execution_time,
      cache_hit: Map.get(result, :cache_hit, false),
      optimization_applied: optimization_hints,
      performance_score: performance_score,
      estimated_cost: estimated_cost
    }

    Map.put(result, :metadata, metadata)
  end
end
