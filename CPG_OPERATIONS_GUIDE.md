
### New Document: `CPG_OPERATIONS_GUIDE.MD`

```markdown
# CPG Operations Guide

## 1. Health Checks and Diagnostics

### Basic Health Check
```bash
# Elixir console commands for production diagnosis
iex> ElixirScope.ASTRepository.Enhanced.Repository.health_check()
%{
  cpg_tables_status: :healthy,
  total_cpg_nodes: 15420,
  total_cpg_edges: 42150,
  cache_hit_rate: 0.87,
  avg_query_time_ms: 23.5,
  memory_usage_mb: 245.2
}
```

### Performance Diagnostics
```elixir
# Identify slow CPG operations
def diagnose_performance_issues() do
  # Check ETS table scan performance
  scan_performance = benchmark_ets_scans()
  
  # Check algorithm cache effectiveness  
  cache_stats = get_cache_statistics()
  
  # Check for memory pressure indicators
  memory_stats = get_memory_pressure_indicators()
  
  %{
    ets_scan_performance: scan_performance,
    cache_effectiveness: cache_stats,
    memory_pressure: memory_stats,
    recommendations: generate_optimization_recommendations()
  }
end
```

## 2. Maintenance Procedures

### CPG Cache Cleanup
```elixir
# Periodic cache cleanup to prevent unbounded growth
def cleanup_stale_cpg_cache() do
  current_time = System.system_time(:second)
  cutoff_time = current_time - @cache_ttl_seconds
  
  # Remove entries older than TTL
  match_spec = [
    {{:_, :_, :_, :"$1"}, [{:<, :"$1", cutoff_time}], [true]}
  ]
  
  deleted_count = :ets.select_delete(@cpg_analysis_cache, match_spec)
  Logger.info("Cleaned up #{deleted_count} stale CPG cache entries")
end
```

### ETS Table Defragmentation
```elixir
# Periodic defragmentation for optimal performance
def defragment_cpg_tables() do
  tables = [@cpg_nodes_table, @cpg_edges_table, @cpg_analysis_cache]
  
  Enum.each(tables, fn table ->
    # ETS doesn't have built-in defrag, but we can rebuild
    if should_defragment?(table) do
      rebuild_ets_table(table)
    end
  end)
end

defp should_defragment?(table) do
  info = :ets.info(table)
  # Heuristic: if deleted objects > 30% of total
  (info[:size] + info[:delete_count]) * 0.7 < info[:size]
end
```

## 3. Scaling Strategies

### Horizontal Scaling Preparation
```elixir
# Prepare for distributed CPG analysis
defmodule CPGDistribution do
  # Partition CPG data by module for distributed processing
  def partition_cpg_by_module(cpg_data) do
    cpg_data
    |> group_by_module()
    |> assign_to_nodes()
  end
  
  # Coordinate cross-module analysis across nodes
  def coordinate_cross_module_analysis(analysis_type, modules) do
    # Implementation for distributed CPG analysis
    # This is prep work for future distributed deployment
  end
end
```

### Vertical Scaling Guidelines
```markdown
## Memory Sizing Guidelines

**Small Projects (< 100 modules)**:
- Base ElixirScope: 512MB
- CPG Enhancement: +150MB
- Recommended: 1GB total

**Medium Projects (100-500 modules)**:
- Base ElixirScope: 1GB  
- CPG Enhancement: +400MB
- Recommended: 2GB total

**Large Projects (500+ modules)**:
- Base ElixirScope: 2GB
- CPG Enhancement: +800MB  
- Recommended: 4GB total

**Memory Pressure Indicators**:
- ETS table memory > 80% of available
- Query response time > 500ms
- Frequent cache evictions
- GC pressure from large binaries
```
```

## Integration Testing Strategy for Production

### Comprehensive Integration Test Plan

```elixir
# Production-like integration test
defmodule CPGProductionIntegrationTest do
  use ExUnit.Case, async: false
  
  @moduletag :integration
  @moduletag :production_simulation
  
  setup do
    # Set up production-like ETS table configuration
    configure_production_ets_settings()
    
    # Load realistic test data (large project simulation)
    load_large_project_simulation()
    
    on_exit(fn -> cleanup_production_simulation() end)
  end
  
  test "full CPG analysis pipeline under production load" do
    # Simulate realistic workload
    tasks = [
      Task.async(fn -> simulate_continuous_queries() end),
      Task.async(fn -> simulate_incremental_updates() end),
      Task.async(fn -> simulate_pattern_analysis() end),
      Task.async(fn -> simulate_ai_feature_extraction() end)
    ]
    
    # Let workload run for meaningful duration
    Process.sleep(30_000) # 30 seconds
    
    # Verify system remains responsive
    assert query_response_time() < 100
    assert memory_usage() < @memory_limit
    assert error_rate() < 0.01
    
    # Clean shutdown
    Enum.each(tasks, &Task.shutdown/1)
  end
  
  test "graceful degradation under memory pressure" do
    # Consume most available memory
    _memory_pressure = create_memory_pressure()
    
    # Verify CPG still functions with limited capability
    assert {:ok, _limited_result} = execute_cpg_query_under_pressure()
    assert cache_hit_rate() > 0.5 # Should still have some caching
    
    # Verify no crashes or data corruption
    assert system_stable?()
  end
end
```

This comprehensive approach ensures that our CPG enhancement not only provides the advanced algorithmic capabilities outlined in the original documents but does so in a production-ready, robust manner that builds effectively on the existing ElixirScope ETS-based architecture.
 