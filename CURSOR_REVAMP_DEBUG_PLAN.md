# ElixirScope Runtime Tracing Revamp Plan

## Executive Summary

This document outlines a comprehensive plan to revamp ElixirScope from its current AST-based compile-time instrumentation approach to a runtime tracing system that leverages BEAM's built-in debugging primitives. This shift addresses the valid critique in `OPUS_DONT_REINVENT_AND_USE_BUILTIN_DEBUG.md` while preserving ElixirScope's core value propositions: AI-guided analysis, high-performance event processing, and the "Execution Cinema" vision.

## Core Philosophy

**Leverage, Don't Reinvent**: Use `:erlang.trace/3`, `:sys.trace/2`, `:dbg`, and other BEAM primitives as primary data sources.

**Runtime Flexibility**: Enable dynamic tracing control without recompilation, essential for production debugging.

**Preserve Backend Value**: Retain the high-performance capture pipeline (`RingBuffer`, `Ingestor`, `EventCorrelator`, `DataAccess`) as these provide genuine value regardless of data source.

**AI-Guided Runtime Plans**: Shift AI analysis from generating AST transformations to generating runtime tracing strategies.

**Production-Ready API**: Comprehensive runtime API with safety controls, sampling strategies, and interactive debugging (enhanced from `OPUS_PROD_RUNTIME_INSTRUMENTATION_API_SKETCH.md`).

## Phase 1: Foundation & Core Runtime Components

### 1.1 Create Runtime Tracing Infrastructure

#### ✅ **Task 1.1.1: Create `ElixirScope.Runtime` API Module**
- **File**: `lib/elixir_scope/runtime.ex`
- **Purpose**: Comprehensive runtime tracing API (enhanced from OPUS_PROD_RUNTIME_INSTRUMENTATION_API_SKETCH.md)
- **Core Functions**:
  - `trace(module, opts)` - Module-level tracing with sampling, conditions
  - `trace_function(module, function, arity, opts)` - Function-specific tracing
  - `trace_process(pid, opts)` - Process-level tracing with children
  - `stop_trace(ref)` - Stop specific trace
  - `list_traces()` - Show active traces with detailed info
  - `adjust_trace(ref, adjustments)` - Runtime parameter adjustment
- **Advanced Functions**:
  - `trace_when(module, function, opts)` - Conditional breakpoint-style tracing
  - `trace_anomalies(type, opts)` - Automatic anomaly detection and tracing
  - `trace_pattern(pattern, opts)` - Pattern-based message/call tracing
  - `instrument(module, opts)` - Hot code loading with custom instrumentation
- **Production Safety**:
  - `set_limits(limits)` - Global safety controls and resource limits
  - `emergency_stop()` - Emergency shutdown of all tracing

#### ✅ **Task 1.1.2: Create `ElixirScope.Runtime.Controller`**
- **File**: `lib/elixir_scope/runtime/controller.ex`
- **Purpose**: Central GenServer managing all runtime tracing
- **Responsibilities**:
  - Coordinate `TracerManager` and `StateMonitorManager`
  - Apply runtime plans from AI.Orchestrator
  - Handle API calls from `ElixirScope.Runtime`
  - Manage global tracing state

#### ✅ **Task 1.1.3: Create `ElixirScope.Runtime.TracerManager`**
- **File**: `lib/elixir_scope/runtime/tracer_manager.ex`
- **Purpose**: Manage multiple `Tracer` instances
- **Responsibilities**:
  - Start/stop individual tracers based on plans
  - Distribute tracing load across tracer processes
  - Handle tracer failures and restarts

#### ✅ **Task 1.1.4: Create `ElixirScope.Runtime.Tracer`**
- **File**: `lib/elixir_scope/runtime/tracer.ex`
- **Purpose**: Individual tracer process using `:dbg` or `:erlang.trace`
- **Responsibilities**:
  - Set up BEAM trace patterns using `:dbg.tp/2`, `:dbg.p/2`
  - Receive and process trace messages
  - Convert trace messages to `ElixirScope.Events`
  - Manage correlation IDs and call stacks per PID
  - Forward events to `Ingestor`

### 1.2 State Monitoring Infrastructure

#### ✅ **Task 1.2.1: Create `ElixirScope.Runtime.StateMonitorManager`**
- **File**: `lib/elixir_scope/runtime/state_monitor_manager.ex`
- **Purpose**: Manage OTP process state monitoring
- **Responsibilities**:
  - Start/stop state monitors for OTP processes
  - Apply state monitoring plans
  - Handle monitor failures

#### ✅ **Task 1.2.2: Create `ElixirScope.Runtime.StateMonitor`**
- **File**: `lib/elixir_scope/runtime/state_monitor.ex`
- **Purpose**: Monitor individual OTP process using `:sys.install`
- **Responsibilities**:
  - Use `:sys.install/3` to attach to OTP processes
  - Implement debug handler functions
  - Capture state changes and snapshots
  - Generate `StateChange` and `StateSnapshot` events

### 1.3 Supporting Runtime Modules (from API Sketch)

