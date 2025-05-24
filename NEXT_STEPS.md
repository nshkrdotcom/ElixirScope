# NEXT_STEPS.md

## ElixirScope Foundation Implementation: Next Steps

This document outlines the immediate next steps for getting the ElixirScope foundation implementation from non-compiling code to a working, tested system. The approach focuses on incremental compilation fixes, layered testing, and systematic validation.

---

## Phase 1: Get Basic Compilation Working (Days 1-3)

### 1.1 Fix Immediate Compilation Issues

#### Missing Dependencies and Applications
```elixir
# mix.exs - Add missing dependencies
defp deps do
  [
    {:phoenix, "~> 1.7.0"},
    {:phoenix_live_view, "~> 0.20.0"},
    {:telemetry, "~> 1.0"},
    {:jason, "~> 1.0"},
    {:httpoison, "~> 2.0", only: :test},
    {:ex_unit, "~> 1.0", only: :test}
  ]
end

# Add to application.ex
def application do
  [
    extra_applications: [:logger, :telemetry],
    mod: {ElixirScope.Application, []}
  ]
end
```

#### Fix Module Dependencies and Circular References
1. **Create stub implementations for missing modules:**
   ```elixir
   # lib/elixir_scope/config.ex - Basic stub
   defmodule ElixirScope.Config do
     def get, do: %{}
     def update(_path, _value), do: :ok
   end
   
   # lib/elixir_scope/events/event.ex - Basic event wrapper
   defmodule ElixirScope.Events.Event do
     defstruct [:id, :timestamp, :data, :correlation_id]
   end
   ```

2. **Fix circular dependency issues:**
   - Remove forward references that don't exist yet
   - Replace complex module calls with simple stubs
   - Comment out advanced features that depend on unimplemented modules

#### Fix Syntax and Compilation Errors
1. **Run compilation in stages:**
   ```bash
   # Start with core modules only
   mix compile --force lib/elixir_scope/utils.ex
   mix compile --force lib/elixir_scope/events.ex
   mix compile --force lib/elixir_scope/config.ex
   ```

2. **Create missing helper functions:**
   ```elixir
   # Add to utils.ex
   def extract_function_name(_ast), do: :unknown
   def extract_arity(_ast), do: 0
   def build_selective_instrumentation(_profile), do: %{entry: [], exit: []}
   ```

### 1.2 Layer 0: Core Utilities Compilation

**Target**: Get `ElixirScope.Utils` and `ElixirScope.Events` compiling

```bash
# Test compilation incrementally
mix compile lib/elixir_scope/utils.ex
mix compile lib/elixir_scope/events.ex
```

**Missing Implementations to Add:**
```elixir
# In utils.ex - Add missing functions
def extract_function_name(ast) do
  case ast do
    {:def, _, [{name, _, _}, _]} -> name
    {:defp, _, [{name, _, _}, _]} -> name
    _ -> :unknown
  end
end

def format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
def format_bytes(bytes) when bytes < 1048576, do: "#{Float.round(bytes/1024, 1)} KB"
# ... rest of implementations
```

### 1.3 Layer 1: Basic Event Structures

**Target**: Get event structures compiling without complex dependencies

```elixir
# Simplify events.ex initially
defmodule ElixirScope.Events do
  # Remove complex helper functions initially
  # Focus on struct definitions only
  
  defmodule FunctionExecution do
    defstruct [:id, :timestamp, :module, :function, :event_type]
  end
  
  # Add helper functions as simple stubs
  def serialize(event), do: :erlang.term_to_binary(event)
  def deserialize(binary), do: :erlang.binary_to_term(binary)
end
```

---

## Phase 2: Layered Testing Strategy (Days 4-10)

### 2.1 Unit Testing Layer - Core Utilities

**Start with the simplest, most fundamental components**

#### Test Implementation Priority:
1. **ElixirScope.Utils** - Most fundamental, fewest dependencies
2. **ElixirScope.Events** - Basic data structures
3. **ElixirScope.Config** - Configuration management
4. **ElixirScope.Capture.RingBuffer** - Core performance component

