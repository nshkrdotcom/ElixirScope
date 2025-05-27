# ElixirScope Hybrid Architecture Test Plan
**Living Document - Updated May 26, 2025**  
**Purpose**: Comprehensive test strategy for AST Repository Foundation and Runtime Correlation

---

## 🎯 **TEST STRATEGY OVERVIEW**

### **Testing Philosophy**
- **Test-Driven Enhancement**: Every new function gets unit tests before integration
- **Backward Compatibility**: All existing functionality must continue working
- **Performance Validation**: Every enhancement must meet latency targets
- **Integration Coverage**: End-to-end workflows must be validated
- **Regression Prevention**: Comprehensive test coverage prevents breaking changes

### **Test Pyramid Structure**
```
    🔺 Integration Tests (10%)
   🔺🔺 Component Tests (20%)  
  🔺🔺🔺 Unit Tests (70%)
```

---

## 📋 **WEEK 1: AST REPOSITORY FOUNDATION TESTS**

### ✅ **COMPLETED - Day 1: Core Repository Tests**

#### **Repository Module Tests** (`test/elixir_scope/ast_repository/repository_test.exs`)
- ✅ **16 tests implemented and passing**
- ✅ Repository lifecycle (creation, GenServer startup, health checks)
- ✅ Module storage and retrieval (store, get, update operations)
- ✅ Function storage and retrieval
- ✅ Runtime correlation (event correlation, error handling)
- ✅ Statistics and monitoring
- ✅ Instrumentation points management

#### **ModuleData Tests** (Implicit via Repository tests)
- ✅ Module data structure creation and validation
- ✅ Static analysis integration
- ✅ Runtime correlation data updates

#### **FunctionData Tests** (Implicit via Repository tests)
- ✅ Function data structure creation and validation
- ✅ Performance profiling data
- ✅ Error tracking capabilities

#### **RuntimeCorrelator Tests** (Implicit via Repository tests)
- ✅ Basic correlation mapping
- ✅ ETS-based caching
- ✅ Performance statistics

---

### 🚧 **IN PROGRESS - Day 1: InstrumentationRuntime Enhancement Tests**

#### **Enhanced InstrumentationRuntime Tests** (`test/elixir_scope/capture/instrumentation_runtime_enhanced_test.exs`)

**NEW AST CORRELATION FUNCTIONS - Unit Tests Required:**

1. **`report_ast_function_entry_with_node_id/5`**
   - [ ] Test with valid AST node ID
   - [ ] Test call stack management (push)
   - [ ] Test event ingestion with correlation metadata
   - [ ] Test disabled context handling
   - [ ] Test invalid buffer handling

2. **`report_ast_function_exit_with_node_id/4`**
   - [ ] Test with valid AST node ID
   - [ ] Test call stack management (pop)
   - [ ] Test event ingestion with correlation metadata
   - [ ] Test disabled context handling

3. **`report_ast_variable_snapshot/4`**
   - [ ] Test variable capture with AST node correlation
   - [ ] Test line number tracking
   - [ ] Test correlation metadata inclusion
   - [ ] Test large variable maps handling

4. **`report_ast_expression_value/5`**
   - [ ] Test expression tracking with AST node correlation
   - [ ] Test value capture and serialization
   - [ ] Test line number correlation
   - [ ] Test complex expression values

5. **`report_ast_line_execution/4`**
   - [ ] Test line execution tracking with AST node correlation
   - [ ] Test context metadata capture
   - [ ] Test performance impact measurement

6. **`report_ast_pattern_match/6`**
   - [ ] Test pattern match success tracking
   - [ ] Test pattern match failure tracking
   - [ ] Test variable binding capture
   - [ ] Test complex pattern structures

7. **`report_ast_branch_execution/6`**
   - [ ] Test if/case/cond branch tracking
   - [ ] Test condition evaluation capture
   - [ ] Test branch taken/not taken scenarios
   - [ ] Test nested conditional handling

8. **`report_ast_loop_iteration/6`**
   - [ ] Test Enum.map iteration tracking
   - [ ] Test for comprehension tracking
   - [ ] Test iteration count accuracy
   - [ ] Test current value capture

