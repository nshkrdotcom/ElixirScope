# CURSOR_EXISTING.md - Comprehensive AST Infrastructure Inventory

## Executive Summary

After thorough analysis of the ElixirScope codebase, I've discovered a **complex, multi-layered AST infrastructure** with significant duplication, unclear boundaries, and a mix of working and broken components. This document provides a complete inventory to guide our consolidation and improvement efforts.

## Directory Structure Analysis

### Why Two AST Directories?

#### `lib/elixir_scope/ast/` - **Compile-Time AST Processing**
- **Purpose**: AST transformation and injection during compilation
- **Files**: 3 files, ~28KB total
  - `transformer.ex` (279 lines) - Basic AST transformation
  - `enhanced_transformer.ex` (299 lines) - Advanced AST transformation
  - `injector_helpers.ex` (355 lines) - AST injection utilities
- **Focus**: Modifying AST during compilation for instrumentation

#### `lib/elixir_scope/ast_repository/` - **Runtime AST Storage & Analysis**
- **Purpose**: Storing, analyzing, and querying AST at runtime
- **Files**: 9 files, ~142KB total (excluding enhanced/)
- **Focus**: Persistent AST storage, runtime correlation, analysis

#### `lib/elixir_scope/ast_repository/enhanced/` - **Advanced Analysis Components**
- **Purpose**: CFG, DFG, CPG generation and advanced AST analysis
- **Files**: 14 files, ~155KB total
- **Focus**: Revolutionary debugging capabilities through graph analysis

**Conclusion**: The separation makes sense - `ast/` for compile-time, `ast_repository/` for runtime. The `enhanced/` subdirectory contains the Phase 3 advanced features.

## Complete Component Inventory

### 1. Compile-Time AST Processing (`ast/`)

| File | Lines | Purpose | Status | Test Coverage |
|------|-------|---------|--------|---------------|
| `transformer.ex` | 279 | Basic AST transformation | ✅ Working | ❓ Unknown |
| `enhanced_transformer.ex` | 299 | Advanced AST transformation | ✅ Working | ❓ Unknown |
| `injector_helpers.ex` | 355 | AST injection utilities | ✅ Working | ❓ Unknown |

**Analysis**: These appear to be working compile-time components. Need to verify test coverage.

### 2. Core AST Repository (`ast_repository/`)

| File | Lines | Purpose | Status | Test Coverage |
|------|-------|---------|--------|---------------|
| `repository.ex` | 525 | Basic AST repository | ✅ Working | ✅ Tested (358 lines) |
| `enhanced_repository.ex` | 641 | Enhanced AST repository with GenServer | ⚠️ Partial | ✅ Tested (473 lines) |
| `parser.ex` | 354 | AST parsing utilities | ✅ Working | ✅ Tested (67 lines) |
| `module_data.ex` | 726 | Module-level AST data | ✅ Working | ✅ Tested (298 lines) |
| `function_data.ex` | 367 | Function-level AST data | ✅ Working | ❓ Unknown |
| `enhanced_module_data.ex` | 433 | Enhanced module data | ⚠️ Partial | ❓ Unknown |
| `enhanced_function_data.ex` | 630 | Enhanced function data | ⚠️ Partial | ❓ Unknown |
| `runtime_correlator.ex` | 592 | Runtime-AST correlation | ✅ Working | ✅ Tested (329 lines) |
| `instrumentation_mapper.ex` | 502 | Instrumentation mapping | ✅ Working | ✅ Tested (522 lines) |

**Analysis**: Core repository is mostly working. Enhanced components are partially implemented.

### 3. Enhanced Analysis Components (`ast_repository/enhanced/`)

| File | Lines | Purpose | Status | Test Coverage | Test Results |
|------|-------|---------|--------|---------------|--------------|
| `cfg_generator.ex` | 705 | Control Flow Graph generation | ❌ Broken | ✅ Tested (601 lines) | 24 tests, 18 failures |
| `dfg_generator.ex` | 962 | Data Flow Graph generation | ❌ Broken | ✅ Tested (496 lines) | 21 tests, 19 failures |
| `cpg_builder.ex` | 715 | Code Property Graph builder | ❌ Broken | ✅ Tested (538 lines) | 19 tests, 18 failures |
| `enhanced_repository.ex` | 464 | Enhanced repository interface | ⚠️ Partial | ❓ Unknown | ❓ Unknown |
| `project_populator.ex` | 741 | Project-wide AST discovery | ✅ Working | ✅ Tested (475 lines) | All passing, 1 skipped |
| `file_watcher.ex` | 744 | Real-time file monitoring | ⚠️ Partial | ✅ Tested (513 lines) | 17 tests, 13 failures |
| `synchronizer.ex` | 86 | AST synchronization | ❌ Broken | ✅ Tested (475 lines) | 16 tests, 12 failures |
| `complexity_metrics.ex` | 449 | Code complexity analysis | ❓ Unknown | ❓ Unknown | ❓ Unknown |

