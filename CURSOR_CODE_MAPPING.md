# ElixirScope Code Mapping & Architecture Guide
**For Cursor AI Code Understanding**  
**Date**: May 26, 2025  
**Purpose**: Map existing codebase to hybrid architecture implementation

---

## 🗺️ **EXISTING CODE FOUNDATION ANALYSIS**

### **Core Application Structure**

```
lib/elixir_scope.ex                    # Main application entry point
lib/elixir_scope/application.ex        # OTP Application supervisor
lib/elixir_scope/config.ex            # Centralized configuration management
lib/elixir_scope/events.ex            # Event type definitions and utilities
lib/elixir_scope/utils.ex             # Shared utility functions
```

**Status**: ✅ **Production Ready** - These form the solid foundation for hybrid architecture

**Integration Strategy**: 
- Extend `config.ex` with hybrid architecture settings
- Add AST correlation event types to `events.ex`
- Enhance `application.ex` supervision tree with AST repository

---

## 🧠 **AI & ANALYSIS LAYER (90% COMPLETE)**

### **Core AI Infrastructure**
```
lib/elixir_scope/ai/
├── orchestrator.ex                 # ✅ Central AI coordination - ENHANCE for AST repo
├── code_analyzer.ex               # ✅ Static code analysis - ADD runtime correlation
├── complexity_analyzer.ex         # ✅ Code complexity metrics - ADD runtime metrics
├── pattern_recognizer.ex          # ✅ Pattern detection - ADD hybrid patterns
└── analysis/
    └── intelligent_code_analyzer.ex # ✅ Advanced AI analysis - ADD hybrid context
```

**Current Capabilities:**
- **Multi-provider LLM integration** (Gemini, Vertex AI, Mock)
- **Static code analysis and complexity metrics**
- **Pattern recognition and architectural analysis**
- **AI orchestration and coordination**

**Integration Points for Hybrid Architecture:**
1. **Enhance `orchestrator.ex`** to coordinate with AST Repository
2. **Extend `code_analyzer.ex`** to consume hybrid AST+Runtime context
3. **Upgrade `pattern_recognizer.ex`** to detect runtime correlation patterns

### **LLM Provider Infrastructure**
```
lib/elixir_scope/ai/llm/
├── client.ex                      # ✅ LLM client abstraction
├── config.ex                     # ✅ Provider configuration
├── provider.ex                   # ✅ Provider interface
├── response.ex                   # ✅ Response processing
└── providers/
    ├── gemini.ex                  # ✅ Google Gemini integration
    ├── vertex.ex                  # ✅ Vertex AI integration
    └── mock.ex                    # ✅ Testing mock provider
```

**Status**: ✅ **Production Ready** - Comprehensive LLM infrastructure

**Integration Strategy**: Create new `lib/elixir_scope/llm/` modules that use this infrastructure for hybrid context processing

---

## 🌳 **AST TRANSFORMATION LAYER (80% COMPLETE)**

### **Current AST Capabilities**
```
lib/elixir_scope/ast/
├── transformer.ex                 # ✅ Core AST transformation
├── enhanced_transformer.ex       # ✅ Advanced instrumentation injection
└── injector_helpers.ex           # ✅ AST manipulation utilities
```

**Current Features:**
- **Core AST transformation** with instrumentation injection
- **Enhanced transformation** with variable capture and expression tracing
- **Helper utilities** for AST manipulation and code generation

**Integration for Hybrid Architecture:**
1. **Extend `enhanced_transformer.ex`** to inject AST node IDs and correlation metadata
2. **Enhance instrumentation injection** to support runtime correlation hooks
3. **Add AST node mapping** for correlation with runtime events

**Key Enhancement Needed:**
```elixir
# Enhance existing enhanced_transformer.ex
def transform_with_correlation_metadata(ast, plan) do
  ast
  |> assign_unique_node_ids()           # NEW: Assign unique IDs to AST nodes
  |> inject_correlation_hooks(plan)     # NEW: Inject correlation metadata
  |> transform_with_enhanced_instrumentation(plan)  # EXISTING: Use current logic
  |> map_instrumentation_points()       # NEW: Map instrumentation to AST nodes
end
```

---

