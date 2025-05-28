
## New Document: `CPG_MIGRATION_STRATEGY.MD`

```markdown
# CPG Migration and Rollout Strategy

## 1. Phased Rollout Approach

### Phase 1: Foundation (Weeks 1-2)
**Goal**: Enhance existing ETS infrastructure without breaking changes

**Deliverables**:
- Enhanced `CPGData.t()` with versioning and caching fields
- New ETS tables for CPG storage alongside existing tables
- Backward-compatible serialization for existing data
- Basic CPG generation for simple functions

**Risk Mitigation**:
- All changes additive, no modifications to existing schemas
- Feature flags for CPG generation (disabled by default)
- Comprehensive rollback procedures documented

### Phase 2: Core Algorithms (Weeks 3-4)
**Goal**: Implement essential graph algorithms with ETS integration

**Deliverables**:
- `CPGMath` module with basic graph algorithms
- ETS-optimized caching for algorithmic results
- Query integration for simple CPG metrics
- Performance monitoring and alerting

**Risk Mitigation**:
- Algorithm correctness validation against known test cases
- Performance regression testing on existing queries
- Circuit breaker pattern for expensive computations

### Phase 3: Advanced Features (Weeks 5-6)
**Goal**: Full CPG semantic analysis and pattern detection

**Deliverables**:
- `CPGSemantics` with code-aware interpretations
- Enhanced `PatternMatcher` with CPG rules
- AI/ML feature extraction via CPG
- Complete query language extensions

**Risk Mitigation**:
- A/B testing of pattern detection accuracy
- User feedback collection on new analysis features
- Performance impact assessment on production workloads

## 2. Data Migration Strategy

### Existing Data Preservation
```elixir
# Migration function to enhance existing ETS data
def migrate_existing_ast_data_to_cpg_compatible() do
  # Read existing enhanced module data
  existing_modules = :ets.tab2list(@enhanced_ast_repository)
  
  Enum.each(existing_modules, fn {key, serialized_data} ->
    module_data = EnhancedModuleData.from_ets_format(serialized_data)
    
    # Add CPG-compatible fields without changing core structure
    enhanced_data = %{module_data | 
      cpg_metadata: %{version: 1, generation_pending: true},
      unified_analysis: UnifiedAnalysis.empty()
    }
    
    # Store back with new fields
    :ets.insert(@enhanced_ast_repository, {key, EnhancedModuleData.to_ets_format(enhanced_data)})
  end)
end
```

### Progressive CPG Generation
```elixir
# Generate CPGs incrementally without blocking existing functionality
def generate_cpg_progressively() do
  # Priority queue: most accessed modules first
  modules_by_priority = get_modules_by_access_frequency()
  
  Task.async_stream(modules_by_priority, fn module_key ->
    try do
      generate_and_store_cpg(module_key)
    rescue
      error -> 
        Logger.warn("CPG generation failed for #{inspect(module_key)}: #{inspect(error)}")
        mark_cpg_generation_failed(module_key)
    end
  end, max_concurrency: System.schedulers())
  |> Stream.run()
end
```

## 3. Rollback Procedures

### ETS Table Rollback
```elixir
def rollback_cpg_tables() do
  # Safely remove CPG-specific tables
  safe_ets_delete(@cpg_nodes_table)
  safe_ets_delete(@cpg_edges_table) 
  safe_ets_delete(@cpg_analysis_cache)
  
  # Remove CPG fields from existing module data
  rollback_enhanced_module_data()
end

defp safe_ets_delete(table) do
  if :ets.info(table) != :undefined do
    :ets.delete(table)
  end
end
```

### Query Compatibility Layer
```elixir
# Ensure existing queries continue to work during migration
defmodule CPGCompatibilityLayer do
  def execute_query_with_fallback(query_spec) do
    case execute_cpg_enhanced_query(query_spec) do
      {:ok, result} -> {:ok, result}
      {:error, :cpg_not_available} -> 
        execute_legacy_query(query_spec)
      {:error, _} = error -> 
        Logger.warn("CPG query failed, falling back to legacy: #{inspect(error)}")
        execute_legacy_query(query_spec)
    end
  end
end
```
```

## Revised Test Strategy Emphasizing Production Readiness

### Update `CPG-OPUS_TESTLIST.md` with Production-Focused Tests

Add new test categories:

```markdown
### XII. Production Readiness Tests

#### Migration and Compatibility Tests
- `test "existing ElixirScope installations can upgrade without data loss"`
- `test "CPG features gracefully degrade when ETS memory limits reached"`
- `test "concurrent access to ETS tables during CPG generation is safe"`
- `test "CPG generation failure does not impact existing AST functionality"`
- `test "rollback procedures restore system to pre-CPG state successfully"`

#### Load and Stress Tests  
- `test "CPG generation under memory pressure completes or fails gracefully"`
- `test "concurrent CPG queries do not cause ETS table locks or deadlocks"`
- `test "large project analysis (10k+ functions) completes within SLA"`
- `test "ETS table corruption detection and recovery procedures work"`
- `test "CPG cache eviction under memory pressure maintains query functionality"`

#### Monitoring and Observability Tests
- `test "CPG operation metrics are correctly reported to telemetry"`
- `test "ETS table size monitoring triggers appropriate alerts"`
- `test "slow CPG queries are identified and logged for optimization"`
- `test "CPG cache hit/miss ratios are tracked and reported"`
- `test "algorithm performance regressions are detected automatically"`
```

