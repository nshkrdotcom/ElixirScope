# ElixirScope AST + Runtime Merge Analysis

## 🎯 **MISSION: Seamless Integration of Compile-Time AST + Runtime Tracing**

**Status**: 🔍 **ANALYSIS PHASE** - Mapping unified architecture for both approaches

---

## 📊 **Current State Analysis**

### ✅ **Runtime Approach (Current - Post df3b905a)**
- **8 Core Runtime Modules**: All implemented and tested (28/28 tests passing)
- **BEAM Primitives**: Uses `:dbg`, `:erlang.trace`, `:sys` for runtime tracing
- **Dynamic Control**: Start/stop tracing without recompilation
- **Production Safety**: Circuit breakers, resource monitoring, graceful degradation
- **Environment Compatibility**: Works in minimal OTP environments

### 🔍 **Compile-Time AST Approach (Pre df3b905a)**
- **AST Transformer**: `ElixirScope.AST.Transformer` - Core AST transformation engine
- **Injector Helpers**: `ElixirScope.AST.InjectorHelpers` - Instrumentation call generation
- **Mix Compiler**: `Mix.Tasks.Compile.ElixirScope` - Compilation integration
- **Granular Instrumentation**: Line-by-line, expression-level debugging capability
- **Static Analysis**: Compile-time optimization and planning

---

## 🔬 **Key Differences & Complementary Strengths**

### **Runtime Tracing Strengths**
1. **Dynamic Control**: Enable/disable without recompilation
2. **Production Safe**: Built-in limits and circuit breakers  
3. **BEAM Native**: Leverages existing debugging infrastructure
4. **Minimal Overhead**: Only active when tracing is enabled
5. **Environment Agnostic**: Works in containers, production, etc.

### **Compile-Time AST Strengths**
1. **Granular Control**: Line-by-line, expression-level instrumentation
2. **Custom Logic**: Inject arbitrary debugging code at any AST node
3. **Static Analysis**: Compile-time optimization and dead code elimination
4. **Deep Integration**: Access to local variables, intermediate values
5. **Conditional Compilation**: Different instrumentation for dev/test/prod

### **Limitations Confirmed**

#### **Runtime Tracing Limitations** ✅ CONFIRMED
- **Function-Level Only**: Cannot trace individual expressions within functions
- **Limited Variable Access**: Cannot access local variables mid-function
- **No Conditional Logic**: Cannot inject custom debugging logic
- **BEAM Constraints**: Limited by what `:dbg` and `:erlang.trace` support

#### **Compile-Time AST Limitations**
- **Static Only**: Cannot enable/disable at runtime
- **Recompilation Required**: Changes require full rebuild
- **Development Overhead**: Instrumented code in production builds
- **Complexity**: AST manipulation is error-prone

---

## 🏗️ **Unified Architecture Design**

### **Phase 1: Dual-Mode Foundation**

```elixir
defmodule ElixirScope.Unified do
  @moduledoc """
  Unified interface supporting both runtime and compile-time tracing.
  """
  
  @doc """
  Start tracing with automatic mode selection.
  """
  def trace(target, opts \\ []) do
    mode = determine_optimal_mode(target, opts)
    
    case mode do
      :runtime -> ElixirScope.Runtime.trace(target, opts)
      :compile_time -> ElixirScope.CompileTime.trace(target, opts)
      :hybrid -> start_hybrid_trace(target, opts)
    end
  end
  
  defp determine_optimal_mode(target, opts) do
    cond do
      # Force runtime mode
      opts[:force_runtime] -> :runtime
      
      # Force compile-time mode  
      opts[:force_compile_time] -> :compile_time
      
      # Granular debugging requested - needs compile-time
      opts[:granular] or opts[:line_level] or opts[:expression_level] ->
        if compile_time_available?(target) do
          :compile_time
        else
          {:error, :granular_requires_compile_time}
        end
      
      # Production environment - prefer runtime
      Mix.env() == :prod -> :runtime
      
      # Development with granular needs - hybrid
      opts[:detailed] -> :hybrid
      
      # Default to runtime for simplicity
      true -> :runtime
    end
  end
end
```

### **Phase 2: Enhanced AST System with "Cinema Data" Capabilities**