## 📊 **DATA CAPTURE PIPELINE (95% COMPLETE)**

### **High-Performance Event Pipeline**
```
lib/elixir_scope/capture/
├── instrumentation_runtime.ex     # ✅ Runtime event capture - ENHANCE for AST correlation
├── ingestor.ex                    # ✅ Event ingestion - ADD AST node mapping  
├── ring_buffer.ex                 # ✅ High-performance buffering
├── event_correlator.ex            # ✅ Event correlation - EXTEND for AST correlation
├── async_writer.ex                # ✅ Async event processing
├── async_writer_pool.ex           # ✅ Worker pool management
└── pipeline_manager.ex            # ✅ Pipeline orchestration
```

**Current Pipeline Flow:**
```
InstrumentationRuntime → Ingestor → RingBuffer → AsyncWriterPool → EventCorrelator → Storage
```

**Integration Strategy for Hybrid Architecture:**
1. **Enhance `instrumentation_runtime.ex`** - Add functions for AST-correlated events
2. **Extend `ingestor.ex`** - Process AST correlation metadata
3. **Upgrade `event_correlator.ex`** - Correlate events with AST nodes

**Key Code Points:**

#### **InstrumentationRuntime Enhancement:**
```elixir
# ADD to existing lib/elixir_scope/capture/instrumentation_runtime.ex
def report_ast_correlated_function_entry(module, function, args, correlation_id, ast_node_id) do
  # Use existing infrastructure but with AST correlation
  enhanced_event = %{
    module: module,
    function: function, 
    args: args,
    correlation_id: correlation_id,
    ast_node_id: ast_node_id,  # NEW: AST correlation
    timestamp: System.monotonic_time(:nanosecond)
  }
  
  # Leverage existing capture infrastructure
  case get_context() do
    %{enabled: true, buffer: buffer} when not is_nil(buffer) ->
      Ingestor.ingest_ast_correlated_event(buffer, :ast_function_entry, enhanced_event)
    _ -> :ok
  end
end
```

#### **Ingestor Enhancement:**
```elixir
# ADD to existing lib/elixir_scope/capture/ingestor.ex
def ingest_ast_correlated_event(buffer, event_type, event_data) do
  # Enhance event with AST correlation metadata
  correlated_event = Map.merge(event_data, %{
    event_type: event_type,
    has_ast_correlation: true,
    correlation_metadata: extract_ast_correlation_metadata(event_data)
  })
  
  # Use existing ingest logic
  ingest(buffer, correlated_event)
end
```

---

## 💾 **STORAGE LAYER (70% COMPLETE)**

### **Current Storage Infrastructure**
```
lib/elixir_scope/storage/
└── data_access.ex                 # ✅ ETS-based storage - EXTEND for AST repository
```

**Current Capabilities:**
- **ETS-based high-performance storage**
- **Event storage and retrieval**
- **Basic query capabilities**

**Integration Strategy:**
Create new AST Repository that **extends** existing storage rather than replaces it:

```elixir
# NEW: lib/elixir_scope/ast_repository/repository.ex
defmodule ElixirScope.ASTRepository.Repository do
  # Leverage existing DataAccess infrastructure
  alias ElixirScope.Storage.DataAccess
  
  def store_module_with_correlation(module_data) do
    # Store in existing storage system
    DataAccess.store_event(:module_data, module_data)
    
    # Add AST-specific indexing
    update_correlation_index(module_data)
  end
end
```

---

## 🧪 **COMPREHENSIVE TEST INFRASTRUCTURE**

### **Existing Test Coverage Analysis**

#### **AI Component Tests (90% Coverage)**
```
test/elixir_scope/ai/
├── code_analyzer_test.exs          # ✅ Static analysis testing
├── llm/                           # ✅ Complete LLM testing infrastructure
│   ├── client_test.exs             # ✅ Client functionality
│   ├── provider_compliance_test.exs # ✅ Provider interface compliance
│   └── providers/                  # ✅ All provider implementations tested
└── analysis/
    └── intelligent_code_analyzer_test.exs # ✅ Advanced analysis testing
```

#### **AST Transformation Tests (85% Coverage)**
```
test/elixir_scope/ast/
├── enhanced_transformer_test.exs   # ✅ Advanced transformation testing
└── transformer_test.exs           # ✅ Core transformation testing
```

