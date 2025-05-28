# ElixirScope

[![Hex.pm](https://img.shields.io/hexpm/v/elixir_scope.svg)](https://hex.pm/packages/elixir_scope)
[![Elixir CI](https://github.com/nshkrdotcom/ElixirScope/workflows/CI/badge.svg)](https://github.com/nshkrdotcom/ElixirScope/actions)
[![Coverage Status](https://coveralls.io/repos/github/nshkrdotcom/ElixirScope/badge.svg?branch=main)](https://coveralls.io/github/nshkrdotcom/ElixirScope?branch=main)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg)](https://opensource.org/licenses/MIT)

**Revolutionary AST-based debugging and code intelligence platform for Elixir applications**

ElixirScope transforms debugging from a line-by-line process into a cinematic experience by combining compile-time AST instrumentation with runtime event correlation, all guided by AI-powered analysis. It provides deep observability into your Elixir applications, enabling time-travel debugging, comprehensive event capture, and intelligent analysis of concurrent systems.

## 🚀 Current Status

- **Latest Release**: v0.0.1 (Foundation Release) - [Hex.pm](https://hex.pm/packages/elixir_scope)
- **Development**: v0.0.2 - Enhanced AST Repository & Core Graphing Capabilities (Active)
- **Demo**: Fully functional Cinema Demo showcasing core v0.0.1 capabilities and foundational elements for v0.0.2.

## 📦 Installation

To add ElixirScope to your project, include it in your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:elixir_scope, "~> 0.0.1"}
  ]
end
```

For the latest development version (main branch, targeting v0.0.2 features):
```elixir
def deps do
  [
    {:elixir_scope, github: "nshkrdotcom/ElixirScope", branch: "main"}
  ]
end
```

Then, run `mix deps.get`.

## 🎯 Key Features

### Available Now (v0.0.1 & early v0.0.2 foundations)
- **⚡ High-Performance Event Capture**: Core event capture pipeline with low overhead (target <100µs per instrumented call) using correlation IDs.
- **🎬 Foundational Cinema Debugger**: Basic time-travel debugging capabilities with state reconstruction for GenServers.
- **🤖 AI-Powered Analysis (LLM Integration)**: Multi-provider LLM support (Gemini, Vertex AI, Mock) for code analysis, error explanation, and fix suggestions.
- **🔍 AST Instrumentation (Compile-Time)**: Core AST transformation engine to inject instrumentation calls.
- **📊 Basic Performance Monitoring**: Real-time metrics for event capture and core system components.
- **🔄 Basic State Reconstruction**: Ability to query GenServer state at specific past timestamps.
- **🌳 Enhanced AST Repository (Foundational v0.0.2)**:
    - Core GenServer for storing enhanced module and function data.
    - AST parsing with unique Node ID assignment (`ElixirScope.ASTRepository.Parser`, `NodeIdentifier`).
    - Initial CFG, DFG, and CPG generation capabilities (`ElixirScope.ASTRepository.Enhanced.{CFGGenerator, DFGGenerator, CPGBuilder}`).
    - Project population and file watching/synchronization mechanisms (`ProjectPopulator`, `FileWatcher`, `Synchronizer`).
    - Advanced data structures for AST, CFG, DFG, and CPG representation.
    - Query building and execution foundations (`QueryBuilder`, `QueryExecutor`).
    - Memory management and pattern matching infrastructure (`MemoryManager`, `PatternMatcher`).

### Coming in v0.0.2 (Full Release - Target: May 2025)
- **🌳 Fully Operational Enhanced AST Repository**: Persistent, queryable storage for ASTs, CFGs, DFGs, and CPGs with optimized ETS backend.
- **📈 Complete Code Property Graphs**: Robust generation and unification of AST, Control Flow Graphs (CFG), and Data Flow Graphs (DFG - SSA based).
- **🔗 Deep Runtime-AST Correlation**: Precise linking of runtime events to specific AST sub-trees and CPG nodes using stable AST Node IDs.
- **🎯 Semantic Code Search & Advanced Queries**: AI-powered semantic search across the CPG; rich query language for static and dynamic data via `QueryEngine.ASTExtensions`.
- **🚨 Predictive Debugging & Advanced AI**: ML-based error prediction, performance bottleneck identification, and more sophisticated AI insights leveraging CPGs.
- **🔧 Advanced Debugging Tools**: Fully functional structural breakpoints, data flow breakpoints, and semantic watchpoints integrated with the enhanced repository.

## 🏗️ Architecture

ElixirScope's architecture is designed for deep analysis and runtime observability. The Enhanced AST Repository (v0.0.2) is a central component.

```mermaid
graph TB
    subgraph CT["Compile Time (v0.0.2 Focus)"]
        direction LR
        SRC[Source Code .ex/.exs] --> MIX_COMPILER{Mix.Tasks.Compile.ElixirScope}
        MIX_COMPILER --> ORCH[CompileTime.Orchestrator]
        ORCH --> AI_PLAN_CA[AI.CodeAnalyzer for Plan]
        AI_PLAN_CA --> PLAN[Instrumentation Plan]

        MIX_COMPILER --> PARSER_NODER[ASTRepository.Parser & NodeIdentifier]
        PARSER_NODER -- AST w/ NodeIDs --> AST_ANALYZER[ASTRepository.ASTAnalyzer]
        AST_ANALYZER -- EnhancedModule/FunctionData --> REPO_API[EnhancedRepository API]
        AST_ANALYZER -- Function ASTs --> GRAPH_GENS[Graph Generators (CFG, DFG, CPG)]
        GRAPH_GENS --> REPO_API


        PARSER_NODER -- AST w/ NodeIDs --> TRANSFORMER[AST.EnhancedTransformer]
        PLAN ==> TRANSFORMER
        TRANSFORMER --> INSTR_AST[Instrumented AST .beam]
    end

    subgraph RT["Runtime System"]
        direction LR
        INSTR_AST -- Executes --> APP[User Application]
        APP -- Calls (Event + AST Node ID) --> RUNTIME_API[Capture.InstrumentationRuntime]
        RUNTIME_API --> CAPTURE_PIPELINE[Capture.PipelineManager (Ingestor, RingBuffer, AsyncWriters)]
        CAPTURE_PIPELINE --> EVENT_STORE_SVC[Storage.EventStore Service]

        RUNTIME_API -- AST-Aware Events --> ENH_INSTR[Capture.EnhancedInstrumentation]
        ENH_INSTR --> RUNTIME_CORR[ASTRepository.RuntimeCorrelator]
        RUNTIME_CORR -- AST/CPG Context --> ENH_REPO_GS[EnhancedRepository GenServer]
        ENH_INSTR --> DEBUG_ACTIONS[Breakpoint/Watchpoint Actions]

        RUNTIME_API --> TEMP_BRIDGE_ENH[Capture.TemporalBridgeEnhancement]
        TEMP_BRIDGE_ENH <--> RUNTIME_CORR
        TEMP_BRIDGE_ENH <--> TEMP_STORAGE[Capture.TemporalStorage]
    end

    subgraph AN["Analysis & Query"]
        direction LR
        ENH_REPO_GS <--> ETS_STATIC_DATA[(ETS: Enhanced AST, CFG, DFG, CPG Data)]
        EVENT_STORE_SVC <--> ETS_RUNTIME_EVENTS[(ETS: Runtime Events)]
        TEMP_STORAGE <--> ETS_TEMPORAL_EVENTS[(ETS: Time-Indexed Events)]

        QUERY_ENGINE_EXT[QueryEngine.ASTExtensions] <--> ENH_REPO_GS
        QUERY_ENGINE_EXT <--> EVENT_STORE_SVC
        QUERY_ENGINE_EXT --> UI_API[UI/API Layer / Cinema Debugger]

        AI_COMPONENTS[AI Components (IntelligentCodeAnalyzer, PredictiveAnalyzer)] <--> AI_BRIDGE[AI.Bridge]
        AI_BRIDGE <--> QUERY_ENGINE_EXT
        AI_COMPONENTS --> ORCH
    end

    style SRC fill:#f9f,stroke:#333,stroke-width:2px
    style INSTR_AST fill:#f9f,stroke:#333,stroke-width:2px
    style ETS_STATIC_DATA fill:#e0f7fa,stroke:#006064,stroke-width:2px
    style ETS_RUNTIME_EVENTS fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    style ETS_TEMPORAL_EVENTS fill:#fff3e0,stroke:#e65100,stroke-width:2px

    style CT fill:#eceff1,stroke:#37474f,color:#000
    style RT fill:#eceff1,stroke:#37474f,color:#000
    style AN fill:#eceff1,stroke:#37474f,color:#000

    style ENH_REPO_GS fill:#f57c00,stroke:#e65100,stroke-width:2px,color:#fff
```
**Diagram Description:**
*   **Compile Time**: Source code is parsed, AST Node IDs are assigned. The `ASTAnalyzer` and various Graph Generators (CFG, DFG, CPG) process the ASTs. This rich static data is stored in the `EnhancedRepository` (via its API, managed by the `EnhancedRepository GenServer`). An `Instrumentation Plan` (potentially AI-driven) guides the `EnhancedTransformer` in injecting `InstrumentationRuntime` calls (with AST Node IDs) into the code.
*   **Runtime System**: Instrumented code emits events to `InstrumentationRuntime`. These events, tagged with AST Node IDs, flow through the capture pipeline (`Ingestor`, `RingBuffer`, `AsyncWriterPool`) to `EventStore`. AST-aware events also go to `EnhancedInstrumentation` for breakpoint/watchpoint evaluation, which uses `RuntimeCorrelator` to link with static data from the `EnhancedRepository`. `TemporalBridgeEnhancement` also uses `RuntimeCorrelator` for time-travel context.
*   **Analysis & Query**: The `EnhancedRepository GenServer` manages ETS tables for static data (ASTs, CFGs, DFGs, CPGs). `EventStore` and `TemporalStorage` manage runtime and time-indexed events respectively. `QueryEngine.ASTExtensions` provides a unified interface to query both static and dynamic data, enabling correlated analysis. AI components leverage this through `AI.Bridge`.

## 🎬 Try the Cinema Demo

Experience ElixirScope's core v0.0.1 capabilities with our comprehensive demo:

```bash
git clone https://github.com/nshkrdotcom/ElixirScope.git
cd ElixirScope/test_apps/cinema_demo
./run_showcase.sh
```

The demo currently showcases:
- GenServer state tracking and lifecycle debugging (foundational).
- Complex data transformation pipeline analysis (basic event capture).
- Time-travel debugging with state reconstruction (using `TemporalBridge` and new APIs).
- Performance bottleneck identification (rudimentary).
- Error correlation and root cause analysis (basic).
- Foundational AST-runtime correlation (as APIs are completed).

## 🚦 Quick Start

### Basic Setup

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    # Your other children...
    ElixirScope # Starts ElixirScope.Application and its supervisor
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### Configuration (`config/config.exs`)

```elixir
# config/dev.exs
config :elixir_scope,
  ai: [
    planning: [
      default_strategy: :balanced, # :minimal | :balanced | :full_trace
      sampling_rate: 1.0          # 0.0 to 1.0
    ]
  ],
  capture: [
    ring_buffer: [ size: 1_048_576, max_events: 100_000 ]
  ],
  storage: [
    hot: [ max_events: 1_000_000, max_age_seconds: 3600 ]
  ]

# config/prod.exs
config :elixir_scope,
  ai: [ planning: [ default_strategy: :minimal, sampling_rate: 0.1 ]],
  capture: [ ring_buffer: [ size: 524_288, max_events: 50_000 ]]
```
For Enhanced AST Repository specific configurations (v0.0.2+):
```elixir
# config/dev.exs
config :elixir_scope, :ast_repository,
  max_memory_mb: 1024,
  populator_include_test_files: true,
  generate_cpg: true # Enable CPG generation for development
```
See `ElixirScope.Config` and `ElixirScope.ASTRepository.Config` for all options.

### Time-Travel Debugging & Event Querying

```elixir
# Start ElixirScope (typically in application.ex)
ElixirScope.start()

# Your application runs...

# Query recent events for a specific process
events = ElixirScope.get_events(pid: some_pid, limit: 50)

# Reconstruct GenServer state at a past timestamp
# Ensure TemporalBridge and TemporalStorage are running for this.
# Example: ElixirScope.Capture.TemporalBridge.start_link(name: :my_bridge)
# ElixirScope.Capture.TemporalBridge.register_as_handler(:my_bridge)
past_state = ElixirScope.get_state_at(genserver_pid, past_timestamp_ns)

# For AST-aware time-travel (v0.0.2 features):
# {:ok, enhanced_state} = ElixirScope.Capture.TemporalBridgeEnhancement.reconstruct_state_with_ast(
#   session_id, past_timestamp_ns, EnhancedRepository
# )
```

### AI-Powered Analysis & Enhanced Repository (v0.0.2 Focus)

```elixir
# Populate the Enhanced AST Repository (e.g., in a Mix task or dev startup)
# {:ok, repo_pid} = ElixirScope.ASTRepository.Enhanced.Repository.start_link()
# ElixirScope.ASTRepository.Enhanced.ProjectPopulator.populate_project(repo_pid, "/path/to/your/project")

# Analyze codebase using AI components
# {:ok, insights} = ElixirScope.AI.Analysis.IntelligentCodeAnalyzer.assess_quality(File.read!("lib/my_module.ex"))

# Query the Enhanced AST Repository
# query_spec = ElixirScope.ASTRepository.QueryBuilder.find_functions()
#              |> ElixirScope.ASTRepository.QueryBuilder.where(:complexity_score, :gt, 10.0)
# {:ok, complex_functions} = ElixirScope.ASTRepository.Enhanced.Repository.query_analysis(:functions, query_spec)
# Or using QueryEngine.ASTExtensions for correlated queries.
```

## 📊 Performance Impact

ElixirScope is engineered for production use with minimal overhead.

| Metric                      | Target (v0.0.1)         | Target (v0.0.2+)           | Notes                                                                 |
|-----------------------------|-------------------------|----------------------------|-----------------------------------------------------------------------|
| Event Capture Overhead      | <100µs                  | <50µs (AST-aware)          | Per instrumented function call (average, balanced strategy)           |
| Memory Overhead (Runtime)   | ~50MB                   | ~50-100MB                  | For typical applications, excluding persistent AST data                 |
| Event Ingestion Throughput  | >100k events/sec        | >150k events/sec           | To `RingBuffer`                                                       |
| Query Response (Runtime)    | <100ms (1k events)      | <50ms (1k events)          | For common event queries                                              |
| AST Analysis (Compile-Time) | N/A                     | <100ms/module (avg)        | For AST parsing, basic analysis, CFG/DFG generation                   |
| CPG Generation (Compile-Time)| N/A                     | <500ms/module (avg)        | Can be intensive; opt-in or background processed                      |
| AST Repo Memory (Static)    | N/A                     | <500MB (1000 modules)     | For storing `EnhancedModuleData`, CPG summaries, indexes              |
| Correlated Query Response   | N/A                     | <200ms                     | For queries joining static AST/CPG with runtime events                 |

*Actual overhead depends on the chosen instrumentation strategy, sampling rate, and application characteristics.*

## 🔧 Development

### Running Tests

```bash
# Run all tests (currently 1072 tests, 0 failures, 76 excluded by default)
# Excluded tests are typically live API tests or performance benchmarks marked :skip.
mix test

# Run with code coverage
mix coveralls.github

# Run specific test suites or files using aliases in mix.exs or test_runner.sh
./test_runner.sh --summary                # Quick summary
./test_runner.sh --quick                  # Fast, single-threaded subset
./test_runner.sh --specific path/to/test_file.exs
mix test.llm                              # Run LLM integration tests (excluding live)
mix test.llm.live                         # Run live LLM API tests (requires setup)
```

### LLM Provider Setup

For tests or features involving live LLM calls:

```bash
# For Gemini API
export GEMINI_API_KEY="your-google-ai-studio-api-key"
# Optionally:
# export GEMINI_BASE_URL="custom-gemini-endpoint"
# export GEMINI_DEFAULT_MODEL="gemini-1.5-pro-latest"

# For Vertex AI API
export VERTEX_JSON_FILE="/path/to/your-gcp-service-account.json"
# Optionally:
# export VERTEX_MODEL="gemini-1.5-flash-001" # Or other compatible model
```
Ensure your GCP project for Vertex AI has the "Vertex AI API" enabled.

### Contributing

We welcome contributions! Please see our `CONTRIBUTING.md` (to be created) for guidelines on pull requests, issue reporting, and development setup.

Current focus areas for v0.0.2 and beyond:
-   🌐 Phoenix web interface for the Execution Cinema.
-   🎨 Advanced visual debugging tools and interactive execution timelines.
-   🧠 Enhancing AI models for more accurate CPG-based analysis and prediction.
-   ⚙️ Optimizing CPG storage and query performance for very large codebases.
-   🔗 Robust inter-procedural analysis (cross-function data flow in CPGs).
-   📚 Comprehensive documentation, tutorials, and usage examples.
-   🧪 Expanding property-based testing and introducing chaos testing for resilience.

## 📈 Roadmap

### v0.0.2 (Enhanced AST Repository - In Progress - Target May 2025)
-   [x] Design Enhanced AST Repository, CFG, DFG, CPG data structures.
-   [x] Implement core AST parsing with Node ID assignment.
-   [x] Foundational CFG, DFG, CPG generators.
-   [x] Basic `EnhancedRepository` GenServer with ETS storage for modules/functions.
-   [x] Initial `ProjectPopulator`, `FileWatcher`, `Synchronizer` for repository updates.
-   [ ] **Next**: Full CPG persistence, advanced query capabilities, refined graph generation, robust `RuntimeCorrelator` for deep AST-event linking.

### v0.1.0 (Execution Cinema Alpha - Target June 2025)
-   [ ] Initial Phoenix web interface for basic event viewing and AST navigation.
-   [ ] Visual time-travel debugger (alpha) leveraging `TemporalBridgeEnhancement`.
-   [ ] Real-time event streaming to UI.
-   [ ] Interactive execution timeline (basic).

### v0.2.0 (Advanced Analysis & Distributed Tracing Beta - Target July 2025)
-   [ ] Distributed tracing support across ElixirScope-enabled nodes.
-   [ ] Advanced AI predictions (performance, errors) using CPG and runtime data.
-   [ ] Initial IDE integration concepts (e.g., ElixirLS).
-   [ ] More sophisticated production deployment patterns and guides.

### v1.0.0 (Public Release - Target Q3 2025)
-   [ ] Stable API guarantee for core features.
-   [ ] Comprehensive performance optimization tools and dashboards.
-   [ ] Enterprise-focused features (e.g., advanced security, compliance reporting).
-   [ ] Full documentation suite.

## 🎓 Resources

-   **Core Documentation**: `mix docs` or [HexDocs](https://hexdocs.pm/elixir_scope) (once published for v0.0.2+)
-   **Cinema Demo Guide**: [test_apps/cinema_demo/README.md](test_apps/cinema_demo/README.md)
-   **Design Documents (v0.0.2 - CPG & Enhanced AST)**:
    -   [Code Property Graph Design Enhancements](docs/docs20250527_2/CODE_PROPERTY_GRAPH_DESIGN_ENHANCE/README.md)
    -   [API Documentation (Generated)](docs/API_DOCUMENTATION.md)
    -   [Design Overview (Generated)](docs/DESIGN_OVERVIEW.md)
    -   [Integration Guide (Generated)](docs/INTEGRATION_GUIDE.md)
-   **Original Write-ups (v0.0.1 Foundation)**: [docs/docs20250527_2/WRITEUP_CURSOR/README.md](docs/docs20250527_2/WRITEUP_CURSOR/README.md)

## 💬 Community

-   **GitHub Issues**: [Questions, Bugs, Feature Requests](https://github.com/nshkrdotcom/ElixirScope/issues)
-   **Elixir Forum**: Tag posts with `elixir-scope` for community discussion.
-   **X/Twitter**: Follow [@nshkrdotcom](https://x.com/nshkrdotcom) (project maintainer) for updates.

## 📊 Comparison with Other Tools

| Feature                     | ElixirScope (v0.0.2 Target) | Recon      | Observer   | Otter      |
|-----------------------------|-----------------------------|------------|------------|------------|
| AST-based Instrumentation   | ✅ (Deep, CPG-aware)        | ❌         | ❌         | ❌         |
| Time-Travel Debugging       | ✅ (AST-correlated)         | ❌         | ❌         | ❌         |
| AI-Powered Analysis         | ✅ (CPG, Runtime)           | ❌         | ❌         | ❌         |
| Code Property Graphs (CPG)  | ✅                          | ❌         | ❌         | ❌         |
| Runtime Overhead (Balanced) | <1-2%                       | <1% (est.) | UI only    | <1-3% (est.)|
| State Reconstruction        | ✅ (AST-contextual)         | Limited    | Basic      | Limited    |
| Compile-Time Integration    | ✅ (Deep Analysis)          | ❌         | ❌         | ❌         |
| Semantic Code Search        | ✅ (Planned, CPG/AI)        | ❌         | ❌         | ❌         |
| Predictive Debugging        | ✅ (Planned, ML)            | ❌         | ❌         | ❌         |

## 🙏 Acknowledgments

ElixirScope builds upon the excellent Elixir ecosystem and is inspired by advanced debugging concepts from other languages and research:
-   The Elixir core team for a highly introspectable and extensible language.
-   The Phoenix team for inspiring real-time capabilities and developer experience.
-   The Erlang/OTP team for the robust, concurrent foundation.
-   The creators of tools like `recon`, `observer`, and `otter` for paving the way in Elixir observability.
-   Research in Code Property Graphs and program analysis that informs our advanced features.
-   The Elixir community for its continuous support and innovation.

## 📄 License

Copyright (c) 2025 ElixirScope Contributors

Licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">
  <strong>ElixirScope</strong><br>
  <em>See your code run. Understand how it works. Debug with confidence.</em><br>
  <br>
  <a href="https://hex.pm/packages/elixir_scope">Hex</a> •
  <a href="https://github.com/nshkrdotcom/ElixirScope">GitHub</a> •
  <a href="https://hexdocs.pm/elixir_scope">Docs</a>
</div>