```elixir
defmodule ElixirScope.AST.EnhancedTransformer do
  @moduledoc """
  Enhanced AST transformer with runtime integration and granular instrumentation.
  
  Provides "Cinema Data" - rich, detailed execution traces including:
  - Local variable capture at specific lines
  - Expression-level value tracking  
  - Custom debugging logic injection
  - Runtime system coordination
  """
  
  def transform_with_runtime_bridge(ast, plan) do
    # Transform AST with enhanced capabilities
    transformed = transform_with_granular_instrumentation(ast, plan)
    
    # Inject runtime coordination calls
    inject_runtime_coordination(transformed, plan)
  end
  
  defp transform_with_granular_instrumentation(ast, plan) do
    ast
    |> inject_local_variable_capture(plan)
    |> inject_expression_tracing(plan)
    |> inject_custom_debugging_logic(plan)
    |> ElixirScope.AST.Transformer.transform_module(plan)
  end
  
  defp inject_local_variable_capture(ast, %{capture_locals: locals, after_line: line}) do
    # Inject variable capture after specific line
    quote do
      unquote(ast)
      # Capture specified local variables
      ElixirScope.Capture.InstrumentationRuntime.report_local_variable_snapshot(
        unquote(get_call_id()),
        %{unquote_splicing(build_variable_map(locals))},
        unquote(line),
        :ast
      )
    end
  end
  
  defp inject_expression_tracing(ast, %{trace_expressions: expressions}) do
    # Wrap specified expressions with value capture
    Macro.prewalk(ast, fn
      {expr_name, meta, args} = node when expr_name in expressions ->
        quote do
          __es_expr_val = unquote(node)
          ElixirScope.Capture.InstrumentationRuntime.report_expression_value(
            unquote(get_call_id()),
            unquote(Macro.to_string(node)),
            __es_expr_val,
            unquote(meta[:line] || 0),
            :ast
          )
          __es_expr_val
        end
      
      node -> node
    end)
  end
  
  defp inject_runtime_coordination(ast, plan) do
    # Add calls to register compile-time instrumented functions
    # with the runtime system for unified control
    quote do
      # Register this module with runtime system for hybrid coordination
      ElixirScope.Runtime.register_instrumented_module(__MODULE__, unquote(plan))
      
      # Check runtime flags before executing AST instrumentation
      if ElixirScope.Runtime.ast_tracing_enabled?(__MODULE__) do
        unquote(ast)
      else
        # AST instrumentation disabled at runtime - execute original code
        unquote(strip_instrumentation(ast))
      end
    end
  end
end
```

### **Phase 3: Hybrid Tracing Engine**

```elixir
defmodule ElixirScope.Hybrid.TracingEngine do
  @moduledoc """
  Coordinates between compile-time and runtime tracing.
  """
  
  defstruct [
    :session_id,
    :runtime_tracers,
    :compile_time_modules,
    :unified_buffer,
    :correlation_map
  ]
  
  def start_hybrid_session(targets, opts) do
    session = %__MODULE__{
      session_id: make_ref(),
      runtime_tracers: %{},
      compile_time_modules: MapSet.new(),
      unified_buffer: create_unified_buffer(opts),
      correlation_map: %{}
    }
    
    # Start runtime tracing for dynamic targets
    runtime_targets = filter_runtime_targets(targets)
    runtime_tracers = start_runtime_tracers(runtime_targets, session)
    
    # Activate compile-time instrumentation
    compile_time_targets = filter_compile_time_targets(targets)
    activate_compile_time_instrumentation(compile_time_targets, session)
    
    %{session | 
      runtime_tracers: runtime_tracers,
      compile_time_modules: MapSet.new(compile_time_targets)
    }
  end
  
  def correlate_events(session, runtime_event, compile_time_event) do
    # Correlate events from both systems using timestamps,
    # process IDs, and function signatures
    correlation_id = generate_correlation_id(runtime_event, compile_time_event)
    
    unified_event = %ElixirScope.Events.UnifiedEvent{
      correlation_id: correlation_id,
      runtime_data: runtime_event,
      compile_time_data: compile_time_event,
      timestamp: min(runtime_event.timestamp, compile_time_event.timestamp)
    }
    
    ElixirScope.Capture.Ingestor.ingest_unified_event(session.unified_buffer, unified_event)
  end
end
```

---

## 🔧 **Enhanced Implementation Plan**

### **Step 1: Restore & Modernize AST Infrastructure (Foundation)**
- [ ] **Task 1.1**: Restore core AST modules from pre-df3b905a
  - [ ] Restore `ElixirScope.AST.Transformer` with current API compatibility
  - [ ] Restore `ElixirScope.AST.InjectorHelpers` with runtime integration hooks
  - [ ] Restore `Mix.Tasks.Compile.ElixirScope` with on-demand compilation support
- [ ] **Task 1.2**: Modernize AST components for unified system
  - [ ] Update `AST.Transformer` to inject calls with source tagging (`:ast`)
  - [ ] Implement local variable capture in `AST.InjectorHelpers`
  - [ ] Add expression-level tracing capabilities
  - [ ] Make `MixTask` triggerable on-demand rather than always running
- [ ] **Task 1.3**: Create `ElixirScope.CompileTime.Orchestrator`
  - [ ] Generate AST instrumentation plans from user requests
  - [ ] Integrate with `AI.CodeAnalyzer` for context understanding
  - [ ] Support granular plans (locals, expressions, lines)
- [ ] **Task 1.4**: Update AST system integration
  - [ ] Ensure all AST events flow through `ElixirScope.Capture.Ingestor`
  - [ ] Add event source tagging (`:runtime` vs `:ast`)
  - [ ] Implement shared correlation IDs between systems

### **Step 2: Implement Unified API & Mode Selection**
- [ ] **Task 2.1**: Create `ElixirScope.Unified` module
  - [ ] Implement `trace/2` function with intelligent mode selection
  - [ ] Add `determine_optimal_mode/2` with AI integration
  - [ ] Support explicit mode forcing via options