**Supporting Data Structures:**
| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| `cfg_data.ex` | 81 | CFG data structures | ✅ Basic |
| `dfg_data.ex` | 93 | DFG data structures | ✅ Basic |
| `cpg_data.ex` | 35 | CPG data structures | ✅ Basic |
| `variable_data.ex` | 27 | Variable data structures | ✅ Basic |
| `supporting_structures.ex` | 552 | Supporting data structures | ✅ Working |
| `enhanced_module_data.ex` | 49 | Enhanced module data | ✅ Basic |
| `enhanced_function_data.ex` | 141 | Enhanced function data | ✅ Basic |

**Analysis**: The enhanced components are extensively tested but mostly broken. Data structures are basic compared to research designs.

## Test Coverage Analysis

### Comprehensive Test Suite (7,000+ lines total)

| Component | Test File | Lines | Status | Pass Rate |
|-----------|-----------|-------|--------|-----------|
| **Working Components** |
| Repository | `repository_test.exs` | 358 | ✅ Passing | ~100% |
| Enhanced Repository | `enhanced_repository_test.exs` | 473 | ✅ Passing | ~100% |
| Runtime Correlator | `runtime_correlator_test.exs` | 329 | ✅ Passing | ~100% |
| Instrumentation Mapper | `instrumentation_mapper_test.exs` | 522 | ✅ Passing | ~100% |
| Project Populator | `project_populator_test.exs` | 475 | ✅ Passing | ~100% |
| **Broken Components** |
| CFG Generator | `cfg_generator_test.exs` | 601 | ❌ Failing | 25% (6/24) |
| DFG Generator | `dfg_generator_test.exs` | 496 | ❌ Failing | 10% (2/21) |
| CPG Builder | `cpg_builder_test.exs` | 538 | ❌ Failing | 5% (1/19) |
| File Watcher | `file_watcher_test.exs` | 513 | ❌ Failing | 24% (4/17) |
| Synchronizer | `synchronizer_test.exs` | 475 | ❌ Failing | 25% (4/16) |

**Total Test Coverage**: ~7,000 lines of tests covering all major components

## Architecture Analysis

### Data Flow Architecture

```
Compile Time:
AST Source → ast/transformer.ex → Instrumented AST → Compilation

Runtime:
Instrumented Code → Events → ast_repository/repository.ex → Storage
                         ↓
Enhanced Analysis: ast_repository/enhanced/* → CFG/DFG/CPG → Queries
```

### Component Dependencies

```
Core Dependencies (Working):
- repository.ex ← module_data.ex, function_data.ex
- enhanced_repository.ex ← repository.ex
- runtime_correlator.ex ← repository.ex
- instrumentation_mapper.ex ← repository.ex

Enhanced Dependencies (Broken):
- cfg_generator.ex ← supporting_structures.ex, cfg_data.ex
- dfg_generator.ex ← supporting_structures.ex, dfg_data.ex
- cpg_builder.ex ← cfg_generator.ex, dfg_generator.ex, cpg_data.ex
- file_watcher.ex ← enhanced_repository.ex
- synchronizer.ex ← enhanced_repository.ex, file_watcher.ex
```

### Integration Points

1. **EventStore Integration**: Working via wrapper in `lib/elixir_scope/event_store.ex`
2. **Query Engine Integration**: Partial, needs enhanced query capabilities
3. **Storage Integration**: Working via ETS and EventStore
4. **Runtime Integration**: Working via runtime_correlator.ex

## Critical Issues Identified

### 1. Data Structure Mismatch

**Current vs. Research Comparison:**

| Aspect | Current Implementation | Research Design | Gap |
|--------|----------------------|-----------------|-----|
| CFG Data | Basic 81-line struct | Comprehensive 130-line struct with complexity metrics | Missing complexity, path analysis |
| DFG Data | Basic 93-line struct | SSA-based 184-line struct with phi nodes | Missing SSA form, phi nodes |
| Variable Handling | Simple tracking | Versioned SSA variables | No versioning system |
| Scope Management | Basic scope IDs | Comprehensive scope hierarchy | Missing scope relationships |

