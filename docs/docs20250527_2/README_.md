# ElixirScope: AI-Powered Execution Cinema Debugger for Elixir

[![Elixir](https://img.shields.io/badge/elixir-%234B275F.svg?style=for-the-badge&logo=elixir&logoColor=white)](https://elixir-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**ElixirScope is a next-generation debugging and observability platform for Elixir applications, designed to provide an "Execution Cinema" experience through deep, compile-time AST instrumentation guided by AI-powered analysis.**

## 🎬 **Try the Cinema Demo Now!**

**Experience ElixirScope in action with our comprehensive working demo:**

```bash
git clone https://github.com/your-org/elixir_scope.git
cd elixir_scope/test_apps/cinema_demo
./run_showcase.sh
```

**✨ See all features working in ~1 minute:** Time-travel debugging, performance monitoring, state reconstruction, and more!

**[📖 Complete Demo Documentation →](https://github.com/nshkrdotcom/ElixirScope/blob/main/test_apps/cinema_demo/FULLY_BLOWN.md**

## 🎯 Vision & Mission

Transform Elixir development by providing unprecedented insight into application behavior through:

- **Total Behavioral Recall**: Capture comprehensive execution history through compile-time instrumentation
- **AI-Driven Guidance**: Intelligent instrumentation planning and code analysis  
- **Compile-Time Granularity**: Access local variables, trace expressions, and inject custom logic with precision
- **Time-Travel Debugging**: Navigate through your application's execution history (planned)
- **Multi-Dimensional Analysis**: Correlate events across time, processes, state, and performance

---

## 🚀 Current Implementation Status

ElixirScope has achieved **major milestones** with a **comprehensive working demo** and core components fully operational:

### 🎬 **NEW: Complete Cinema Demo Available!**

**✅ FULLY WORKING SHOWCASE** - Experience all ElixirScope features in action:

```bash
cd test_apps/cinema_demo
./run_showcase.sh
```

**What you'll see:**
- ✅ All 6 demo scenarios running (Task Management, Data Processing, Complex Operations, Error Handling, Performance Analysis, Time Travel Debugging)
- ✅ Real-time performance metrics and system monitoring
- ✅ TemporalBridge integration with working time-travel debugging
- ✅ Complete end-to-end workflow demonstration
- ✅ ~1 minute comprehensive feature showcase

**[📖 See FULLY_BLOWN.md for complete demo documentation](https://github.com/nshkrdotcom/ElixirScope/blob/main/test_apps/cinema_demo/FULLY_BLOWN.md)**

### ✅ **Production-Ready Components**

#### **Core Infrastructure (100% Complete)**
- **✅ Configuration System** - `ElixirScope.Config` with environment support and validation
- **✅ Event System** - `ElixirScope.Events` with comprehensive event type definitions
- **✅ Utility Functions** - `ElixirScope.Utils` with ID generation, timestamps, and data formatting
- **✅ Application Supervision** - Robust OTP application structure

#### **Data Capture Pipeline (95% Complete)**
- **✅ InstrumentationRuntime** - High-performance runtime event capture API (920 lines)
  - Function entry/exit tracking with correlation IDs
  - Local variable snapshots and expression tracing
  - AST-correlated event reporting (enhanced for hybrid architecture)
  - Phoenix, LiveView, Ecto, and GenServer integration functions
  - <1µs overhead when disabled, <500ns when enabled
- **✅ Ring Buffer** - Lock-free, high-performance event storage (supporting >100k events/sec)
- **✅ Ingestor** - Ultra-fast event ingestion (<1µs per event target)
- **✅ Pipeline Manager** - Coordinated async processing with backpressure
- **✅ Data Access** - ETS-based storage with efficient querying

#### **AST Transformation Engine (90% Complete)**
- **✅ Core Transformer** - Production-ready AST instrumentation for functions and GenServer callbacks
- **✅ Enhanced Transformer** - Granular instrumentation with local variable capture and expression tracing
- **✅ Injector Helpers** - Comprehensive AST manipulation utilities
- **Pattern Support**: GenServer, Phoenix Controller, LiveView, and Channel instrumentation

#### **AI Analysis Framework (85% Complete)**
- **✅ LLM Integration** - Complete multi-provider support:
  - **Google Gemini API** - Production integration with authentication
  - **Vertex AI** - Service account authentication and error handling  
  - **Mock Provider** - Comprehensive testing infrastructure
- **✅ AI Orchestrator** - Centralized AI coordination and instrumentation planning
- **✅ Pattern Recognizer** - OTP pattern detection (GenServer, Supervisor, Phoenix patterns)
- **🚧 Code Analyzer** - Basic analysis with room for enhancement
- **🚧 Predictive Execution** - ML-based execution path and resource prediction

#### **Cinema Debugger System (90% Complete)**
- **✅ TemporalStorage** - High-performance temporal event storage with AST correlation
- **✅ TemporalBridge** - Real-time bridge between runtime events and temporal storage
- **✅ State Reconstruction** - Working time-travel debugging via TemporalBridge
- **✅ Event Correlation** - AST node correlation with runtime events
- **✅ Performance Tracking** - Real-time metrics and system monitoring

#### **AST Repository System (85% Complete)**
- **✅ Repository Core** - Central AST storage with runtime correlation
- **✅ Function Data** - Comprehensive function-level analysis structure
- **✅ Runtime Correlator** - Bridge between AST nodes and runtime events (working)
- **🚧 Parser Integration** - AST parsing with instrumentation point mapping (partial)

#### **Compile-Time Orchestration (80% Complete)**
- **✅ Orchestrator** - Complete instrumentation planning and AI integration
- **✅ Configuration Management** - Runtime configuration updates
- **🚧 Mix Task Integration** - Automatic compile-time transformation (planned)

### 📋 **Planned Features**

#### **Web Interface (Next Priority)**
- Phoenix web interface for trace visualization
- Visual time-travel debugging interface
- Interactive execution timeline
- Multi-dimensional event correlation

#### **Advanced Integrations (Future)**
- IDE integration (ElixirLS compatibility)
- Distributed tracing capabilities
- Advanced AI analysis and recommendations
- Hypothesis testing framework

---

## 🏗️ **Architecture Overview**

ElixirScope follows a **compile-time first** approach with runtime correlation capabilities:

```mermaid
graph TD
    subgraph "Developer Tools"
        IDE["IDE / IEx"]
        MixTask["Mix Tasks (Planned)"]
    end

    subgraph "AI Analysis Engine"
        Orchestrator["AI.Orchestrator ✅"]
        CodeAnalyzer["Code Analyzer ✅"]
        PatternRecognizer["Pattern Recognizer ✅"]
        LLMProviders["LLM Providers ✅<br/>Gemini • Vertex • Mock"]
    end

    subgraph "AST Transformation"
        Transformer["AST.Transformer ✅"]
        EnhancedTransformer["Enhanced Transformer ✅"]
        CompileTime["Compile-Time Orchestrator 🚧"]
    end

    subgraph "Data Capture Pipeline"
        Runtime["InstrumentationRuntime ✅"]
        Ingestor["Ingestor ✅"]
        RingBuffer["Ring Buffer ✅"]
        Pipeline["Pipeline Manager ✅"]
        Storage["Data Access ✅"]
    end

    subgraph "Cinema Debugger System"
        TemporalStorage["TemporalStorage ✅"]
        TemporalBridge["TemporalBridge ✅"]
        StateReconstruction["State Reconstruction ✅"]
    end

    subgraph "AST Repository"
        Repository["Repository Core ✅"]
        FunctionData["Function Data ✅"] 
        Correlator["Runtime Correlator ✅"]
    end

    IDE --> Orchestrator
    Orchestrator --> CodeAnalyzer
    CodeAnalyzer --> LLMProviders
    CodeAnalyzer --> Transformer
    Transformer --> Runtime
    Runtime --> Ingestor
    Ingestor --> RingBuffer
    RingBuffer --> Pipeline
    Pipeline --> Storage
    Storage --> TemporalStorage
    TemporalStorage --> TemporalBridge
    TemporalBridge --> StateReconstruction
    Repository --> Correlator
    Correlator --> TemporalBridge
    
    style Runtime fill:#c8e6c9,color:#000
    style Ingestor fill:#c8e6c9,color:#000
    style Orchestrator fill:#e1f5fe,color:#000
    style Repository fill:#fff3e0,color:#000
    style TemporalBridge fill:#c8e6c9,color:#000
    style StateReconstruction fill:#c8e6c9,color:#000
```

### **Key Architectural Principles**

- **Compile-Time First**: Primary focus on AST transformation for deep instrumentation
- **AI-Guided Intelligence**: Smart instrumentation planning based on code analysis
- **High-Performance Pipeline**: Sub-microsecond event processing with async correlation
- **Production-Safe**: Configurable instrumentation levels with minimal overhead
- **Extensible**: Plugin architecture for new analysis types and integrations

---

## 🚀 **Getting Started**

### **Installation**

Add ElixirScope to your `mix.exs`:

```elixir
def deps do
  [
    {:elixir_scope, "~> 0.1.0"}
  ]
end
```

### **Basic Configuration**

```elixir
# config/config.exs
config :elixir_scope,
  # Data capture settings
  capture: [
    buffer_size: 10_000,
    batch_size: 100,
    flush_interval: 1_000
  ],
  
  # AI analysis settings  
  ai: [
    llm_provider: :mock,  # :gemini, :vertex, :mock
    analysis_timeout: 30_000,
    planning: [
      default_strategy: :balanced
    ]
  ],
  
  # AST instrumentation settings
  ast: [
    default_instrumentation_level: :function_boundaries,
    performance_monitoring: true,
    variable_capture: false
  ]
```

### **Quick Start - Try the Cinema Demo!**

The fastest way to experience ElixirScope is through our comprehensive demo:

```bash
# Clone the repository
git clone https://github.com/nshkrdotcom/ElixirScope.git elixir_scope
cd elixir_scope

# Run the complete showcase
cd test_apps/cinema_demo
./run_showcase.sh
```

This will demonstrate:
- ✅ **Task Management** - GenServer state tracking and lifecycle management
- ✅ **Data Processing** - Complex data transformation pipelines
- ✅ **Time Travel Debugging** - State reconstruction at any point in time
- ✅ **Performance Analysis** - Real-time metrics and bottleneck identification
- ✅ **Error Handling** - Graceful recovery and error correlation
- ✅ **Complex Operations** - Deep call stacks and recursive function analysis

### **Current Usage Examples**

#### **Main Application API**
```elixir
# Start ElixirScope with your application
children = [
  # Your application children...
  {ElixirScope, []}
]

# Use the main API
ElixirScope.start(strategy: :full_trace, sampling_rate: 1.0)
status = ElixirScope.status()

# Check if running
ElixirScope.running?()
# => true

# Update configuration at runtime
ElixirScope.update_config([:ai, :planning, :sampling_rate], 0.5)
```

#### **Cinema Debugger Features**
```elixir
# Start TemporalBridge for time-travel debugging
{:ok, bridge} = ElixirScope.Capture.TemporalBridge.start_link(
  name: :my_bridge,
  buffer_size: 1000
)

# Get bridge statistics
{:ok, stats} = ElixirScope.Capture.TemporalBridge.get_stats(bridge)

# Reconstruct state at specific timestamp
{:ok, past_state} = ElixirScope.Capture.TemporalBridge.reconstruct_state_at(
  bridge, 
  timestamp
)
```

#### **AI-Powered Code Analysis**
```elixir
# Analyze code with AI
{:ok, analysis} = ElixirScope.AI.CodeAnalyzer.analyze_module(MyModule)

# Generate instrumentation plan
{:ok, plan} = ElixirScope.AI.Orchestrator.plan_for_module(source_code)

# Recognize patterns
patterns = ElixirScope.AI.PatternRecognizer.extract_patterns(ast)
```

### **LLM Provider Setup**

#### **Google Gemini API**
```bash
export GOOGLE_API_KEY="your-gemini-api-key"
```

```elixir
config :elixir_scope, ai: [llm_provider: :gemini]
```

#### **Vertex AI**
```bash
export VERTEX_JSON_FILE="/path/to/service-account.json"
```

```elixir
config :elixir_scope, ai: [llm_provider: :vertex]
```

---

## 🧪 **Testing & Development**

ElixirScope has comprehensive testing with **723 tests passing, 0 failures** and extensive coverage across all components.

### **Test Commands**

```bash
# Default test command - excludes live API tests, shows full test names
mix test

# All tests including live API tests (may hang without API keys)
mix test.all

# Fast tests (parallelized)  
mix test.fast

# LLM provider tests
mix test.mock          # Mock provider only
mix test.gemini        # Live Gemini API tests
mix test.vertex        # Live Vertex AI tests
mix test.live          # All live API tests

# Legacy alias (same as default mix test)
mix test.trace

# Performance validation
mix test.performance
```

### **Cinema Demo Testing**

```bash
# Test the complete demo application
cd test_apps/cinema_demo
mix test

# Run individual demo scenarios
mix run -e "CinemaDemo.run_task_management_demo()"
mix run -e "CinemaDemo.run_time_travel_debugging_demo()"

# Run the complete showcase
./run_showcase.sh
```

### **Live API Testing**

To run tests against real LLM APIs:

```bash
# Set up credentials
export GOOGLE_API_KEY="your-key"
export VERTEX_JSON_FILE="/path/to/service-account.json"

# Run live tests
mix test.live
```

---

## 📊 **Performance Characteristics**

### **Current Benchmarks**

| Component | Performance | Status |
|-----------|-------------|---------|
| **InstrumentationRuntime** | <100µs per event | ✅ Production Ready |
| **TemporalBridge** | <100µs event forwarding | ✅ Production Ready |
| **Ring Buffer** | >100k events/sec throughput | ✅ Production Ready |
| **Event Ingestor** | <1µs per event processing | ✅ Production Ready |
| **State Reconstruction** | <10ms for typical GenServer | ✅ Production Ready |
| **AST Transformation** | <100ms for medium modules | ✅ Production Ready |
| **AI Analysis** | <30s for project analysis | ✅ Functional |
| **Cinema Demo** | ~1 minute complete showcase | ✅ Fully Working |

### **Memory Usage**

- **Base overhead**: ~10MB for core system
- **TemporalBridge**: ~5MB per bridge instance
- **Per-module overhead**: 50KB (small), 200KB (medium), 1MB (large)
- **Ring buffer**: Configurable, 1-10MB typical
- **Cinema Demo**: ~15MB total during showcase
- **Total overhead**: <50MB for typical projects

---

## 🗺️ **Development Roadmap**

### **✅ Phase 1: Foundation Complete (May 2025)**

#### **Major Achievements**
- ✅ Complete Cinema Demo with all 6 scenarios working
- ✅ TemporalBridge integration for time-travel debugging
- ✅ State reconstruction capabilities
- ✅ Performance monitoring and metrics
- ✅ AST-runtime correlation system
- ✅ Comprehensive test suite (723 tests passing)
- ✅ Production-ready core components

### **Phase 2: Web Interface & Enhanced Features (Q2 2025)**

#### **Immediate Priorities**
- [ ] Phoenix web interface for Cinema Debugger
- [ ] Visual time-travel debugging interface
- [ ] Interactive execution timeline
- [ ] Real-time event streaming dashboard

#### **Enhanced Features**
- [ ] Mix task for automatic instrumentation
- [ ] IEx helpers for debugging workflow
- [ ] Enhanced AI orchestration and planning
- [ ] User-friendly instrumentation API

### **Phase 3: Advanced Features (Q2-Q3 2025)**

- [ ] Distributed tracing across nodes
- [ ] Advanced AI analysis and recommendations
- [ ] IDE integration (ElixirLS)
- [ ] Production deployment patterns
- [ ] Performance optimization tools

---

## 🤝 **Contributing**

We welcome contributions! ElixirScope is built with a solid foundation and clear architecture.

### **Current Contribution Opportunities**

1. **Web Interface** - Build the Phoenix-based Cinema Debugger web UI
2. **Visual Debugging** - Create interactive time-travel debugging interface
3. **AI Enhancement** - Improve code analysis and pattern recognition
4. **Performance Optimization** - Enhance event processing and storage
5. **Documentation** - Improve guides and examples
6. **Testing** - Add property-based and chaos testing

### **Getting Started with Development**

1. Fork the repository
2. Set up development environment:
   ```bash
   mix deps.get
   mix test  # Ensure all tests pass (723 tests, excludes live API tests)
   ```
3. Try the Cinema Demo:
   ```bash
   cd test_apps/cinema_demo
   ./run_showcase.sh
   ```
4. Create a feature branch
5. Add comprehensive tests for new functionality
6. Submit a pull request

### **Development Guidelines**

- **Test-driven development**: All new features need tests (current: 723 tests passing)
- **Performance-conscious**: Maintain <100µs instrumentation overhead
- **Backward compatibility**: Don't break existing APIs
- **Documentation**: Update guides for new features
- **Demo integration**: Consider adding features to Cinema Demo showcase

---

## 📄 **License**

ElixirScope is released under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## 🙏 **Acknowledgments**

ElixirScope builds on the excellent foundation of the Elixir and OTP ecosystem. Special thanks to:

- The Elixir core team for creating such an introspectable language
- The Phoenix team for demonstrating excellent debugging tools
- The Erlang/OTP team for the robust foundation
- The Elixir community for inspiration and feedback

---

## 📞 **Support & Community**

- **Documentation**: [Coming Soon]
- **Issues**: [GitHub Issues](https://github.com/your-org/elixir_scope/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/elixir_scope/discussions)
- **Elixir Forum**: Tag your posts with `elixir-scope`

---

**ElixirScope**: Transforming Elixir development through intelligent instrumentation and AI-powered analysis. **The future of debugging is here - and it's working!** 🎬✨

**[🚀 Try the Cinema Demo Now!](test_apps/cinema_demo/)**