- [ ] **Task 2.2**: Implement mode selection logic
  - [ ] Environment-based selection (dev vs prod)
  - [ ] Capability-based selection (granular needs)
  - [ ] Availability-based fallbacks
  - [ ] AI-driven recommendations
- [ ] **Task 2.3**: Create delegation system
  - [ ] Delegate to `ElixirScope.Runtime.trace/2` for runtime mode
  - [ ] Implement `ElixirScope.CompileTime.trace/2` for AST mode
  - [ ] Handle hybrid mode coordination

### **Step 3: Implement Hybrid Tracing Engine**
- [ ] **Task 3.1**: Design `ElixirScope.Hybrid.TracingEngine`
  - [ ] Create GenServer for session management
  - [ ] Implement `start_hybrid_session/2` function
  - [ ] Coordinate runtime and compile-time tracing activation
  - [ ] Generate unified session IDs
- [ ] **Task 3.2**: Enhance event correlation
  - [ ] Modify `Capture.Ingestor` for dual-source events
  - [ ] Implement session-based event grouping
  - [ ] Add timestamp synchronization between sources
  - [ ] Create call ID linking for same function calls
- [ ] **Task 3.3**: Implement event correlation logic
  - [ ] Match runtime and AST events for same calls
  - [ ] Handle timing windows for correlation
  - [ ] Link local variable events to function calls
  - [ ] Support partial correlation (one source missing)

### **Step 4: Enhanced Configuration & Data Model**
- [ ] **Task 4.1**: Implement unified configuration system
  - [ ] Add `:unified_tracing` config section
  - [ ] Support mode-specific configurations
  - [ ] Implement auto-mode thresholds
  - [ ] Add feature flags for AST capabilities
- [ ] **Task 4.2**: Enhance data model for unified events
  - [ ] Add `trace_source` field to events
  - [ ] Create `LocalVariableChange` event type
  - [ ] Implement `trace_session_id` for grouping
  - [ ] Add enhanced correlation metadata
- [ ] **Task 4.3**: Create AST plan storage system
  - [ ] File-based plan storage in `_build`
  - [ ] Plan invalidation on source changes
  - [ ] Runtime override mechanisms

### **Step 5: Advanced AST Capabilities**
- [ ] **Task 5.1**: Implement targeted local variable capture
  - [ ] Support specific variable selection
  - [ ] Add line-based capture triggers
  - [ ] Implement variable diff computation
- [ ] **Task 5.2**: Add expression tracing capabilities
  - [ ] Wrap expressions with value capture
  - [ ] Support before/after expression evaluation
  - [ ] Add conditional expression tracing
- [ ] **Task 5.3**: Implement conditional compilation
  - [ ] Environment-specific instrumentation
  - [ ] Compile-time flag support
  - [ ] Runtime enable/disable of AST code

### **Step 6: Developer Experience & IEx Integration**
- [ ] **Task 6.1**: Create seamless mode transition
  - [ ] Implement `ElixirScope.inspect_deeply/1` IEx helper
  - [ ] Add user prompts for recompilation
  - [ ] Support targeted module recompilation
- [ ] **Task 6.2**: Enhance IEx helpers for unified data
  - [ ] Update `IExHelpers.history/2` for interleaved events
  - [ ] Add source tagging in output
  - [ ] Support filtering by trace source
- [ ] **Task 6.3**: Implement runtime control of AST instrumentation
  - [ ] Shared flags for enabling/disabling AST code
  - [ ] ETS or persistent_term based coordination
  - [ ] Graceful degradation when AST unavailable

### **Step 7: AI Integration & Intelligence**
- [ ] **Task 7.1**: Enhance AI-driven mode selection
  - [ ] Integrate with `AI.CodeAnalyzer` for complexity assessment
  - [ ] Add historical performance data consideration
  - [ ] Implement automatic mode switching suggestions
- [ ] **Task 7.2**: Implement intelligent instrumentation planning
  - [ ] Generate runtime plans for `Runtime.Controller`
  - [ ] Create fine-grained AST plans for `CompileTime.Orchestrator`
  - [ ] Support hybrid plans with mixed approaches
- [ ] **Task 7.3**: Add adaptive tracing capabilities
  - [ ] Monitor trace effectiveness
  - [ ] Suggest mode switches based on data quality
  - [ ] Auto-escalate to deeper tracing when needed

---

## 🎯 **Use Cases for Each Mode**

### **Runtime Mode - Best For:**
- Production debugging
- Dynamic service monitoring  
- Performance profiling
- Process lifecycle tracking
- Message flow analysis
- Quick debugging without recompilation

### **Compile-Time Mode - Best For:**
- Deep algorithm debugging with local variable inspection
- Variable state tracking and diff computation
- Expression-level analysis ("print debugging on steroids")
- Custom debugging logic injection at any AST node
- Static analysis integration and optimization
- Development-time detailed tracing with "Cinema Data"
- Line-by-line stepping through complex functions
- Conditional instrumentation based on compile-time flags

