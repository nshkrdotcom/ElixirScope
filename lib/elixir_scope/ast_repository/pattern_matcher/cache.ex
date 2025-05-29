defmodule ElixirScope.ASTRepository.PatternMatcher.Cache do
  @moduledoc """
  Caching layer for pattern matching results to improve performance.
  """
  
  use GenServer
  require Logger
  
  alias ElixirScope.ASTRepository.PatternMatcher.Config
  
  @cache_table :pattern_match_cache
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    if Config.get(:enable_pattern_cache) do
      :ets.new(@cache_table, [:named_table, :public, :set, {:read_concurrency, true}])
      schedule_cleanup()
    end
    
    {:ok, %{cleanup_timer: nil}}
  end
  
  @spec get(term()) :: {:ok, term()} | :not_found
  def get(key) do
    if Config.get(:enable_pattern_cache) do
      case :ets.lookup(@cache_table, key) do
        [{^key, value, timestamp}] ->
          if cache_expired?(timestamp) do
            :ets.delete(@cache_table, key)
            :not_found
          else
            {:ok, value}
          end
        [] ->
          :not_found
      end
    else
      :not_found
    end
  end
  
  @spec put(term(), term()) :: :ok
  def put(key, value) do
    if Config.get(:enable_pattern_cache) do
      timestamp = System.system_time(:second)
      :ets.insert(@cache_table, {key, value, timestamp})
    end
    :ok
  end
  
  @spec clear() :: :ok
  def clear do
    if Config.get(:enable_pattern_cache) do
      :ets.delete_all_objects(@cache_table)
    end
    :ok
  end
  
  def handle_info(:cleanup_expired, state) do
    cleanup_expired_entries()
    schedule_cleanup()
    {:noreply, state}
  end
  
  defp cache_expired?(timestamp) do
    ttl_seconds = Config.get(:cache_ttl_minutes) * 60
    System.system_time(:second) - timestamp > ttl_seconds
  end
  
  defp schedule_cleanup do
    # Run cleanup every 5 minutes
    Process.send_after(self(), :cleanup_expired, 5 * 60 * 1000)
  end
  
  defp cleanup_expired_entries do
    if Config.get(:enable_pattern_cache) do
      current_time = System.system_time(:second)
      ttl_seconds = Config.get(:cache_ttl_minutes) * 60
      
      expired_keys = :ets.select(@cache_table, [
        {{'$1', '_', '$3'}, [{:'<', '$3', current_time - ttl_seconds}], ['$1']}
      ])
      
      Enum.each(expired_keys, fn key ->
        :ets.delete(@cache_table, key)
      end)
      
      if length(expired_keys) > 0 do
        Logger.debug("Cleaned up #{length(expired_keys)} expired cache entries")
      end
    end
  end
end
