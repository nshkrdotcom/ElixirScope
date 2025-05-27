# AST Repository Implementation Guide

## Overview

This guide provides step-by-step implementation instructions for the enhanced AST Repository (Phase 3, Week 1-2). It includes code organization, implementation order, integration points, and specific technical considerations.

## Implementation Order

### Phase 1: Foundation (Days 1-3)

1. **Enhanced Data Structures**
   - Implement all data schemas from the specification
   - Add type specs and documentation
   - Create factory functions for testing

2. **ETS Table Management**
   - Extend existing Repository GenServer
   - Create all required tables with indexes
   - Implement table cleanup and memory management

3. **Basic Storage Operations**
   - Implement store/retrieve for modules and functions
   - Add index maintenance logic
   - Create batch operation support

### Phase 2: AST Analysis (Days 4-6)

1. **AST Analyzer Enhancement**
   - Implement comprehensive AST traversal
   - Extract all metadata (variables, calls, patterns)
   - Calculate complexity metrics

2. **CFG Generator**
   - Implement control flow graph generation
   - Handle all Elixir control structures
   - Calculate complexity metrics

3. **DFG Generator**
   - Implement data flow analysis
   - Track variable definitions and uses
   - Identify data dependencies

### Phase 3: Project Population (Days 7-9)

1. **Project Populator**
   - Implement file discovery with filtering
   - Create parallel parsing pipeline
   - Add progress reporting

2. **File Watcher Integration**
   - Implement FileSystem-based watching
   - Add debouncing logic
   - Create change event handling

3. **Synchronizer**
   - Implement incremental updates
   - Add change detection logic
   - Handle cascading updates

### Phase 4: Advanced Features (Days 10-12)

1. **CPG Builder**
   - Combine AST, CFG, and DFG
   - Create unified graph structure
   - Implement pattern detection

2. **Query Engine Integration**
   - Extend existing query engine
   - Add AST-specific query types
   - Implement query optimization

3. **Performance Optimization**
   - Add caching layers
   - Implement lazy loading
   - Optimize memory usage

### Phase 5: Testing & Documentation (Days 13-14)

1. **Comprehensive Testing**
   - Unit tests for all components
   - Integration tests
   - Performance benchmarks

2. **Documentation**
   - API documentation
   - Usage examples
   - Architecture documentation

## Code Organization

```
lib/elixir_scope/ast_repository/
├── enhanced/
│   ├── schemas/
│   │   ├── enhanced_module_data.ex
│   │   ├── enhanced_function_data.ex
│   │   ├── variable_data.ex
│   │   ├── cfg_data.ex
│   │   ├── dfg_data.ex
│   │   └── cpg_data.ex
│   ├── analyzers/
│   │   ├── ast_analyzer.ex
│   │   ├── cfg_generator.ex
│   │   ├── dfg_generator.ex
│   │   └── cpg_builder.ex
│   ├── storage/
│   │   ├── repository.ex (enhanced version)
│   │   ├── table_manager.ex
│   │   └── index_manager.ex
│   └── population/
│       ├── project_populator.ex
│       ├── file_watcher.ex
│       └── synchronizer.ex
├── queries/
│   ├── query_builder.ex
│   ├── query_executor.ex
│   └── query_optimizer.ex
└── integration/
    ├── runtime_bridge.ex
    ├── temporal_bridge.ex
    └── ai_bridge.ex
```

## Integration Points

### 1. With Existing Repository

The enhanced repository should extend, not replace, the existing one:

```elixir
defmodule ElixirScope.ASTRepository.Repository do
  # Existing code...
  
  # Add new enhanced storage functions
  def store_enhanced_module(module_data) do
    # Store in existing tables
    store_module(module_data)
    
    # Store in new enhanced tables
    store_enhanced_data(module_data)
    
    # Update indexes
    update_indexes(module_data)
  end
end
```

### 2. With InstrumentationRuntime

Enhance AST node ID generation and correlation:

```elixir
# In InstrumentationMapper
def generate_enhanced_ast_node_id(ast_path, context) do
  # Generate richer IDs with more context
  base_id = generate_ast_node_id(ast_path)
  
  # Add variable scope, control flow context, etc.
  "#{base_id}:#{context.scope_id}:#{context.cfg_node_id}"
end
```