#### Utils Testing Strategy:
```elixir
# test/elixir_scope/utils_test.exs
defmodule ElixirScope.UtilsTest do
  use ExUnit.Case
  alias ElixirScope.Utils
  
  # Start with tests that don't require complex setup
  describe "timestamp generation" do
    test "monotonic_timestamp returns increasing values" do
      t1 = Utils.monotonic_timestamp()
      Process.sleep(1)
      t2 = Utils.monotonic_timestamp()
      assert t2 > t1
    end
  end
  
  describe "id generation" do
    test "generate_id returns unique values" do
      id1 = Utils.generate_id()
      id2 = Utils.generate_id()
      assert id1 != id2
    end
  end
  
  # Add simple data handling tests
  describe "data inspection" do
    test "safe_inspect handles small data" do
      result = Utils.safe_inspect(%{key: "value"})
      assert is_binary(result)
      assert result =~ "key"
    end
  end
end
```

#### Testing Command Sequence:
```bash
# Test utilities in isolation
mix test test/elixir_scope/utils_test.exs

# Test events next
mix test test/elixir_scope/events_test.exs

# Test config
mix test test/elixir_scope/config_test.exs
```

### 2.2 Component Testing Layer - Individual Modules

**Focus on getting each component working in isolation**

#### RingBuffer Testing Strategy:
```elixir
# test/elixir_scope/capture/ring_buffer_test.exs
defmodule ElixirScope.Capture.RingBufferTest do
  use ExUnit.Case
  alias ElixirScope.Capture.RingBuffer
  
  # Start with basic functionality
  describe "basic operations" do
    test "can create a ring buffer" do
      assert {:ok, buffer} = RingBuffer.new(size: 64)
      assert RingBuffer.size(buffer) == 64
    end
    
    test "can write and read single event" do
      {:ok, buffer} = RingBuffer.new(size: 64)
      event = %{id: 1, data: "test"}
      
      assert :ok = RingBuffer.write(buffer, event)
      assert {:ok, ^event, _pos} = RingBuffer.read(buffer, 0)
    end
  end
  
  # Add performance tests later
  @tag :performance
  describe "performance characteristics" do
    test "write latency is under target" do
      # Add after basic functionality works
    end
  end
end
```

#### Component Test Implementation Order:
1. **RingBuffer** - Core performance component
2. **InstrumentationRuntime** - Interface for instrumented code
3. **EventIngestor** - Event processing
4. **AsyncWriter** - Background processing
5. **EventCorrelator** - Event relationships

### 2.3 Integration Testing Layer - Component Interactions

**Test how components work together**

#### Pipeline Integration Testing:
```elixir
# test/integration/capture_pipeline_test.exs
defmodule ElixirScope.Integration.CaptureePipelineTest do
  use ExUnit.Case
  
  # Test the full capture pipeline
  describe "event capture pipeline" do
    test "events flow from runtime to storage" do
      # Start minimal pipeline
      {:ok, buffer} = ElixirScope.Capture.RingBuffer.new()
      
      # Generate test event
      correlation_id = ElixirScope.Utils.generate_correlation_id()
      
      # Test pipeline flow
      :ok = ElixirScope.Capture.InstrumentationRuntime.report_function_entry(
        TestModule, :test_function, [], correlation_id
      )
      
      # Wait for processing
      Process.sleep(100)
      
      # Verify event was processed
      # (Implementation depends on storage layer)
    end
  end
end
```

### 2.4 Performance Testing Layer - Validate Targets

**Ensure performance targets are met**