#### ✅ **Task 1.3.1: Create `ElixirScope.Runtime.Matchers`**
- **File**: `lib/elixir_scope/runtime/matchers.ex`
- **Purpose**: Pattern matching DSL for runtime tracing conditions
- **Features**:
  - `match_spec/1` macro for building BEAM match specifications
  - Compile-time optimization of match patterns
  - Support for complex argument and return value patterns
  - Integration with conditional tracing

#### ✅ **Task 1.3.2: Create `ElixirScope.Runtime.Sampling`**
- **File**: `lib/elixir_scope/runtime/sampling.ex`
- **Purpose**: Intelligent sampling strategies for production tracing
- **Features**:
  - `adaptive_sampler/1` - Load-based sampling adjustment
  - `tail_sampler/1` - Trace full request if interesting (errors, slow)
  - Custom sampling functions based on system metrics
  - Integration with production safety limits

#### ✅ **Task 1.3.3: Create `ElixirScope.Runtime.Safety`**
- **File**: `lib/elixir_scope/runtime/safety.ex`
- **Purpose**: Production safety controls and circuit breakers
- **Features**:
  - Resource usage monitoring (CPU, memory, event rate)
  - Automatic trace reduction under load
  - Emergency stop mechanisms
  - Configurable safety thresholds

### 1.4 Testing Infrastructure for Phase 1

#### ✅ **Task 1.4.1: Create Runtime API Tests**
- **File**: `test/elixir_scope/runtime_test.exs`
- **Coverage**: Enhanced API functions from sketch, error handling, integration

#### ✅ **Task 1.4.2: Create Controller Tests**
- **File**: `test/elixir_scope/runtime/controller_test.exs`
- **Coverage**: Plan application, tracer coordination, state management

#### ✅ **Task 1.4.3: Create Tracer Tests**
- **Files**: 
  - `test/elixir_scope/runtime/tracer_manager_test.exs`
  - `test/elixir_scope/runtime/tracer_test.exs`
- **Coverage**: BEAM trace setup, message processing, event generation

#### ✅ **Task 1.4.4: Create State Monitor Tests**
- **Files**:
  - `test/elixir_scope/runtime/state_monitor_manager_test.exs`
  - `test/elixir_scope/runtime/state_monitor_test.exs`
- **Coverage**: `:sys.install` integration, state capture, event generation

#### ✅ **Task 1.4.5: Create Supporting Module Tests**
- **Files**:
  - `test/elixir_scope/runtime/matchers_test.exs`
  - `test/elixir_scope/runtime/sampling_test.exs`
  - `test/elixir_scope/runtime/safety_test.exs`
- **Coverage**: Pattern matching DSL, sampling strategies, production safety

## Phase 2: AI Layer Adaptation

### 2.1 Modify AI.Orchestrator for Runtime Plans

#### ✅ **Task 2.1.1: Update `ElixirScope.AI.Orchestrator`**
- **File**: `lib/elixir_scope/ai/orchestrator.ex`
- **Changes**:
  - Replace AST instrumentation plan generation with runtime tracing plans
  - Generate plans specifying:
    - Which modules/functions to trace with `:dbg.tp/2`
    - Which PIDs to trace with `:dbg.p/2`
    - Match specifications for detailed capture
    - OTP processes to monitor with `:sys.install`
    - Sampling rates and trace flags
  - Store runtime plans in `DataAccess`
  - Provide plan update mechanisms

#### ✅ **Task 2.1.2: Define Runtime Plan Schema**
- **File**: `lib/elixir_scope/ai/runtime_plan.ex` (new)
- **Purpose**: Define structured schema for runtime tracing plans
- **Schema**:
  ```elixir
  %RuntimePlan{
    global_trace_flags: [:call, :return_to, :send, :receive, :timestamp],
    module_traces: %{
      MyModule => %{
        functions: %{
          {:my_func, 2} => %{
            trace_level: :detailed,
            match_spec: [...],
            sampling_rate: 0.8
          }
        },
        otp_monitoring: :state_changes
      }
    },
    pid_traces: %{},
    sampling_rate: 1.0
  }
  ```

### 2.2 Update Configuration Schema

#### ✅ **Task 2.2.1: Modify `ElixirScope.Config`**
- **File**: `lib/elixir_scope/config.ex`
- **Changes**:
  - Remove/deprecate `:instrumentation` section
  - Add `:runtime_tracing` section with:
    - `enabled_by_default: boolean()`
    - `default_trace_flags: [atom()]`
    - `default_otp_monitoring_level: :none | :state_changes | :full_callbacks`
    - `max_traced_processes: integer()`
    - `exclude_modules_from_runtime_trace: [module()]`
  - Update validation logic for new schema
  - Maintain backward compatibility where possible

## Phase 3: Capture Layer Adaptation

### 3.1 Modify Existing Capture Components

#### ✅ **Task 3.1.1: Simplify `InstrumentationRuntime`**
- **File**: `lib/elixir_scope/capture/instrumentation_runtime.ex`
- **Changes**:
  - Remove complex per-process call stack management
  - Simplify to basic event formatting and forwarding
  - Keep framework-specific reporting functions for Telemetry handlers
  - Remove AST-injection specific context management
  - Focus on being a bridge between tracers and `Ingestor`

