defmodule ElixirScope.Capture.EnhancedInstrumentation.Storage do
  @moduledoc """
  Manages ETS storage for enhanced instrumentation data.

  This module handles all persistent storage operations for breakpoints,
  watchpoints, and related metadata using ETS tables.
  """

  @table_name :enhanced_instrumentation_main
  @breakpoint_table :enhanced_instrumentation_breakpoints
  @watchpoint_table :enhanced_instrumentation_watchpoints
  @alert_table :enhanced_instrumentation_alerts

  @doc """
  Initializes all ETS tables for enhanced instrumentation.
  """
  @spec initialize() :: :ok
  def initialize() do
    # Create ETS tables (handle existing tables gracefully)
    create_table(@table_name)
    create_table(@breakpoint_table)
    create_table(@watchpoint_table)
    create_table(@alert_table)
    :ok
  end

  @doc """
  Stores a breakpoint in the breakpoint table.
  """
  @spec store_breakpoint(String.t(), {atom(), map()}) :: :ok
  def store_breakpoint(breakpoint_id, breakpoint_data) do
    :ets.insert(@breakpoint_table, {breakpoint_id, breakpoint_data})
    :ok
  end

  @doc """
  Updates an existing breakpoint.
  """
  @spec update_breakpoint(String.t(), {atom(), map()}) :: :ok
  def update_breakpoint(breakpoint_id, breakpoint_data) do
    :ets.insert(@breakpoint_table, {breakpoint_id, breakpoint_data})
    :ok
  end

  @doc """
  Removes a breakpoint from storage.
  """
  @spec remove_breakpoint(String.t()) :: :ok
  def remove_breakpoint(breakpoint_id) do
    :ets.delete(@breakpoint_table, breakpoint_id)
    :ok
  end

  @doc """
  Gets breakpoints by type.
  """
  @spec get_breakpoints_by_type(atom()) :: list(map())
  def get_breakpoints_by_type(type) do
    :ets.select(@breakpoint_table, [
      {{:'$1', {type, :'$2'}}, [], [:'$2']}
    ])
  end

  @doc """
  Lists breakpoints by type as a map.
  """
  @spec list_breakpoints_by_type(atom()) :: map()
  def list_breakpoints_by_type(type) do
    :ets.select(@breakpoint_table, [
      {{:'$1', {type, :'$2'}}, [], [{{:'$1', :'$2'}}]}
    ]) |> Enum.into(%{})
  end

  @doc """
  Counts breakpoints by type.
  """
  @spec count_breakpoints_by_type(atom()) :: non_neg_integer()
  def count_breakpoints_by_type(type) do
    :ets.select(@breakpoint_table, [
      {{:'$1', {type, :'$2'}}, [], [:'$1']}
    ]) |> length()
  end

  @doc """
  Gets performance-based breakpoints.
  """
  @spec get_performance_breakpoints() :: list(map())
  def get_performance_breakpoints() do
    :ets.select(@breakpoint_table, [
      {{:'$1', {:structural, :'$2'}},
       [{:==, {:map_get, :condition, :'$2'}, :slow_execution}],
       [:'$2']}
    ])
  end

  @doc """
  Stores a watchpoint in the watchpoint table.
  """
  @spec store_watchpoint(String.t(), map()) :: :ok
  def store_watchpoint(watchpoint_id, watchpoint_data) do
    :ets.insert(@watchpoint_table, {watchpoint_id, watchpoint_data})
    :ok
  end

  @doc """
  Updates an existing watchpoint.
  """
  @spec update_watchpoint(String.t(), map()) :: :ok
  def update_watchpoint(watchpoint_id, watchpoint_data) do
    :ets.insert(@watchpoint_table, {watchpoint_id, watchpoint_data})
    :ok
  end

  @doc """
  Removes a watchpoint from storage.
  """
  @spec remove_watchpoint(String.t()) :: :ok
  def remove_watchpoint(watchpoint_id) do
    :ets.delete(@watchpoint_table, watchpoint_id)
    :ok
  end

  @doc """
  Gets a specific watchpoint by ID.
  """
  @spec get_watchpoint(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_watchpoint(watchpoint_id) do
    case :ets.lookup(@watchpoint_table, watchpoint_id) do
      [{^watchpoint_id, watchpoint}] -> {:ok, watchpoint}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all watchpoints.
  """
  @spec list_watchpoints() :: map()
  def list_watchpoints() do
    :ets.tab2list(@watchpoint_table) |> Enum.into(%{})
  end

  @doc """
  Gets all watchpoints as a list of tuples.
  """
  @spec get_all_watchpoints() :: list({String.t(), map()})
  def get_all_watchpoints() do
    :ets.tab2list(@watchpoint_table)
  end

  @doc """
  Counts active watchpoints.
  """
  @spec count_watchpoints() :: non_neg_integer()
  def count_watchpoints() do
    :ets.info(@watchpoint_table, :size)
  end

  @doc """
  Stores an alert in the alert table.
  """
  @spec store_alert(map()) :: :ok
  def store_alert(alert) do
    alert_id = generate_alert_id()
    timestamped_alert = Map.put(alert, :id, alert_id)
    :ets.insert(@alert_table, {alert_id, timestamped_alert})

    # Limit alert storage to prevent memory growth
    limit_alert_storage()
    :ok
  end

  @doc """
  Gets recent alerts.
  """
  @spec get_recent_alerts(non_neg_integer()) :: list(map())
  def get_recent_alerts(limit \\ 50) do
    :ets.tab2list(@alert_table)
    |> Enum.map(fn {_id, alert} -> alert end)
    |> Enum.sort_by(fn alert -> alert.timestamp end, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Clears old alerts to prevent memory growth.
  """
  @spec clear_old_alerts(non_neg_integer()) :: :ok
  def clear_old_alerts(keep_count \\ 100) do
    all_alerts = :ets.tab2list(@alert_table)

    if length(all_alerts) > keep_count do
      sorted_alerts = Enum.sort_by(all_alerts, fn {_id, alert} ->
        alert.timestamp
      end, :desc)

      {_keep, delete} = Enum.split(sorted_alerts, keep_count)

      Enum.each(delete, fn {alert_id, _alert} ->
        :ets.delete(@alert_table, alert_id)
      end)
    end

    :ok
  end

  @doc """
  Stores general key-value data in the main table.
  """
  @spec store_data(atom(), term()) :: :ok
  def store_data(key, value) do
    :ets.insert(@table_name, {key, value})
    :ok
  end

  @doc """
  Gets data from the main table.
  """
  @spec get_data(atom()) :: {:ok, term()} | {:error, :not_found}
  def get_data(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets storage statistics.
  """
  @spec get_storage_stats() :: map()
  def get_storage_stats() do
    %{
      main_table_size: :ets.info(@table_name, :size),
      breakpoints_count: :ets.info(@breakpoint_table, :size),
      watchpoints_count: :ets.info(@watchpoint_table, :size),
      alerts_count: :ets.info(@alert_table, :size),
      memory_usage: %{
        main_table: :ets.info(@table_name, :memory) * :erlang.system_info(:wordsize),
        breakpoint_table: :ets.info(@breakpoint_table, :memory) * :erlang.system_info(:wordsize),
        watchpoint_table: :ets.info(@watchpoint_table, :memory) * :erlang.system_info(:wordsize),
        alert_table: :ets.info(@alert_table, :memory) * :erlang.system_info(:wordsize)
      }
    }
  end

  @doc """
  Clears all storage tables.
  """
  @spec clear_all() :: :ok
  def clear_all() do
    :ets.delete_all_objects(@table_name)
    :ets.delete_all_objects(@breakpoint_table)
    :ets.delete_all_objects(@watchpoint_table)
    :ets.delete_all_objects(@alert_table)
    :ok
  end

  # Private Implementation

  defp create_table(table_name) do
    try do
      :ets.new(table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    rescue
      ArgumentError ->
        # Table already exists, clear it
        :ets.delete_all_objects(table_name)
    end
  end

  defp generate_alert_id() do
    "alert_" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end

  defp limit_alert_storage() do
    # Keep storage manageable by periodically clearing old alerts
    if :ets.info(@alert_table, :size) > 200 do
      clear_old_alerts(100)
    end
  end
end
