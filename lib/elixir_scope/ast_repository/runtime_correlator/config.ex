defmodule ElixirScope.ASTRepository.RuntimeCorrelator.Config do
  @moduledoc """
  Configuration settings for the RuntimeCorrelator system.

  Centralizes all configuration values, timeouts, and performance targets
  used across the RuntimeCorrelator modules.
  """

  # ETS Table Names
  @main_table :runtime_correlator_main
  @context_cache :runtime_correlator_context_cache
  @trace_cache :runtime_correlator_trace_cache

  # Performance Targets (in milliseconds)
  @event_correlation_target 1
  @ast_context_lookup_target 10
  @runtime_query_enhancement_target 50
  @memory_overhead_target 0.10  # 10% of base EventStore

  # Timeout Values (in milliseconds)
  @correlation_timeout 5_000
  @context_lookup_timeout 5_000
  @query_enhancement_timeout 5_000
  @cache_cleanup_timeout 10_000

  # Cache Settings
  @cache_ttl 300_000  # 5 minutes in milliseconds
  @max_cache_size 10_000  # Maximum entries per cache
  @cache_cleanup_interval 60_000  # 1 minute in milliseconds

  # Trace Settings
  @max_trace_events 100_000  # Maximum events per trace
  @trace_compression_threshold 50_000  # Compress traces larger than this
  @max_variable_history 1_000  # Maximum history entries per variable

  # Breakpoint Settings
  @max_breakpoints_per_type 100
  @max_watchpoints 50
  @breakpoint_hit_limit 1_000  # Maximum hits before auto-disable

  # Performance Monitoring
  @performance_sample_rate 0.1  # 10% of events sampled for performance
  @slow_operation_threshold 100  # Operations slower than 100ms are flagged

  # API Functions

  @doc "Gets ETS table names configuration."
  def tables do
    %{
      main: @main_table,
      context_cache: @context_cache,
      trace_cache: @trace_cache
    }
  end

  @doc "Gets performance target configuration."
  def performance_targets do
    %{
      event_correlation_ms: @event_correlation_target,
      ast_context_lookup_ms: @ast_context_lookup_target,
      runtime_query_enhancement_ms: @runtime_query_enhancement_target,
      memory_overhead_ratio: @memory_overhead_target
    }
  end

  @doc "Gets timeout configuration."
  def timeouts do
    %{
      correlation: @correlation_timeout,
      context_lookup: @context_lookup_timeout,
      query_enhancement: @query_enhancement_timeout,
      cache_cleanup: @cache_cleanup_timeout
    }
  end

  @doc "Gets cache configuration."
  def cache do
    %{
      ttl_ms: @cache_ttl,
      max_size: @max_cache_size,
      cleanup_interval_ms: @cache_cleanup_interval
    }
  end

  @doc "Gets trace configuration."
  def trace do
    %{
      max_events: @max_trace_events,
      compression_threshold: @trace_compression_threshold,
      max_variable_history: @max_variable_history
    }
  end

  @doc "Gets breakpoint configuration."
  def breakpoints do
    %{
      max_per_type: @max_breakpoints_per_type,
      max_watchpoints: @max_watchpoints,
      hit_limit: @breakpoint_hit_limit
    }
  end

  @doc "Gets performance monitoring configuration."
  def performance_monitoring do
    %{
      sample_rate: @performance_sample_rate,
      slow_operation_threshold_ms: @slow_operation_threshold
    }
  end

  @doc "Gets all configuration as a single map."
  def all do
    %{
      tables: tables(),
      performance_targets: performance_targets(),
      timeouts: timeouts(),
      cache: cache(),
      trace: trace(),
      breakpoints: breakpoints(),
      performance_monitoring: performance_monitoring()
    }
  end

  @doc "Validates that the current configuration is reasonable."
  def validate_config do
    validations = [
      {:cache_ttl_positive, @cache_ttl > 0},
      {:timeouts_reasonable, @correlation_timeout > 1000},
      {:max_cache_size_reasonable, @max_cache_size > 100},
      {:trace_limits_reasonable, @max_trace_events > 1000},
      {:performance_targets_achievable, @event_correlation_target < 100}
    ]

    case Enum.find(validations, fn {_name, valid} -> not valid end) do
      nil -> :ok
      {failed_check, _} -> {:error, {:config_validation_failed, failed_check}}
    end
  end

  @doc "Gets environment-specific overrides."
  def get_env_overrides do
    base_config = all()

    # In development, use more aggressive caching and shorter TTLs
    case Mix.env() do
      :dev ->
        put_in(base_config, [:cache, :ttl_ms], 60_000)  # 1 minute in dev

      :test ->
        base_config
        |> put_in([:cache, :ttl_ms], 5_000)  # 5 seconds in test
        |> put_in([:timeouts, :correlation], 1_000)  # Shorter timeouts in test

      :prod ->
        base_config  # Use default production settings

      _ ->
        base_config
    end
  end
end