### 3. With TemporalBridge

Add AST-aware event filtering and correlation:

```elixir
# In TemporalBridge
def store_event_with_ast_context(event, ast_context) do
  enhanced_event = %{
    event | 
    ast_node_id: ast_context.node_id,
    ast_metadata: %{
      function_complexity: ast_context.complexity,
      variable_scope: ast_context.scope,
      control_flow_path: ast_context.cfg_path
    }
  }
  
  store_event(enhanced_event)
end
```

### 4. With Query Engine

Extend query engine to support AST queries:

```elixir
# In Query.Engine
def execute_ast_query(query) do
  case query.type do
    :ast_pattern ->
      Repository.query_by_ast_pattern(query.pattern)
    
    :complexity ->
      Repository.query_by_complexity(query.criteria)
    
    :data_flow ->
      Repository.query_data_flow(query.variable, query.scope)
  end
end
```

## Technical Considerations

### 1. Memory Management

```elixir
# Implement memory limits
defmodule ElixirScope.ASTRepository.MemoryManager do
  @max_memory_mb 500
  @cleanup_threshold 0.9
  
  def check_memory_usage do
    current_usage = calculate_ets_memory()
    
    if current_usage > @max_memory_mb * @cleanup_threshold do
      perform_cleanup()
    end
  end
  
  defp perform_cleanup do
    # Remove least recently used entries
    # Archive to disk if needed
    # Trigger garbage collection
  end
end
```

### 2. Performance Optimization

```elixir
# Parallel processing for large projects
defmodule ElixirScope.ASTRepository.ParallelProcessor do
  def process_files(files) do
    files
    |> Task.async_stream(&parse_and_analyze/1,
        max_concurrency: System.schedulers_online(),
        timeout: 30_000
      )
    |> Enum.reduce({[], []}, fn
      {:ok, result}, {results, errors} -> 
        {[result | results], errors}
      {:error, error}, {results, errors} -> 
        {results, [error | errors]}
    end)
  end
end
```

### 3. Error Handling

```elixir
# Graceful error handling
defmodule ElixirScope.ASTRepository.ErrorHandler do
  require Logger
  
  def handle_parse_error(file, error) do
    Logger.warning("Failed to parse #{file}: #{inspect(error)}")
    
    # Store partial results if possible
    store_error_metadata(file, error)
    
    # Continue with other files
    {:continue, build_error_report(file, error)}
  end
  
  def handle_analysis_error(module, error) do
    Logger.error("Analysis failed for #{module}: #{inspect(error)}")
    
    # Fall back to basic analysis
    perform_basic_analysis(module)
  end
end
```

### 4. Change Detection

```elixir
# Efficient change detection
defmodule ElixirScope.ASTRepository.ChangeDetector do
  def detect_changes(file_path) do
    current_hash = hash_file(file_path)
    stored_hash = Repository.get_file_hash(file_path)
    
    cond do
      stored_hash == nil -> :new_file
      current_hash == stored_hash -> :unchanged
      true -> analyze_changes(file_path, stored_hash, current_hash)
    end
  end
  
  defp analyze_changes(file_path, old_hash, new_hash) do
    # Determine what specifically changed
    # Return detailed change information
  end
end
```

## Testing Strategy

### 1. Unit Test Structure

```elixir
defmodule ElixirScope.ASTRepository.EnhancedModuleDataTest do
  use ExUnit.Case, async: true
  
  describe "new/2" do
    test "creates module data with all fields" do
      ast = quote do
        defmodule TestModule do
          def test_function, do: :ok
        end
      end
      
      module_data = EnhancedModuleData.new(TestModule, ast)
      
      assert module_data.module_name == TestModule
      assert length(module_data.functions) == 1
      assert module_data.complexity_metrics.cyclomatic >= 1
    end
  end
end
```

### 2. Integration Test Structure