### **Hybrid Mode - Best For:**
- Comprehensive development debugging with multi-level detail
- Performance optimization workflows (runtime + granular analysis)
- Complex system analysis with correlated events
- Research and experimentation requiring full visibility
- Teaching and learning scenarios with progressive detail
- Full system understanding from high-level flows to variable changes
- "Cinema Data" visualization with interleaved runtime/AST events
- Progressive debugging: start runtime, escalate to AST as needed
- Cross-system correlation (e.g., runtime GenServer + AST callback internals)

---

## 📋 **Technical Considerations**

### **Event Correlation Strategy**
```elixir
defmodule ElixirScope.Events.Correlator do
  def correlate(runtime_event, compile_time_event) do
    # Match by:
    # 1. Process ID + timestamp window
    # 2. Function signature + call stack
    # 3. Correlation IDs injected by both systems
    # 4. Message sequence numbers
  end
end
```

### **Enhanced Unified Configuration**
```elixir
config :elixir_scope,
  # Unified tracing configuration
  unified_tracing: [
    default_mode_for_dev: :hybrid,     # :runtime, :compile_time, :hybrid, :auto
    default_mode_for_prod: :runtime,
    auto_mode_thresholds: %{
      # Switch to compile_time if AI determines high internal complexity
      complexity_for_compile_time: 15,
      # Switch to hybrid for detailed debugging requests
      detail_level_for_hybrid: 3
    },
    # Global feature flags
    enable_ast_local_variable_capture: true,
    enable_ast_expression_tracing: false,
    enable_on_demand_recompilation: true
  ],
  
  # Runtime configuration (existing)
  runtime_tracing: [
    safety_limits: [cpu: 80, memory: 1024],
    sampling_rate: 0.1,
    # New: coordination with AST system
    coordinate_with_ast: true,
    shared_session_management: true
  ],
  
  # Compile-time/AST configuration
  compile_time_tracing: [
    default_instrumentation_level: :function_boundaries,  # :expressions, :locals, :lines
    environments: [:dev, :test],
    custom_injections: [],
    # AST plan storage
    plan_storage_path: "_build/elixir_scope/ast_plans",
    plan_cache_ttl: 3600,  # seconds
    # On-demand compilation
    enable_targeted_recompilation: true,
    recompile_timeout: 30_000  # ms
  ],
  
  # Hybrid coordination configuration
  hybrid: [
    correlation_window: 100,           # ms for event correlation
    auto_switch_threshold: 1000,      # events/sec
    session_timeout: 300_000,         # ms (5 minutes)
    max_concurrent_sessions: 10,
    # Event correlation strategy
    correlation_strategy: :timestamp_and_call_id,
    # Unified data presentation
    interleave_events: true,
    show_source_tags: true
  ],
  
  # AI integration for mode selection
  ai_mode_selection: [
    enable_intelligent_selection: true,
    complexity_analysis_timeout: 5000,  # ms
    historical_data_weight: 0.3,
    user_preference_weight: 0.7
  ]
```

### **Performance Optimization**
- **Lazy Loading**: Only load AST system when needed
- **Conditional Compilation**: Different builds for different environments
- **Smart Buffering**: Unified buffer with mode-aware optimization
- **Resource Sharing**: Shared infrastructure between both systems

---

## 🚀 **Expected Benefits**

### **For Developers**
1. **Best of Both Worlds**: Runtime flexibility + compile-time granularity
2. **Seamless Experience**: Single API for all tracing needs
3. **Intelligent Defaults**: Automatic mode selection
4. **Progressive Enhancement**: Start simple, add detail as needed

### **For Production**
1. **Safe Runtime Debugging**: No recompilation required
2. **Granular Development**: Deep debugging when developing
3. **Unified Tooling**: Single set of tools for all scenarios
4. **Performance Optimized**: Each mode optimized for its use case

### **For the Ecosystem**
1. **Comprehensive Solution**: Covers all debugging scenarios
2. **BEAM Integration**: Leverages existing infrastructure
3. **Extensible Architecture**: Easy to add new capabilities
4. **Educational Value**: Great for learning Elixir/BEAM internals

---

## 📈 **Success Metrics**

### **Technical Metrics**
- [ ] All existing runtime tests continue passing (28/28)
- [ ] All existing compile-time tests restored and passing
- [ ] Unified API tests covering all modes
- [ ] Performance benchmarks for each mode
- [ ] Memory usage optimization verified

### **Usability Metrics**
- [ ] Single API covers 95% of debugging use cases
- [ ] Mode switching works seamlessly
- [ ] Documentation covers all scenarios
- [ ] Examples demonstrate each mode's strengths

---

## 🔄 **Next Actions**

1. **Immediate**: Start with Step 1 - restore AST infrastructure
2. **Priority**: Ensure backward compatibility with current runtime system
3. **Focus**: Maintain all existing test coverage while adding new capabilities
4. **Goal**: Seamless integration that enhances rather than replaces current functionality

---

## 🧪 **Comprehensive Testing Strategy**

### **Current Test Infrastructure Analysis**

