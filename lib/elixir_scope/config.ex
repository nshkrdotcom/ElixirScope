defmodule ElixirScope.Config do
  @moduledoc """
  Configuration management for ElixirScope.

  Handles loading, validation, and runtime access to ElixirScope configuration.
  Supports configuration from multiple sources:
  - Application environment (config.exs files)
  - Environment variables
  - Runtime configuration updates

  The configuration is validated on startup and cached for fast access.
  """

  use GenServer

  require Logger

  # Configuration structure
  defstruct [
    # AI Configuration
    ai: %{
      provider: :mock,
      api_key: nil,
      model: "gpt-4",
      analysis: %{
        max_file_size: 1_000_000,
        timeout: 30_000,
        cache_ttl: 3600
      },
      planning: %{
        default_strategy: :balanced,
        performance_target: 0.01,
        sampling_rate: 1.0
      }
    },

    # Capture Configuration
    capture: %{
      ring_buffer: %{
        size: 1_048_576,
        max_events: 100_000,
        overflow_strategy: :drop_oldest,
        num_buffers: :schedulers
      },
      processing: %{
        batch_size: 1000,
        flush_interval: 100,
        max_queue_size: 10_000
      },
      vm_tracing: %{
        enable_spawn_trace: true,
        enable_exit_trace: true,
        enable_message_trace: false,
        trace_children: true
      }
    },

    # Storage Configuration
    storage: %{
      hot: %{
        max_events: 1_000_000,
        max_age_seconds: 3600,
        prune_interval: 60_000
      },
      warm: %{
        enable: false,
        path: "./elixir_scope_data",
        max_size_mb: 1000,
        compression: :zstd
      },
      cold: %{
        enable: false
      }
    },

    # Interface Configuration
    interface: %{
      iex_helpers: true,
      query_timeout: 5000,
      web: %{
        enable: false,
        port: 4000
      }
    },

    # Instrumentation Configuration
    instrumentation: %{
      default_level: :function_boundaries,
      module_overrides: %{},
      function_overrides: %{},
      exclude_modules: [ElixirScope, :logger, :gen_server, :supervisor]
    }
  ]

  #############################################################################
  # Public API
  #############################################################################

  @doc """
  Starts the configuration server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the current configuration.
  """
  def get() do
    GenServer.call(__MODULE__, :get_config)
  end

  @doc """
  Gets a specific configuration value by path.
  
  ## Examples
  
      iex> ElixirScope.Config.get([:ai, :provider])
      :mock
      
      iex> ElixirScope.Config.get([:capture, :ring_buffer, :size])
      1048576
  """
  def get(path) when is_list(path) do
    GenServer.call(__MODULE__, {:get_config_path, path})
  end

  @doc """
  Updates configuration at runtime (for specific allowed keys).
  """
  def update(path, value) when is_list(path) do
    GenServer.call(__MODULE__, {:update_config, path, value})
  end

  @doc """
  Validates a configuration structure.
  Returns {:ok, config} or {:error, reasons}.
  """
  def validate(config) do
    with :ok <- validate_ai_config(config.ai),
         :ok <- validate_capture_config(config.capture),
         :ok <- validate_storage_config(config.storage),
         :ok <- validate_interface_config(config.interface),
         :ok <- validate_instrumentation_config(config.instrumentation) do
      {:ok, config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  #############################################################################
  # GenServer Callbacks
  #############################################################################

  @impl true
  def init(_opts) do
    case load_and_validate_config() do
      {:ok, config} ->
        Logger.info("ElixirScope configuration loaded and validated successfully")
        {:ok, config}
      
      {:error, reason} ->
        Logger.error("Failed to load ElixirScope configuration: #{inspect(reason)}")
        {:stop, {:config_error, reason}}
    end
  end

  @impl true
  def handle_call(:get_config, _from, config) do
    {:reply, config, config}
  end

  @impl true
  def handle_call({:get_config_path, path}, _from, config) do
    value = get_config_path(config, path)
    {:reply, value, config}
  end

  @impl true
  def handle_call({:update_config, path, value}, _from, config) do
    if updatable_path?(path) do
      case update_config_path(config, path, value) do
        {:ok, new_config} ->
          case validate(new_config) do
            {:ok, validated_config} ->
              Logger.info("Configuration updated: #{inspect(path)} = #{inspect(value)}")
              {:reply, :ok, validated_config}
            
            {:error, reason} ->
              Logger.warning("Configuration update rejected: #{inspect(reason)}")
              {:reply, {:error, reason}, config}
          end
        
        {:error, reason} ->
          {:reply, {:error, reason}, config}
      end
    else
      {:reply, {:error, :not_updatable}, config}
    end
  end

  #############################################################################
  # Private Functions
  #############################################################################

  defp load_and_validate_config() do
    config = 
      %__MODULE__{}
      |> merge_application_env()
      |> merge_environment_variables()

    validate(config)
  end

  defp merge_application_env(config) do
    app_config = Application.get_all_env(:elixir_scope)
    merge_config(config, app_config)
  end

  defp merge_environment_variables(config) do
    # Support for key environment variables
    config
    |> maybe_update_from_env("ELIXIR_SCOPE_AI_PROVIDER", [:ai, :provider], &String.to_atom/1)
    |> maybe_update_from_env("ELIXIR_SCOPE_AI_API_KEY", [:ai, :api_key], &Function.identity/1)
    |> maybe_update_from_env("ELIXIR_SCOPE_LOG_LEVEL", [:log_level], &String.to_atom/1)
  end

  defp maybe_update_from_env(config, env_var, path, transform_fn) do
    case System.get_env(env_var) do
      nil -> config
      value -> 
        try do
          transformed_value = transform_fn.(value)
          case update_config_path(config, path, transformed_value) do
            {:ok, updated_config} -> updated_config
            {:error, _} -> 
              Logger.warning("Invalid environment variable #{env_var}: #{value}")
              config
          end
        rescue
          _ -> 
            Logger.warning("Invalid environment variable #{env_var}: #{value}")
            config
        end
    end
  end

  defp merge_config(config, app_config) do
    Enum.reduce(app_config, config, fn {key, value}, acc ->
      case key do
        :ai -> %{acc | ai: merge_nested_config(acc.ai, value)}
        :capture -> %{acc | capture: merge_nested_config(acc.capture, value)}
        :storage -> %{acc | storage: merge_nested_config(acc.storage, value)}
        :interface -> %{acc | interface: merge_nested_config(acc.interface, value)}
        :instrumentation -> %{acc | instrumentation: merge_nested_config(acc.instrumentation, value)}
        _ -> acc  # Ignore unknown keys
      end
    end)
  end

  defp merge_nested_config(base, overrides) when is_map(base) and is_list(overrides) do
    Enum.reduce(overrides, base, fn {key, value}, acc ->
      if is_list(value) and Map.has_key?(acc, key) and is_map(Map.get(acc, key)) do
        # Convert keyword list to map and merge recursively
        value_map = Enum.into(value, %{})
        Map.put(acc, key, merge_nested_config(Map.get(acc, key), value_map))
      else
        Map.put(acc, key, value)
      end
    end)
  end

  defp merge_nested_config(base, overrides) when is_map(base) and is_map(overrides) do
    Map.merge(base, overrides, fn _key, base_value, override_value ->
      if is_map(base_value) and is_map(override_value) do
        merge_nested_config(base_value, override_value)
      else
        override_value
      end
    end)
  end

  defp merge_nested_config(_base, overrides), do: overrides

  # Validation functions
  defp validate_ai_config(ai_config) do
    with :ok <- validate_required_keys(ai_config, [:provider]),
         :ok <- validate_ai_provider(ai_config.provider),
         :ok <- validate_positive_integer(ai_config.analysis.max_file_size, "ai.analysis.max_file_size"),
         :ok <- validate_positive_integer(ai_config.analysis.timeout, "ai.analysis.timeout"),
         :ok <- validate_positive_integer(ai_config.analysis.cache_ttl, "ai.analysis.cache_ttl"),
         :ok <- validate_strategy(ai_config.planning.default_strategy),
         :ok <- validate_percentage(ai_config.planning.performance_target, "ai.planning.performance_target"),
         :ok <- validate_percentage(ai_config.planning.sampling_rate, "ai.planning.sampling_rate") do
      :ok
    end
  end

  defp validate_capture_config(capture_config) do
    with :ok <- validate_positive_integer(capture_config.ring_buffer.size, "capture.ring_buffer.size"),
         :ok <- validate_positive_integer(capture_config.ring_buffer.max_events, "capture.ring_buffer.max_events"),
         :ok <- validate_overflow_strategy(capture_config.ring_buffer.overflow_strategy),
         :ok <- validate_positive_integer(capture_config.processing.batch_size, "capture.processing.batch_size"),
         :ok <- validate_positive_integer(capture_config.processing.flush_interval, "capture.processing.flush_interval") do
      :ok
    end
  end

  defp validate_storage_config(storage_config) do
    with :ok <- validate_positive_integer(storage_config.hot.max_events, "storage.hot.max_events"),
         :ok <- validate_positive_integer(storage_config.hot.max_age_seconds, "storage.hot.max_age_seconds"),
         :ok <- validate_positive_integer(storage_config.hot.prune_interval, "storage.hot.prune_interval") do
      :ok
    end
  end

  defp validate_interface_config(interface_config) do
    with :ok <- validate_positive_integer(interface_config.query_timeout, "interface.query_timeout") do
      :ok
    end
  end

  defp validate_instrumentation_config(instr_config) do
    with :ok <- validate_instrumentation_level(instr_config.default_level) do
      :ok
    end
  end

  # Validation helpers
  defp validate_required_keys(map, keys) do
    missing = Enum.filter(keys, fn key -> not Map.has_key?(map, key) end)
    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required keys: #{inspect(missing)}"}
    end
  end

  defp validate_positive_integer(value, _field) when is_integer(value) and value > 0, do: :ok
  defp validate_positive_integer(_value, field), do: {:error, "#{field} must be a positive integer"}

  defp validate_percentage(value, _field) when is_number(value) and value >= 0 and value <= 1, do: :ok
  defp validate_percentage(_value, field), do: {:error, "#{field} must be a number between 0 and 1"}

  defp validate_ai_provider(provider) when provider in [:mock, :openai, :anthropic], do: :ok
  defp validate_ai_provider(_), do: {:error, "ai.provider must be one of [:mock, :openai, :anthropic]"}

  defp validate_strategy(strategy) when strategy in [:minimal, :balanced, :full_trace], do: :ok
  defp validate_strategy(_), do: {:error, "planning strategy must be one of [:minimal, :balanced, :full_trace]"}

  defp validate_overflow_strategy(strategy) when strategy in [:drop_oldest, :drop_newest, :block], do: :ok
  defp validate_overflow_strategy(_), do: {:error, "overflow_strategy must be one of [:drop_oldest, :drop_newest, :block]"}

  defp validate_instrumentation_level(level) when level in [:none, :function_boundaries, :full_trace], do: :ok
  defp validate_instrumentation_level(_), do: {:error, "instrumentation level must be one of [:none, :function_boundaries, :full_trace]"}

  # Custom path access functions (avoiding Access behavior issues)
  defp get_config_path(config, path) do
    try do
      Enum.reduce(path, config, fn key, acc ->
        case acc do
          %{} -> Map.get(acc, key)
          _ -> nil
        end
      end)
    rescue
      _ -> nil
    end
  end

  defp update_config_path(config, path, value) do
    try do
      {:ok, do_update_path(config, path, value)}
    rescue
      e -> {:error, "Failed to update path #{inspect(path)}: #{inspect(e)}"}
    end
  end

  defp do_update_path(config, [key], value) when is_map(config) do
    Map.put(config, key, value)
  end

  defp do_update_path(config, [key | rest], value) when is_map(config) do
    current_value = Map.get(config, key, %{})
    updated_value = do_update_path(current_value, rest, value)
    Map.put(config, key, updated_value)
  end

  # Runtime update safety
  defp updatable_path?(path) do
    # Only allow runtime updates to specific safe configuration paths
    case path do
      [:ai, :planning, :sampling_rate] -> true
      [:ai, :planning, :default_strategy] -> true
      [:capture, :processing, :batch_size] -> true
      [:capture, :processing, :flush_interval] -> true
      [:interface, :query_timeout] -> true
      _ -> false
    end
  end
end 