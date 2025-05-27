# ElixirScope AST Repository Action Plan (Day 2 - REVISED)

## 🔍 **CRITICAL ASSESSMENT: TEMPORALBRIDGE NOT NEEDED FOR MVP**

### **Key Discovery**
After thorough analysis of the existing codebase, **TemporalBridge is NOT necessary for a useful MVP**. The `RuntimeCorrelator` already provides all the temporal correlation capabilities needed:

**✅ Already Implemented:**
- AST-Runtime correlation with <5ms latency and 95%+ accuracy
- Temporal indexing: `temporal_index` ETS table with time-ordered events
- Time-range queries: `query_temporal_events_impl(start_time, end_time)`
- Event storage with correlation metadata and timestamps
- Cinema Debugger foundation: temporal primitives for time-travel debugging

**🎯 The Real MVP Value:** Focus on completing existing gaps rather than building redundant temporal infrastructure.

---

## 🚀 **REVISED DAY 2 STRATEGY: COMPLETE EXISTING FUNCTIONALITY**

### **Priority 1: Fix RuntimeCorrelator Query Implementation**
The `get_correlated_events_impl` function is currently a placeholder. This is critical for MVP functionality.

**Current Issue:**
```elixir
defp get_correlated_events_impl(_state, _ast_node_id) do
  # TODO: Query events that have been correlated with this AST node
  {:ok, []}  # Placeholder!
end
```

**MVP Impact:** This function is essential for:
- Querying all runtime events for a specific AST node
- Building execution history for functions/modules
- Enabling basic Cinema Debugger queries

### **Priority 2: Enhance DataAccess for AST Queries**
The RuntimeCorrelator needs DataAccess to support AST node queries, which is currently missing.

**Current Gap:** DataAccess doesn't support `query_by_ast_node_id(ast_node_id)`

**MVP Impact:** Without this, we can't:
- Get runtime events for specific AST nodes
- Build execution timelines for code sections
- Provide AST-centric debugging views

### **Priority 3: Complete InstrumentationMapper**
This provides systematic instrumentation point mapping, which is more valuable than temporal infrastructure.

**MVP Impact:** 
- Systematic compile-time instrumentation planning
- Intelligent instrumentation point selection
- Foundation for AI-guided instrumentation

---

## 📋 **REVISED DAY 2 IMPLEMENTATION PLAN**

### **Task 1: Complete RuntimeCorrelator Query Implementation (2-3 hours)**

#### **1.1 Implement get_correlated_events_impl**
```elixir
defp get_correlated_events_impl(state, ast_node_id) do
  try do
    # Get all correlation IDs for this AST node from temporal index
    correlation_ids = :ets.select(state.temporal_index, [
      {{:_, {:'$1', ast_node_id}}, [], [:'$1']}
    ])
    
    # Get events from DataAccess for each correlation ID
    events = Enum.flat_map(correlation_ids, fn correlation_id ->
      case DataAccess.query_by_correlation(state.data_access, correlation_id) do
        {:ok, events} -> events
        {:error, _} -> []
      end
    end)
    
    # Sort by timestamp for chronological order
    sorted_events = Enum.sort_by(events, & &1.timestamp)
    {:ok, sorted_events}
  rescue
    error -> {:error, {:query_failed, error}}
  end
end
```

#### **1.2 Add AST Node Query API**
```elixir
@doc """
Gets all runtime events correlated with a specific AST node, ordered chronologically.
"""
@spec get_events_for_ast_node(GenServer.server(), ast_node_id()) :: 
  {:ok, [runtime_event()]} | {:error, term()}
def get_events_for_ast_node(correlator \\ __MODULE__, ast_node_id) do
  GenServer.call(correlator, {:get_events_for_ast_node, ast_node_id})
end
```

### **Task 2: Enhance DataAccess for AST Queries (1-2 hours)**

#### **2.1 Add AST Node Query Support**
Enhance `ElixirScope.Storage.DataAccess` to support:
```elixir
@spec query_by_ast_node_id(t(), ast_node_id()) :: {:ok, [event()]} | {:error, term()}
def query_by_ast_node_id(data_access, ast_node_id)
```