#### ✅ **Task 3.1.2: Enhance `Ingestor` for Runtime Events**
- **File**: `lib/elixir_scope/capture/ingestor.ex`
- **Changes**:
  - Add `ingest_generic_event/7` function for tracer-generated events
  - Enhance existing functions to handle events from multiple sources
  - Improve timestamp handling for BEAM trace timestamps
  - Add support for trace-specific correlation ID patterns

#### ✅ **Task 3.1.3: Update `EventCorrelator`**
- **File**: `lib/elixir_scope/capture/event_correlator.ex`
- **Changes**:
  - Enhance correlation logic for runtime-traced events
  - Handle correlation IDs generated by tracers vs. Telemetry
  - Improve call stack reconstruction from trace messages
  - Add support for cross-process correlation via message tracing

### 3.2 Testing Updates for Capture Layer

#### ✅ **Task 3.2.1: Update `InstrumentationRuntime` Tests**
- **File**: `test/elixir_scope/capture/instrumentation_runtime_test.exs`
- **Changes**: Simplify tests to match reduced API surface

#### ✅ **Task 3.2.2: Update `Ingestor` Tests**
- **File**: `test/elixir_scope/capture/ingestor_test.exs`
- **Changes**: Add tests for `ingest_generic_event/7` and runtime event handling

#### ✅ **Task 3.2.3: Update `EventCorrelator` Tests**
- **File**: `test/elixir_scope/capture/event_correlator_test.exs`
- **Changes**: Add tests for runtime trace correlation scenarios

## Phase 4: Integration Layer Updates

### 4.1 Update Framework Integrations

#### ✅ **Task 4.1.1: Modify Phoenix Integration**
- **File**: `lib/elixir_scope/phoenix/integration.ex`
- **Changes**:
  - Update Telemetry handlers to work with runtime tracing
  - Use `ElixirScope.Runtime` API to tag/control traces
  - Maintain semantic event reporting for Phoenix-specific context
  - Integrate with correlation ID propagation from runtime tracers

#### ✅ **Task 4.1.2: Update Other Framework Integrations**
- **Files**: Other integration modules in `lib/elixir_scope/`
- **Changes**: Similar updates to work with runtime tracing approach

### 4.2 Update Main API

#### ✅ **Task 4.2.1: Modify `ElixirScope` Main Module**
- **File**: `lib/elixir_scope.ex`
- **Changes**:
  - Update `start/1` to initialize runtime tracing instead of AST compilation
  - Modify options to support runtime tracing parameters
  - Update `analyze_codebase/1` to generate runtime plans
  - Change `update_instrumentation/1` to update runtime plans

## Phase 5: Deprecation and Cleanup

### 5.1 Remove AST Components

#### ✅ **Task 5.1.1: Archive AST Transformation Code**
- **Files to Remove**:
  - `lib/elixir_scope/ast/transformer.ex`
  - `lib/elixir_scope/ast/injector_helpers.ex`
  - `test/elixir_scope/ast/transformer_test.exs`
- **Action**: Move to `deprecated/` directory with clear documentation

#### ✅ **Task 5.1.2: Modify/Remove Compiler Task**
- **File**: `lib/elixir_scope/compiler/mix_task.ex`
- **Changes**:
  - Repurpose as `mix elixir_scope.analyze` task
  - Remove AST transformation logic
  - Focus on triggering AI analysis and runtime plan generation
  - Update documentation and help text

### 5.2 Update Documentation

#### ✅ **Task 5.2.1: Update README.md**
- **File**: `README.md`
- **Changes**:
  - Update architecture description
  - Remove references to compile-time instrumentation
  - Add runtime tracing examples
  - Update quick start guide

#### ✅ **Task 5.2.2: Update GETTING_STARTED.md**
- **File**: `GETTING_STARTED.md`
- **Changes**:
  - Remove compiler registration instructions
  - Add runtime tracing setup
  - Update configuration examples
  - Revise workflow descriptions

#### ✅ **Task 5.2.3: Create Migration Guide**
- **File**: `MIGRATION_TO_RUNTIME_TRACING.md` (new)
- **Purpose**: Help existing users migrate from AST to runtime approach

## Phase 6: Advanced Features and Optimization

### 6.1 Time-Travel Debugging Engine

#### ✅ **Task 6.1.1: Create `ElixirScope.TimeTravel.ReplayEngine`**
- **File**: `lib/elixir_scope/time_travel/replay_engine.ex`
- **Purpose**: Reconstruct historical state from runtime-captured events (enhanced from API sketch)
- **Features**:
  - `enable_time_travel(target, opts)` - State capture with snapshots and triggers
  - `replay_to(session_id, timestamp_or_checkpoint, opts)` - Time-travel to specific points
  - `step_forward/backward(session_id, opts)` - Step-by-step execution control
  - `checkpoint(session_id, opts)` - Create state checkpoints
  - State modification during replay for "what-if" scenarios
  - Compression and efficient storage of state snapshots

#### ✅ **Task 6.1.2: Create Interactive Debugging Interface**
- **File**: `lib/elixir_scope/runtime/interactive.ex`
- **Purpose**: IEx-integrated debugging interface (enhanced from API sketch)
- **Features**:
  - `debug/2` macro for interactive debugging sessions
  - `break/2` macro for runtime breakpoints with conditions
  - Integration with time-travel engine
  - Real-time trace adjustment during debugging sessions
  - Pattern-based debugging triggers

