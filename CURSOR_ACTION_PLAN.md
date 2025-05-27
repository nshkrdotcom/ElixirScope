# ElixirScope AST Repository Action Plan

**Version**: 1.0  
**Date**: May 26, 2025  
**Focus**: Core AST compilation-time instrumentation and runtime storage  
**Status**: Active Development Plan

---

## 🎯 **EXECUTIVE SUMMARY**

Based on comprehensive analysis of current implementation status, this action plan focuses on delivering the core value proposition: **AST compilation-time instrumentation with runtime correlation**. We will NOT build performance infrastructure, monitoring, or production deployment features. Instead, we focus on the foundational AST capabilities that enable the hybrid architecture.

### **Core Value Proposition**
- **Compile-time AST analysis** with instrumentation point identification
- **Runtime event correlation** to AST nodes with high accuracy
- **Temporal storage** for time-based correlation (Cinema Debugger foundation)
- **Basic query capabilities** for AST-runtime hybrid data

---

## 📊 **CURRENT STATUS ASSESSMENT**

### **✅ Solid Foundation (70% Complete)**
- **Repository Core**: Fully operational (36 tests passing)
- **Runtime Correlation**: Working with 95%+ accuracy
- **Module Analysis**: Complete pattern detection (GenServer, Phoenix, Ecto)
- **Basic APIs**: Core CRUD operations functional

### **🚧 Critical Gaps Identified**
1. **AST Parser**: Missing systematic node ID assignment
2. **TemporalBridge**: Missing time-based correlation (critical for Cinema Debugger)
3. **InstrumentationMapper**: Missing systematic instrumentation point mapping
4. **Test Infrastructure**: Missing property-based and integration tests

### **❌ Explicitly Out of Scope**
- Performance benchmarking and optimization
- Production deployment infrastructure
- Monitoring and alerting systems
- Memory usage optimization
- Scaling and configuration systems

---

## 🗺️ **IMPLEMENTATION ROADMAP**

### **Phase 1: Complete Core AST Foundation (Days 1-3)**

#### **Day 1: AST Parser with Node ID Assignment**
**Goal**: Systematic AST node ID assignment for instrumentation correlation

**Tasks**:
- [ ] Enhance `lib/elixir_scope/ast_repository/parser.ex`
- [ ] Implement unique node ID assignment to instrumentable AST nodes
- [ ] Build instrumentation point extraction
- [ ] Create correlation index for fast lookup
- [ ] Integration with existing AST transformation pipeline

**Success Criteria**: Every instrumentable AST node has unique ID, correlation index operational

#### **Day 2: TemporalBridge Implementation**
**Goal**: Time-based correlation for Cinema Debugger foundation

**Tasks**:
- [ ] Create `lib/elixir_scope/ast_repository/temporal_bridge.ex`
- [ ] Implement time-based event correlation
- [ ] Build temporal index for time-range queries
- [ ] Integration with existing event system
- [ ] Support for temporal event ordering

**Success Criteria**: Events can be correlated to AST nodes with temporal context

#### **Day 3: InstrumentationMapper**
**Goal**: Systematic instrumentation point mapping

**Tasks**:
- [ ] Create `lib/elixir_scope/ast_repository/instrumentation_mapper.ex`
- [ ] Map AST nodes to instrumentation strategies
- [ ] Build instrumentation point configuration
- [ ] Integration with compile-time transformation
- [ ] Support for different instrumentation types

**Success Criteria**: AST nodes systematically mapped to instrumentation points

### **Phase 2: Enhanced Correlation & Storage (Days 4-5)**

#### **Day 4: Enhanced Event Processing**
**Goal**: AST-aware event processing pipeline

**Tasks**:
- [ ] Enhance `lib/elixir_scope/capture/ingestor.ex` for AST correlation
- [ ] Add AST correlation metadata to events
- [ ] Maintain existing functionality (backward compatibility)
- [ ] Integration with temporal storage
- [ ] Enhanced event correlation accuracy

**Success Criteria**: Events processed with AST correlation metadata, no regression

#### **Day 5: Basic Query Capabilities**
**Goal**: Simple query interface for AST-runtime data

**Tasks**:
- [ ] Create basic query interface in Repository
- [ ] Support for simple AST node queries
- [ ] Support for correlation-based queries
- [ ] Support for temporal range queries
- [ ] Integration with existing data structures

**Success Criteria**: Basic queries work for AST-runtime hybrid data

### **Phase 3: Test Infrastructure & Validation (Days 6-7)**

#### **Day 6: Comprehensive Test Suite**
**Goal**: Robust test coverage for core functionality

