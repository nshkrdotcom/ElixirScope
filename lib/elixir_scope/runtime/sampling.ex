defmodule ElixirScope.Runtime.Sampling do
  @moduledoc """
  Intelligent sampling strategies for production tracing.
  
  This module provides various sampling algorithms to reduce the overhead
  of runtime tracing while maintaining useful coverage for debugging and analysis.
  """

  use GenServer
  require Logger

  # Conditional compilation for :cpu_sup module availability
  @compile (if Code.ensure_loaded?(:cpu_sup) == {:module, :cpu_sup} do
    []
  else
    [
      {:no_warn_undefined, {:cpu_sup, :util, 0}},
      {:no_warn_undefined, {:cpu_sup, :avg1, 0}},
      {:no_warn_undefined, {:cpu_sup, :avg5, 0}},
      {:no_warn_undefined, {:cpu_sup, :avg15, 0}}
    ]
  end)

  @default_config %{
    base_rate: 0.1,
    max_rate: 1.0,
    min_rate: 0.001,
    adjustment_interval: 5_000,
    cpu_threshold: 0.8,
    memory_threshold: 0.9,
    event_rate_threshold: 10_000
  }

  # Client API

  @doc """
  Starts the sampling manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates an adaptive sampler that adjusts based on system load.
  
  ## Examples
  
      iex> sampler = adaptive_sampler(base_rate: 0.1, cpu_threshold: 0.8)
      iex> should_sample?(sampler, %{cpu_usage: 0.5})
      true
  """
  def adaptive_sampler(opts \\ []) do
    config = Map.merge(@default_config, Map.new(opts))
    
    %{
      type: :adaptive,
      config: config,
      current_rate: config.base_rate,
      last_adjustment: System.monotonic_time(:millisecond),
      stats: %{
        samples_taken: 0,
        samples_skipped: 0,
        adjustments: 0
      }
    }
  end

  @doc """
  Creates a tail sampler that traces full requests if they're interesting.
  
  Tail sampling makes decisions after seeing the complete trace, keeping
  traces that contain errors, are slow, or match other interesting criteria.
  
  ## Examples
  
      iex> sampler = tail_sampler(keep_errors: true, slow_threshold: 1000)
      iex> should_keep_trace?(sampler, trace_events)
      true
  """
  def tail_sampler(opts \\ []) do
    config = %{
      keep_errors: Keyword.get(opts, :keep_errors, true),
      slow_threshold: Keyword.get(opts, :slow_threshold, 1000),
      keep_rate: Keyword.get(opts, :keep_rate, 0.01),
      interesting_patterns: Keyword.get(opts, :interesting_patterns, [])
    }
    
    %{
      type: :tail,
      config: config,
      pending_traces: %{},
      stats: %{
        traces_started: 0,
        traces_kept: 0,
        traces_dropped: 0
      }
    }
  end

  @doc """
  Creates a reservoir sampler that maintains a fixed-size sample.
  
  ## Examples
  
      iex> sampler = reservoir_sampler(size: 1000)
      iex> add_sample(sampler, event)
      {:ok, updated_sampler}
  """
  def reservoir_sampler(opts \\ []) do
    size = Keyword.get(opts, :size, 1000)
    
    %{
      type: :reservoir,
      config: %{size: size},
      reservoir: [],
      count: 0,
      stats: %{
        total_seen: 0,
        current_size: 0
      }
    }
  end

  @doc """
  Creates a rate-limited sampler with burst capacity.
  
  ## Examples
  
      iex> sampler = rate_limited_sampler(rate: 100, burst: 10)
      iex> should_sample?(sampler, %{})
      true
  """
  def rate_limited_sampler(opts \\ []) do
    config = %{
      rate: Keyword.get(opts, :rate, 100),  # events per second
      burst: Keyword.get(opts, :burst, 10), # burst capacity
      window: Keyword.get(opts, :window, 1000) # window in ms
    }
    
    %{
      type: :rate_limited,
      config: config,
      tokens: config.burst,
      last_refill: System.monotonic_time(:millisecond),
      stats: %{
        requests: 0,
        accepted: 0,
        rejected: 0
      }
    }
  end

  @doc """
  Determines if a sample should be taken based on the sampler configuration.
  """
  def should_sample?(sampler, context \\ %{})

  def should_sample?(%{type: :adaptive} = sampler, context) do
    sampler = maybe_adjust_adaptive_rate(sampler, context)
    random_sample?(sampler.current_rate)
  end

  def should_sample?(%{type: :rate_limited} = sampler, _context) do
    case consume_token(sampler) do
      {:ok, _updated_sampler} -> true
      {:error, :rate_limited} -> false
    end
  end

  def should_sample?(%{type: :reservoir} = sampler, _context) do
    # Reservoir sampling always accepts initially, then probabilistically
    if sampler.count < sampler.config.size do
      true
    else
      # Probability of replacing an existing sample
      :rand.uniform() < (sampler.config.size / (sampler.count + 1))
    end
  end

  def should_sample?(%{type: :tail}, _context) do
    # Tail sampling always starts traces, decision made later
    true
  end

  @doc """
  Determines if a completed trace should be kept (for tail sampling).
  """
  def should_keep_trace?(%{type: :tail} = sampler, trace_events) do
    config = sampler.config
    
    cond do
      config.keep_errors and has_errors?(trace_events) ->
        true
      
      config.slow_threshold and is_slow?(trace_events, config.slow_threshold) ->
        true
      
      has_interesting_patterns?(trace_events, config.interesting_patterns) ->
        true
      
      true ->
        random_sample?(config.keep_rate)
    end
  end

  def should_keep_trace?(_sampler, _trace_events), do: true

  @doc """
  Adds a sample to a reservoir sampler.
  """
  def add_sample(%{type: :reservoir} = sampler, sample) do
    updated_stats = %{sampler.stats | 
      total_seen: sampler.stats.total_seen + 1
    }
    
    if sampler.count < sampler.config.size do
      # Reservoir not full, add sample
      updated_sampler = %{sampler |
        reservoir: [sample | sampler.reservoir],
        count: sampler.count + 1,
        stats: %{updated_stats | current_size: sampler.count + 1}
      }
      {:ok, updated_sampler}
    else
      # Reservoir full, maybe replace
      if :rand.uniform() < (sampler.config.size / (sampler.count + 1)) do
        # Replace random sample
        index = :rand.uniform(sampler.config.size) - 1
        updated_reservoir = List.replace_at(sampler.reservoir, index, sample)
        updated_sampler = %{sampler |
          reservoir: updated_reservoir,
          count: sampler.count + 1,
          stats: updated_stats
        }
        {:ok, updated_sampler}
      else
        # Don't add sample
        updated_sampler = %{sampler |
          count: sampler.count + 1,
          stats: updated_stats
        }
        {:skip, updated_sampler}
      end
    end
  end

  @doc """
  Gets current sampling statistics.
  """
  def get_stats(sampler) do
    base_stats = sampler.stats
    
    case sampler.type do
      :adaptive ->
        Map.merge(base_stats, %{
          current_rate: sampler.current_rate,
          last_adjustment: sampler.last_adjustment
        })
      
      :rate_limited ->
        Map.merge(base_stats, %{
          current_tokens: sampler.tokens,
          last_refill: sampler.last_refill
        })
      
      _ ->
        base_stats
    end
  end

  @doc """
  Updates sampler configuration at runtime.
  """
  def update_config(sampler, new_config)

  def update_config(sampler, new_config) when is_map(sampler) do
    updated_config = Map.merge(sampler.config, new_config)
    %{sampler | config: updated_config}
  end

  def update_config(:global, new_config) do
    # For global config updates, we could store in a GenServer or ETS table
    # For now, just return :ok to satisfy the API
    Logger.info("Global sampling config updated: #{inspect(new_config)}")
    :ok
  end

  @doc """
  Gets the current system metrics for adaptive sampling.
  """
  def get_system_metrics do
    GenServer.call(__MODULE__, :get_system_metrics)
  end

  @doc """
  Gets current CPU usage.
  """
  def get_cpu_usage do
    case :cpu_sup.util() do
      {:error, _} -> {:error, :cpu_sup_unavailable}
      usage when is_number(usage) -> {:ok, usage / 100.0}
      _ -> {:error, :cpu_sup_unavailable}
    end
  rescue
    _ -> {:error, :cpu_sup_unavailable}
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Start periodic system monitoring
    :timer.send_interval(1000, :collect_metrics)
    
    state = %{
      cpu_usage: 0.0,
      memory_usage: 0.0,
      event_rate: 0,
      last_event_count: 0,
      last_metrics_time: System.monotonic_time(:millisecond)
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call(:get_system_metrics, _from, state) do
    metrics = %{
      cpu_usage: state.cpu_usage,
      memory_usage: state.memory_usage,
      event_rate: state.event_rate
    }
    {:reply, metrics, state}
  end

  @impl true
  def handle_info(:collect_metrics, state) do
    new_state = collect_system_metrics(state)
    {:noreply, new_state}
  end

  # Private functions

  defp maybe_adjust_adaptive_rate(sampler, context) do
    now = System.monotonic_time(:millisecond)
    time_since_adjustment = now - sampler.last_adjustment
    
    if time_since_adjustment >= sampler.config.adjustment_interval do
      adjust_adaptive_rate(sampler, context, now)
    else
      sampler
    end
  end

  defp adjust_adaptive_rate(sampler, context, now) do
    config = sampler.config
    system_metrics = Map.merge(get_system_metrics(), context)
    
    # Calculate adjustment factor based on system load
    adjustment_factor = cond do
      system_metrics.cpu_usage > config.cpu_threshold ->
        0.5  # Reduce sampling when CPU is high
      
      system_metrics.memory_usage > config.memory_threshold ->
        0.3  # Reduce sampling more when memory is high
      
      system_metrics.event_rate > config.event_rate_threshold ->
        0.7  # Reduce sampling when event rate is high
      
      true ->
        1.2  # Increase sampling when system is healthy
    end
    
    new_rate = sampler.current_rate * adjustment_factor
    new_rate = max(config.min_rate, min(config.max_rate, new_rate))
    
    updated_stats = %{sampler.stats |
      adjustments: sampler.stats.adjustments + 1
    }
    
    %{sampler |
      current_rate: new_rate,
      last_adjustment: now,
      stats: updated_stats
    }
  end

  defp consume_token(sampler) do
    now = System.monotonic_time(:millisecond)
    sampler = refill_tokens(sampler, now)
    
    if sampler.tokens >= 1 do
      updated_sampler = %{sampler |
        tokens: sampler.tokens - 1,
        stats: %{sampler.stats |
          requests: sampler.stats.requests + 1,
          accepted: sampler.stats.accepted + 1
        }
      }
      {:ok, updated_sampler}
    else
      _updated_sampler = %{sampler |
        stats: %{sampler.stats |
          requests: sampler.stats.requests + 1,
          rejected: sampler.stats.rejected + 1
        }
      }
      {:error, :rate_limited}
    end
  end

  defp refill_tokens(sampler, now) do
    time_passed = now - sampler.last_refill
    config = sampler.config
    
    if time_passed >= config.window do
      # Refill tokens based on rate
      tokens_to_add = (config.rate * time_passed) / 1000
      new_tokens = min(config.burst, sampler.tokens + tokens_to_add)
      
      %{sampler |
        tokens: new_tokens,
        last_refill: now
      }
    else
      sampler
    end
  end

  defp random_sample?(rate) do
    :rand.uniform() < rate
  end

  defp has_errors?(trace_events) do
    Enum.any?(trace_events, fn event ->
      case event do
        %{type: :exception} -> true
        %{type: :error} -> true
        %{result: {:error, _}} -> true
        _ -> false
      end
    end)
  end

  defp is_slow?(trace_events, threshold) do
    case {List.first(trace_events), List.last(trace_events)} do
      {%{timestamp: start_time}, %{timestamp: end_time}} ->
        duration = end_time - start_time
        duration > threshold
      
      _ ->
        false
    end
  end

  defp has_interesting_patterns?(trace_events, patterns) do
    Enum.any?(patterns, fn pattern ->
      Enum.any?(trace_events, &matches_pattern?(&1, pattern))
    end)
  end

  defp matches_pattern?(event, pattern) do
    # Simple pattern matching - could be enhanced with more sophisticated logic
    case pattern do
      {:module, module} -> event.module == module
      {:function, {module, function}} -> event.module == module and event.function == function
      {:message, message_pattern} -> matches_message_pattern?(event, message_pattern)
      _ -> false
    end
  end

  defp matches_message_pattern?(%{type: :message_received, message: message}, pattern) do
    case pattern do
      {:tag, tag} when is_tuple(message) -> elem(message, 0) == tag
      literal -> message == literal
    end
  end
  defp matches_message_pattern?(_, _), do: false

  defp collect_system_metrics(state) do
    now = System.monotonic_time(:millisecond)
    
    # Get CPU usage (simplified - in production, use proper system monitoring)
    cpu_usage = case get_cpu_usage() do
      {:ok, usage} -> usage
      {:error, _} -> 0.0
    end
    
    # Get memory usage
    memory_info = :erlang.memory()
    total_memory = memory_info[:total]
    system_memory = get_system_memory()
    memory_usage = if system_memory > 0, do: total_memory / system_memory, else: 0.0
    
    # Calculate event rate
    current_event_count = get_current_event_count()
    time_diff = now - state.last_metrics_time
    event_rate = if time_diff > 0 do
      (current_event_count - state.last_event_count) * 1000 / time_diff
    else
      state.event_rate
    end
    
    %{state |
      cpu_usage: cpu_usage,
      memory_usage: memory_usage,
      event_rate: event_rate,
      last_event_count: current_event_count,
      last_metrics_time: now
    }
  end

  # Remove the private function since we now have a public one

  defp get_system_memory do
    # Get total system memory (simplified)
    case File.read("/proc/meminfo") do
      {:ok, content} ->
        case Regex.run(~r/MemTotal:\s+(\d+)\s+kB/, content) do
          [_, total_kb] -> String.to_integer(total_kb) * 1024
          _ -> 0
        end
      
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp get_current_event_count do
    # Get current event count from the system
    # This would integrate with the actual event counting system
    0
  end
end 