# ElixirScope

**AI-Powered Execution Cinema Debugger for Elixir/BEAM**

ElixirScope is a next-generation debugging and observability platform that provides "Execution Cinema" - a comprehensive view of your Elixir application's runtime behavior with AI-guided instrumentation and time-travel debugging capabilities.

## ✨ Vision

ElixirScope revolutionizes Elixir debugging by providing:

- **Total Behavioral Recall**: Capture complete execution history with minimal overhead
- **AI-Driven Instrumentation**: Intelligent code analysis and automatic instrumentation planning  
- **Time-Travel Debugging**: Navigate through execution history with intuitive UI
- **Multi-Dimensional Analysis**: Correlate events across temporal, process, state, and performance dimensions
- **Production-Ready Performance**: Sub-microsecond event capture overhead

## 🚀 Current Status

**Version**: 0.1.0 (Foundation Phase)  
**Status**: ✅ **Production Ready Foundation**

### What's Working

✅ **Complete Event Capture Pipeline**
- Ultra-fast ring buffer implementation with <1µs write performance  
- Asynchronous event processing and storage
- ETS-based data access with multiple indexes
- Batch processing with 24x performance improvement

✅ **AI Analysis Engine**  
- Code complexity analysis and pattern recognition
- Instrumentation planning and orchestration
- Rule-based decision making for optimal tracing

✅ **Cross-Framework Integration**
- Phoenix request/response lifecycle
- LiveView mount, events, and state changes  
- GenServer callbacks and state monitoring
- Ecto query tracing
- Phoenix Channels support

✅ **Distributed System Support**
- Node coordination and event synchronization
- Hybrid logical clocks for distributed timing
- Cross-node event correlation

✅ **High-Performance Architecture**
- **310 passing tests** with comprehensive coverage
- Lock-free concurrent data structures
- Configurable sampling and performance budgets
- Production-ready error handling

## 🏗️ Architecture

ElixirScope is built on a **7-layer foundation architecture**:

**Layer 1**: Core data structures and utilities  
**Layer 2**: High-performance event capture pipeline  
**Layer 3**: AST transformation and code instrumentation  
**Layer 4**: AI analysis and planning engine  
**Layer 5**: Cross-framework integration (Phoenix, LiveView, etc.)  
**Layer 6**: Time-travel debugging and correlation  
**Layer 7**: Production monitoring and observability  

## 🚀 Quick Start

### Installation

Add ElixirScope to your `mix.exs`:

```elixir
def deps do
  [
    {:elixir_scope, "~> 0.1.0"}
  ]
end
```

### Basic Usage

1. **Start ElixirScope**:
```elixir
{:ok, _} = ElixirScope.start()
```

2. **Capture Events**:
```elixir
# Manual event capture
ElixirScope.Capture.Ingestor.ingest_function_call(
  buffer, MyModule, :my_function, [arg1, arg2], self(), "correlation-123"
)

# Batch processing (24x faster)
events = [event1, event2, event3]
{:ok, count} = ElixirScope.Capture.Ingestor.ingest_batch(buffer, events)
```

3. **Query Events**:
```elixir
# Get event by ID
{:ok, event} = ElixirScope.Storage.DataAccess.get_event_by_id(event_id)

# Query with filters  
events = ElixirScope.Storage.DataAccess.query_events(%{
  module: MyModule,
  function: :my_function,
  timerange: {start_time, end_time}
})
```

### Configuration

```elixir
# config/config.exs
config :elixir_scope,
  ai: [
    planning: [
      default_strategy: :balanced,
      sampling_rate: 0.8
    ]
  ],
  capture: [
    buffer_size: 1024,
    batch_size: 50,
    async_processing: true
  ]
```

## 📊 Performance

ElixirScope is designed for production use with minimal overhead:

- **Event Capture**: <1µs per event (sub-microsecond performance)
- **Batch Processing**: 24x faster than individual writes (242ns vs 5,825ns per event)
- **Memory Efficient**: Configurable ring buffers with overflow strategies
- **Concurrent Safe**: Lock-free data structures for high throughput

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Run all tests
mix test

# Run performance tests
mix test --include performance

# Run with coverage
mix test --cover
```

**Current Results**: 310 tests, 0 failures ✅

## 📚 Documentation

- **[Technical Architecture](docs/)**: Detailed implementation guides and specifications
- **[Development History](docs_extra/)**: Progress tracking and implementation notes  
- **[API Documentation](https://hexdocs.pm/elixir_scope)**: Complete API reference

## 🛠️ Development

### Prerequisites

- Elixir 1.15+
- Erlang/OTP 25+

### Setup

```bash
git clone https://github.com/yourusername/elixir_scope.git
cd elixir_scope
mix deps.get
mix compile
mix test
```

### Architecture Overview

```
Application
├── AI Layer (Analysis & Planning)
│   ├── CodeAnalyzer - AST analysis and pattern recognition
│   ├── ComplexityAnalyzer - Code complexity scoring  
│   ├── PatternRecognizer - Framework pattern detection
│   └── Orchestrator - AI coordination and planning
├── Capture Layer (Event Pipeline)  
│   ├── InstrumentationRuntime - Lightweight event reporting
│   ├── Ingestor - Fast event processing and validation
│   ├── RingBuffer - Lock-free concurrent event storage
│   └── PipelineManager - Async processing coordination
├── Storage Layer (Data Management)
│   ├── DataAccess - ETS-based storage with indexing
│   ├── EventCorrelator - Cross-event relationship tracking
│   └── AsyncWriter - Background persistence
└── Integration Layer (Framework Support)
    ├── Phoenix - Request/response lifecycle  
    ├── LiveView - Mount, events, state changes
    ├── GenServer - Callback and state monitoring
    └── Distributed - Node coordination
```

## 🚧 Roadmap

### Phase 2: AST Transformation Engine (In Progress)
- [ ] Compile-time code instrumentation
- [ ] Mix compiler integration
- [ ] Semantic preservation testing

### Phase 3: Advanced AI Features
- [ ] LLM integration for intelligent analysis
- [ ] Predictive instrumentation planning
- [ ] Anomaly detection and root cause analysis

### Phase 4: Time-Travel Debugging UI
- [ ] Web-based execution timeline interface
- [ ] Multi-dimensional event visualization  
- [ ] Interactive debugging session management

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality  
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

ElixirScope is released under the MIT License. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built with ❤️ for the Elixir community. Special thanks to:

- The BEAM team for the incredible runtime
- The Elixir core team for the beautiful language
- The Phoenix team for the inspiring framework architecture
- The open source community for continuous innovation

---

**ElixirScope**: Making Elixir debugging as elegant as the language itself. 