### 6.2 Performance Optimization

#### ✅ **Task 6.2.1: Optimize Tracer Performance**
- **Focus**: Minimize overhead of trace message processing
- **Techniques**:
  - Efficient match specifications
  - Batched event processing
  - Smart sampling strategies
  - Tracer process pooling

#### ✅ **Task 6.2.2: Benchmark Runtime vs AST Approach**
- **Purpose**: Validate performance characteristics
- **Metrics**:
  - Event capture overhead
  - Memory usage
  - Throughput comparison
  - Production readiness assessment

### 6.3 Integration with Existing Tools

#### ✅ **Task 6.3.1: Observer Integration**
- **File**: `lib/elixir_scope/integrations/observer.ex`
- **Purpose**: Feed ElixirScope data into `:observer`
- **Features**: Custom backend for Observer's process and application views

#### ✅ **Task 6.3.2: Recon Integration**
- **File**: `lib/elixir_scope/integrations/recon.ex`
- **Purpose**: Use `:recon_trace` for production-safe tracing
- **Features**: Pipeline recon output into ElixirScope's processing

## Implementation Strategy

### Development Approach

1. **Incremental Development**: Implement phases sequentially with working checkpoints
2. **Parallel Testing**: Maintain both old and new systems during transition
3. **Feature Flags**: Use configuration to enable/disable runtime tracing during development
4. **Backward Compatibility**: Maintain API compatibility where possible

### Quality Assurance

1. **Comprehensive Testing**: Each component gets full test coverage
2. **Integration Testing**: End-to-end scenarios with real applications
3. **Performance Testing**: Continuous benchmarking throughout development
4. **Production Validation**: Gradual rollout with monitoring

### Risk Mitigation

1. **Fallback Mechanisms**: Graceful degradation when tracing fails
2. **Resource Limits**: Built-in protections against trace storms
3. **Documentation**: Clear migration paths and troubleshooting guides
4. **Community Feedback**: Early preview releases for feedback

## Success Criteria

### Technical Metrics
- [ ] Zero compilation warnings maintained
- [ ] Test coverage ≥ 90% for new components
- [ ] Runtime tracing overhead < 5% in production scenarios
- [ ] Memory usage comparable to or better than AST approach
- [ ] Support for all major OTP patterns (GenServer, Supervisor, etc.)

### Functional Goals
- [ ] Dynamic tracing control without recompilation
- [ ] Time-travel debugging with runtime-captured data
- [ ] Integration with existing BEAM debugging tools
- [ ] Production-ready performance and safety
- [ ] Comprehensive documentation and migration guides

### User Experience
- [ ] Simpler setup (no compiler registration required)
- [ ] More flexible debugging workflows
- [ ] Better integration with existing Elixir/Erlang tooling
- [ ] Clearer mental model aligned with BEAM primitives

## Timeline Estimate

- **Phase 1**: 3-4 weeks (Foundation)
- **Phase 2**: 2-3 weeks (AI Adaptation)
- **Phase 3**: 2-3 weeks (Capture Layer)
- **Phase 4**: 2 weeks (Integration Updates)
- **Phase 5**: 1-2 weeks (Cleanup)
- **Phase 6**: 3-4 weeks (Advanced Features)

**Total Estimated Duration**: 13-18 weeks

## Architectural Analysis & Changes Summary

### Current Architecture (AST-Based)
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Mix Compiler  │───▶│  AST.Transformer │───▶│ Instrumented    │
│   Task          │    │  + InjectorHelpers│    │ .beam Files     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                ▲
                                │
                       ┌──────────────────┐
                       │ AI.Orchestrator  │
                       │ (AST Plans)      │
                       └──────────────────┘
                                ▲
                                │
                       ┌──────────────────┐
                       │ InstrumentationRT│◀─── Injected calls
                       │ (Process Dict)   │     from .beam
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │    Ingestor      │
                       └──────────────────┘
```

### New Architecture (Runtime Tracing)
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ ElixirScope.    │───▶│ Runtime.         │───▶│ BEAM Trace     │
│ Runtime API     │    │ Controller       │    │ Messages        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │ TracerManager    │    │ StateMonitor    │
                       │                  │    │ Manager         │
                       └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │ Tracer Processes │    │ StateMonitor    │
                       │ (:dbg, :trace)   │    │ (:sys.install)  │
                       └──────────────────┘    └─────────────────┘
                                │                        │
                                └────────┬───────────────┘
                                         ▼
                                ┌──────────────────┐
                                │    Ingestor      │
                                │ (Enhanced)       │
                                └──────────────────┘
                                         ▲
                                         │
                                ┌──────────────────┐
                                │ AI.Orchestrator  │
                                │ (Runtime Plans)  │
                                └──────────────────┘
```

### Key Architectural Changes

1. **Data Source Shift**: From AST-injected calls to BEAM trace messages
2. **Control Mechanism**: From compile-time transformation to runtime API
3. **AI Planning**: From AST instrumentation plans to runtime tracing strategies
4. **Process Management**: From process dictionary context to tracer process coordination
5. **State Capture**: From callback injection to `:sys.install` monitoring
6. **Correlation**: From injected correlation IDs to trace message correlation