**AST CORRELATION HELPER FUNCTIONS - Unit Tests Required:**

9. **`get_ast_correlation_metadata/0`**
   - [ ] Test metadata structure completeness
   - [ ] Test timestamp accuracy
   - [ ] Test process ID capture
   - [ ] Test enabled state reflection

10. **`validate_ast_node_id/1`**
    - [ ] Test valid format: "module:function:line:node_type"
    - [ ] Test invalid formats (missing parts, wrong separators)
    - [ ] Test non-string inputs
    - [ ] Test edge cases (empty strings, special characters)

11. **`report_ast_correlation_performance/3`**
    - [ ] Test performance metric capture
    - [ ] Test operation type tracking
    - [ ] Test duration measurement accuracy
    - [ ] Test correlation with performance targets

**ENHANCED EXISTING FUNCTIONS - Regression Tests Required:**

12. **Enhanced `report_local_variable_snapshot/4`**
    - [ ] Test backward compatibility (existing signature works)
    - [ ] Test new source metadata inclusion
    - [ ] Test existing functionality preserved

13. **Enhanced `report_expression_value/5`**
    - [ ] Test backward compatibility
    - [ ] Test new source metadata inclusion
    - [ ] Test existing functionality preserved

14. **Enhanced `report_line_execution/4`**
    - [ ] Test backward compatibility
    - [ ] Test new source metadata inclusion
    - [ ] Test existing functionality preserved

15. **Enhanced `report_ast_function_entry/4`**
    - [ ] Test backward compatibility
    - [ ] Test new correlation_id metadata inclusion
    - [ ] Test existing functionality preserved

16. **Enhanced `report_ast_function_exit/3`**
    - [ ] Test backward compatibility
    - [ ] Test call stack management addition
    - [ ] Test new correlation_id metadata inclusion

---

### 📊 **PERFORMANCE TESTS REQUIRED**

#### **AST Correlation Performance Tests** (`test/elixir_scope/performance/ast_correlation_benchmarks_test.exs`)

1. **Correlation Latency Tests**
   - [ ] Test `report_ast_function_entry_with_node_id` latency <500ns
   - [ ] Test `report_ast_variable_snapshot` latency <1μs
   - [ ] Test `validate_ast_node_id` latency <100ns
   - [ ] Test overall correlation pipeline <5ms (P95)

2. **Memory Overhead Tests**
   - [ ] Test AST correlation metadata memory usage
   - [ ] Test call stack memory growth with nesting
   - [ ] Test ETS table memory scaling
   - [ ] Test overall memory overhead <15% baseline

3. **Throughput Tests**
   - [ ] Test 10,000+ correlations/second capability
   - [ ] Test concurrent correlation handling
   - [ ] Test correlation under high load
   - [ ] Test graceful degradation under pressure

4. **Backward Compatibility Performance**
   - [ ] Test existing function performance unchanged
   - [ ] Test disabled context performance <100ns
   - [ ] Test performance impact when AST correlation disabled

---

### 🔗 **INTEGRATION TESTS REQUIRED**

#### **End-to-End AST Correlation Tests** (`test/elixir_scope/integration/ast_correlation_workflow_test.exs`)

1. **Complete Correlation Flow**
   - [ ] AST parsing → node ID assignment → instrumentation → runtime correlation
   - [ ] Test with realistic GenServer module
   - [ ] Test with Phoenix Controller
   - [ ] Test with complex nested functions

2. **Repository Integration**
   - [ ] Test InstrumentationRuntime → Repository correlation
   - [ ] Test event storage with AST metadata
   - [ ] Test correlation lookup accuracy >95%
   - [ ] Test temporal correlation queries

3. **Error Handling Integration**
   - [ ] Test correlation failures graceful handling
   - [ ] Test invalid AST node ID handling
   - [ ] Test buffer unavailable scenarios
   - [ ] Test system recovery after errors

4. **Multi-Process Correlation**
   - [ ] Test correlation across process boundaries
   - [ ] Test GenServer callback correlation
   - [ ] Test Phoenix request correlation
   - [ ] Test distributed node correlation

---