#### **✅ Existing Test Coverage (33 test files)**
- **Runtime Tests**: 4 files (28 tests passing)
  - `compilation_integration_test.exs` - Module compilation verification
  - `environment_compatibility_test.exs` - OTP environment handling
  - `warning_detection_test.exs` - Compilation warning detection
  - `warning_validation_test.exs` - Warning validation logic

- **AST Tests**: 1 file (Legacy from pre-df3b905a)
  - `transformer_test.exs` - AST transformation verification

- **Core Infrastructure**: 8 files
  - `capture/` - Ring buffer, ingestor, async writer, correlator
  - `storage/` - Data access and persistence
  - `events_test.exs` - Event creation and serialization
  - `config_test.exs` - Configuration management

- **Integration Tests**: 3 files
  - `phoenix/integration_test.exs` - Phoenix framework integration
  - `integration/production_phoenix_test.exs` - Production scenarios
  - `compiler/mix_task_test.exs` - Compile-time integration

- **AI & Analysis**: 8 files
  - LLM provider tests, code analysis, predictive execution

- **Distributed & Performance**: 6 files
  - Multi-node testing, performance benchmarks

#### **🔍 Test Coverage Gaps for Unified System**
1. **No unified mode testing** - Runtime + AST integration
2. **No hybrid tracing tests** - Event correlation between systems
3. **No mode switching tests** - Dynamic switching between approaches
4. **No performance comparison tests** - Runtime vs AST vs Hybrid
5. **No backward compatibility tests** - Ensuring existing APIs work

---

### **🎯 Testing Strategy for Unified AST + Runtime System**

#### **Phase 1: Foundation Testing**

```elixir
# test/elixir_scope/unified/
├── mode_selection_test.exs           # Automatic mode detection
├── api_compatibility_test.exs        # Backward compatibility
├── configuration_test.exs            # Unified configuration
└── fallback_mechanism_test.exs       # Mode fallback handling
```

**Key Test Cases:**
- **Mode Selection Logic**: Verify automatic mode selection based on environment, options, and target
- **API Compatibility**: Ensure all existing `ElixirScope.Runtime` APIs continue working
- **Configuration Merging**: Test unified config handling for both systems
- **Graceful Degradation**: Test fallbacks when preferred mode unavailable

#### **Phase 2: Enhanced AST Testing**

```elixir
# test/elixir_scope/ast/
├── enhanced_transformer_test.exs     # Enhanced AST transformation
├── runtime_bridge_test.exs           # AST-Runtime integration
├── granular_instrumentation_test.exs # Expression-level tracing
├── conditional_compilation_test.exs  # Environment-specific builds
└── variable_capture_test.exs         # Local variable access
```

**Key Test Cases:**
- **Expression-Level Instrumentation**: Verify line-by-line debugging capability
- **Variable Capture**: Test access to local variables mid-function
- **Custom Logic Injection**: Verify arbitrary debugging code injection
- **Runtime Registration**: Test AST modules registering with runtime system
- **Conditional Compilation**: Different instrumentation for dev/test/prod

#### **Phase 3: Hybrid System Testing**

```elixir
# test/elixir_scope/hybrid/
├── tracing_engine_test.exs           # Hybrid coordination
├── event_correlation_test.exs        # Cross-system event matching
├── unified_buffer_test.exs           # Combined event storage
├── mode_switching_test.exs           # Dynamic mode changes
└── performance_comparison_test.exs   # Runtime vs AST vs Hybrid
```

**Key Test Cases:**
- **Event Correlation**: Match events from runtime and AST systems
- **Unified Buffer**: Single storage for both event types
- **Mode Switching**: Hot-swap between modes during execution
- **Performance Benchmarks**: Compare overhead of each mode
- **Session Management**: Multi-target hybrid sessions

#### **Phase 4: Integration Testing**

```elixir
# test/elixir_scope/integration/
├── unified_phoenix_test.exs          # Phoenix with all modes
├── unified_genserver_test.exs        # GenServer with all modes
├── production_scenarios_test.exs     # Real-world usage patterns
├── stress_testing_test.exs           # High-load scenarios
└── end_to_end_workflows_test.exs     # Complete debugging workflows
```

**Key Test Cases:**
- **Phoenix Integration**: All modes working with Phoenix controllers/LiveView
- **GenServer Integration**: State monitoring across all modes
- **Production Scenarios**: Real application debugging workflows
- **Stress Testing**: High-frequency events, memory usage, performance
- **End-to-End**: Complete debugging sessions using multiple modes

#### **Phase 5: Specialized Testing**

```elixir
# test/elixir_scope/specialized/
├── compile_time_optimization_test.exs # AST optimizations
├── runtime_safety_test.exs           # Production safety features
├── visualization_test.exs            # Unified data visualization
├── time_travel_test.exs              # Time-travel debugging
└── educational_scenarios_test.exs    # Learning/teaching use cases
```

---

### **🔧 Test Implementation Plan**

