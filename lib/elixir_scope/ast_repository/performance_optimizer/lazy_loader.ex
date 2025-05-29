# ==============================================================================
# Lazy Loading Component
# ==============================================================================

defmodule ElixirScope.ASTRepository.PerformanceOptimizer.LazyLoader do
  @moduledoc """
  Manages lazy loading of expensive analysis data like CFG and DFG.
  """

  use GenServer

  alias ElixirScope.ASTRepository.{MemoryManager, EnhancedRepository}

  @function_cache_prefix "function:"
  @lazy_loading_threshold 1000  # bytes

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{}}
  end

  @doc """
  Retrieves function with lazy analysis loading.
  """
  @spec get_function_lazy(atom(), atom(), non_neg_integer()) :: {:ok, term()} | {:error, term()}
  def get_function_lazy(module_name, function_name, arity) do
    cache_key = @function_cache_prefix <> "#{module_name}.#{function_name}/#{arity}"

    case MemoryManager.cache_get(:analysis, cache_key) do
      {:ok, cached_data} ->
        track_access({module_name, function_name, arity}, :cache_hit)
        {:ok, cached_data}

      :miss ->
        case EnhancedRepository.get_enhanced_function(module_name, function_name, arity) do
          {:ok, function_data} ->
            optimized_data = apply_lazy_loading(function_data)
            MemoryManager.cache_put(:analysis, cache_key, optimized_data)
            track_access({module_name, function_name, arity}, :cache_miss)
            {:ok, optimized_data}

          error ->
            error
        end
    end
  end

  @doc """
  Stores function with lazy analysis optimization.
  """
  @spec store_function_lazy(atom(), atom(), non_neg_integer(), term(), keyword()) :: {:ok, term()} | {:error, term()}
  def store_function_lazy(module_name, function_name, arity, ast, opts) do
    ast_size = estimate_ast_size(ast)

    if ast_size > @lazy_loading_threshold do
      lazy_opts = Keyword.put(opts, :lazy_analysis, true)
      EnhancedRepository.store_enhanced_function(module_name, function_name, arity, ast, lazy_opts)
    else
      EnhancedRepository.store_enhanced_function(module_name, function_name, arity, ast, opts)
    end
  end

  # Private implementation
  defp apply_lazy_loading(function_data) do
    cond do
      is_nil(function_data.cfg_data) and should_load_cfg?(function_data) ->
        case EnhancedRepository.get_cfg(function_data.module_name, function_data.function_name, function_data.arity) do
          {:ok, cfg} -> %{function_data | cfg_data: cfg}
          _ -> function_data
        end

      is_nil(function_data.dfg_data) and should_load_dfg?(function_data) ->
        case EnhancedRepository.get_dfg(function_data.module_name, function_data.function_name, function_data.arity) do
          {:ok, dfg} -> %{function_data | dfg_data: dfg}
          _ -> function_data
        end

      true ->
        function_data
    end
  end

  defp should_load_cfg?(function_data) do
    complexity = get_function_complexity(function_data)
    access_count = get_access_count({function_data.module_name, function_data.function_name, function_data.arity})

    complexity > 5 or access_count > 10
  end

  defp should_load_dfg?(function_data) do
    has_variables = function_has_variables?(function_data.ast)
    access_count = get_access_count({function_data.module_name, function_data.function_name, function_data.arity})

    has_variables and access_count > 5
  end

  defp estimate_ast_size(ast) do
    :erlang.external_size(ast)
  end

  defp get_function_complexity(function_data) do
    case function_data.complexity_metrics do
      %{cyclomatic_complexity: complexity} -> complexity
      _ -> 1
    end
  end

  defp function_has_variables?(ast) do
    is_tuple(ast) and tuple_size(ast) > 0
  end

  defp get_access_count(identifier) do
    case :ets.lookup(:ast_repo_access_tracking, identifier) do
      [{^identifier, _last_access, access_count}] -> access_count
      [] -> 0
    end
  end

  defp track_access(identifier, access_type) do
    current_time = System.monotonic_time(:second)

    case :ets.lookup(:ast_repo_access_tracking, identifier) do
      [{^identifier, _last_access, access_count}] ->
        new_count = if access_type == :cache_hit, do: access_count + 1, else: access_count
        :ets.insert(:ast_repo_access_tracking, {identifier, current_time, new_count})

      [] ->
        :ets.insert(:ast_repo_access_tracking, {identifier, current_time, 1})
    end
  end
end