#### **Data Pipeline Tests (95% Coverage)**
```
test/elixir_scope/capture/
├── instrumentation_runtime_integration_test.exs # ✅ Runtime integration
├── ingestor_test.exs              # ✅ Event ingestion
├── ring_buffer_test.exs           # ✅ Buffer performance
├── event_correlator_test.exs      # ✅ Event correlation
├── async_writer_test.exs          # ✅ Async processing
├── async_writer_pool_test.exs     # ✅ Pool management
└── pipeline_manager_test.exs      # ✅ Pipeline orchestration
```

#### **Integration & Performance Tests**
```
test/elixir_scope/integration/
└── end_to_end_hybrid_test.exs     # 🚧 PLACEHOLDER - needs implementation

test/elixir_scope/performance/
└── hybrid_benchmarks_test.exs     # 🚧 PLACEHOLDER - needs implementation
```

**Test Strategy for Hybrid Implementation:**
1. **Extend existing tests** to validate hybrid functionality
2. **Create new AST repository tests** that integrate with existing infrastructure
3. **Build comprehensive integration tests** for hybrid workflows

---

## 🎯 **SPECIFIC INTEGRATION PATTERNS**

### **1. Configuration Integration Pattern**

#### **Extend Existing Config:**
```elixir
# config/config.exs - ADD to existing configuration
config :elixir_scope,
  # Existing configuration preserved...
  capture: [
    buffer_size: 10_000,
    batch_size: 100,
    flush_interval: 1_000
  ],
  
  # NEW: AST Repository configuration
  ast_repository: [
    enabled: true,
    correlation_enabled: true,
    storage_backend: :ets,
    max_correlations: 100_000,
    correlation_timeout_ms: 5_000
  ],
  
  # NEW: Hybrid features configuration  
  hybrid_features: [
    temporal_storage_enabled: true,
    context_building_enabled: true,
    performance_correlation_enabled: true
  ]
```

### **2. Supervision Tree Integration Pattern**

#### **Enhance Application Supervision:**
```elixir
# lib/elixir_scope/application.ex - ENHANCE existing supervision tree
def start(_type, _args) do
  children = [
    # Existing children preserved...
    {ElixirScope.Capture.PipelineManager, []},
    {ElixirScope.Storage.DataAccess, []},
    
    # NEW: AST Repository supervision
    {ElixirScope.ASTRepository.Repository, []},
    {ElixirScope.ASTRepository.RuntimeCorrelator, []},
    
    # NEW: Temporal storage (if enabled)
    temporal_storage_child(),
    
    # NEW: Hybrid LLM context builder (if enabled)
    hybrid_context_child()
  ] |> Enum.filter(& &1)  # Filter out nil children
  
  opts = [strategy: :one_for_one, name: ElixirScope.Supervisor]
  Supervisor.start_link(children, opts)
end

defp temporal_storage_child do
  if Application.get_env(:elixir_scope, [:hybrid_features, :temporal_storage_enabled], false) do
    {ElixirScope.Capture.TemporalStorage, []}
  else
    nil
  end
end

defp hybrid_context_child do
  if Application.get_env(:elixir_scope, [:hybrid_features, :context_building_enabled], false) do
    {ElixirScope.LLM.ContextBuilder, []}
  else
    nil
  end
end
```

### **3. Event Flow Integration Pattern**

#### **Enhance Existing Event Flow:**
```elixir
# Current Flow:
# InstrumentationRuntime → Ingestor → RingBuffer → AsyncWriterPool → EventCorrelator → Storage

# Enhanced Hybrid Flow:
# InstrumentationRuntime (with AST correlation) → 
# Ingestor (with AST metadata) → 
# RingBuffer → 
# AsyncWriterPool → 
# EventCorrelator (with AST correlation) → 
# [Storage + ASTRepository.RuntimeCorrelator] → 
# TemporalStorage (optional)
```