#### **Step 1: Restore & Enhance AST Tests**
```elixir
# test/elixir_scope/ast/enhanced_transformer_test.exs
defmodule ElixirScope.AST.EnhancedTransformerTest do
  use ExUnit.Case
  
  describe "expression-level instrumentation" do
    test "instruments individual expressions within function" do
      input_ast = quote do
        def complex_function(x, y) do
          temp1 = x + y           # <- Should be instrumentable
          temp2 = temp1 * 2       # <- Should be instrumentable  
          result = temp2 - 1      # <- Should be instrumentable
          result
        end
      end
      
      plan = %{
        granularity: :expression,
        capture_variables: [:temp1, :temp2, :result]
      }
      
      result = EnhancedTransformer.transform_with_runtime_bridge(input_ast, plan)
      
      # Verify each expression has instrumentation
      assert expression_instrumented?(result, :temp1_assignment)
      assert expression_instrumented?(result, :temp2_assignment)
      assert expression_instrumented?(result, :result_assignment)
      
      # Verify variable values are captured
      assert variable_capture_present?(result, :temp1)
      assert variable_capture_present?(result, :temp2)
      assert variable_capture_present?(result, :result)
    end
    
    test "injects custom debugging logic" do
      input_ast = quote do
        def algorithm(data) do
          Enum.map(data, &process_item/1)
        end
      end
      
      custom_logic = quote do
        IO.puts("Processing #{length(data)} items")
        ElixirScope.Debug.checkpoint(:algorithm_start, %{data_size: length(data)})
      end
      
      plan = %{
        custom_injections: [
          {1, :before, custom_logic}  # Inject at line 1, before execution
        ]
      }
      
      result = EnhancedTransformer.transform_with_runtime_bridge(input_ast, plan)
      
      assert custom_logic_injected?(result, custom_logic)
    end
  end
  
  describe "runtime integration" do
    test "registers instrumented modules with runtime system" do
      input_ast = quote do
        defmodule TestModule do
          def test_function do
            :ok
          end
        end
      end
      
      plan = %{module: TestModule, functions: [:test_function]}
      
      result = EnhancedTransformer.transform_with_runtime_bridge(input_ast, plan)
      
      # Verify registration call is injected
      assert runtime_registration_present?(result, TestModule)
      
      # Verify plan is passed to runtime system
      assert plan_passed_to_runtime?(result, plan)
    end
  end
end
```

#### **Step 2: Unified API Tests**
```elixir
# test/elixir_scope/unified/api_compatibility_test.exs
defmodule ElixirScope.Unified.APICompatibilityTest do
  use ExUnit.Case
  
  describe "backward compatibility" do
    test "existing Runtime.trace/2 calls work unchanged" do
      # Existing code should work without modification
      assert {:ok, _session} = ElixirScope.Runtime.trace(TestModule, [])
      
      # Should automatically select runtime mode
      assert ElixirScope.Runtime.list_traces() |> length() == 1
    end
    
    test "new unified API provides same functionality" do
      # New unified API should provide same results
      assert {:ok, _session} = ElixirScope.Unified.trace(TestModule, [])
      
      # Should work with existing runtime functions
      assert ElixirScope.Runtime.list_traces() |> length() == 1
    end
    
    test "mode selection respects environment" do
      # Production environment should prefer runtime
      with_env(:prod, fn ->
        {:ok, session} = ElixirScope.Unified.trace(TestModule, [])
        assert session.mode == :runtime
      end)
      
      # Development with granular request should use AST
      with_env(:dev, fn ->
        {:ok, session} = ElixirScope.Unified.trace(TestModule, [granular: true])
        assert session.mode == :compile_time
      end)
    end
  end
end
```

#### **Step 3: Hybrid System Tests**
```elixir
# test/elixir_scope/hybrid/event_correlation_test.exs
defmodule ElixirScope.Hybrid.EventCorrelationTest do
  use ExUnit.Case
  
  describe "cross-system event correlation" do
    test "correlates runtime and AST events for same function call" do
      # Start hybrid session
      {:ok, session} = ElixirScope.Hybrid.TracingEngine.start_hybrid_session(
        [TestModule], 
        [mode: :hybrid]
      )
      
      # Simulate function call that generates both runtime and AST events
      runtime_event = create_runtime_event(:function_entry, TestModule, :test_func)
      ast_event = create_ast_event(:variable_assignment, TestModule, :test_func, :local_var)
      
      # Correlate events
      {:ok, unified_event} = ElixirScope.Hybrid.TracingEngine.correlate_events(
        session, runtime_event, ast_event
      )
      
      # Verify correlation
      assert unified_event.correlation_id
      assert unified_event.runtime_data == runtime_event
      assert unified_event.compile_time_data == ast_event
      assert unified_event.timestamp <= max(runtime_event.timestamp, ast_event.timestamp)
    end
    
    test "handles event correlation with timing windows" do
      # Events within correlation window should be matched
      base_time = System.monotonic_time(:nanosecond)
      
      runtime_event = create_runtime_event_at(base_time)
      ast_event = create_ast_event_at(base_time + 50_000_000)  # 50ms later
      
      {:ok, session} = create_hybrid_session([correlation_window: 100])  # 100ms window
      
      # Should correlate within window
      assert {:ok, _unified} = ElixirScope.Hybrid.TracingEngine.correlate_events(
        session, runtime_event, ast_event
      )
      
      # Events outside window should not correlate
      late_ast_event = create_ast_event_at(base_time + 150_000_000)  # 150ms later
      
      assert {:error, :correlation_timeout} = ElixirScope.Hybrid.TracingEngine.correlate_events(
        session, runtime_event, late_ast_event
      )
    end
  end
end
```