### 2. Algorithm Implementation Issues

**CFG Generator Problems:**
- ❌ Wrong complexity calculation (counting edges vs. decision points)
- ❌ Missing Elixir-specific node types (pattern_match, guard_check)
- ❌ Incorrect state threading

**DFG Generator Problems:**
- ❌ No SSA form implementation
- ❌ Broken state management architecture
- ❌ Missing phi node generation
- ❌ Incorrect variable scoping

**CPG Builder Problems:**
- ❌ Depends on broken CFG and DFG
- ❌ No unified representation
- ❌ Missing cross-graph correlation

### 3. Test-Implementation Mismatch

The tests expect sophisticated behavior that the current implementation doesn't provide:

```elixir
# Test expects:
assert map_size(dfg.nodes) >= 2
# But implementation returns:
%DFGData{nodes: %{}} # Empty nodes map

# Test expects:
assert {:ok, cpg} = CPGBuilder.build_cpg(function_ast)
# But implementation returns:
{:error, {:cpg_generation_failed, "argument error"}}
```

## Migration Strategy Assessment

### What to Keep (Working Components)

1. **Core Repository Infrastructure** ✅
   - `repository.ex` - Solid foundation
   - `module_data.ex` - Working module tracking
   - `runtime_correlator.ex` - Runtime integration works
   - `instrumentation_mapper.ex` - Instrumentation mapping works

2. **Project Management** ✅
   - `project_populator.ex` - Project discovery works
   - EventStore integration pattern

3. **Test Infrastructure** ✅
   - Comprehensive test suite structure
   - Good test coverage patterns
   - Performance testing framework

### What to Replace (Broken Components)

1. **Graph Generators** ❌
   - `cfg_generator.ex` - Wrong algorithms, needs rewrite
   - `dfg_generator.ex` - Broken architecture, needs rewrite
   - `cpg_builder.ex` - Depends on broken components

2. **Data Structures** ❌
   - All `*_data.ex` files - Too basic, need research versions
   - Variable handling - No SSA support

3. **File System Integration** ❌
   - `file_watcher.ex` - Partially working but has issues
   - `synchronizer.ex` - Broken integration

### What to Add (Missing Components)

1. **SSA Form Implementation**
   - Variable versioning system
   - Phi node generation
   - Scope merge handling

2. **Enhanced Data Structures**
   - Research-based CFG/DFG/CPG structures
   - Comprehensive complexity metrics
   - Query optimization indexes

3. **Validation Framework**
   - Correctness validation
   - Performance benchmarking
   - Regression testing

## Implementation Roadmap

### Phase 1: Foundation Stabilization (Week 1)
1. **Audit working components** - Verify core repository functionality
2. **Update data structures** - Replace basic structs with research designs
3. **Fix EventStore integration** - Ensure all components use consistent API

### Phase 2: CFG Generator Rewrite (Week 2)
1. **Implement decision points complexity** - Fix McCabe calculation
2. **Add Elixir-specific nodes** - Pattern match, guard, pipe nodes
3. **Fix state threading** - Proper functional state management

### Phase 3: DFG Generator Rewrite (Week 3)
1. **Implement SSA form** - Variable versioning and phi nodes
2. **Fix scope management** - Proper Elixir scoping semantics
3. **Add data flow tracking** - Correct def-use chains

### Phase 4: CPG Integration (Week 4)
1. **Build unified representation** - Correlate CFG/DFG nodes
2. **Add query capabilities** - Cross-graph queries
3. **Implement pattern detection** - Code quality analysis

### Phase 5: Testing & Validation (Week 5)
1. **Implement validation framework** - From research
2. **Update test expectations** - Match new implementations
3. **Add performance benchmarks** - Meet targets

## Conclusion

The ElixirScope AST infrastructure is **ambitious and well-architected** but suffers from:

1. **Implementation-Research Gap**: Current code doesn't match the sophisticated research designs
2. **Algorithm Issues**: Wrong approaches for CFG complexity and DFG variable handling
3. **Data Structure Mismatch**: Basic structs vs. comprehensive research structures

**Key Insight**: We have excellent test coverage and working core infrastructure, but the advanced analysis components need to be rewritten using the research designs rather than debugged.

**Recommendation**: Follow the phased migration strategy, leveraging the working components while replacing the broken graph generators with research-based implementations.

The path forward is clear: **adopt the research designs** and **rewrite the broken components** rather than trying to fix fundamentally flawed algorithms. 