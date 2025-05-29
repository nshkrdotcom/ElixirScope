defmodule ElixirScope.ASTRepository.MemoryManager.Config do
  @moduledoc """
  Configuration management for the Memory Manager subsystem.

  Centralizes all configuration options and provides runtime
  configuration updates with validation.
  """

  @doc """
  Gets the default configuration for the Memory Manager.
  """
  @spec default_config() :: map()
  def default_config() do
    %{
      # Memory monitoring configuration
      memory_check_interval: 30_000,      # 30 seconds
      monitoring_enabled: true,

      # Cleanup configuration
      cleanup_interval: 300_000,          # 5 minutes
      default_max_age: 3600,              # 1 hour
      cleanup_enabled: true,

      # Compression configuration
      compression_interval: 600_000,      # 10 minutes
      compression_level: 6,               # zlib compression level
      compression_enabled: true,
      access_threshold: 5,                # Minimum accesses to avoid compression
      age_threshold: 1800,                # 30 minutes before compression eligible

      # Cache configuration
      query_cache_ttl: 60_000,           # 1 minute
      analysis_cache_ttl: 300_000,       # 5 minutes
      cpg_cache_ttl: 600_000,            # 10 minutes
      max_cache_entries: 1000,
      cache_enabled: true,

      # Memory pressure thresholds (percentage)
      memory_pressure_level_1: 80,
      memory_pressure_level_2: 90,
      memory_pressure_level_3: 95,
      memory_pressure_level_4: 98,

      # Performance targets
      target_memory_usage_mb: 500,       # <500MB for 1000 modules
      target_query_response_ms: 100,     # <100ms for 95th percentile
      target_cache_hit_ratio: 0.80,      # >80% for repeated queries
      target_cleanup_duration_ms: 10,    # <10ms per cleanup cycle

      # Logging and debugging
      log_level: :info,
      debug_enabled: false,
      metrics_enabled: true
    }
  end

  @doc """
  Gets the current runtime configuration.

  Merges default configuration with application environment
  and any runtime overrides.
  """
  @spec get_config() :: map()
  def get_config() do
    default_config()
    |> Map.merge(get_application_config())
    |> Map.merge(get_runtime_config())
  end

  @doc """
  Updates runtime configuration with validation.
  """
  @spec update_config(map()) :: {:ok, map()} | {:error, term()}
  def update_config(updates) when is_map(updates) do
    current = get_config()
    new_config = Map.merge(current, updates)

    case validate_config(new_config) do
      :ok ->
        store_runtime_config(updates)
        {:ok, new_config}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates a configuration map.
  """
  @spec validate_config(map()) :: :ok | {:error, term()}
  def validate_config(config) when is_map(config) do
    validations = [
      &validate_intervals/1,
      &validate_thresholds/1,
      &validate_cache_config/1,
      &validate_targets/1
    ]

    Enum.reduce_while(validations, :ok, fn validator, _acc ->
      case validator.(config) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  Gets a specific configuration value with optional default.
  """
  @spec get(atom(), term()) :: term()
  def get(key, default \\ nil) do
    Map.get(get_config(), key, default)
  end

  @doc """
  Sets a specific configuration value with validation.
  """
  @spec set(atom(), term()) :: {:ok, map()} | {:error, term()}
  def set(key, value) do
    update_config(%{key => value})
  end

  @doc """
  Resets configuration to defaults.
  """
  @spec reset_to_defaults() :: :ok
  def reset_to_defaults() do
    clear_runtime_config()
    :ok
  end

  @doc """
  Gets configuration schema for documentation/validation.
  """
  @spec get_schema() :: map()
  def get_schema() do
    %{
      memory_check_interval: %{
        type: :integer,
        min: 1000,
        max: 300_000,
        description: "Interval between memory checks in milliseconds"
      },
      cleanup_interval: %{
        type: :integer,
        min: 10_000,
        max: 3_600_000,
        description: "Interval between automatic cleanups in milliseconds"
      },
      compression_interval: %{
        type: :integer,
        min: 60_000,
        max: 3_600_000,
        description: "Interval between compression runs in milliseconds"
      },
      compression_level: %{
        type: :integer,
        min: 1,
        max: 9,
        description: "zlib compression level (1=fast, 9=best)"
      },
      max_cache_entries: %{
        type: :integer,
        min: 100,
        max: 100_000,
        description: "Maximum entries per cache table"
      },
      memory_pressure_level_1: %{
        type: :integer,
        min: 50,
        max: 95,
        description: "Memory usage percentage for level 1 pressure"
      }
      # Add more schema entries as needed
    }
  end

  # Private Implementation

  defp get_application_config() do
    Application.get_env(:elixir_scope, :memory_manager, %{})
  end

  defp get_runtime_config() do
    # Store runtime config in persistent term for performance
    case :persistent_term.get({__MODULE__, :runtime_config}, nil) do
      nil -> %{}
      config -> config
    end
  end

  defp store_runtime_config(config) do
    current = get_runtime_config()
    new_config = Map.merge(current, config)
    :persistent_term.put({__MODULE__, :runtime_config}, new_config)
  end

  defp clear_runtime_config() do
    :persistent_term.erase({__MODULE__, :runtime_config})
  end

  defp validate_intervals(config) do
    intervals = [
      {:memory_check_interval, 1000, 300_000},
      {:cleanup_interval, 10_000, 3_600_000},
      {:compression_interval, 60_000, 3_600_000}
    ]

    Enum.reduce_while(intervals, :ok, fn {key, min, max}, _acc ->
      case Map.get(config, key) do
        value when is_integer(value) and value >= min and value <= max ->
          {:cont, :ok}
        value when is_integer(value) ->
          {:halt, {:error, {:invalid_interval, key, value, min, max}}}
        nil ->
          {:cont, :ok}  # Optional field
        value ->
          {:halt, {:error, {:invalid_type, key, value, :integer}}}
      end
    end)
  end

  defp validate_thresholds(config) do
    thresholds = [
      :memory_pressure_level_1,
      :memory_pressure_level_2,
      :memory_pressure_level_3,
      :memory_pressure_level_4
    ]

    # Check that thresholds are in ascending order
    values = Enum.map(thresholds, fn key -> Map.get(config, key, get(key)) end)

    if values == Enum.sort(values) and Enum.all?(values, fn v -> v >= 50 and v <= 100 end) do
      :ok
    else
      {:error, {:invalid_pressure_thresholds, values}}
    end
  end

  defp validate_cache_config(config) do
    cache_configs = [
      {:query_cache_ttl, 10_000, 3_600_000},
      {:analysis_cache_ttl, 10_000, 3_600_000},
      {:cpg_cache_ttl, 10_000, 3_600_000},
      {:max_cache_entries, 10, 1_000_000}
    ]

    Enum.reduce_while(cache_configs, :ok, fn {key, min, max}, _acc ->
      case Map.get(config, key) do
        value when is_integer(value) and value >= min and value <= max ->
          {:cont, :ok}
        value when is_integer(value) ->
          {:halt, {:error, {:invalid_cache_config, key, value, min, max}}}
        nil ->
          {:cont, :ok}  # Optional field
        value ->
          {:halt, {:error, {:invalid_type, key, value, :integer}}}
      end
    end)
  end

  defp validate_targets(config) do
    targets = [
      {:target_memory_usage_mb, 1, 10_000},
      {:target_query_response_ms, 1, 10_000},
      {:target_cleanup_duration_ms, 1, 1_000}
    ]

    Enum.reduce_while(targets, :ok, fn {key, min, max}, _acc ->
      case Map.get(config, key) do
        value when is_number(value) and value >= min and value <= max ->
          {:cont, :ok}
        value when is_number(value) ->
          {:halt, {:error, {:invalid_target, key, value, min, max}}}
        nil ->
          {:cont, :ok}  # Optional field
        value ->
          {:halt, {:error, {:invalid_type, key, value, :number}}}
      end
    end)
  end
end