**Tasks**:
- [ ] Property-based tests for correlation invariants
- [ ] Integration tests for end-to-end workflows
- [ ] Test fixtures for complex scenarios
- [ ] Validation of correlation accuracy
- [ ] Temporal consistency tests

**Success Criteria**: Comprehensive test coverage, all tests passing

#### **Day 7: Integration & Polish**
**Goal**: System integration and final validation

**Tasks**:
- [ ] End-to-end integration testing
- [ ] Documentation updates
- [ ] API consistency validation
- [ ] Regression testing
- [ ] Preparation for next phase

**Success Criteria**: Integrated system ready for Cinema Debugger integration

---

## 🧪 **COMPREHENSIVE TEST STRATEGY**

### **Test Categories & Files**

#### **1. Core Functionality Tests**
```
test/elixir_scope/ast_repository/
├── parser_enhanced_test.exs              # AST parsing with node ID assignment
├── temporal_bridge_test.exs              # Time-based correlation testing
├── instrumentation_mapper_test.exs       # Instrumentation point mapping
├── enhanced_correlation_test.exs         # Enhanced correlation accuracy
└── basic_query_test.exs                  # Basic query functionality
```

#### **2. Integration Tests**
```
test/elixir_scope/integration/
├── ast_runtime_workflow_test.exs         # End-to-end AST-runtime correlation
├── temporal_correlation_test.exs         # Temporal correlation workflows
├── instrumentation_workflow_test.exs     # Compile-time to runtime workflow
└── hybrid_data_access_test.exs           # Hybrid data query workflows
```

#### **3. Property-Based Tests**
```
test/elixir_scope/property_tests/
├── correlation_invariants_test.exs       # Correlation bijection properties
├── temporal_ordering_test.exs            # Temporal consistency properties
├── ast_integrity_test.exs               # AST transformation properties
└── instrumentation_properties_test.exs   # Instrumentation mapping properties
```

#### **4. Test Support Infrastructure**
```
test/elixir_scope/ast_repository/test_support/
├── fixtures/
│   ├── sample_asts.ex                   # Curated AST samples
│   ├── runtime_events.ex                # Corresponding runtime events
│   ├── temporal_sequences.ex            # Time-ordered event sequences
│   └── correlation_scenarios.ex         # Complex correlation scenarios
├── generators.ex                        # Property-based test generators
├── matchers.ex                          # Custom test matchers
└── helpers.ex                           # Test helper functions
```

### **Test Approach**

#### **Test-Driven Development (TDD)**
1. **Red**: Write failing test for new functionality
2. **Green**: Implement minimal code to pass test
3. **Refactor**: Improve implementation while maintaining tests

#### **Property-Based Testing**
- **Correlation Bijection**: Forward and reverse correlation consistency
- **Temporal Ordering**: Event ordering preserved across operations
- **AST Integrity**: AST structure preserved during transformation
- **Instrumentation Consistency**: Instrumentation points correctly mapped

#### **Integration Testing**
- **End-to-End Workflows**: Complete compile-time to runtime workflows
- **Backward Compatibility**: Existing functionality preserved
- **Cross-Component Integration**: Components work together correctly

---

## 📋 **DETAILED TASK BREAKDOWN**

### **Day 1: AST Parser Enhancement** ✅ **IN PROGRESS**

#### **Tasks**:
1. **✅ Write parser tests** (`test/elixir_scope/ast_repository/parser_enhanced_test.exs`)
   - ✅ Test unique node ID assignment
   - ✅ Test instrumentation point extraction
   - ✅ Test correlation index building
   - ✅ Test AST integrity preservation

2. **✅ Enhance Parser module** (`lib/elixir_scope/ast_repository/parser.ex`)
   - ✅ Add `assign_node_ids/1` function
   - ✅ Add `extract_instrumentation_points/1` function
   - ✅ Add `build_correlation_index/1` function
   - 🚧 Integration with existing AST helpers

3. **🚧 Integration testing**
   - 🚧 Test with existing Repository
   - 🚧 Test with existing RuntimeCorrelator
   - 🚧 Validate correlation accuracy

#### **Success Criteria**:
- [x] **Parser core functionality implemented**
- [x] **Node IDs assigned to instrumentable nodes**
- [x] **Basic correlation index operational**
- [ ] **Test support infrastructure working**
- [ ] **Integration with existing system working**

#### **Current Status**: 
- **Parser module**: ✅ **Complete** - All core functions implemented
- **Basic tests**: ✅ **Passing** - Simple metadata test passes
- **Test infrastructure**: 🚧 **Needs work** - Test support modules not compiling
- **Next**: Fix test support compilation, then validate full functionality

### **Day 2: TemporalBridge Implementation**