#### Performance Test Strategy:
```elixir
# test/performance/ring_buffer_performance_test.exs
defmodule ElixirScope.Performance.RingBufferPerformanceTest do
  use ExUnit.Case
  
  @moduletag :performance
  @moduletag timeout: 60_000
  
  describe "ring buffer performance" do
    test "write latency under 1 microsecond" do
      {:ok, buffer} = ElixirScope.Capture.RingBuffer.new(size: 1024)
      event = %{id: 1, data: "test"}
      
      # Warm up
      for _i <- 1..100, do: ElixirScope.Capture.RingBuffer.write(buffer, event)
      
      # Measure
      times = for _i <- 1..1000 do
        start_time = System.monotonic_time(:nanosecond)
        ElixirScope.Capture.RingBuffer.write(buffer, event)
        System.monotonic_time(:nanosecond) - start_time
      end
      
      avg_time = Enum.sum(times) / length(times)
      assert avg_time < 1000  # Less than 1 microsecond
    end
  end
end
```

---

## Phase 3: Missing Code Implementations (Days 7-14)

### 3.1 Critical Missing Implementations

#### High Priority - Required for Basic Functionality

**1. ElixirScope.Capture.RingBuffer - Core Performance Component**
```elixir
# lib/elixir_scope/capture/ring_buffer.ex
# Missing implementations:

defp claim_write_position(%__MODULE__{} = buffer) do
  # TODO: Implement atomic write position claiming
  # This is critical for lock-free operation
end

defp handle_overflow(%__MODULE__{} = buffer, event) do
  # TODO: Implement overflow strategies
  case buffer.overflow_strategy do
    :drop_oldest -> # Implementation needed
    :drop_newest -> # Implementation needed  
    :block -> # Implementation needed
  end
end
```

**2. ElixirScope.Capture.InstrumentationRuntime - Interface Layer**
```elixir
# lib/elixir_scope/capture/instrumentation_runtime.ex
# Missing implementations:

defp get_buffer do
  # TODO: Implement buffer retrieval from application
  # This connects runtime to the ring buffer
end

def initialize_context do
  # TODO: Implement process-specific context initialization
  # Critical for correlation tracking
end
```

**3. ElixirScope.AST.Transformer - Core Value Proposition**
```elixir
# lib/elixir_scope/ast/transformer.ex
# Missing implementations:

defp instrument_function_body(signature, body, plan) do
  # TODO: This is the core AST transformation logic
  # Without this, no automatic instrumentation works
end

defp extract_function_name(signature) do
  # TODO: Extract function name from AST signature
end

defp extract_args(signature) do
  # TODO: Extract arguments from AST signature  
end
```

### 3.2 Medium Priority - Required for Advanced Features

**1. ElixirScope.AI.CodeAnalyzer - Intelligence Layer**
```elixir
# lib/elixir_scope/ai/code_analyzer.ex
# Missing implementations:

defp analyze_ast(ast) do
  # TODO: Implement AST analysis for pattern recognition
end

defp find_elixir_files(project_path) do
  # TODO: Implement file discovery
end
```

**2. ElixirScope.Phoenix.Integration - Real-world Value**
```elixir
# lib/elixir_scope/phoenix/integration.ex
# Missing implementations:

def handle_http_event(event_name, measurements, metadata, config) do
  # TODO: Implement telemetry event handling
end

defp put_correlation_id(conn, correlation_id) do
  # TODO: Implement correlation ID storage in conn
end
```

### 3.3 Implementation Priority Matrix

| Component | Priority | Effort | Value | Dependencies |
|-----------|----------|--------|-------|-------------|
| **RingBuffer core logic** | Critical | High | High | Utils only |
| **InstrumentationRuntime basic** | Critical | Medium | High | RingBuffer |
| **AST.Transformer basic** | Critical | High | Very High | InstrumentationRuntime |
| **EventIngestor** | High | Medium | Medium | RingBuffer |
| **AsyncWriter** | High | Medium | Medium | EventIngestor |
| **Phoenix Integration** | High | High | Very High | All capture components |
| **AI CodeAnalyzer** | Medium | Very High | High | AST knowledge |

---

## Phase 4: Missing Test Implementations (Days 11-17)

### 4.1 Critical Missing Tests

#### Core Component Tests - Required for Stability

