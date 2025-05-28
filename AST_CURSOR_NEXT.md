# AST Repository Test Failure Analysis & Action Plan

## Executive Summary

**Current Status**: 207 tests, 61 failures (70% pass rate)
**Priority**: CRITICAL - Core AST analysis infrastructure is broken

The test failures reveal systematic issues across multiple components of the AST repository system. The DFG (Data Flow Graph) generator has been successfully fixed (100% pass rate), but critical failures exist in other core components.

## Critical Issue Categories

### 1. **CRITICAL: Function Analysis Crashes** 
**Impact**: Affects 80% of failing tests
**Root Cause**: Function parameter extraction expecting maps but receiving lists

```
Function analysis crashed for handle_call/3: expected a map, got: ["_from", "state"]
Function analysis crashed for simple_function/0: expected a map, got: []
```

**Affected Components**:
- Enhanced Repository (function storage)
- Project Populator (function extraction)
- Synchronizer (function analysis)
- File Watcher (function tracking)

### 2. **CRITICAL: CPG Builder Complete Failure**
**Impact**: 20/20 tests failing (0% pass rate)
**Root Cause**: Missing DFG generator function export

```
function ElixirScope.ASTRepository.Enhanced.DFGGenerator.generate_dfg/2 is undefined or private
```

### 3. **CRITICAL: CFG Generator Pattern Matching Failures**
**Impact**: 13/21 tests failing (38% pass rate)
**Root Cause**: Missing pattern matching for complex AST structures

```
no function clause matching in ElixirScope.ASTRepository.Enhanced.CFGGenerator.process_function_body/2
```

### 4. **HIGH: Repository Integration Failures**
**Impact**: Module storage/retrieval not working
**Root Cause**: Repository processes not staying alive, synchronization issues

```
no process: the process is not alive or there's no process currently associated with the given name
```

## Prioritized Action Plan

### Phase 1: Core Infrastructure Fixes (CRITICAL - Week 1)

#### 1.1 Fix Function Analysis Parameter Extraction
**Priority**: P0 - Blocking 80% of tests
**Files**: 
- `lib/elixir_scope/ast_repository/enhanced/function_analyzer.ex`
- `lib/elixir_scope/ast_repository/enhanced/enhanced_repository.ex`

**Issue**: Function parameter extraction is receiving parameter lists as strings instead of maps
**Fix**: Update parameter extraction to handle both map and list formats

#### 1.2 Fix CPG Builder DFG Integration
**Priority**: P0 - Blocking all CPG tests
**Files**:
- `lib/elixir_scope/ast_repository/enhanced/cpg_builder.ex`
- `lib/elixir_scope/ast_repository/enhanced/dfg_generator.ex`

**Issue**: DFG generator function not properly exported or accessible
**Fix**: Ensure proper module exports and function visibility

#### 1.3 Fix CFG Generator Pattern Matching
**Priority**: P0 - Blocking CFG functionality
**Files**:
- `lib/elixir_scope/ast_repository/enhanced/cfg_generator.ex`

**Issue**: Missing pattern matching clauses for complex AST structures
**Fix**: Add comprehensive pattern matching for all AST node types

### Phase 2: Repository Stability (HIGH - Week 2)

#### 2.1 Fix Repository Process Management
**Priority**: P1 - Core functionality
**Files**:
- `lib/elixir_scope/ast_repository/enhanced_repository.ex`
- `lib/elixir_scope/ast_repository/enhanced/synchronizer.ex`

**Issue**: Repository processes dying unexpectedly
**Fix**: Improve process supervision and error handling

#### 2.2 Fix File Watcher Integration
**Priority**: P1 - Real-time updates
**Files**:
- `lib/elixir_scope/ast_repository/enhanced/file_watcher.ex`

**Issue**: File events not properly triggering repository updates
**Fix**: Improve file system event handling and debouncing

### Phase 3: Enhanced Features (MEDIUM - Week 3)

#### 3.1 Parser Enhanced Instrumentation
**Priority**: P2 - Advanced features
**Files**:
- `lib/elixir_scope/ast_repository/parser_enhanced.ex`

