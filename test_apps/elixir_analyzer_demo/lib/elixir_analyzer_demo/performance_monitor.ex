defmodule ElixirAnalyzerDemo.PerformanceMonitor do
  @moduledoc """
  Real-time performance monitoring for the Enhanced AST Repository demo.
  
  Demonstrates:
  - Real-time metrics collection
  - Performance dashboard
  - Alert system
  - Historical trend analysis
  """
  
  use GenServer
  
  alias ElixirScope.ASTRepository.MemoryManager
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def start_monitoring do
    GenServer.call(__MODULE__, :start_monitoring)
  end
  
  def stop_monitoring do
    GenServer.call(__MODULE__, :stop_monitoring)
  end
  
  def get_performance_dashboard do
    GenServer.call(__MODULE__, :get_dashboard)
  end
  
  def get_metrics_history do
    GenServer.call(__MODULE__, :get_history)
  end
  
  def init(_opts) do
    {:ok, %{
      monitoring_enabled: false,
      metrics_history: [],
      alerts: [],
      thresholds: %{
        memory_usage: 80,      # 80% memory usage
        query_time: 100,       # 100ms query time
        cache_hit_ratio: 0.7   # 70% cache hit ratio
      }
    }}
  end
  
  def handle_call(:start_monitoring, _from, state) do
    if not state.monitoring_enabled do
      # Schedule first collection
      Process.send_after(self(), :collect_metrics, 1000)
      new_state = %{state | monitoring_enabled: true}
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :already_monitoring}, state}
    end
  end
  
  def handle_call(:stop_monitoring, _from, state) do
    new_state = %{state | monitoring_enabled: false}
    {:reply, :ok, new_state}
  end
  
  def handle_call(:get_dashboard, _from, state) do
    dashboard = generate_dashboard(state)
    {:reply, dashboard, state}
  end
  
  def handle_call(:get_history, _from, state) do
    {:reply, state.metrics_history, state}
  end
  
  def handle_info(:collect_metrics, state) do
    if state.monitoring_enabled do
      # Collect current metrics
      current_metrics = collect_current_metrics()
      
      # Check for alerts
      new_alerts = check_thresholds(current_metrics, state.thresholds)
      
      # Update state
      new_state = %{state |
        metrics_history: [current_metrics | Enum.take(state.metrics_history, 99)],
        alerts: new_alerts ++ Enum.take(state.alerts, 49)
      }
      
      # Schedule next collection
      Process.send_after(self(), :collect_metrics, 5000)  # Every 5 seconds
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  def handle_info(_msg, state) do
    {:noreply, state}
  end
  
  # Private functions
  
  defp collect_current_metrics do
    # Get memory stats from MemoryManager
    memory_stats = case MemoryManager.monitor_memory_usage() do
      {:ok, stats} -> stats
      {:error, _} -> %{
        repository_memory: 0,
        memory_usage_percent: 0
      }
    end
    
    # Get cache hit ratio separately
    cache_hit_ratio = case MemoryManager.get_stats() do
      {:ok, all_stats} when is_map(all_stats.cache) ->
        all_stats.cache.cache_hit_ratio
      _ ->
        0.0  # Default value when cache stats not available
    end
    
    %{
      timestamp: DateTime.utc_now(),
      memory: %{
        repository_memory: memory_stats.repository_memory,
        system_memory_usage: memory_stats.memory_usage_percent,
        cache_hit_ratio: cache_hit_ratio
      },
      performance: collect_performance_metrics(),
      repository: collect_repository_metrics(),
      system: collect_system_metrics()
    }
  end
  
  defp collect_performance_metrics do
    %{
      average_query_time: calculate_average_query_time(),
      throughput: calculate_current_throughput(),
      concurrent_operations: count_concurrent_operations(),
      response_times: %{
        p50: 5.2,
        p95: 15.8,
        p99: 45.3
      }
    }
  end
  
  defp collect_repository_metrics do
    # Use get_statistics instead of list_modules which doesn't exist
    {module_count, function_count} = try do
      case ElixirScope.ASTRepository.EnhancedRepository.get_statistics() do
        {:ok, stats} -> {stats.modules, stats.functions}
        _ -> {0, 0}
      end
    rescue
      _ -> {0, 0}
    end
    
    %{
      total_modules: module_count,
      total_functions: function_count,
      analysis_coverage: calculate_analysis_coverage(module_count),
      storage_efficiency: calculate_storage_efficiency()
    }
  end
  
  defp collect_system_metrics do
    %{
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      disk_usage: get_disk_usage(),
      network_io: get_network_io()
    }
  end
  
  defp check_thresholds(metrics, thresholds) do
    alerts = []
    
    # Check memory usage
    alerts = if metrics.memory.system_memory_usage > thresholds.memory_usage do
      alert = %{
        type: :memory_high,
        severity: :warning,
        message: "Memory usage is #{metrics.memory.system_memory_usage}%, exceeds threshold of #{thresholds.memory_usage}%",
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end
    
    # Check cache hit ratio
    alerts = if metrics.memory.cache_hit_ratio < thresholds.cache_hit_ratio do
      alert = %{
        type: :cache_efficiency_low,
        severity: :warning,
        message: "Cache hit ratio is #{Float.round(metrics.memory.cache_hit_ratio * 100, 1)}%, below threshold of #{thresholds.cache_hit_ratio * 100}%",
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end
    
    # Check query performance
    alerts = if metrics.performance.average_query_time > thresholds.query_time do
      alert = %{
        type: :query_performance_slow,
        severity: :warning,
        message: "Average query time is #{metrics.performance.average_query_time}ms, exceeds threshold of #{thresholds.query_time}ms",
        timestamp: DateTime.utc_now()
      }
      [alert | alerts]
    else
      alerts
    end
    
    alerts
  end
  
  defp generate_dashboard(state) do
    latest_metrics = List.first(state.metrics_history)
    
    %{
      current_status: assess_system_health(latest_metrics, state.alerts),
      metrics: latest_metrics,
      trends: analyze_trends(state.metrics_history),
      alerts: Enum.take(state.alerts, 10),  # Latest 10 alerts
      recommendations: generate_performance_recommendations(state),
      uptime: calculate_uptime(),
      last_updated: DateTime.utc_now()
    }
  end
  
  defp assess_system_health(nil, _alerts), do: :unknown
  defp assess_system_health(_metrics, alerts) do
    critical_alerts = Enum.filter(alerts, &(&1.severity == :critical))
    warning_alerts = Enum.filter(alerts, &(&1.severity == :warning))
    
    cond do
      length(critical_alerts) > 0 -> :critical
      length(warning_alerts) > 3 -> :degraded
      length(warning_alerts) > 0 -> :warning
      true -> :healthy
    end
  end
  
  defp analyze_trends(history) when length(history) < 2, do: %{}
  defp analyze_trends(history) do
    recent = Enum.take(history, 10)
    
    %{
      memory_trend: calculate_trend(recent, fn m -> m.memory.repository_memory end),
      performance_trend: calculate_trend(recent, fn m -> m.performance.average_query_time end),
      cache_trend: calculate_trend(recent, fn m -> m.memory.cache_hit_ratio end),
      throughput_trend: calculate_trend(recent, fn m -> m.performance.throughput end)
    }
  end
  
  defp calculate_trend(metrics, extractor) do
    values = Enum.map(metrics, extractor)
    
    if length(values) >= 2 do
      first = List.last(values)
      last = List.first(values)
      
      cond do
        last > first * 1.1 -> :increasing
        last < first * 0.9 -> :decreasing
        true -> :stable
      end
    else
      :unknown
    end
  end
  
  defp generate_performance_recommendations(state) do
    recommendations = []
    
    # Check recent alerts for recommendations
    recent_alerts = Enum.take(state.alerts, 5)
    
    recommendations = if Enum.any?(recent_alerts, &(&1.type == :memory_high)) do
      ["Consider running memory cleanup", "Enable compression for old analysis data" | recommendations]
    else
      recommendations
    end
    
    recommendations = if Enum.any?(recent_alerts, &(&1.type == :cache_efficiency_low)) do
      ["Warm cache with frequently accessed modules", "Increase cache size" | recommendations]
    else
      recommendations
    end
    
    recommendations = if Enum.any?(recent_alerts, &(&1.type == :query_performance_slow)) do
      ["Enable lazy loading", "Use batch operations for multiple queries" | recommendations]
    else
      recommendations
    end
    
    if length(recommendations) == 0 do
      ["System is performing well", "Consider enabling performance optimizations for better efficiency"]
    else
      recommendations
    end
  end
  
  # Utility functions (simplified implementations)
  
  defp calculate_average_query_time do
    # Simulate query time measurement
    base_time = 2.5
    variation = :rand.uniform() * 10
    Float.round(base_time + variation, 1)
  end
  
  defp calculate_current_throughput do
    # Simulate throughput calculation (operations per second)
    base_throughput = 1000
    variation = :rand.uniform(500)
    base_throughput + variation
  end
  
  defp count_concurrent_operations do
    # Simulate concurrent operations count
    :rand.uniform(20)
  end
  
  defp calculate_analysis_coverage(module_count) do
    # Simulate analysis coverage percentage
    if module_count > 0 do
      base_coverage = 85.0
      variation = :rand.uniform() * 10
      Float.round(base_coverage + variation, 1)
    else
      0.0
    end
  end
  
  defp calculate_storage_efficiency do
    # Simulate storage efficiency
    base_efficiency = 75.0
    variation = :rand.uniform() * 20
    Float.round(base_efficiency + variation, 1)
  end
  
  defp get_cpu_usage do
    # Simulate CPU usage
    base_cpu = 25.0
    variation = :rand.uniform() * 30
    Float.round(base_cpu + variation, 1)
  end
  
  defp get_memory_usage do
    # Simulate memory usage
    base_memory = 45.0
    variation = :rand.uniform() * 20
    Float.round(base_memory + variation, 1)
  end
  
  defp get_disk_usage do
    # Simulate disk usage
    base_disk = 60.0
    variation = :rand.uniform() * 15
    Float.round(base_disk + variation, 1)
  end
  
  defp get_network_io do
    # Simulate network I/O
    %{
      bytes_in: :rand.uniform(1000000),
      bytes_out: :rand.uniform(500000),
      packets_in: :rand.uniform(10000),
      packets_out: :rand.uniform(8000)
    }
  end
  
  defp calculate_uptime do
    # Simulate uptime calculation
    hours = :rand.uniform(168)  # Up to 1 week
    minutes = :rand.uniform(60)
    "#{hours}h #{minutes}m"
  end
end 