#### **Event Enhancement Pattern:**
```elixir
# Pattern for enhancing existing events with AST correlation
defmodule ElixirScope.Events do
  # ADD to existing events.ex
  
  def enhance_event_with_ast_correlation(event, ast_node_id, correlation_id) do
    Map.merge(event, %{
      ast_correlation: %{
        ast_node_id: ast_node_id,
        correlation_id: correlation_id,
        correlation_timestamp: System.monotonic_time(:nanosecond),
        correlation_strategy: :ast_node_mapping
      }
    })
  end
  
  def extract_ast_correlation(event) do
    Map.get(event, :ast_correlation, %{})
  end
  
  def has_ast_correlation?(event) do
    Map.has_key?(event, :ast_correlation) and
    Map.has_key?(event.ast_correlation, :ast_node_id)
  end
end
```

---

## 🏗️ **NEW MODULES TO CREATE**

### **Priority 1: AST Repository Core (Week 1)**

#### **1. Repository Core Module**
```elixir
# lib/elixir_scope/ast_repository/repository.ex
defmodule ElixirScope.ASTRepository.Repository do
  @moduledoc """
  Central AST repository that integrates with existing ElixirScope storage.
  
  Leverages:
  - ElixirScope.Storage.DataAccess for persistence
  - ElixirScope.Config for configuration
  - ElixirScope.Events for event type definitions
  """
  
  use GenServer
  alias ElixirScope.Storage.DataAccess
  alias ElixirScope.Config
  alias ElixirScope.Events
  
  # Integration with existing infrastructure
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    # Use existing configuration system
    config = Config.get_config()
    
    # Initialize using existing storage
    DataAccess.ensure_table_exists(:ast_modules)
    DataAccess.ensure_table_exists(:ast_correlations)
    
    state = %{
      modules: %{},
      correlation_index: %{},
      config: config
    }
    
    {:ok, state}
  end
  
  # Public API that integrates with existing patterns
  def store_module(module_data) do
    GenServer.call(__MODULE__, {:store_module, module_data})
  end
  
  def correlate_runtime_event(event) do
    GenServer.call(__MODULE__, {:correlate_event, event})
  end
end
```

#### **2. Runtime Correlator Module**
```elixir
# lib/elixir_scope/ast_repository/runtime_correlator.ex
defmodule ElixirScope.ASTRepository.RuntimeCorrelator do
  @moduledoc """
  Bridges runtime events with AST nodes using existing capture infrastructure.
  """
  
  use GenServer
  alias ElixirScope.Capture.EventCorrelator
  alias ElixirScope.Events
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def correlate_event(event) do
    GenServer.call(__MODULE__, {:correlate_event, event})
  end
  
  # Integration with existing event correlation
  def handle_call({:correlate_event, event}, _from, state) do
    correlation_result = case Events.extract_ast_correlation(event) do
      %{ast_node_id: ast_node_id, correlation_id: correlation_id} ->
        perform_correlation(ast_node_id, correlation_id, event, state)
      
      _ ->
        {:error, :no_ast_correlation_metadata}
    end
    
    {:reply, correlation_result, state}
  end
  
  defp perform_correlation(ast_node_id, correlation_id, event, state) do
    # Implement correlation logic
    # Update AST repository with runtime insights
    # Track correlation accuracy metrics
    {:ok, ast_node_id}
  end
end
```

#### **3. AST Parser with Correlation**
```elixir
# lib/elixir_scope/ast_repository/parser.ex
defmodule ElixirScope.ASTRepository.Parser do
  @moduledoc """
  Parses AST and assigns correlation metadata for runtime correlation.
  
  Integrates with existing AST transformation infrastructure.
  """
  
  alias ElixirScope.AST.InjectorHelpers
  
  def parse_with_correlation_metadata(source_code) do
    with {:ok, ast} <- Code.string_to_quoted(source_code) do
      enhanced_ast = ast
      |> assign_unique_node_ids()
      |> extract_instrumentation_points()
      |> build_correlation_index()
      
      {:ok, %{
        ast: enhanced_ast,
        correlation_index: extract_correlation_index(enhanced_ast),
        instrumentation_points: extract_instrumentation_points(enhanced_ast)
      }}
    end
  end
  
  defp assign_unique_node_ids(ast) do
    # Traverse AST and assign unique IDs to instrumentable nodes
    # Leverage existing InjectorHelpers for AST manipulation
    InjectorHelpers.traverse_and_transform(ast, fn node ->
      case instrumentable_node?(node) do
        true -> add_node_id(node)
        false -> node
      end
    end)
  end
end
```