**1. RingBuffer Comprehensive Testing**
```elixir
# test/elixir_scope/capture/ring_buffer_test.exs
# Missing test implementations:

describe "concurrent access" do
  test "multiple writers don't corrupt data" do
    # TODO: Implement concurrent write testing
    # Critical for multi-process safety
  end
  
  test "reader doesn't block writers" do
    # TODO: Implement reader/writer independence testing
  end
end

describe "overflow handling" do
  test "drop_oldest strategy works correctly" do
    # TODO: Test overflow behavior
  end
  
  test "buffer recovers after overflow" do
    # TODO: Test recovery mechanisms
  end
end
```

**2. AST Transformation Testing**
```elixir
# test/elixir_scope/ast/transformer_test.exs
# Missing test implementations:

describe "semantic equivalence" do
  test "instrumented code produces same results as original" do
    # TODO: Critical test for correctness
    # Must verify no behavior changes
  end
  
  test "instrumented code preserves error behavior" do
    # TODO: Test exception handling preservation
  end
end

describe "edge cases" do
  test "handles macro-generated code" do
    # TODO: Test with Phoenix, Ecto macros
  end
  
  test "handles complex pattern matching" do
    # TODO: Test with guards, multiple clauses
  end
end
```

### 4.2 Integration Tests - Required for Real-world Usage

**1. Phoenix Integration Testing**
```elixir
# test/integration/phoenix_integration_test.exs
# Missing implementation: Complete test for real Phoenix app

defmodule ElixirScope.Integration.PhoenixIntegrationTest do
  use ExUnit.Case
  # TODO: Implement comprehensive Phoenix testing
  # This proves real-world value
end
```

**2. Performance Integration Testing**
```elixir
# test/performance/end_to_end_performance_test.exs
# Missing implementation: End-to-end performance validation

defmodule ElixirScope.Performance.EndToEndTest do
  use ExUnit.Case
  @moduletag :performance
  
  # TODO: Implement complete pipeline performance testing
  # This validates the <1% overhead target
end
```

### 4.3 Test Implementation Strategy

#### Week 1: Core Component Tests
- **Day 1-2**: Utils and Events tests
- **Day 3-4**: RingBuffer tests (basic → concurrent → performance)
- **Day 5-6**: InstrumentationRuntime tests
- **Day 7**: Integration between RingBuffer and InstrumentationRuntime

#### Week 2: Advanced Component Tests  
- **Day 8-9**: AST Transformer tests (basic → semantic equivalence)
- **Day 10-11**: EventIngestor and AsyncWriter tests
- **Day 12-13**: EventCorrelator tests
- **Day 14**: Component integration tests

#### Week 3: Integration and Performance Tests
- **Day 15-16**: Phoenix integration tests
- **Day 17-18**: End-to-end performance tests
- **Day 19-20**: Chaos engineering tests
- **Day 21**: Production readiness validation

---

## Phase 5: Incremental Validation Strategy (Days 18-24)

### 5.1 Layered Validation Approach

#### Layer 1: Unit Validation
```bash
# Run tests in dependency order
mix test test/elixir_scope/utils_test.exs
mix test test/elixir_scope/events_test.exs
mix test test/elixir_scope/capture/ring_buffer_test.exs
```

#### Layer 2: Component Validation
```bash
# Test component interactions
mix test test/elixir_scope/capture/
mix test test/elixir_scope/ast/
```

#### Layer 3: Integration Validation
```bash
# Test complete features
mix test test/integration/
mix test test/phoenix/
```

#### Layer 4: Performance Validation
```bash
# Validate performance targets
mix test test/performance/ --include performance
```

### 5.2 Validation Criteria by Layer

#### Layer 1 Success Criteria:
- [ ] All unit tests pass (95%+ coverage)
- [ ] No compilation warnings
- [ ] Basic functionality demonstrated

#### Layer 2 Success Criteria:
- [ ] Component tests pass
- [ ] Inter-component communication works
- [ ] Error handling is robust

#### Layer 3 Success Criteria:
- [ ] Integration tests pass
- [ ] Real Phoenix app can be instrumented
- [ ] Events flow through complete pipeline