#### **2.2 Add Correlation Metadata Indexing**
Ensure events with `ast_node_id` metadata can be efficiently queried.

### **Task 3: Implement InstrumentationMapper (2-3 hours)**

#### **3.1 Create InstrumentationMapper Module**
```elixir
defmodule ElixirScope.ASTRepository.InstrumentationMapper do
  @moduledoc """
  Maps AST nodes to instrumentation strategies and points.
  
  Provides systematic instrumentation point mapping for compile-time transformation.
  """
  
  @spec map_instrumentation_points(ast()) :: {:ok, [instrumentation_point()]}
  def map_instrumentation_points(ast)
  
  @spec select_instrumentation_strategy(ast_node(), context()) :: instrumentation_strategy()
  def select_instrumentation_strategy(ast_node, context)
end
```

#### **3.2 Integration with Enhanced Parser**
Connect InstrumentationMapper with the existing Parser for systematic instrumentation.

---

## 🧪 **REVISED TEST STRATEGY**

### **Test Priority 1: RuntimeCorrelator Query Tests**
```elixir
test "get_events_for_ast_node returns chronologically ordered events" do
  # Setup correlator with test data
  # Store events with different timestamps for same AST node
  # Query events for AST node
  # Assert chronological ordering and completeness
end
```

### **Test Priority 2: DataAccess AST Query Tests**
```elixir
test "query_by_ast_node_id returns all events for AST node" do
  # Store events with ast_node_id metadata
  # Query by AST node ID
  # Assert all events returned
end
```

### **Test Priority 3: InstrumentationMapper Tests**
```elixir
test "maps instrumentation points systematically" do
  # Given: Sample AST with various node types
  # When: Map instrumentation points
  # Then: All instrumentable nodes have appropriate strategies
end
```

---

## ✅ **SUCCESS CRITERIA (REVISED)**

### **Day 2 MVP Success:**
1. **✅ RuntimeCorrelator Complete**: All query functions implemented and tested
2. **✅ DataAccess Enhanced**: AST node queries working efficiently  
3. **✅ InstrumentationMapper**: Systematic instrumentation point mapping operational
4. **✅ Integration**: All components work together seamlessly
5. **✅ Foundation Ready**: Solid base for Cinema Debugger integration

### **MVP Value Delivered:**
- **Complete AST-Runtime correlation** with full query capabilities
- **Systematic instrumentation** planning and execution
- **Time-based debugging** foundation (using existing temporal capabilities)
- **AI integration** readiness with hybrid AST-runtime context

---

## 🎯 **WHY THIS APPROACH IS BETTER**

### **1. Immediate MVP Value**
- Completes existing functionality rather than building redundant features
- Provides working AST-runtime correlation with full query capabilities
- Enables basic Cinema Debugger functionality immediately

### **2. Architectural Soundness**
- Leverages existing robust temporal infrastructure in RuntimeCorrelator
- Avoids duplication and complexity of separate TemporalBridge
- Maintains clean separation of concerns

### **3. Development Efficiency**
- 6-8 hours of focused work vs. 2-3 days of TemporalBridge development
- Builds on proven, tested infrastructure
- Delivers tangible user value faster

### **4. Foundation for Future**
- Completed RuntimeCorrelator provides solid base for Cinema Debugger
- InstrumentationMapper enables AI-guided instrumentation
- Enhanced DataAccess supports advanced query patterns

---

## 🚨 **RISK MITIGATION**

### **Technical Risks:**
1. **DataAccess Enhancement Complexity**: Mitigate with incremental implementation and thorough testing
2. **Performance Impact**: Validate query performance with benchmarks
3. **Integration Issues**: Comprehensive integration testing

### **Timeline Risks:**
1. **Scope Creep**: Focus strictly on MVP functionality, defer enhancements
2. **Technical Debt**: Ensure clean implementation for future extensibility

---

**This revised approach delivers a complete, working MVP with AST-runtime correlation, systematic instrumentation, and Cinema Debugger foundation - all while avoiding unnecessary complexity and duplication.** 