### **Priority 2: Temporal Storage (Week 1-2)**

#### **4. Temporal Storage Module**
```elixir
# lib/elixir_scope/capture/temporal_storage.ex
defmodule ElixirScope.Capture.TemporalStorage do
  @moduledoc """
  Time-based event storage with AST correlation support.
  
  Integrates with existing capture pipeline and storage infrastructure.
  """
  
  use GenServer
  alias ElixirScope.Storage.DataAccess
  alias ElixirScope.Events
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def store_event_with_temporal_index(event) do
    GenServer.cast(__MODULE__, {:store_event, event})
  end
  
  def get_events_in_time_range(start_time, end_time) do
    GenServer.call(__MODULE__, {:get_events_range, start_time, end_time})
  end
  
  def get_events_for_ast_node(ast_node_id, time_range \\ nil) do
    GenServer.call(__MODULE__, {:get_events_for_ast_node, ast_node_id, time_range})
  end
  
  # Integration with existing storage
  def handle_cast({:store_event, event}, state) do
    enhanced_event = Events.enhance_event_with_temporal_metadata(event)
    
    # Store using existing DataAccess but with temporal indexing
    DataAccess.store_event_with_index(:temporal_events, enhanced_event, [:timestamp, :ast_node_id])
    
    {:noreply, state}
  end
end
```

### **Priority 3: Hybrid LLM Integration (Week 3)**

#### **5. Context Builder Module**
```elixir
# lib/elixir_scope/llm/context_builder.ex
defmodule ElixirScope.LLM.ContextBuilder do
  @moduledoc """
  Builds hybrid static+runtime context for LLM analysis.
  
  Leverages existing AI infrastructure and AST repository.
  """
  
  alias ElixirScope.AI.CodeAnalyzer
  alias ElixirScope.AI.LLM.Client
  alias ElixirScope.ASTRepository.Repository
  alias ElixirScope.Capture.TemporalStorage
  
  def build_hybrid_context(query, opts \\ []) do
    with {:ok, static_context} <- build_static_context(query),
         {:ok, runtime_context} <- build_runtime_context(query),
         {:ok, correlation_context} <- build_correlation_context(query) do
      
      hybrid_context = %{
        static_context: static_context,
        runtime_context: runtime_context,
        correlation_context: correlation_context,
        metadata: build_context_metadata(query)
      }
      
      {:ok, hybrid_context}
    end
  end
  
  defp build_static_context(query) do
    # Use existing CodeAnalyzer for static analysis
    case CodeAnalyzer.analyze_module(query.target_module) do
      {:ok, analysis} -> {:ok, analysis}
      error -> error
    end
  end
  
  defp build_runtime_context(query) do
    # Get runtime data from temporal storage
    case TemporalStorage.get_events_for_ast_node(query.ast_node_id) do
      {:ok, events} -> {:ok, aggregate_runtime_insights(events)}
      error -> error
    end
  end
  
  defp build_correlation_context(query) do
    # Get correlation data from AST repository
    case Repository.get_correlations_for_module(query.target_module) do
      {:ok, correlations} -> {:ok, build_correlation_insights(correlations)}
      error -> error
    end
  end
end
```