**Issue**: Instrumentation point extraction not finding expected patterns
**Fix**: Improve pattern recognition for GenServer callbacks and Phoenix controllers

#### 3.2 Performance Optimization
**Priority**: P2 - Performance targets
**Files**: Various performance-critical modules

**Issue**: Some tests failing performance benchmarks
**Fix**: Optimize critical paths and memory usage

## Detailed Fix Specifications

### Fix 1: Function Analysis Parameter Extraction

**Current Issue**:
```elixir
# Expected: %{name: "param", type: :parameter}
# Actual: ["param"]
```

**Required Fix**:
```elixir
defp extract_function_parameters(params) when is_list(params) do
  Enum.map(params, fn
    {param_name, _, _} when is_atom(param_name) ->
      %{name: to_string(param_name), type: :parameter}
    param when is_binary(param) ->
      %{name: param, type: :parameter}
    _ ->
      %{name: "unknown", type: :parameter}
  end)
end
```

### Fix 2: CPG Builder DFG Integration

**Current Issue**:
```elixir
# CPGBuilder trying to call undefined function
DFGGenerator.generate_dfg/2
```

**Required Fix**:
```elixir
# In dfg_generator.ex - ensure function is public
def generate_dfg(ast, options \\ []) do
  # existing implementation
end

# In cpg_builder.ex - proper error handling
case DFGGenerator.generate_dfg(ast) do
  {:ok, dfg} -> {:ok, dfg}
  {:error, reason} -> {:error, {:dfg_generation_failed, reason}}
end
```

### Fix 3: CFG Generator Pattern Matching

**Current Issue**:
```elixir
# Missing pattern for complex AST structures
def process_function_body({:__block__, _, statements}, state) do
  # Missing implementation
end
```

**Required Fix**:
```elixir
def process_function_body(body, state) do
  case body do
    {:__block__, _, statements} ->
      process_statements(statements, state)
    {:def, _, _} = def_node ->
      process_function_definition(def_node, state)
    {:defp, _, _} = defp_node ->
      process_function_definition(defp_node, state)
    single_statement ->
      process_statement(single_statement, state)
  end
end
```

## Success Metrics

### Phase 1 Targets:
- Function analysis crashes: 0 (currently ~50)
- CPG Builder tests: 80% pass rate (currently 0%)
- CFG Generator tests: 80% pass rate (currently 38%)

### Phase 2 Targets:
- Repository integration tests: 90% pass rate
- File watcher tests: 85% pass rate
- Overall test suite: 85% pass rate

### Phase 3 Targets:
- All test suites: 95% pass rate
- Performance benchmarks: All passing
- Memory usage: Within specified limits

## Risk Assessment

### High Risk:
- **Function analysis fixes**: Core to most functionality, changes could break working components
- **Repository process management**: Critical for data persistence

### Medium Risk:
- **CFG/CPG integration**: Complex interdependencies
- **File watcher changes**: Real-time system stability

### Low Risk:
- **Parser enhancements**: Isolated functionality
- **Performance optimizations**: Non-breaking improvements

## Implementation Notes

1. **Test-Driven Approach**: Fix one test category at a time, verify no regressions
2. **Incremental Deployment**: Deploy fixes in phases to isolate issues
3. **Monitoring**: Add comprehensive logging for process lifecycle events
4. **Rollback Plan**: Maintain ability to revert to DFG-only functionality if needed

## Current Working Components (DO NOT BREAK)

✅ **DFG Generator**: 100% pass rate - PROTECT THIS
✅ **Basic Repository**: Core CRUD operations working
✅ **Runtime Correlator**: Event correlation working
✅ **Module Data Integration**: Pattern detection working
✅ **Instrumentation Mapper**: Basic mapping working

## Next Immediate Actions

1. **TODAY**: Fix function parameter extraction in enhanced repository
2. **THIS WEEK**: Fix CPG builder DFG integration
3. **NEXT WEEK**: Fix CFG generator pattern matching
4. **WEEK 3**: Repository process stability improvements

---

**Last Updated**: 2025-05-28
**Status**: ACTIVE DEVELOPMENT
**Owner**: AST Repository Team 