#### **Tasks**:
1. **Write temporal bridge tests** (`test/elixir_scope/ast_repository/temporal_bridge_test.exs`)
   - Test time-based event correlation
   - Test temporal index operations
   - Test temporal range queries
   - Test event ordering preservation

2. **Create TemporalBridge module** (`lib/elixir_scope/ast_repository/temporal_bridge.ex`)
   - Add `correlate_temporal_event/2` function
   - Add `get_events_in_range/3` function
   - Add `build_temporal_index/1` function
   - Integration with existing event system

3. **Integration with Repository**
   - Add temporal correlation to Repository
   - Update RuntimeCorrelator for temporal support
   - Test temporal query capabilities

#### **Success Criteria**:
- [ ] All temporal bridge tests passing
- [ ] Time-based correlation working
- [ ] Temporal queries operational
- [ ] Foundation for Cinema Debugger ready

### **Day 3: InstrumentationMapper Implementation**

#### **Tasks**:
1. **Write instrumentation mapper tests** (`test/elixir_scope/ast_repository/instrumentation_mapper_test.exs`)
   - Test instrumentation point mapping
   - Test instrumentation strategy selection
   - Test configuration management
   - Test integration with compile-time transformation

2. **Create InstrumentationMapper module** (`lib/elixir_scope/ast_repository/instrumentation_mapper.ex`)
   - Add `map_instrumentation_points/1` function
   - Add `select_instrumentation_strategy/2` function
   - Add `configure_instrumentation/2` function
   - Integration with AST transformation pipeline

3. **Integration testing**
   - Test with enhanced Parser
   - Test with compile-time transformation
   - Validate instrumentation accuracy

#### **Success Criteria**:
- [ ] All instrumentation mapper tests passing
- [ ] Systematic instrumentation point mapping
- [ ] Integration with transformation pipeline
- [ ] Instrumentation configuration working

---

## 🎯 **SUCCESS CRITERIA & VALIDATION**

### **Phase 1 Success Criteria**
- [ ] **AST Parser**: Unique node IDs assigned to all instrumentable nodes
- [ ] **TemporalBridge**: Time-based correlation operational
- [ ] **InstrumentationMapper**: Systematic instrumentation point mapping
- [ ] **Integration**: All components work together
- [ ] **Tests**: Core functionality tests passing

### **Phase 2 Success Criteria**
- [ ] **Enhanced Ingestor**: AST correlation metadata in events
- [ ] **Basic Queries**: Simple AST-runtime queries working
- [ ] **Backward Compatibility**: No regression in existing functionality
- [ ] **Integration**: Enhanced pipeline operational
- [ ] **Tests**: Integration tests passing

### **Phase 3 Success Criteria**
- [ ] **Test Coverage**: Comprehensive test suite complete
- [ ] **Property Tests**: Invariants validated
- [ ] **Integration Tests**: End-to-end workflows tested
- [ ] **Documentation**: Updated documentation
- [ ] **System Ready**: Ready for Cinema Debugger integration

### **Overall Success Metrics**
- **Correlation Accuracy**: >95% for instrumented code
- **Test Coverage**: >90% for core functionality
- **Integration**: All existing tests continue passing
- **Foundation**: Ready for Cinema Debugger and LLM integration

---

## 📝 **IMPLEMENTATION NOTES**

### **Key Integration Points**
1. **Existing AST Helpers**: Use `ElixirScope.AST.InjectorHelpers` patterns
2. **Event System**: Integrate with `ElixirScope.Capture.EventCorrelator`
3. **Transformation Pipeline**: Work with `ElixirScope.AST.EnhancedTransformer`
4. **Repository**: Extend existing `ElixirScope.ASTRepository.Repository`

### **Backward Compatibility**
- All existing APIs must continue working
- No changes to existing test behavior
- Existing functionality preserved during enhancement

### **Quality Standards**
- Test-driven development for all new functionality
- Property-based testing for critical invariants
- Integration testing for cross-component functionality
- Documentation updates for all new APIs

---

## 🚀 **NEXT STEPS**

### **Immediate Actions**
1. **Start Day 1**: Begin with AST Parser enhancement tests
2. **Create test infrastructure**: Set up test support structure
3. **Implement TDD cycle**: Red-Green-Refactor for each component
4. **Maintain status**: Update this document with progress

### **Status Tracking**
This document will be updated daily with:
- [ ] Task completion status
- [ ] Test results
- [ ] Integration status
- [ ] Issues and blockers
- [ ] Next day planning

### **Success Validation**
At the end of each day:
- Run full test suite
- Validate integration with existing system
- Update status in this document
- Plan next day tasks

---

**This action plan focuses on delivering the core AST value proposition without performance infrastructure, providing a solid foundation for Cinema Debugger and LLM integration.** 