#### **6. Hybrid Analyzer Module**
```elixir
# lib/elixir_scope/llm/hybrid_analyzer.ex
defmodule ElixirScope.LLM.HybridAnalyzer do
  @moduledoc """
  AI-powered analysis using both static AST and runtime correlation data.
  
  Integrates with existing LLM providers and AI infrastructure.
  """
  
  alias ElixirScope.AI.LLM.Client
  alias ElixirScope.AI.Orchestrator
  alias ElixirScope.LLM.ContextBuilder
  
  def analyze_with_hybrid_context(query) do
    with {:ok, hybrid_context} <- ContextBuilder.build_hybrid_context(query),
         {:ok, analysis_prompt} <- build_hybrid_analysis_prompt(hybrid_context),
         {:ok, llm_response} <- Client.analyze_code(analysis_prompt) do
      
      process_hybrid_analysis_response(llm_response, hybrid_context)
    end
  end
  
  defp build_hybrid_analysis_prompt(hybrid_context) do
    # Build sophisticated prompt that includes both static and runtime insights
    prompt = """
    Analyze the following Elixir code with both static structure and runtime behavior:
    
    Static Analysis:
    #{format_static_context(hybrid_context.static_context)}
    
    Runtime Behavior:
    #{format_runtime_context(hybrid_context.runtime_context)}
    
    Correlations:
    #{format_correlation_context(hybrid_context.correlation_context)}
    
    Please provide insights that combine static code analysis with actual runtime behavior.
    """
    
    {:ok, prompt}
  end
  
  defp process_hybrid_analysis_response(response, context) do
    # Process LLM response and correlate insights back to AST nodes
    insights = %{
      static_insights: extract_static_insights(response),
      runtime_insights: extract_runtime_insights(response),
      hybrid_insights: extract_hybrid_insights(response),
      recommendations: extract_recommendations(response)
    }
    
    {:ok, insights}
  end
end
```

---

## 🧪 **TESTING INTEGRATION STRATEGY**

### **Extend Existing Test Infrastructure**

#### **1. Enhance Existing Test Helpers**
```elixir
# test/support/ai_test_helpers.ex - ADD to existing helpers
defmodule ElixirScope.TestSupport.AITestHelpers do
  # Existing helpers preserved...
  
  # NEW: AST Repository test helpers
  def setup_test_ast_repository do
    # Use existing storage setup
    ElixirScope.Storage.DataAccess.clear_all_tables()
    
    # Start AST repository
    {:ok, _pid} = ElixirScope.ASTRepository.Repository.start_link([])
    
    # Create test data
    test_modules = create_test_ast_modules()
    test_correlations = create_test_correlations()
    
    %{modules: test_modules, correlations: test_correlations}
  end
  
  def create_test_ast_modules do
    [
      create_genserver_module_with_ast(),
      create_supervisor_module_with_ast(),
      create_phoenix_controller_module_with_ast()
    ]
  end
  
  def setup_hybrid_test_environment do
    # Set up complete hybrid testing environment
    setup_test_ast_repository()
    start_supervised!(ElixirScope.Capture.TemporalStorage)
    start_supervised!(ElixirScope.LLM.ContextBuilder)
    
    # Generate test correlation data
    generate_test_runtime_events_with_correlation()
  end
end
```

#### **2. Integration Test Patterns**
```elixir
# test/elixir_scope/integration/hybrid_workflow_test.exs
defmodule ElixirScope.Integration.HybridWorkflowTest do
  use ExUnit.Case
  import ElixirScope.TestSupport.AITestHelpers
  
  setup do
    # Use existing test infrastructure
    setup_hybrid_test_environment()
  end
  
  test "complete hybrid workflow: AST → Runtime → Correlation → AI Analysis" do
    # Step 1: Parse AST with correlation metadata
    source_code = load_test_fixture("sample_genserver.ex")
    {:ok, parsed_ast} = ElixirScope.ASTRepository.Parser.parse_with_correlation_metadata(source_code)
    
    # Step 2: Store in repository (using existing storage)
    :ok = ElixirScope.ASTRepository.Repository.store_module(parsed_ast)
    
    # Step 3: Generate runtime events with correlation
    runtime_events = simulate_runtime_execution_with_correlation(parsed_ast)
    
    # Step 4: Correlate events with AST nodes
    correlation_results = for event <- runtime_events do
      ElixirScope.ASTRepository.RuntimeCorrelator.correlate_event(event)
    end
    
    # Step 5: Build hybrid context
    query = %{target_module: TestGenServer, include_runtime_data: true}
    {:ok, hybrid_context} = ElixirScope.LLM.ContextBuilder.build_hybrid_context(query)
    
    # Step 6: AI analysis with hybrid context
    {:ok, analysis} = ElixirScope.LLM.HybridAnalyzer.analyze_with_hybrid_context(query)
    
    # Verify end-to-end workflow
    assert length(correlation_results) > 0
    assert hybrid_context.static_context != nil
    assert hybrid_context.runtime_context != nil
    assert analysis.hybrid_insights != []
  end
end
```

---