#### **Step 4: Performance & Stress Tests**
```elixir
# test/elixir_scope/performance/mode_comparison_test.exs
defmodule ElixirScope.Performance.ModeComparisonTest do
  use ExUnit.Case
  
  @moduletag :performance
  
  describe "performance comparison across modes" do
    test "runtime mode has minimal overhead when inactive" do
      # Measure baseline performance
      baseline_time = measure_function_execution(TestModule, :cpu_intensive_function, [1000])
      
      # Start runtime tracing
      {:ok, _session} = ElixirScope.Runtime.trace(TestModule, [])
      
      # Measure with runtime tracing
      runtime_time = measure_function_execution(TestModule, :cpu_intensive_function, [1000])
      
      # Runtime overhead should be < 5%
      overhead_percent = ((runtime_time - baseline_time) / baseline_time) * 100
      assert overhead_percent < 5.0
    end
    
    test "AST mode overhead is acceptable for development" do
      # Compile module with AST instrumentation
      instrumented_module = compile_with_ast_instrumentation(TestModule)
      
      baseline_time = measure_function_execution(TestModule, :cpu_intensive_function, [1000])
      ast_time = measure_function_execution(instrumented_module, :cpu_intensive_function, [1000])
      
      # AST overhead should be < 20% for development use
      overhead_percent = ((ast_time - baseline_time) / baseline_time) * 100
      assert overhead_percent < 20.0
    end
    
    test "hybrid mode balances overhead and capability" do
      {:ok, session} = ElixirScope.Hybrid.TracingEngine.start_hybrid_session(
        [TestModule], [mode: :hybrid]
      )
      
      baseline_time = measure_function_execution(TestModule, :cpu_intensive_function, [1000])
      hybrid_time = measure_function_execution(TestModule, :cpu_intensive_function, [1000])
      
      # Hybrid overhead should be between runtime and AST
      overhead_percent = ((hybrid_time - baseline_time) / baseline_time) * 100
      assert overhead_percent > 5.0   # More than runtime
      assert overhead_percent < 20.0  # Less than full AST
    end
  end
  
  describe "memory usage patterns" do
    test "runtime mode memory usage is bounded" do
      initial_memory = :erlang.memory(:total)
      
      # Start many runtime traces
      sessions = for i <- 1..100 do
        {:ok, session} = ElixirScope.Runtime.trace(:"TestModule#{i}", [])
        session
      end
      
      peak_memory = :erlang.memory(:total)
      memory_increase = peak_memory - initial_memory
      
      # Memory increase should be reasonable (< 50MB for 100 traces)
      assert memory_increase < 50 * 1024 * 1024
      
      # Cleanup
      Enum.each(sessions, &ElixirScope.Runtime.stop_trace/1)
    end
  end
end
```

---

### **📊 Test Coverage Metrics**

#### **Target Coverage Goals**
- **Unit Tests**: 95% line coverage for all new unified components
- **Integration Tests**: 100% of API combinations tested
- **Performance Tests**: All modes benchmarked under realistic loads
- **Compatibility Tests**: 100% backward compatibility verified
- **Edge Cases**: All error conditions and fallbacks tested

#### **Test Execution Strategy**
```elixir
# mix.exs test configuration
def project do
  [
    # ... existing config ...
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
      "test.performance": :test,
      "test.integration": :test
    ],
    aliases: [
      "test.all": ["test", "test.performance", "test.integration"],
      "test.performance": ["test --only performance"],
      "test.integration": ["test --only integration"],
      "test.unified": ["test test/elixir_scope/unified/"],
      "test.hybrid": ["test test/elixir_scope/hybrid/"]
    ]
  ]
end
```

#### **Continuous Integration Pipeline**
1. **Fast Tests** (< 30 seconds): Unit tests, basic integration
2. **Standard Tests** (< 5 minutes): Full test suite except performance
3. **Performance Tests** (< 15 minutes): Benchmarks and stress tests
4. **Full Integration** (< 30 minutes): End-to-end scenarios, multi-node

#### **Test Data & Fixtures**
```elixir
# test/fixtures/
├── sample_modules/           # Test modules for transformation
├── instrumentation_plans/    # Various instrumentation configurations
├── performance_scenarios/    # Realistic workload simulations
└── integration_apps/         # Complete Phoenix/GenServer applications
```

---

### **🎯 Success Criteria**

#### **Technical Validation**
- [ ] All existing tests continue passing (325+ tests)
- [ ] New unified tests achieve 95%+ coverage
- [ ] Performance benchmarks meet targets
- [ ] Memory usage stays within bounds
- [ ] No regressions in existing functionality

#### **Functional Validation**
- [ ] All three modes (Runtime, AST, Hybrid) work correctly
- [ ] Mode selection logic handles all scenarios
- [ ] Event correlation works across systems
- [ ] Fallback mechanisms activate properly
- [ ] Configuration system supports all modes