```elixir
defmodule ElixirScope.ASTRepository.IntegrationTest do
  use ExUnit.Case, async: false
  
  setup do
    # Start repository
    {:ok, repo} = Repository.start_link()
    
    # Create test project
    project_path = create_test_project()
    
    on_exit(fn ->
      cleanup_test_project(project_path)
    end)
    
    {:ok, repo: repo, project: project_path}
  end
  
  test "complete project population workflow", %{repo: repo, project: path} do
    # Test complete workflow
    assert {:ok, stats} = ProjectPopulator.populate_project(path)
    assert stats.modules > 0
    
    # Verify data integrity
    assert {:ok, modules} = Repository.list_modules(repo)
    assert length(modules) == stats.modules
  end
end
```

### 3. Performance Test Structure

```elixir
defmodule ElixirScope.ASTRepository.PerformanceTest do
  use ExUnit.Case, async: false
  
  @tag :performance
  test "handles large projects efficiently" do
    large_project = generate_large_project(modules: 100)
    
    {time, {:ok, _stats}} = :timer.tc(fn ->
      ProjectPopulator.populate_project(large_project)
    end)
    
    # Should complete in under 30 seconds
    assert time < 30_000_000
  end
end
```

## Migration Strategy

### 1. Backward Compatibility

```elixir
# Maintain backward compatibility
defmodule ElixirScope.ASTRepository.Repository do
  # Existing API
  def get_module(name) do
    # Try enhanced storage first
    case get_enhanced_module(name) do
      {:ok, enhanced} -> {:ok, to_legacy_format(enhanced)}
      {:error, :not_found} -> get_legacy_module(name)
    end
  end
  
  # New enhanced API
  def get_enhanced_module(name) do
    # Implementation
  end
end
```

### 2. Data Migration

```elixir
defmodule ElixirScope.ASTRepository.Migrator do
  def migrate_to_enhanced do
    # Get all existing modules
    modules = Repository.list_legacy_modules()
    
    # Migrate each module
    modules
    |> Task.async_stream(&migrate_module/1)
    |> Stream.run()
  end
  
  defp migrate_module(module_data) do
    # Re-analyze with enhanced analyzer
    enhanced = enhance_module_data(module_data)
    
    # Store in new format
    Repository.store_enhanced_module(enhanced)
  end
end
```

## Monitoring and Debugging

### 1. Performance Metrics

```elixir
defmodule ElixirScope.ASTRepository.Metrics do
  def record_operation(operation, time) do
    :telemetry.execute(
      [:ast_repository, operation],
      %{duration: time},
      %{}
    )
  end
  
  def setup_telemetry do
    :telemetry.attach_many(
      "ast-repository-metrics",
      [
        [:ast_repository, :parse],
        [:ast_repository, :analyze],
        [:ast_repository, :store],
        [:ast_repository, :query]
      ],
      &handle_event/4,
      nil
    )
  end
end
```

### 2. Debug Helpers

```elixir
defmodule ElixirScope.ASTRepository.Debug do
  def inspect_module(module_name) do
    with {:ok, data} <- Repository.get_enhanced_module(module_name),
         {:ok, cpg} <- CPGBuilder.build_cpg(data) do
      %{
        module: module_name,
        functions: length(data.functions),
        complexity: data.complexity_metrics,
        ast_nodes: count_ast_nodes(data.ast),
        cpg_nodes: map_size(cpg.nodes),
        cpg_edges: count_edges(cpg)
      }
    end
  end
  
  def visualize_cfg(module_name, function_name, arity) do
    with {:ok, function} <- Repository.get_function(module_name, function_name, arity),
         {:ok, cfg} <- CFGGenerator.generate_cfg(function.ast) do
      # Generate DOT format for visualization
      generate_dot_graph(cfg)
    end
  end
  
  def analyze_memory_usage do
    tables = [
      :ast_modules_enhanced,
      :ast_functions_enhanced,
      :ast_nodes_detailed,
      :ast_variables,
      :ast_cpg
    ]
    
    Enum.map(tables, fn table ->
      info = :ets.info(table)
      %{
        table: table,
        size: info[:size],
        memory_bytes: info[:memory],
        memory_mb: info[:memory] / 1_048_576
      }
    end)
  end
end
```

## Common Pitfalls and Solutions

### 1. AST Size Explosion

**Problem**: Full ASTs can be very large for complex modules.