## 📊 **PERFORMANCE INTEGRATION STRATEGY**

### **Leverage Existing Performance Infrastructure**

#### **1. Extend Existing Benchmarks**
```elixir
# test/elixir_scope/performance/hybrid_benchmarks_test.exs
defmodule ElixirScope.Performance.HybridBenchmarksTest do
  use ExUnit.Case
  
  # Leverage existing performance testing patterns
  
  test "AST correlation adds <10% overhead to existing capture pipeline" do
    # Baseline: existing capture performance
    baseline_performance = benchmark_existing_capture_pipeline()
    
    # With AST correlation: enhanced capture performance
    enhanced_performance = benchmark_capture_with_ast_correlation()
    
    # Calculate overhead
    overhead_percentage = (enhanced_performance - baseline_performance) / baseline_performance * 100
    
    assert overhead_percentage < 10, "AST correlation overhead: #{overhead_percentage}%, expected <10%"
  end
  
  test "hybrid context building meets <100ms target" do
    setup_large_test_repository(modules: 100, correlations: 1000)
    
    query = %{target_module: TestModule, include_runtime_data: true}
    
    {time_us, _result} = :timer.tc(fn ->
      ElixirScope.LLM.ContextBuilder.build_hybrid_context(query)
    end)
    
    time_ms = time_us / 1000
    assert time_ms < 100, "Context building took #{time_ms}ms, expected <100ms"
  end
  
  defp benchmark_existing_capture_pipeline do
    # Use existing capture infrastructure benchmarking
    events = generate_test_events(1000)
    
    {time_us, _} = :timer.tc(fn ->
      for event <- events do
        ElixirScope.Capture.InstrumentationRuntime.report_function_entry(TestModule, :test, [])
      end
    end)
    
    time_us / 1000  # Convert to milliseconds
  end
end
```

### **2. Memory Usage Integration**
```elixir
# Monitor memory usage integration with existing infrastructure
defmodule ElixirScope.Performance.MemoryMonitor do
  def measure_hybrid_memory_overhead do
    # Baseline memory usage
    baseline_memory = measure_existing_system_memory()
    
    # Start hybrid components
    start_ast_repository_components()
    
    # Enhanced memory usage
    enhanced_memory = measure_system_memory_with_hybrid()
    
    overhead = enhanced_memory - baseline_memory
    overhead_percentage = (overhead / baseline_memory) * 100
    
    %{
      baseline_memory_mb: baseline_memory / 1_000_000,
      enhanced_memory_mb: enhanced_memory / 1_000_000,
      overhead_mb: overhead / 1_000_000,
      overhead_percentage: overhead_percentage
    }
  end
end
```

---

## 🎯 **IMMEDIATE IMPLEMENTATION ROADMAP**

### **Day 1: Core Repository Foundation**
1. **Create** `lib/elixir_scope/ast_repository/repository.ex`
2. **Create** `test/elixir_scope/ast_repository/repository_test.exs`
3. **Enhance** `lib/elixir_scope/capture/instrumentation_runtime.ex` with AST correlation functions
4. **Verify** integration with existing storage and capture infrastructure

### **Day 2: Runtime Correlation**
1. **Create** `lib/elixir_scope/ast_repository/runtime_correlator.ex`
2. **Create** `test/elixir_scope/ast_repository/runtime_correlator_test.exs`
3. **Enhance** `lib/elixir_scope/capture/ingestor.ex` with AST metadata processing
4. **Test** end-to-end event correlation

### **Day 3: AST Parser Integration**
1. **Create** `lib/elixir_scope/ast_repository/parser.ex`
2. **Create** `test/elixir_scope/ast_repository/parser_test.exs`
3. **Enhance** `lib/elixir_scope/ast/enhanced_transformer.ex` with correlation metadata
4. **Validate** AST node ID assignment and instrumentation point mapping

### **Week 1 Goal**
Complete AST Repository foundation that seamlessly integrates with existing ElixirScope infrastructure while maintaining 100% backward compatibility and achieving initial correlation accuracy targets.

This code mapping provides Cursor AI with a comprehensive understanding of how to evolve the existing robust codebase into the revolutionary hybrid architecture while preserving all existing functionality and leveraging the strong foundation already built.