### Enhanced Design Principles (from API Sketch)

The production runtime instrumentation API sketch provides excellent design principles that enhance our revamp:

1. **Progressive Enhancement**: Start with cheap tracing, add detail as needed
   - Basic → Detailed → Full tracing levels
   - Adaptive sampling based on system load
   - Conditional tracing that activates on interesting events

2. **Production Safety First**: Built-in limits, circuit breakers, and emergency stops
   - Resource usage monitoring (CPU, memory, event rate)
   - Automatic trace reduction under load
   - Emergency stop mechanisms with configurable thresholds

3. **Zero Configuration**: Sensible defaults that work in production
   - Intelligent sampling strategies (adaptive, tail-based)
   - Automatic anomaly detection and response
   - Safe defaults for all tracing parameters

4. **Composable Tracing**: Mix and match different tracing strategies
   - Module-level, function-level, and process-level tracing
   - Pattern-based tracing for messages and calls
   - Conditional tracing with custom predicates

5. **Time-Travel Native**: State capture and replay as first-class features
   - Checkpoint creation and restoration
   - Step-by-step execution control
   - State modification during replay for "what-if" scenarios

6. **Interactive Debugging**: IEx integration for real-time debugging
   - Runtime breakpoints with conditions
   - Interactive debugging sessions
   - Real-time trace adjustment during debugging

## Comprehensive Testing Strategy

### Testing Philosophy

Given the magnitude of this architectural change, our testing strategy must ensure:
1. **Zero Regression**: All existing functionality continues to work
2. **Runtime Reliability**: New runtime tracing is robust and performant
3. **Migration Safety**: Smooth transition path for existing users
4. **Production Readiness**: Comprehensive validation under realistic conditions

### Current Test Infrastructure Analysis

**Strengths to Preserve:**
- ✅ Comprehensive event ingestion testing (`ingestor_test.exs` - 495 lines)
- ✅ Robust event correlation testing (`event_correlator_test.exs` - 534 lines)
- ✅ High-performance buffer testing (`ring_buffer_test.exs` - 553 lines)
- ✅ AI code analysis testing (`code_analyzer_test.exs` - 255 lines)
- ✅ Mock-based testing infrastructure for fast execution
- ✅ Test helpers and utilities (`test_helper.exs`, `ai_test_helpers.ex`)