**Solution**:
```elixir
defmodule ElixirScope.ASTRepository.ASTCompressor do
  @max_ast_depth 50
  @max_node_children 100
  
  def compress_ast(ast) do
    ast
    |> limit_depth(@max_ast_depth)
    |> limit_children(@max_node_children)
    |> remove_metadata()
    |> store_separately_if_large()
  end
  
  defp store_separately_if_large(ast) do
    if ast_size(ast) > 1000 do
      # Store in separate table/file
      id = generate_ast_id()
      LargeASTStorage.store(id, ast)
      {:ref, id}
    else
      ast
    end
  end
end
```

### 2. Circular Dependencies

**Problem**: Modules with circular dependencies can cause infinite loops.

**Solution**:
```elixir
defmodule ElixirScope.ASTRepository.DependencyResolver do
  def resolve_dependencies(modules, visited \\ MapSet.new()) do
    Enum.reduce(modules, {[], visited}, fn module, {acc, visited} ->
      if MapSet.member?(visited, module) do
        {acc, visited}
      else
        resolve_module(module, acc, MapSet.put(visited, module))
      end
    end)
  end
  
  defp resolve_module(module, acc, visited) do
    # Process dependencies with cycle detection
    deps = get_dependencies(module)
    
    {resolved_deps, new_visited} = 
      resolve_dependencies(deps, visited)
    
    {[module | resolved_deps] ++ acc, new_visited}
  end
end
```

### 3. File System Race Conditions

**Problem**: Files changing during analysis.

**Solution**:
```elixir
defmodule ElixirScope.ASTRepository.SafeFileReader do
  @max_retries 3
  
  def read_and_parse(file_path) do
    read_with_retry(file_path, @max_retries)
  end
  
  defp read_with_retry(file_path, retries) do
    try do
      content = File.read!(file_path)
      hash = :crypto.hash(:sha256, content)
      
      case Code.string_to_quoted(content) do
        {:ok, ast} -> 
          # Verify file hasn't changed
          if :crypto.hash(:sha256, File.read!(file_path)) == hash do
            {:ok, ast, hash}
          else
            read_with_retry(file_path, retries - 1)
          end
          
        {:error, _} = error -> 
          error
      end
    rescue
      e in File.Error ->
        if retries > 0 do
          Process.sleep(100)
          read_with_retry(file_path, retries - 1)
        else
          {:error, e}
        end
    end
  end
end
```

### 4. Memory Leaks

**Problem**: ETS tables growing without bounds.

**Solution**:
```elixir
defmodule ElixirScope.ASTRepository.MemoryGuard do
  use GenServer
  
  @check_interval 60_000  # 1 minute
  @max_table_size 100_000
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end
  
  def handle_info(:check_memory, state) do
    check_all_tables()
    schedule_check()
    {:noreply, state}
  end
  
  defp check_all_tables do
    tables = [:ast_modules_enhanced, :ast_functions_enhanced]
    
    Enum.each(tables, fn table ->
      size = :ets.info(table, :size)
      
      if size > @max_table_size do
        cleanup_table(table)
      end
    end)
  end
  
  defp cleanup_table(table) do
    # Remove least recently used entries
    # Or archive to disk
  end
  
  defp schedule_check do
    Process.send_after(self(), :check_memory, @check_interval)
  end
end
```

## Configuration

### 1. Application Configuration

```elixir
# config/config.exs
config :elixir_scope, :ast_repository,
  # Storage settings
  max_memory_mb: 500,
  max_ast_size: 10_000,
  
  # Analysis settings
  parallel_workers: System.schedulers_online(),
  analysis_timeout: 30_000,
  
  # File watching
  debounce_ms: 500,
  ignore_patterns: ["_build", "deps", ".git"],
  
  # Performance
  cache_ttl: 300_000,  # 5 minutes
  batch_size: 100
```

### 2. Runtime Configuration

```elixir
defmodule ElixirScope.ASTRepository.Config do
  def configure(opts) do
    Enum.each(opts, fn {key, value} ->
      Application.put_env(:elixir_scope, [:ast_repository, key], value)
    end)
  end
  
  def get(key, default \\ nil) do
    Application.get_env(:elixir_scope, [:ast_repository, key], default)
  end
end
```

## Deployment Considerations

### 1. Resource Requirements