## 📋 **WEEK 2: TEMPORAL STORAGE & EVENT ENHANCEMENT TESTS**

### 🚧 **PLANNED - Day 2: Runtime Correlation Bridge Tests**

#### **Enhanced Ingestor Tests** (`test/elixir_scope/capture/ingestor_enhanced_test.exs`)

1. **AST Correlation Event Processing**
   - [ ] Test `ingest_ast_correlated_event` function
   - [ ] Test correlation metadata extraction
   - [ ] Test existing ingest function unchanged
   - [ ] Test performance impact <5%

2. **Event Enhancement Tests**
   - [ ] Test events enhanced with correlation metadata
   - [ ] Test backward compatibility with existing consumers
   - [ ] Test correlation metadata validation
   - [ ] Test error handling for malformed correlation data

#### **RuntimeCorrelator Integration Tests** (`test/elixir_scope/ast_repository/runtime_correlator_integration_test.exs`)

1. **High-Performance Correlation**
   - [ ] Test <5ms correlation latency P95
   - [ ] Test correlation accuracy >95%
   - [ ] Test multiple correlation strategies
   - [ ] Test correlation failure handling

2. **ETS-Based Caching Tests**
   - [ ] Test fast lookup performance
   - [ ] Test cache invalidation
   - [ ] Test memory management
   - [ ] Test concurrent access

3. **Temporal Event Indexing**
   - [ ] Test time-based queries
   - [ ] Test chronological ordering
   - [ ] Test range query performance
   - [ ] Test index maintenance

### 🚧 **PLANNED - Day 3: AST Parser Integration Tests**

#### **AST Parser Tests** (`test/elixir_scope/ast_repository/parser_test.exs`)

1. **AST Node ID Assignment**
   - [ ] Test unique node ID generation
   - [ ] Test node ID format consistency
   - [ ] Test instrumentation point extraction
   - [ ] Test correlation index building

2. **AST Integrity Tests**
   - [ ] Test AST structure preserved after enhancement
   - [ ] Test compilation success after transformation
   - [ ] Test runtime behavior unchanged
   - [ ] Test incremental parsing support

---

## 📋 **WEEK 3: HYBRID LLM INTEGRATION TESTS**

### 🚧 **PLANNED - Hybrid Context Builder Tests**

#### **Context Building Tests** (`test/elixir_scope/llm/context_builder_test.exs`)

1. **Hybrid Context Generation**
   - [ ] Test static + runtime context combination
   - [ ] Test context building <100ms for medium projects
   - [ ] Test context compaction for LLM token limits
   - [ ] Test correlation mapping accuracy

2. **AI Integration Tests**
   - [ ] Test integration with existing AI infrastructure
   - [ ] Test context quality validation
   - [ ] Test LLM provider compatibility
   - [ ] Test analysis accuracy improvement >40%

---

## 🧪 **TEST IMPLEMENTATION PRIORITIES**

### **Immediate (Day 1 Completion)**
1. ✅ **InstrumentationRuntime Enhanced Unit Tests** - All new AST correlation functions
2. ✅ **Performance Validation Tests** - Ensure <10% overhead
3. ✅ **Backward Compatibility Tests** - All existing functionality preserved

### **Short Term (Week 1)**
1. **Integration Tests** - End-to-end AST correlation workflow
2. **Error Handling Tests** - Comprehensive edge case coverage
3. **Multi-Process Tests** - Cross-process correlation validation

### **Medium Term (Week 2)**
1. **Temporal Storage Tests** - Time-based query validation
2. **Enhanced Event Processing Tests** - Pipeline integration
3. **Scalability Tests** - Large project performance

### **Long Term (Week 3)**
1. **Hybrid LLM Tests** - AI integration validation
2. **Production Readiness Tests** - Full system validation
3. **Performance Optimization Tests** - Final tuning validation

---

## 📊 **TEST METRICS & SUCCESS CRITERIA**

### **Coverage Targets**
- **Unit Test Coverage**: >90% for all new functions
- **Integration Test Coverage**: >85% for critical workflows
- **Performance Test Coverage**: 100% for latency-critical functions