**Gaps to Address:**
- ❌ No instrumentation runtime tests (file doesn't exist)
- ❌ No orchestrator tests (file doesn't exist)
- ❌ Limited integration testing (mostly skipped)
- ❌ No BEAM tracing integration tests
- ❌ No state monitoring tests

### Phase-by-Phase Testing Strategy

#### Phase 1: Foundation Testing (Runtime Components)

##### ✅ **Task T1.1: Runtime API Testing**
- **File**: `test/elixir_scope/runtime_test.exs`
- **Coverage** (Enhanced from API Sketch):
  - [ ] `trace/2` with sampling, conditions, and various targets
  - [ ] `trace_function/4` with fine-grained control and match specs
  - [ ] `trace_process/2` with children and message tracing
  - [ ] `trace_when/3` conditional breakpoint-style tracing
  - [ ] `trace_anomalies/2` automatic anomaly detection
  - [ ] `trace_pattern/2` pattern-based message/call tracing
  - [ ] `instrument/2` hot code loading with custom instrumentation
  - [ ] `adjust_trace/2` runtime parameter adjustment
  - [ ] `set_limits/1` production safety controls
  - [ ] `emergency_stop/0` emergency shutdown
  - [ ] Error handling and resource cleanup
  - [ ] Concurrent API usage safety

```elixir
# Enhanced test examples from API sketch
describe "trace/2 with advanced options" do
  test "traces with sampling and conditions" do
    {:ok, trace_ref} = ElixirScope.Runtime.trace(TestModule,
      level: :detailed,
      sample_rate: 0.1,
      when: fn(mod, fun, args) -> 
        match?({:error, _}, List.first(args)) 
      end
    )
    assert is_reference(trace_ref)
  end
  
  test "trace_function with custom match specs" do
    {:ok, trace_ref} = ElixirScope.Runtime.trace_function(MyCache, :get, 1,
      match: fn [key] when byte_size(key) > 100 -> true; _ -> false end,
      capture: [:args, :returns, :timing]
    )
    assert is_reference(trace_ref)
  end
  
  test "trace_when for conditional breakpoints" do
    {:ok, trace_ref} = ElixirScope.Runtime.trace_when(MyApp.Orders, :place_order,
      condition: fn(_mod, _fun, [order]) -> order.total > 10_000 end,
      then: [level: :full, include_call_stack: true]
    )
    assert is_reference(trace_ref)
  end
end

describe "production safety" do
  test "sets global limits and safety controls" do
    assert :ok = ElixirScope.Runtime.set_limits(
      max_events_per_second: 100_000,
      max_memory: {500, :megabytes},
      auto_stop_on: [{:cpu_usage, ">", 80}]
    )
  end
  
  test "emergency stop functionality" do
    # Start some traces
    {:ok, _ref1} = ElixirScope.Runtime.trace(Module1)
    {:ok, _ref2} = ElixirScope.Runtime.trace(Module2)
    
    # Emergency stop
    {:ok, stopped_count} = ElixirScope.Runtime.emergency_stop()
    assert stopped_count == 2
    assert ElixirScope.Runtime.list_traces() == []
  end
end
```

##### ✅ **Task T1.2: Controller Testing**
- **File**: `test/elixir_scope/runtime/controller_test.exs`
- **Coverage**:
  - [ ] GenServer lifecycle (start, stop, restart)
  - [ ] Runtime plan application from AI.Orchestrator
  - [ ] Tracer and StateMonitor coordination
  - [ ] Global tracing state management
  - [ ] Plan updates and dynamic reconfiguration
  - [ ] Error recovery and fault tolerance
  - [ ] Resource limit enforcement

```elixir
describe "plan application" do
  test "applies runtime plan correctly" do
    plan = %RuntimePlan{
      module_traces: %{TestModule => %{functions: %{{:test_func, 1} => %{trace_level: :detailed}}}}
    }
    
    assert :ok = Controller.activate_tracing(plan, [])
    
    # Verify tracers were started
    state = Controller.get_state()
    assert map_size(state.active_traces) > 0
  end
end
```

##### ✅ **Task T1.3: TracerManager Testing**
- **File**: `test/elixir_scope/runtime/tracer_manager_test.exs`
- **Coverage**:
  - [ ] Tracer process lifecycle management
  - [ ] Load distribution across multiple tracers
  - [ ] Tracer failure detection and restart
  - [ ] Plan-based tracer configuration
  - [ ] Resource usage monitoring
  - [ ] Graceful shutdown procedures

##### ✅ **Task T1.4: Individual Tracer Testing**
- **File**: `test/elixir_scope/runtime/tracer_test.exs`
- **Coverage**:
  - [ ] BEAM trace setup using `:dbg.tp/2`, `:dbg.p/2`
  - [ ] Trace message reception and processing
  - [ ] Event conversion from trace messages to `ElixirScope.Events`
  - [ ] Correlation ID management per PID
  - [ ] Call stack tracking for nested calls
  - [ ] Match specification handling
  - [ ] Trace cleanup on termination

```elixir
describe "trace message processing" do
  test "converts :call trace to FunctionEntry event" do
    tracer = start_supervised!({Tracer, ["test-ref", TestModule, [], buffer]})
    
    # Simulate BEAM trace message
    trace_msg = {:trace_ts, self(), :call, {TestModule, :test_func, [:arg1]}, timestamp}
    GenServer.cast(tracer, {:trace_message, trace_msg})
    
    # Verify event was generated
    assert_receive {:event_generated, %Events.FunctionEntry{}}
  end
end
```

##### ✅ **Task T1.5: StateMonitor Testing**
- **File**: `test/elixir_scope/runtime/state_monitor_test.exs`
- **Coverage**:
  - [ ] `:sys.install/3` integration with GenServer processes
  - [ ] Debug handler function implementation
  - [ ] State change detection and event generation
  - [ ] State snapshot capture
  - [ ] Monitor cleanup and resource management
  - [ ] Error handling for non-OTP processes

```elixir
describe "GenServer state monitoring" do
  test "captures state changes via :sys.install" do
    {:ok, genserver} = TestGenServer.start_link(%{counter: 0})
    {:ok, monitor} = StateMonitor.start_link(genserver, [], buffer)
    
    # Trigger state change
    GenServer.call(genserver, :increment)
    
    # Verify state change event was captured
    assert_receive {:event_generated, %Events.StateChange{}}
  end
end
```

#### Phase 2: AI Layer Testing (Runtime Plans)

##### ✅ **Task T2.1: Enhanced Orchestrator Testing**
- **File**: `test/elixir_scope/ai/orchestrator_test.exs` (new)
- **Coverage**:
  - [ ] Runtime plan generation from code analysis
  - [ ] Plan storage and retrieval via DataAccess
  - [ ] Plan update mechanisms
  - [ ] Integration with existing CodeAnalyzer
  - [ ] Performance impact estimation for runtime plans
  - [ ] Plan validation and optimization

```elixir
describe "runtime plan generation" do
  test "generates appropriate runtime plan for GenServer module" do
    genserver_code = """
    defmodule TestGenServer do
      use GenServer
      def handle_call(:get_state, _from, state), do: {:reply, state, state}
    end
    """
    
    {:ok, plan} = Orchestrator.analyze_and_plan_runtime(genserver_code)
    
    assert %RuntimePlan{} = plan
    assert Map.has_key?(plan.module_traces, TestGenServer)
    assert plan.module_traces[TestGenServer].otp_monitoring == :state_changes
  end
end
```

##### ✅ **Task T2.2: Runtime Plan Schema Testing**
- **File**: `test/elixir_scope/ai/runtime_plan_test.exs` (new)
- **Coverage**:
  - [ ] Plan structure validation
  - [ ] Serialization/deserialization
  - [ ] Plan merging and updates
  - [ ] Performance impact calculation
  - [ ] Plan optimization algorithms

#### Phase 3: Capture Layer Testing (Enhanced Components)

##### ✅ **Task T3.1: Enhanced Ingestor Testing**
- **File**: `test/elixir_scope/capture/ingestor_test.exs` (enhanced)
- **Coverage**:
  - [ ] Existing functionality preservation (all current tests pass)
  - [ ] New `ingest_generic_event/7` function
  - [ ] Runtime trace timestamp handling
  - [ ] Multiple event source coordination
  - [ ] Trace-specific correlation ID patterns

```elixir
describe "ingest_generic_event/7" do
  test "ingests tracer-generated events correctly" do
    assert :ok = Ingestor.ingest_generic_event(
      buffer, :function_entry, 
      %{module: TestModule, function: :test_func, args: [:arg1]},
      self(), "trace-corr-123", timestamp, wall_time
    )
    
    {:ok, event, _} = RingBuffer.read(buffer, 0)
    assert event.correlation_id == "trace-corr-123"
    assert event.timestamp == timestamp
  end
end
```

##### ✅ **Task T3.2: Enhanced EventCorrelator Testing**
- **File**: `test/elixir_scope/capture/event_correlator_test.exs` (enhanced)
- **Coverage**:
  - [ ] Existing correlation logic preservation
  - [ ] Runtime trace correlation patterns
  - [ ] Mixed source correlation (traces + Telemetry)
  - [ ] Call stack reconstruction from trace messages
  - [ ] Cross-process correlation via message tracing

##### ✅ **Task T3.3: Simplified InstrumentationRuntime Testing**
- **File**: `test/elixir_scope/capture/instrumentation_runtime_test.exs` (new, simplified)
- **Coverage**:
  - [ ] Simplified event formatting and forwarding
  - [ ] Framework-specific reporting functions
  - [ ] Integration with Telemetry handlers
  - [ ] Graceful degradation when tracing disabled

#### Phase 4: Integration Testing (Framework Updates)

##### ✅ **Task T4.1: Enhanced Phoenix Integration Testing**
- **File**: `test/elixir_scope/phoenix/integration_test.exs` (enhanced)
- **Coverage**:
  - [ ] Telemetry handler updates for runtime tracing
  - [ ] Runtime API integration for trace control
  - [ ] Correlation ID propagation from runtime tracers
  - [ ] Phoenix-specific semantic event reporting
  - [ ] LiveView and Channel integration with runtime tracing

```elixir
describe "runtime tracing integration" do
  test "Phoenix requests trigger appropriate runtime traces" do
    # Enable runtime tracing for Phoenix controllers
    {:ok, _ref} = ElixirScope.Runtime.trace(MyApp.UserController)
    
    # Simulate Phoenix request
    conn = build_conn(:get, "/users/123")
    
    # Verify both Telemetry events and runtime traces are captured
    assert_receive {:telemetry_event, [:phoenix, :endpoint, :start]}
    assert_receive {:runtime_trace, %Events.FunctionEntry{module: MyApp.UserController}}
  end
end
```

##### ✅ **Task T4.2: Main API Testing**
- **File**: `test/elixir_scope_test.exs` (enhanced)
- **Coverage**:
  - [ ] Updated `start/1` with runtime tracing initialization
  - [ ] Runtime tracing parameter support
  - [ ] `analyze_codebase/1` generating runtime plans
  - [ ] `update_instrumentation/1` updating runtime plans
  - [ ] Backward compatibility for existing API usage

#### Phase 5: Migration and Compatibility Testing

##### ✅ **Task T5.1: Backward Compatibility Testing**
- **File**: `test/elixir_scope/migration/compatibility_test.exs` (new)
- **Coverage**:
  - [ ] Existing API calls continue to work
  - [ ] Configuration migration from AST to runtime
  - [ ] Graceful handling of deprecated options
  - [ ] Warning messages for deprecated usage
  - [ ] Data format compatibility

##### ✅ **Task T5.2: Migration Path Testing**
- **File**: `test/elixir_scope/migration/migration_test.exs` (new)
- **Coverage**:
  - [ ] Step-by-step migration procedures
  - [ ] Configuration conversion utilities
  - [ ] Data migration tools
  - [ ] Rollback procedures
  - [ ] Migration validation

#### Phase 6: Advanced Features Testing

##### ✅ **Task T6.1: Time-Travel Engine Testing**
- **File**: `test/elixir_scope/time_travel/replay_engine_test.exs` (new)
- **Coverage**:
  - [ ] State snapshot management
  - [ ] Event replay for state reconstruction
  - [ ] `replay_to/2` functionality
  - [ ] Historical state accuracy
  - [ ] Performance under large event volumes

##### ✅ **Task T6.2: Interactive Debugging Testing**
- **File**: `test/elixir_scope/runtime/interactive_test.exs` (new)
- **Coverage**:
  - [ ] Runtime breakpoint setting
  - [ ] Time-travel stepping
  - [ ] REPL integration
  - [ ] State inspection at arbitrary points

##### ✅ **Task T6.3: Tool Integration Testing**
- **Files**: 
  - `test/elixir_scope/integrations/observer_test.exs` (new)
  - `test/elixir_scope/integrations/recon_test.exs` (new)
- **Coverage**:
  - [ ] Observer backend integration
  - [ ] Recon trace pipeline integration
  - [ ] Data format compatibility
  - [ ] Performance impact assessment

### Performance and Load Testing

##### ✅ **Task TP.1: Runtime Tracing Performance Testing**
- **File**: `test/performance/runtime_tracing_test.exs` (new)
- **Coverage**:
  - [ ] Trace message processing overhead
  - [ ] Memory usage under high trace volumes
  - [ ] Tracer process scalability
  - [ ] Comparison with AST approach
  - [ ] Production-realistic load scenarios

##### ✅ **Task TP.2: Integration Performance Testing**
- **File**: `test/performance/integration_performance_test.exs` (new)
- **Coverage**:
  - [ ] End-to-end tracing performance
  - [ ] Phoenix application under load
  - [ ] Concurrent debugging sessions
  - [ ] Resource usage monitoring
  - [ ] Graceful degradation testing

### Test Infrastructure Enhancements

##### ✅ **Task TI.1: Enhanced Test Helpers**
- **File**: `test/support/runtime_test_helpers.ex` (new)
- **Functions**:
  - [ ] `setup_runtime_tracing/1` - Configure test environment
  - [ ] `create_test_tracer/2` - Spawn test tracer processes
  - [ ] `simulate_trace_messages/2` - Generate test trace messages
  - [ ] `assert_trace_events/2` - Verify trace event generation
  - [ ] `cleanup_runtime_state/0` - Clean test state

##### ✅ **Task TI.2: Mock BEAM Tracing**
- **File**: `test/support/mock_beam_tracer.ex` (new)
- **Purpose**: Mock `:dbg` and `:erlang.trace` for deterministic testing
- **Features**:
  - [ ] Controllable trace message generation
  - [ ] Deterministic timing
  - [ ] Error condition simulation
  - [ ] Resource usage tracking

##### ✅ **Task TI.3: Test GenServer and OTP Processes**
- **File**: `test/support/test_otp_processes.ex` (new)
- **Purpose**: Standardized test processes for state monitoring
- **Components**:
  - [ ] `TestGenServer` with predictable state changes
  - [ ] `TestSupervisor` with child management
  - [ ] `TestAgent` for simple state testing
  - [ ] Process lifecycle helpers

### Continuous Integration Enhancements

##### ✅ **Task CI.1: Test Organization**
- **Structure**:
  ```
  test/
  ├── elixir_scope/
  │   ├── runtime/           # New runtime components
  │   ├── ai/               # Enhanced AI testing
  │   ├── capture/          # Enhanced capture testing
  │   ├── migration/        # Migration testing
  │   └── time_travel/      # Advanced features
  ├── integration/          # Enhanced integration tests
  ├── performance/          # Performance testing
  └── support/              # Enhanced test utilities
  ```

##### ✅ **Task CI.2: Test Categories and Tags**
- **Tags**:
  - `:unit` - Fast unit tests (< 100ms each)
  - `:integration` - Integration tests (< 5s each)
  - `:performance` - Performance tests (may be slow)
  - `:migration` - Migration and compatibility tests
  - `:runtime_tracing` - Runtime tracing specific tests
  - `:beam_integration` - Tests requiring BEAM tracing

##### ✅ **Task CI.3: Test Execution Strategy**
- **Fast Feedback Loop**: Unit tests run on every commit
- **Integration Testing**: Run on PR creation/update
- **Performance Testing**: Run nightly and on release branches
- **Migration Testing**: Run on version changes

### Success Metrics for Testing

#### Coverage Targets
- [ ] **Unit Test Coverage**: ≥ 95% for new runtime components
- [ ] **Integration Test Coverage**: ≥ 90% for framework integrations
- [ ] **Performance Test Coverage**: All critical paths benchmarked
- [ ] **Migration Test Coverage**: 100% of migration scenarios tested

#### Quality Gates
- [ ] **Zero Test Failures**: All tests must pass before merge
- [ ] **Performance Regression**: < 5% overhead increase
- [ ] **Memory Usage**: No memory leaks in long-running tests
- [ ] **Backward Compatibility**: All existing APIs continue to work

#### Test Execution Metrics
- [ ] **Fast Test Suite**: Unit tests complete in < 30 seconds
- [ ] **Full Test Suite**: All tests complete in < 10 minutes
- [ ] **Performance Tests**: Complete in < 30 minutes
- [ ] **Flaky Test Rate**: < 1% test flakiness

### Risk Mitigation Through Testing

1. **BEAM Integration Risks**: Comprehensive mock and real BEAM tracing tests
2. **Performance Risks**: Continuous benchmarking and regression detection
3. **Migration Risks**: Extensive compatibility and migration testing
4. **Production Risks**: Load testing and failure scenario simulation
5. **Data Integrity Risks**: Event correlation and accuracy validation

## Conclusion

This revamp represents a fundamental architectural shift that aligns ElixirScope with BEAM's strengths while preserving its unique value propositions. The runtime tracing approach provides greater flexibility, better production readiness, and stronger integration with the Erlang/Elixir ecosystem, while the AI-guided analysis and high-performance backend continue to differentiate ElixirScope from existing tools.

The phased approach ensures manageable development cycles with clear milestones and validation points, reducing risk while maintaining momentum toward the "Execution Cinema" vision. The comprehensive testing strategy ensures that this major architectural change maintains the project's high quality standards while enabling the new runtime tracing capabilities. 