```elixir
defmodule ElixirScope.ASTRepository.ResourceEstimator do
  def estimate_requirements(project_stats) do
    %{
      memory_mb: estimate_memory(project_stats),
      cpu_cores: estimate_cpu(project_stats),
      disk_mb: estimate_disk(project_stats),
      analysis_time_minutes: estimate_time(project_stats)
    }
  end
  
  defp estimate_memory(%{modules: m, avg_module_size: s}) do
    base_overhead = 100  # MB
    per_module = 0.5     # MB
    
    base_overhead + (m * per_module * (s / 1000))
  end
end
```

### 2. Scaling Strategy

```elixir
defmodule ElixirScope.ASTRepository.Scaler do
  def scale_for_large_project(project_size) do
    cond do
      project_size < 100 ->
        %{strategy: :single_node, workers: 4}
        
      project_size < 1000 ->
        %{strategy: :single_node, workers: 8}
        
      true ->
        %{strategy: :distributed, nodes: 4, workers_per_node: 4}
    end
  end
end
```

## Future Enhancements

### 1. Graph Database Integration

```elixir
# Prepare for future graph database
defmodule ElixirScope.ASTRepository.GraphAdapter do
  @callback store_node(node_type, id, properties) :: :ok | {:error, term()}
  @callback store_edge(from_id, to_id, edge_type, properties) :: :ok | {:error, term()}
  @callback query_pattern(pattern) :: {:ok, results} | {:error, term()}
end

defmodule ElixirScope.ASTRepository.GraphBridge do
  @behaviour GraphAdapter
  
  # Implement adapter pattern for future graph DB
  def store_ast_as_graph(ast, metadata) do
    # Convert AST to graph representation
    # Store in graph database when available
    # For now, store in ETS with graph-like structure
  end
end
```

### 2. Machine Learning Integration

```elixir
# Prepare for ML integration
defmodule ElixirScope.ASTRepository.MLBridge do
  def prepare_features(ast_data) do
    %{
      structural_features: extract_structural_features(ast_data),
      complexity_features: extract_complexity_features(ast_data),
      pattern_features: extract_pattern_features(ast_data)
    }
  end
  
  def generate_embeddings(ast_data) do
    # Future: Call ML model to generate embeddings
    # For now: Generate basic feature vectors
    features = prepare_features(ast_data)
    normalize_features(features)
  end
end
```

### 3. Distributed Repository

```elixir
# Prepare for distributed operation
defmodule ElixirScope.ASTRepository.Distributed do
  def shard_by_module(module_name) do
    # Determine which node should store this module
    :erlang.phash2(module_name, node_count())
  end
  
  def replicate_critical_data(data) do
    # Replicate important data across nodes
    # For now: Single node operation
  end
  
  def query_all_nodes(query) do
    # Future: Query across distributed nodes
    # For now: Query local node
    Repository.execute_query(query)
  end
end
```

## Checklist for Implementation

### Week 1 Tasks
- [ ] Implement enhanced data schemas
- [ ] Create ETS table management
- [ ] Build basic storage operations
- [ ] Implement AST analyzer
- [ ] Create CFG generator
- [ ] Build DFG generator
- [ ] Write unit tests for core components

### Week 2 Tasks
- [ ] Implement project populator
- [ ] Integrate file watcher
- [ ] Create synchronizer
- [ ] Build CPG generator
- [ ] Integrate with query engine
- [ ] Optimize performance
- [ ] Complete integration tests
- [ ] Write documentation

### Quality Gates
- [ ] All tests passing (>95% coverage)
- [ ] Performance benchmarks met
- [ ] Memory usage within limits
- [ ] Documentation complete
- [ ] Code review passed
- [ ] Integration verified

## Conclusion

This implementation guide provides a comprehensive roadmap for building the enhanced AST Repository. Key success factors:

1. **Incremental Development**: Build in phases, test each component
2. **Performance Focus**: Monitor and optimize from the start
3. **Error Resilience**: Handle failures gracefully
4. **Future Proofing**: Design for extensibility
5. **Testing Rigor**: Comprehensive test coverage

Following this guide will result in a robust, performant AST Repository that serves as the foundation for ElixirScope's revolutionary debugging capabilities.