### **Performance Targets**
- **AST Correlation Latency**: <5ms P95
- **Function Entry/Exit Overhead**: <500ns when enabled, <100ns when disabled
- **Memory Overhead**: <15% of baseline system
- **Correlation Accuracy**: >95% under normal conditions

### **Quality Gates**
- **All existing tests continue passing**: 100%
- **New function test coverage**: >90%
- **Performance regression**: <10% of baseline
- **Integration test success**: >95%

---

## 🚨 **CRITICAL TEST SCENARIOS**

### **Must-Pass Scenarios**
1. **Existing ElixirScope functionality unchanged** - All 594 existing tests pass
2. **AST correlation accuracy >95%** - In realistic scenarios
3. **Performance targets met** - All latency and throughput requirements
4. **Graceful degradation** - System stable when correlation fails
5. **Memory usage within limits** - No memory leaks or excessive growth

### **Edge Cases to Test**
1. **High concurrency** - Multiple processes correlating simultaneously
2. **Large codebases** - 1000+ modules with correlation
3. **Network partitions** - Distributed correlation handling
4. **Memory pressure** - Correlation under low memory conditions
5. **Rapid correlation** - High-frequency correlation events

---

## 📝 **TEST IMPLEMENTATION CHECKLIST**

### **Day 1 - InstrumentationRuntime Enhancement**
- [ ] Create `test/elixir_scope/capture/instrumentation_runtime_enhanced_test.exs`
- [ ] Implement unit tests for all 11 new AST correlation functions
- [ ] Implement regression tests for 5 enhanced existing functions
- [ ] Create performance benchmark tests
- [ ] Validate backward compatibility
- [ ] Ensure all tests pass

### **Day 2 - Integration Testing**
- [ ] Create `test/elixir_scope/integration/ast_correlation_workflow_test.exs`
- [ ] Implement end-to-end correlation flow tests
- [ ] Test Repository integration
- [ ] Test multi-process correlation
- [ ] Validate error handling

### **Day 3 - Performance & Scalability**
- [ ] Create `test/elixir_scope/performance/ast_correlation_benchmarks_test.exs`
- [ ] Implement latency benchmarks
- [ ] Implement throughput benchmarks
- [ ] Implement memory usage tests
- [ ] Validate all performance targets

---

## 🎯 **SUCCESS VALIDATION**

### **Daily Validation Checklist**
- [ ] All new functions have comprehensive unit tests
- [ ] All existing tests continue passing
- [ ] Performance targets met in benchmarks
- [ ] Integration tests validate end-to-end workflows
- [ ] Memory usage within acceptable limits

### **Weekly Milestone Validation**
- [ ] Test coverage >90% for all new code
- [ ] Performance regression <10% of baseline
- [ ] Integration test success rate >95%
- [ ] All critical scenarios passing
- [ ] Documentation updated with test results

---

## 📚 **TEST DOCUMENTATION STANDARDS**

### **Test Naming Convention**
```elixir
# Unit Tests
test "function_name should behavior when condition"
test "function_name should handle error_case gracefully"

# Integration Tests  
test "workflow_name should complete successfully with realistic_data"
test "workflow_name should handle failure_scenario gracefully"

# Performance Tests
test "function_name should meet latency_target under load_condition"
test "system should maintain throughput_target with concurrent_operations"
```

### **Test Structure Template**
```elixir
describe "function_name/arity" do
  setup do
    # Test setup
  end
  
  test "should handle normal case" do
    # Arrange, Act, Assert
  end
  
  test "should handle edge case" do
    # Arrange, Act, Assert
  end
  
  test "should handle error case" do
    # Arrange, Act, Assert
  end
end
```

---

## 🚀 **READY FOR TEST IMPLEMENTATION**

This living document will be updated as tests are implemented and new requirements emerge. The test plan ensures:

✅ **Comprehensive Coverage** - Every new function tested  
✅ **Performance Validation** - All targets verified  
✅ **Backward Compatibility** - Existing functionality preserved  
✅ **Integration Validation** - End-to-end workflows tested  
✅ **Quality Assurance** - Production-ready code delivered  

**Next Step**: Implement Day 1 InstrumentationRuntime Enhanced Tests 🧪 