#### **Quality Validation**
- [ ] Documentation covers all test scenarios
- [ ] Examples demonstrate each mode's capabilities
- [ ] Error messages are clear and actionable
- [ ] Performance characteristics are well-understood
- [ ] Maintenance burden is manageable

---

## 📋 **Implementation Progress Checklist**

### **🏗️ Foundation Phase (Step 1-2)**
- [ ] **AST Infrastructure Restoration** (Step 1)
  - [ ] Core modules restored from pre-df3b905a commit
  - [ ] AST components modernized for unified system
  - [ ] CompileTime.Orchestrator implemented
  - [ ] Event source tagging and correlation IDs added
- [ ] **Unified API Implementation** (Step 2)  
  - [ ] ElixirScope.Unified module created
  - [ ] Mode selection logic implemented
  - [ ] Delegation system working
  - [ ] Basic tests passing

### **🔗 Integration Phase (Step 3-4)**
- [ ] **Hybrid Tracing Engine** (Step 3)
  - [ ] TracingEngine GenServer implemented
  - [ ] Event correlation enhanced
  - [ ] Session management working
  - [ ] Cross-system coordination functional
- [ ] **Configuration & Data Model** (Step 4)
  - [ ] Unified configuration system implemented
  - [ ] Enhanced event data model deployed
  - [ ] AST plan storage system working
  - [ ] All configuration options functional

### **🎯 Advanced Features Phase (Step 5-6)**
- [ ] **Enhanced AST Capabilities** (Step 5)
  - [ ] Local variable capture implemented
  - [ ] Expression tracing functional
  - [ ] Conditional compilation working
  - [ ] "Cinema Data" capabilities demonstrated
- [ ] **Developer Experience** (Step 6)
  - [ ] Seamless mode transitions implemented
  - [ ] IEx helpers enhanced for unified data
  - [ ] Runtime control of AST instrumentation working
  - [ ] User experience polished

### **🤖 Intelligence Phase (Step 7)**
- [ ] **AI Integration** (Step 7)
  - [ ] AI-driven mode selection implemented
  - [ ] Intelligent instrumentation planning working
  - [ ] Adaptive tracing capabilities functional
  - [ ] Performance optimization suggestions active

### **🧪 Testing & Validation**
- [ ] **Foundation Testing**
  - [ ] All existing runtime tests still passing (28/28)
  - [ ] AST transformation tests restored and updated
  - [ ] Mode selection logic thoroughly tested
  - [ ] API compatibility verified
- [ ] **Integration Testing**
  - [ ] Hybrid event correlation tested
  - [ ] Cross-system session management verified
  - [ ] Configuration system integration tested
  - [ ] End-to-end workflows validated
- [ ] **Performance Testing**
  - [ ] Runtime mode overhead < 5% (when inactive)
  - [ ] AST mode overhead < 20% (development acceptable)
  - [ ] Hybrid mode balanced performance verified
  - [ ] Memory usage bounds confirmed
- [ ] **Usability Testing**
  - [ ] MiniProcessFlow scenarios tested
  - [ ] IEx helper output validated
  - [ ] Mode switching workflows verified
  - [ ] Documentation and examples complete

### **🚀 Production Readiness**
- [ ] **Quality Assurance**
  - [ ] 95%+ test coverage on new components
  - [ ] All error conditions handled gracefully
  - [ ] Performance benchmarks meet targets
  - [ ] Memory usage optimized
- [ ] **Documentation & Examples**
  - [ ] API documentation complete
  - [ ] Usage examples for all modes
  - [ ] Migration guide from runtime-only
  - [ ] Troubleshooting guide available
- [ ] **Deployment Preparation**
  - [ ] Backward compatibility verified
  - [ ] Configuration migration tools ready
  - [ ] Monitoring and observability added
  - [ ] Production deployment tested

---

## 🎯 **Key Success Metrics**

### **Technical Excellence**
- ✅ **Zero Regressions**: All existing functionality preserved
- ✅ **Performance Targets**: Runtime <5%, AST <20%, Hybrid balanced
- ✅ **Test Coverage**: 95%+ on new unified components
- ✅ **Memory Efficiency**: Bounded usage in all modes

### **Developer Experience**
- ✅ **Seamless Integration**: Single API for all tracing needs
- ✅ **Intelligent Defaults**: Automatic mode selection works correctly
- ✅ **Progressive Enhancement**: Easy escalation from basic to detailed tracing
- ✅ **Clear Feedback**: Excellent error messages and guidance

### **Architectural Soundness**
- ✅ **Clean Separation**: Runtime and AST systems properly decoupled
- ✅ **Unified Data Flow**: All events through same processing pipeline
- ✅ **Robust Correlation**: Cross-system event linking works reliably
- ✅ **Extensible Design**: Easy to add new capabilities

---

*Analysis Status: COMPLETE - Ready for implementation*
*Next Phase: AST Infrastructure Restoration (Step 1)*
*Testing Strategy: COMPREHENSIVE - 5-phase approach covering all aspects*
*Progress Tracking: Detailed checklist for implementation phases* 