#### Layer 4 Success Criteria:
- [ ] Performance targets met (<1μs ring buffer writes)
- [ ] Memory usage is bounded
- [ ] System remains stable under load

---

## Immediate Action Plan (Next 7 Days)

### Day 1: Compilation Fixes
1. **Fix mix.exs dependencies**
2. **Create stub implementations for missing modules**
3. **Get ElixirScope.Utils compiling**
4. **Get ElixirScope.Events compiling**

### Day 2: Core Component Compilation
1. **Fix ElixirScope.Capture.RingBuffer compilation**
2. **Fix ElixirScope.Capture.InstrumentationRuntime compilation**
3. **Create basic tests for compiled modules**

### Day 3: Basic Testing Infrastructure
1. **Implement Utils tests**
2. **Implement Events tests**
3. **Set up test helper functions**
4. **Verify test execution works**

### Day 4-5: RingBuffer Implementation and Testing
1. **Implement core RingBuffer functionality**
2. **Add basic RingBuffer tests**
3. **Add performance tests for RingBuffer**
4. **Validate performance targets**

### Day 6-7: InstrumentationRuntime and Integration
1. **Implement basic InstrumentationRuntime**
2. **Test InstrumentationRuntime → RingBuffer flow**
3. **Create simple end-to-end test**
4. **Document current state and next priorities**

### Success Metrics for Week 1:
- [ ] All core modules compile without errors
- [ ] Basic test suite runs and passes
- [ ] RingBuffer meets performance targets
- [ ] Simple event flow works end-to-end
- [ ] Clear plan for Week 2 established

---

## Risk Mitigation and Fallback Plans

### High-Risk Areas:

#### 1. AST Transformation Complexity
- **Risk**: Complex AST manipulation may be brittle
- **Mitigation**: Start with simple function instrumentation only
- **Fallback**: Manual instrumentation API if AST proves too complex

#### 2. Performance Target Achievement  
- **Risk**: May not achieve <1μs ring buffer writes
- **Mitigation**: Profile and optimize incrementally
- **Fallback**: Relaxed targets if necessary (e.g., <10μs)

#### 3. Phoenix Integration Complexity
- **Risk**: Phoenix internals may be complex to instrument
- **Mitigation**: Use Telemetry events (stable API)
- **Fallback**: Basic HTTP-only tracing if LiveView proves complex

### Monitoring and Course Correction:

#### Daily Check-ins:
- Compilation status
- Test pass rate  
- Performance benchmark results
- Blockers and dependencies

#### Weekly Assessments:
- Progress against timeline
- Quality metrics (test coverage, performance)
- Risk factors and mitigation effectiveness
- Scope adjustments if needed

---

## Tools and Infrastructure Needed

### Development Tools:
```bash
# Required development dependencies
mix archive.install hex phx_new  # For Phoenix test apps
mix deps.get
mix compile

# Performance profiling tools
:observer.start()  # For memory/process monitoring
:fprof  # For performance profiling
```

### Testing Infrastructure:
```elixir
# test/test_helper.exs additions needed
ExUnit.start()

# Add performance testing support
ExUnit.configure(exclude: [:performance], timeout: 60_000)

# Add integration testing support  
ExUnit.configure(exclude: [:integration])
```

### CI/CD Setup:
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix test
      - run: mix test --include performance
```

---

## Success Definition

**The ElixirScope foundation is considered successfully implemented when:**

1. **All core modules compile and run without errors**
2. **Basic event flow works**: Code → InstrumentationRuntime → RingBuffer → Storage
3. **Performance targets are met**: <1μs ring buffer writes, <5% application overhead
4. **Integration tests pass**: Real Phoenix application can be instrumented
5. **Test coverage >90%**: Comprehensive test suite provides confidence
6. **Documentation is complete**: Clear usage instructions and examples

**This foundation then enables the advanced features like AI analysis, distributed tracing, and visual UI to be built on solid ground.**
