# Enhanced AST Repository - API Documentation

## Table of Contents

1. [Overview](#overview)
2. [Core API](#core-api)
3. [Memory Management API](#memory-management-api)
4. [Performance Optimization API](#performance-optimization-api)
5. [Integration Patterns](#integration-patterns)
6. [Performance Characteristics](#performance-characteristics)
7. [Best Practices](#best-practices)
8. [Migration Guide](#migration-guide)
9. [Troubleshooting](#troubleshooting)

## Overview

The Enhanced AST Repository provides a comprehensive, production-ready solution for managing Abstract Syntax Trees (ASTs) in Elixir applications. It extends the basic repository with advanced features including memory management, performance optimization, caching, and comprehensive analysis capabilities.

### Key Features

- **Memory Management**: Intelligent cleanup, compression, and LRU caching
- **Performance Optimization**: Query caching, batch operations, lazy loading
- **Scalability**: Handles 1000+ modules with <500MB memory usage
- **Analysis Integration**: CFG, DFG, and CPG analysis support
- **Production Ready**: Comprehensive monitoring and error handling

### Architecture

```
Enhanced AST Repository
├── EnhancedRepository (Core API)
├── MemoryManager (Memory Management)
├── PerformanceOptimizer (Performance)
├── EnhancedModuleData (Data Structures)
└── EnhancedFunctionData (Function Analysis)
```

## Core API

### ElixirScope.ASTRepository.EnhancedRepository

The main interface for storing and retrieving enhanced AST data.

#### Starting the Repository

```elixir
# Start with default configuration
{:ok, pid} = EnhancedRepository.start_link([])

# Start with custom configuration
{:ok, pid} = EnhancedRepository.start_link([
  memory_limit: 1024 * 1024 * 1024,  # 1GB
  cache_enabled: true,
  monitoring_enabled: true
])
```

#### Module Operations

##### `store_enhanced_module/2`

Stores an enhanced module with comprehensive analysis.

```elixir
@spec store_enhanced_module(atom(), Macro.t()) :: :ok | {:error, term()}

# Basic usage
ast = quote do
  defmodule MyModule do
    def hello(name), do: "Hello, #{name}"
  end
end

:ok = EnhancedRepository.store_enhanced_module(MyModule, ast)
```

**Parameters:**
- `module_name` - The module name (atom)
- `ast` - The complete module AST

**Returns:**
- `:ok` on success
- `{:error, reason}` on failure

##### `get_enhanced_module/1`

Retrieves enhanced module data with all analysis results.

```elixir
@spec get_enhanced_module(atom()) :: {:ok, EnhancedModuleData.t()} | {:error, :not_found}

# Retrieve module data
case EnhancedRepository.get_enhanced_module(MyModule) do
  {:ok, module_data} ->
    IO.inspect(module_data.functions)
    IO.inspect(module_data.metadata)
  {:error, :not_found} ->
    IO.puts("Module not found")
end
```

**Returns:**
- `{:ok, module_data}` - Enhanced module data structure
- `{:error, :not_found}` - Module not in repository

##### `update_enhanced_module/2`

Updates existing module data with new analysis results.

```elixir
@spec update_enhanced_module(atom(), keyword()) :: :ok | {:error, term()}

# Update module metadata
:ok = EnhancedRepository.update_enhanced_module(MyModule, [
  metadata: %{last_analyzed: DateTime.utc_now()},
  complexity_score: 8.5
])
```

##### `delete_enhanced_module/1`

Removes module from repository and cleans up associated data.

```elixir
@spec delete_enhanced_module(atom()) :: :ok

:ok = EnhancedRepository.delete_enhanced_module(MyModule)
```

#### Function Operations

##### `get_enhanced_function/3`

Retrieves detailed function analysis data.

```elixir
@spec get_enhanced_function(atom(), atom(), non_neg_integer()) :: 
  {:ok, EnhancedFunctionData.t()} | {:error, :not_found}

# Get function data
case EnhancedRepository.get_enhanced_function(MyModule, :hello, 1) do
  {:ok, func_data} ->
    IO.inspect(func_data.complexity_score)
    IO.inspect(func_data.control_flow_graph)
  {:error, :not_found} ->
    IO.puts("Function not found")
end
```

##### `store_enhanced_function/4`

Stores enhanced function data with analysis results.

```elixir
@spec store_enhanced_function(atom(), atom(), non_neg_integer(), EnhancedFunctionData.t()) :: 
  :ok | {:error, term()}

function_data = %EnhancedFunctionData{
  module_name: MyModule,
  function_name: :hello,
  arity: 1,
  complexity_score: 2.5,
  # ... other fields
}

:ok = EnhancedRepository.store_enhanced_function(MyModule, :hello, 1, function_data)
```

#### Query Operations

##### `list_modules/0`

Lists all modules in the repository.

```elixir
@spec list_modules() :: [atom()]

modules = EnhancedRepository.list_modules()
# => [:MyModule, :AnotherModule, ...]
```

##### `list_functions/1`

Lists all functions for a given module.

```elixir
@spec list_functions(atom()) :: [{atom(), non_neg_integer()}]

functions = EnhancedRepository.list_functions(MyModule)
# => [{:hello, 1}, {:goodbye, 2}, ...]
```

##### `search_modules/1`

Searches modules by pattern or criteria.

```elixir
@spec search_modules(keyword()) :: [atom()]

# Search by pattern
modules = EnhancedRepository.search_modules(pattern: "Test*")

# Search by complexity
modules = EnhancedRepository.search_modules(complexity: {:gt, 10})

# Search by metadata
modules = EnhancedRepository.search_modules(metadata: %{type: :controller})
```

#### Batch Operations

##### `store_modules_batch/1`

Efficiently stores multiple modules in a single operation.

```elixir
@spec store_modules_batch([{atom(), Macro.t()}]) :: :ok | {:error, term()}

modules = [
  {Module1, ast1},
  {Module2, ast2},
  {Module3, ast3}
]

:ok = EnhancedRepository.store_modules_batch(modules)
```

##### `get_modules_batch/1`

Retrieves multiple modules efficiently.

```elixir
@spec get_modules_batch([atom()]) :: %{atom() => EnhancedModuleData.t()}

module_names = [Module1, Module2, Module3]
modules_data = EnhancedRepository.get_modules_batch(module_names)
# => %{Module1 => data1, Module2 => data2, Module3 => data3}
```

## Memory Management API

### ElixirScope.ASTRepository.MemoryManager

Provides intelligent memory management for the repository.

#### Starting Memory Manager

```elixir
# Start with monitoring enabled
{:ok, pid} = MemoryManager.start_link(monitoring_enabled: true)

# Start with custom configuration
{:ok, pid} = MemoryManager.start_link([
  monitoring_enabled: true,
  cleanup_interval: 300_000,  # 5 minutes
  compression_interval: 600_000,  # 10 minutes
  memory_check_interval: 30_000   # 30 seconds
])
```

#### Memory Monitoring

##### `monitor_memory_usage/0`

Gets current memory usage statistics.

```elixir
@spec monitor_memory_usage() :: {:ok, map()} | {:error, term()}

case MemoryManager.monitor_memory_usage() do
  {:ok, stats} ->
    IO.puts("Repository memory: #{stats.repository_memory} bytes")
    IO.puts("System memory usage: #{stats.memory_usage_percent}%")
    IO.puts("Cache hit ratio: #{stats.cache_hit_ratio}")
  {:error, reason} ->
    IO.puts("Failed to get memory stats: #{reason}")
end
```

**Returns:**
```elixir
%{
  repository_memory: 52428800,        # bytes
  system_memory_total: 8589934592,    # bytes
  system_memory_used: 4294967296,     # bytes
  memory_usage_percent: 50.0,         # percentage
  cache_hit_ratio: 0.85,              # ratio
  last_cleanup: ~U[2024-01-01 12:00:00Z],
  last_compression: ~U[2024-01-01 11:30:00Z]
}
```

##### `enable_monitoring/0` / `disable_monitoring/0`

Controls memory monitoring.

```elixir
@spec enable_monitoring() :: :ok
@spec disable_monitoring() :: :ok

:ok = MemoryManager.enable_monitoring()
:ok = MemoryManager.disable_monitoring()
```

#### Data Cleanup

##### `cleanup_unused_data/1`

Removes stale and unused data from the repository.

```elixir
@spec cleanup_unused_data(keyword()) :: :ok | {:error, term()}

# Basic cleanup (removes data older than 1 hour)
:ok = MemoryManager.cleanup_unused_data([])

# Custom cleanup parameters
:ok = MemoryManager.cleanup_unused_data([
  max_age: 3600,        # 1 hour in seconds
  force: false,         # don't force cleanup of recently accessed data
  dry_run: false        # actually perform cleanup
])

# Dry run to see what would be cleaned
{:ok, stats} = MemoryManager.cleanup_unused_data([dry_run: true])
IO.puts("Would clean #{stats.modules_to_clean} modules")
```

**Options:**
- `max_age` - Maximum age in seconds (default: 3600)
- `force` - Force cleanup regardless of access patterns (default: false)
- `dry_run` - Don't actually clean, just return statistics (default: false)

##### `compress_old_analysis/1`

Compresses infrequently accessed analysis data.

```elixir
@spec compress_old_analysis(keyword()) :: {:ok, map()} | {:error, term()}

# Compress old analysis data
{:ok, stats} = MemoryManager.compress_old_analysis([
  access_threshold: 5,      # minimum access count
  age_threshold: 1800,      # 30 minutes
  compression_level: 6      # zlib compression level
])

IO.puts("Compressed #{stats.modules_compressed} modules")
IO.puts("Compression ratio: #{stats.compression_ratio * 100}%")
IO.puts("Space saved: #{stats.space_saved_bytes} bytes")
```

**Returns:**
```elixir
%{
  modules_compressed: 25,
  compression_ratio: 0.65,
  space_saved_bytes: 1048576,
  compression_time_ms: 150
}
```

#### Caching

##### `cache_put/3` / `cache_get/2`

Manual cache management for query results.

```elixir
@spec cache_put(atom(), term(), term()) :: :ok
@spec cache_get(atom(), term()) :: {:ok, term()} | :miss

# Cache a query result
:ok = MemoryManager.cache_put(:query, {:module, MyModule}, module_data)

# Retrieve from cache
case MemoryManager.cache_get(:query, {:module, MyModule}) do
  {:ok, data} -> data
  :miss -> nil
end
```

**Cache Types:**
- `:query` - Query results (TTL: 60 seconds)
- `:analysis` - Analysis results (TTL: 300 seconds)
- `:cpg` - Code Property Graph data (TTL: 600 seconds)

##### `implement_lru_cache/2`

Configures LRU cache for specific data types.

```elixir
@spec implement_lru_cache(atom(), keyword()) :: :ok

:ok = MemoryManager.implement_lru_cache(:query, [
  max_size: 1000,
  ttl: 60_000  # 60 seconds
])
```

##### `cache_clear/1`

Clears specific cache type or all caches.

```elixir
@spec cache_clear(atom() | :all) :: :ok

:ok = MemoryManager.cache_clear(:query)  # Clear query cache
:ok = MemoryManager.cache_clear(:all)    # Clear all caches
```

#### Memory Pressure Handling

##### `memory_pressure_handler/1`

Handles different levels of memory pressure.

```elixir
@spec memory_pressure_handler(atom()) :: :ok

# Handle memory pressure levels
:ok = MemoryManager.memory_pressure_handler(:level_1)  # 80% memory - clear query caches
:ok = MemoryManager.memory_pressure_handler(:level_2)  # 90% memory - compress old data
:ok = MemoryManager.memory_pressure_handler(:level_3)  # 95% memory - remove unused modules
:ok = MemoryManager.memory_pressure_handler(:level_4)  # 98% memory - emergency cleanup + GC
```

**Pressure Levels:**
- `:level_1` (80% memory) - Clear query caches
- `:level_2` (90% memory) - Clear caches + compress old analysis data
- `:level_3` (95% memory) - Comprehensive cleanup + remove unused modules
- `:level_4` (98% memory) - Emergency cleanup + force garbage collection

#### Statistics

##### `get_cleanup_stats/0` / `get_compression_stats/0`

Retrieves operation statistics.

```elixir
@spec get_cleanup_stats() :: map()
@spec get_compression_stats() :: map()

cleanup_stats = MemoryManager.get_cleanup_stats()
# => %{modules_cleaned: 150, data_removed_bytes: 2097152, total_cleanups: 25, ...}

compression_stats = MemoryManager.get_compression_stats()
# => %{modules_compressed: 75, total_space_saved: 5242880, avg_compression_ratio: 0.68, ...}
```

## Performance Optimization API

### ElixirScope.ASTRepository.PerformanceOptimizer

Provides performance optimization features for the repository.

#### Query Optimization

##### `optimize_query_cache/1`

Optimizes query caching based on access patterns.

```elixir
@spec optimize_query_cache(keyword()) :: :ok

:ok = PerformanceOptimizer.optimize_query_cache([
  cache_size: 1000,
  ttl: 300_000,  # 5 minutes
  preload_popular: true
])
```

##### `warm_cache/1`

Pre-loads frequently accessed data into cache.

```elixir
@spec warm_cache(keyword()) :: :ok

:ok = PerformanceOptimizer.warm_cache([
  modules: [:frequently_used_module],
  functions: [{:MyModule, :hot_function, 2}],
  analysis_types: [:cfg, :dfg]
])
```

#### Batch Operations

##### `store_modules_optimized/2`

Stores multiple modules with performance optimizations.

```elixir
@spec store_modules_optimized([{atom(), Macro.t()}], keyword()) :: :ok

modules = [{Module1, ast1}, {Module2, ast2}]

:ok = PerformanceOptimizer.store_modules_optimized(modules, [
  batch_size: 50,
  parallel: true,
  lazy_analysis: true
])
```

#### Lazy Loading

##### `enable_lazy_loading/1`

Configures lazy loading for large analysis data.

```elixir
@spec enable_lazy_loading(keyword()) :: :ok

:ok = PerformanceOptimizer.enable_lazy_loading([
  threshold_bytes: 1024,  # Load on-demand if > 1KB
  analysis_types: [:cpg, :dfg],
  cache_loaded: true
])
```

## Integration Patterns

### Phoenix Integration

```elixir
# In your Phoenix application
defmodule MyAppWeb.AnalysisController do
  use MyAppWeb, :controller
  
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  def analyze_module(conn, %{"module" => module_name}) do
    module_atom = String.to_existing_atom(module_name)
    
    case EnhancedRepository.get_enhanced_module(module_atom) do
      {:ok, module_data} ->
        json(conn, %{
          complexity: module_data.complexity_score,
          functions: length(module_data.functions),
          memory_usage: module_data.metadata.memory_usage
        })
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Module not found"})
    end
  end
end
```

### GenServer Integration

```elixir
defmodule MyApp.AnalysisWorker do
  use GenServer
  
  alias ElixirScope.ASTRepository.{EnhancedRepository, MemoryManager}
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Start repository and memory manager
    {:ok, _} = EnhancedRepository.start_link([])
    {:ok, _} = MemoryManager.start_link(monitoring_enabled: true)
    
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup, 300_000)  # 5 minutes
    
    {:ok, %{}}
  end
  
  def handle_info(:cleanup, state) do
    MemoryManager.cleanup_unused_data([])
    Process.send_after(self(), :cleanup, 300_000)
    {:noreply, state}
  end
end
```

### Supervision Tree Integration

```elixir
defmodule MyApp.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # Start Enhanced Repository
      {ElixirScope.ASTRepository.EnhancedRepository, []},
      
      # Start Memory Manager with monitoring
      {ElixirScope.ASTRepository.MemoryManager, [monitoring_enabled: true]},
      
      # Your application workers
      MyApp.AnalysisWorker
    ]
    
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Testing Integration

```elixir
defmodule MyApp.AnalysisTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.ASTRepository.{EnhancedRepository, MemoryManager}
  
  setup do
    # Start repository for testing
    {:ok, repo} = EnhancedRepository.start_link([])
    {:ok, memory_manager} = MemoryManager.start_link([])
    
    on_exit(fn ->
      if Process.alive?(repo), do: GenServer.stop(repo)
      if Process.alive?(memory_manager), do: GenServer.stop(memory_manager)
    end)
    
    %{repo: repo}
  end
  
  test "analyzes module complexity", %{repo: _repo} do
    ast = quote do
      defmodule TestModule do
        def simple_function, do: :ok
      end
    end
    
    :ok = EnhancedRepository.store_enhanced_module(TestModule, ast)
    
    {:ok, module_data} = EnhancedRepository.get_enhanced_module(TestModule)
    assert module_data.complexity_score > 0
  end
end
```

## Performance Characteristics

### Memory Usage

| Scale | Modules | Memory Usage | Per Module |
|-------|---------|--------------|------------|
| Small | 10 | ~25KB | ~2.5KB |
| Medium | 100 | ~250KB | ~2.5KB |
| Large | 1000 | ~2.5MB | ~2.5KB |

### Query Performance

| Operation | Target | Typical |
|-----------|--------|---------|
| Module lookup | <100ms | ~0.1ms |
| Function search | <100ms | ~0.05ms |
| Pattern matching | <100ms | ~0.02ms |
| Batch operations | <1s/100 modules | ~0.5s |

### Cache Performance

| Cache Type | TTL | Hit Ratio Target | Typical |
|------------|-----|------------------|---------|
| Query | 60s | >80% | ~95% |
| Analysis | 5min | >70% | ~85% |
| CPG | 10min | >60% | ~75% |

### Scalability Limits

- **Maximum modules**: 10,000+ (tested up to 1,000)
- **Memory limit**: Configurable (default: 500MB for 1,000 modules)
- **Concurrent queries**: 100+ concurrent operations
- **Startup time**: <30s for 1,000 modules

## Best Practices

### Memory Management

1. **Enable monitoring in production**:
   ```elixir
   MemoryManager.start_link(monitoring_enabled: true)
   ```

2. **Configure appropriate cleanup intervals**:
   ```elixir
   # For high-traffic applications
   cleanup_interval: 180_000  # 3 minutes
   
   # For low-traffic applications
   cleanup_interval: 600_000  # 10 minutes
   ```

3. **Use batch operations for bulk data**:
   ```elixir
   # Instead of individual stores
   EnhancedRepository.store_modules_batch(modules)
   ```

4. **Monitor memory pressure**:
   ```elixir
   {:ok, stats} = MemoryManager.monitor_memory_usage()
   if stats.memory_usage_percent > 80 do
     MemoryManager.memory_pressure_handler(:level_1)
   end
   ```

### Performance Optimization

1. **Use lazy loading for large modules**:
   ```elixir
   PerformanceOptimizer.enable_lazy_loading(threshold_bytes: 1024)
   ```

2. **Warm caches for frequently accessed data**:
   ```elixir
   PerformanceOptimizer.warm_cache(modules: [:frequently_used])
   ```

3. **Configure appropriate cache sizes**:
   ```elixir
   MemoryManager.implement_lru_cache(:query, max_size: 1000)
   ```

### Error Handling

1. **Always handle repository errors**:
   ```elixir
   case EnhancedRepository.get_enhanced_module(module) do
     {:ok, data} -> process_data(data)
     {:error, :not_found} -> handle_missing_module()
     {:error, reason} -> handle_error(reason)
   end
   ```

2. **Monitor memory manager health**:
   ```elixir
   case MemoryManager.monitor_memory_usage() do
     {:ok, stats} -> check_memory_health(stats)
     {:error, reason} -> alert_memory_monitoring_failure(reason)
   end
   ```

### Testing

1. **Use async: false for repository tests**:
   ```elixir
   use ExUnit.Case, async: false
   ```

2. **Clean up processes in tests**:
   ```elixir
   on_exit(fn ->
     if Process.alive?(repo), do: GenServer.stop(repo)
   end)
   ```

3. **Test memory management scenarios**:
   ```elixir
   test "handles memory pressure" do
     # Generate memory pressure
     # Test cleanup behavior
     # Verify memory recovery
   end
   ```

## Migration Guide

### From Basic to Enhanced Repository

#### Step 1: Update Dependencies

```elixir
# mix.exs
def deps do
  [
    # Add enhanced repository dependencies
    {:elixir_scope, "~> 0.1.0"}
  ]
end
```

#### Step 2: Replace Basic Repository Calls

**Before (Basic Repository):**
```elixir
# Basic repository usage
ASTRepository.store_module(MyModule, ast)
{:ok, data} = ASTRepository.get_module(MyModule)
```

**After (Enhanced Repository):**
```elixir
# Enhanced repository usage
EnhancedRepository.store_enhanced_module(MyModule, ast)
{:ok, enhanced_data} = EnhancedRepository.get_enhanced_module(MyModule)
```

#### Step 3: Add Memory Management

```elixir
# Start memory manager in your supervision tree
children = [
  {ElixirScope.ASTRepository.EnhancedRepository, []},
  {ElixirScope.ASTRepository.MemoryManager, [monitoring_enabled: true]}
]
```

#### Step 4: Update Data Access Patterns

**Before:**
```elixir
# Direct data access
module_data = get_module_data(module)
functions = module_data.functions
```

**After:**
```elixir
# Enhanced data access with error handling
case EnhancedRepository.get_enhanced_module(module) do
  {:ok, module_data} ->
    functions = module_data.functions
    complexity = module_data.complexity_score
    # Access enhanced analysis data
  {:error, reason} ->
    handle_error(reason)
end
```

#### Step 5: Leverage Enhanced Features

```elixir
# Use batch operations
modules = [{Module1, ast1}, {Module2, ast2}]
EnhancedRepository.store_modules_batch(modules)

# Enable performance optimizations
PerformanceOptimizer.enable_lazy_loading([])
PerformanceOptimizer.warm_cache(modules: frequently_used_modules)

# Monitor memory usage
{:ok, stats} = MemoryManager.monitor_memory_usage()
```

#### Step 6: Update Tests

```elixir
# Update test setup
setup do
  {:ok, repo} = EnhancedRepository.start_link([])
  {:ok, memory_manager} = MemoryManager.start_link([])
  
  on_exit(fn ->
    if Process.alive?(repo), do: GenServer.stop(repo)
    if Process.alive?(memory_manager), do: GenServer.stop(memory_manager)
  end)
  
  %{repo: repo}
end
```

### Migration Checklist

- [ ] Update dependencies
- [ ] Replace basic repository calls
- [ ] Add memory manager to supervision tree
- [ ] Update data access patterns with error handling
- [ ] Enable performance optimizations
- [ ] Add memory monitoring
- [ ] Update tests for enhanced repository
- [ ] Configure cleanup and compression intervals
- [ ] Set up cache warming for frequently accessed data
- [ ] Add memory pressure handling

### Breaking Changes

1. **Return Values**: Enhanced repository returns `{:ok, data}` tuples instead of direct data
2. **Data Structures**: `EnhancedModuleData` has different fields than basic `ModuleData`
3. **Function Signatures**: Some functions have additional optional parameters
4. **Process Management**: Requires starting additional GenServer processes

### Compatibility Layer

For gradual migration, you can create a compatibility layer:

```elixir
defmodule MyApp.RepositoryAdapter do
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  # Compatibility wrapper for basic repository calls
  def store_module(module, ast) do
    case EnhancedRepository.store_enhanced_module(module, ast) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  def get_module(module) do
    case EnhancedRepository.get_enhanced_module(module) do
      {:ok, enhanced_data} -> {:ok, convert_to_basic_data(enhanced_data)}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp convert_to_basic_data(enhanced_data) do
    # Convert enhanced data to basic format
    %{
      module_name: enhanced_data.module_name,
      ast: enhanced_data.ast,
      functions: enhanced_data.functions
      # ... other basic fields
    }
  end
end
```

## Troubleshooting

### Common Issues

#### High Memory Usage

**Symptoms:**
- Memory usage exceeding expected limits
- Slow query performance
- Out of memory errors

**Solutions:**
1. Enable memory monitoring:
   ```elixir
   {:ok, stats} = MemoryManager.monitor_memory_usage()
   ```

2. Reduce cleanup intervals:
   ```elixir
   MemoryManager.cleanup_unused_data(max_age: 1800)  # 30 minutes
   ```

3. Enable compression:
   ```elixir
   MemoryManager.compress_old_analysis([])
   ```

#### Poor Cache Performance

**Symptoms:**
- Low cache hit ratios
- Slow repeated queries

**Solutions:**
1. Check cache configuration:
   ```elixir
   MemoryManager.implement_lru_cache(:query, max_size: 2000)
   ```

2. Warm cache with frequently accessed data:
   ```elixir
   PerformanceOptimizer.warm_cache(modules: hot_modules)
   ```

3. Adjust TTL values:
   ```elixir
   # Increase TTL for stable data
   cache_ttl: 600_000  # 10 minutes
   ```

#### Slow Startup Times

**Symptoms:**
- Long application startup
- Timeout errors during initialization

**Solutions:**
1. Enable lazy loading:
   ```elixir
   PerformanceOptimizer.enable_lazy_loading(threshold_bytes: 512)
   ```

2. Use batch operations:
   ```elixir
   EnhancedRepository.store_modules_batch(modules)
   ```

3. Reduce initial analysis depth:
   ```elixir
   # Store basic data first, analyze later
   EnhancedRepository.store_enhanced_module(module, ast, analyze: false)
   ```

### Debug Information

#### Memory Statistics

```elixir
{:ok, stats} = MemoryManager.monitor_memory_usage()
IO.inspect(stats, label: "Memory Stats")
```

#### Cache Statistics

```elixir
cleanup_stats = MemoryManager.get_cleanup_stats()
compression_stats = MemoryManager.get_compression_stats()
IO.inspect({cleanup_stats, compression_stats}, label: "Operation Stats")
```

#### Performance Metrics

```elixir
# Enable telemetry for detailed metrics
:telemetry.attach("repo-metrics", [:enhanced_repository, :query], fn event, measurements, metadata, _config ->
  IO.puts("Query #{metadata.type} took #{measurements.duration}ms")
end, nil)
```

### Support

For additional support:

1. Check the [Integration Guide](INTEGRATION_GUIDE.md)
2. Review test files for usage examples
3. Enable debug logging for detailed operation traces
4. Use the built-in monitoring and statistics functions

---

*This documentation covers Enhanced AST Repository v0.1.0. For the latest updates, please refer to the project repository.* 