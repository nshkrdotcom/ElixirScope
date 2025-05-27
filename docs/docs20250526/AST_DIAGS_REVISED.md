```mermaid
graph TD
    A["Source Code"] --> B["Elixir Compiler"]
    B --> C["AST Generation with Unique Node IDs"]
    C --> D["Enhanced AST Repository (Static Analysis & Runtime Correlation Store)"]
    D --> E["Compile-time Instrumentation Engine (AST.Transformer / EnhancedTransformer)"]
    E --> F["Instrumented AST (injects calls to InstrumentationRuntime with ast_node_id & correlation_id)"]
    F --> G["Enhanced Bytecode"]
    G --> H["Runtime Execution of Instrumented Code"]
    H --> I["InstrumentationRuntime: Captures Runtime Events (e.g., function calls, var snapshots) with ast_node_id & correlation_id"]
    I --> J["Event Ingestor & Processing Pipeline"]
    J --> K["EventCorrelator (links runtime events to specific AST nodes via IDs)"]
    K --> D_Update["ASTRepository.RuntimeCorrelator: Updates AST Repository with Correlated Runtime Data & Insights"]
    D_Update --> D
    J --> L["TemporalStorage (stores events with AST links & timestamps)"]
    L --> M["Cinema Debugger (Hybrid Static+Runtime Views & Analysis)"]
    D --> M_AST["Static AST Data for Debugger"]
    D --> N["LLMContextBuilder (Builds Hybrid Static+Runtime Context)"]
    N --> N_LLM["LLM for Analysis & Code Intelligence"]

    subgraph "Compile-Time Phase"
        direction LR
        C
        D
        E
        F
    end

    subgraph "Runtime Phase & Correlation Feedback Loop"
        direction LR
        H
        I
        J
        K
        D_Update
        L
    end

    subgraph "Analysis & Tooling"
        direction LR
        M
        N
        N_LLM
    end

    style D fill:#c8e6c9,color:#000
    style I fill:#ffe0b2,color:#000
    style K fill:#b3e5fc,color:#000
    style D_Update fill:#b3e5fc,color:#000
    style M fill:#d1c4e9,color:#000
    style N fill:#f0f4c3,color:#000
```

---

## 2. Enhanced AST Repository Components (Revised)

This diagram details the structure of the `ASTRepository` incorporating compile-time and runtime correlated data.

```mermaid
graph LR
    subgraph "Input Sources"
        SourceCode["Source Files"]
        RuntimeEvents["Correlated Runtime Events via RuntimeCorrelator"]
    end

    SourceCode --> Parser["AST Parser with Instrumentation Point Mapping"]
    Parser --> SemanticAnalyzer["Semantic Analyzer (Static Analysis)"]
    SemanticAnalyzer --> Repository["Enhanced AST Repository"]
    RuntimeEvents --> Repository

    subgraph "AST Repository Core Structure (ElixirScope.ASTRepository.Repository)"
        direction TB
        Repository --> Modules["Modules ASTs (with instrumentation point mapping)"]
        Repository --> FuncDefs["Function Definitions (with runtime correlation IDs)"]
        Repository --> PatternMatches["Pattern Matches (with runtime execution data)"]

        Repository --> DepGraph["Hybrid Dependency Graph (Static + Runtime Call Patterns)"]
        Repository --> CallGraph["Hybrid Call Graph (Static + Actual Runtime Paths)"]
        Repository --> DataFlowGraph["Hybrid Data Flow Graph (Static + Runtime Value Transformations)"]
        Repository --> SupervisionTree["Hybrid Supervision Tree (Static OTP + Runtime Process Events)"]

        Repository --> SemanticMeta["Semantic Metadata (Enriched by Runtime)"]
        SemanticMeta --> DomainConcepts["Domain Concepts (Static + Runtime Behavior)"]
        SemanticMeta --> BusinessRules["Business Rules (Static + Runtime Frequency)"]
        SemanticMeta --> ArchPatterns["Architectural Patterns (Static + Runtime Performance)"]

        Repository --> RuntimeCorrelationInfra["Runtime Correlation Infrastructure"]
        RuntimeCorrelationInfra --> InstrumentationPoints["Instrumentation Points (AST nodes to instrumentation calls)"]
        RuntimeCorrelationInfra --> CorrelationIndex["Correlation ID to AST Node Mapping"]
        RuntimeCorrelationInfra --> RuntimeEventBridge["Runtime Event Bridge (Link to Live Event System)"]
        RuntimeCorrelationInfra --> TemporalCorrelation["Temporal Correlation (Time-based AST to Event)"]

        Repository --> HybridAnalysisData["Hybrid Analysis Data"]
        HybridAnalysisData --> StaticAnalysis["Static Analysis Results"]
        HybridAnalysisData --> RuntimeAnalysis["Runtime Behavior Analysis Results"]
        HybridAnalysisData --> HybridInsights["Combined Static + Runtime Insights"]
        HybridAnalysisData --> PerfCorrelation["AST Performance Impact Mapping"]

        Repository --> CinemaDebuggerInt["Cinema Debugger Integration Data"]
        CinemaDebuggerInt --> ExecTimelines["Execution Timelines (AST nodes with execution timeline data)"]
        CinemaDebuggerInt --> VarLifecycles["Variable Lifecycles (Scope + Runtime Value Changes)"]
        CinemaDebuggerInt --> CausalRels["Causal Relationships (Static Dependencies + Runtime Causality)"]
    end

    subgraph "Key AST Repository Modules (lib/elixir_scope/ast_repository/)"
        direction TB
        RepoMod["repository.ex"]
        ParserMod["parser.ex"]
        SemAnalyzerMod["semantic_analyzer.ex"]
        GraphBuilderMod["graph_builder.ex"]
        MetaExtractorMod["metadata_extractor.ex"]
        IncUpdaterMod["incremental_updater.ex"]
        RuntimeCorrMod["runtime_correlator.ex (NEW)"]
        InstMapperMod["instrumentation_mapper.ex (NEW)"]
        SemEnricherMod["semantic_enricher.ex (NEW - runtime aware)"]
        PatternDetectorMod["pattern_detector.ex (NEW - static+dynamic)"]
        ScopeAnalyzerMod["scope_analyzer.ex (NEW - runtime var tracking)"]
        TemporalBridgeMod["temporal_bridge.ex (NEW - temporal events to AST)"]
    end
    Repository --> RepoMod

    style Repository fill:#c8e6c9,color:#000
    style RuntimeCorrelationInfra fill:#b3e5fc,color:#000
    style HybridAnalysisData fill:#fff9c4,color:#000
    style CinemaDebuggerInt fill:#d1c4e9,color:#000
```

---

## 3. Compile-time Instrumentation Pipeline (Revised)

Focuses on how AST is transformed to include calls to `InstrumentationRuntime`.

```mermaid
graph TD
    A["Original AST with Unique Node IDs"] --> B["Pattern Detector (Identifies instrumentation candidates)"]
    B --> C["Instrumentation Planner (Decides what/how to instrument based on Config/Flags)"]
    C --> D["AST Transformer (e.g., AST.EnhancedTransformer)"]
    D --> E["Instrumented AST (Injects `InstrumentationRuntime` calls with `ast_node_id`, `correlation_id`)"]
    E --> F["Bytecode Generator"]
    F --> G["Enhanced Bytecode (Contains calls to ElixirScope.Capture.InstrumentationRuntime)"]

    subgraph "Instrumentation Types (Examples)"
        direction LR
        GTrace["Function Tracing Hooks"]
        HMsg["Message Logging Hooks"]
        IState["State Tracking Hooks"]
        JPerf["Performance Metric Hooks"]
        KConc["Concurrency Event Hooks"]
    end

    C --> GTrace
    C --> HMsg
    C --> IState
    C --> JPerf
    C --> KConc

    GTrace --> D
    HMsg --> D
    IState --> D
    JPerf --> D
    KConc --> D

    L["ElixirScope Config"] --> C
    M["Debug Flags"] --> C

    style A fill:#e3f2fd,color:#000
    style E fill:#e8f5e8,color:#000
    style C fill:#fff3e0,color:#000
    style G fill:#c5e1a5,color:#000
```

---

## 4. Enhanced Event System with AST Correlation (New)

Details the flow of events from instrumentation to storage, emphasizing AST correlation.

```mermaid
graph TD
    A["Instrumented Code Execution"] -->
    B["ElixirScope.Capture.InstrumentationRuntime"]
    B --"Generates event with ast_node_id, correlation_id, data, timestamp"--> C["ElixirScope.Capture.Ingestor"]
    C --"Ingests AST-correlated event"--> D["Processing Pipeline (PipelineManager)"]
    D --> E["ElixirScope.Capture.RingBuffer (Temporal indexing, efficient storage)"]
    D --> F["ElixirScope.Capture.EventCorrelator (Further AST correlation, linking event streams)"]
    F --> G["ASTRepository.RuntimeCorrelator (Updates AST Repo with runtime insights)"]
    E --> H["ElixirScope.Capture.AsyncWriter (Persists events)"]
    H --> I["ElixirScope.Capture.TemporalStorage (NEW - Time-based event storage with AST links)"]

    subgraph "Key Event System Modules (lib/elixir_scope/capture/)"
        direction TB
        InstRuntime["instrumentation_runtime.ex (Enhanced with AST correlation)"]
        IngestorMod["ingestor.ex (Enhanced with AST node mapping)"]
        RingBufferMod["ring_buffer.ex (Enhanced with temporal indexing)"]
        EventCorrMod["event_correlator.ex (Enhanced with AST correlation)"]
        AsyncWriterMod["async_writer.ex (Enhanced with AST metadata)"]
        PipelineManMod["pipeline_manager.ex (Enhanced with hybrid processing)"]
        TemporalStorMod["temporal_storage.ex (NEW)"]
    end

    B --> InstRuntime
    C --> IngestorMod
    E --> RingBufferMod
    F --> EventCorrMod
    H --> AsyncWriterMod
    D --> PipelineManMod
    I --> TemporalStorMod

    style B fill:#ffe0b2,color:#000
    style C fill:#ffccbc,color:#000
    style E fill:#c8e6c9,color:#000
    style I fill:#b3e5fc,color:#000
    style G fill:#d1c4e9,color:#000
```

---

## 5. Core Hybrid Correlation Flow (New)

Illustrates the lifecycle of correlation from AST to runtime event and back.

```mermaid
graph TD
    subgraph "Compile Time"
        A["Source Code"] --> B{"AST Parser"}
        B -- "Assigns unique ast_node_id to each relevant AST node" --> C["AST Node with ast_node_id"]
        C --> D{"AST.Transformer"}
        D -- "Injects call to InstrumentationRuntime, passing ast_node_id & generating correlation_id" --> E["Instrumented Code Snippet e.g., `InstrumentationRuntime.log_entry(correlation_id, ast_node_id, data)`"]
    end

    subgraph "Runtime"
        F["Execution of Instrumented Code Snippet"] --> G["InstrumentationRuntime Function Called"]
        G -- "Event created: {type, data, timestamp, ast_node_id, correlation_id, process_id}" --> H["Runtime Event"]
    end

    subgraph "Event Processing & Correlation"
        H --> I["Event Ingestor"]
        I --> J["EventCorrelator"]
        J -- "Links event to ast_node_id using correlation_id" --> K["Correlated Event"]
    end

    subgraph "AST Repository Update & Usage"
        K --> L["ASTRepository.RuntimeCorrelator"]
        L -- "Updates AST node (identified by ast_node_id) with runtime data/insights" --> M["Enhanced AST Node in Repository (Static + Runtime Info)"]
        M --> N["LLM Context Builder, Cinema Debugger, Analyzers"]
    end

    subgraph "Temporal Bridging"
        K --> O["TemporalStorage"]
        O --> P["ASTRepository.TemporalBridge"]
        P -- "Correlates temporal event sequences with AST structures" --> M
    end

    style C fill:#e3f2fd,color:#000
    style E fill:#e8f5e8,color:#000
    style H fill:#ffe0b2,color:#000
    style K fill:#b3e5fc,color:#000
    style M fill:#c8e6c9,color:#000
```

---

## 6. LLM Integration Architecture with Hybrid Context (Revised)

Shows how the LLM leverages both static AST and runtime correlated data.

```mermaid
graph LR
    subgraph "Data Sources for LLM Context"
        A["Enhanced AST Repository (Static analysis, semantic patterns, dependencies, arch patterns + correlated runtime insights)"]
        B["Runtime Event System (Execution patterns, performance data, error patterns, variable lifecycles via TemporalStorage & RuntimeCorrelator)"]
    end

    A --> C["ElixirScope.LLM.ContextBuilder (NEW - Builds Hybrid Context)"]
    B --> C

    subgraph "ContextBuilder Components & Output"
        direction TB
        C --> StaticCtx["Static Context (AST structure, semantics)"]
        C --> RuntimeCtx["Runtime Context (Execution traces, performance)"]
        C --> CorrelationCtx["Correlation Context (Static-to-Runtime mapping, causal links from TemporalBridge)"]
        C --> PerformanceCtx["Performance Context (Specific runtime metrics linked to AST)"]
        ContextGroup[StaticCtx, RuntimeCtx, CorrelationCtx, PerformanceCtx] --> CompactedContext["Compacted Hybrid Context for LLM"]
    end

    CompactedContext --> D["ElixirScope.LLM.PromptGenerator (NEW - Creates prompts with hybrid data)"]
    D --> E["LLM Interface (ElixirScope.LLM.Client - Enhanced)"]
    E --> F["LLM (External or Local)"]
    F --> G["AI Response"]
    G --> H["ElixirScope.LLM.ResponseProcessor (NEW - Processes response, correlates with AST)"]

    subgraph "Key LLM Modules (lib/elixir_scope/llm/ - Enhanced)"
        direction TB
        ClientMod["client.ex"]
        ProviderMod["provider.ex"]
        ResponseMod["response.ex"]
        ConfigMod["config.ex"]
        CtxBuilderMod["context_builder.ex (NEW)"]
        SemCompactorMod["semantic_compactor.ex (NEW - uses runtime insights)"]
        PromptGenMod["prompt_generator.ex (NEW)"]
        RespProcMod["response_processor.ex (NEW)"]
        HybridAnalyzerMod["hybrid_analyzer.ex (NEW - analyzes using static+runtime)"]
    end
    C --> CtxBuilderMod
    E --> ClientMod
    H --> RespProcMod

    subgraph "LLM Tasks (Examples)"
        M["Code Completion (Context-aware)"]
        N["Bug Analysis (Leveraging runtime traces)"]
        O["Refactoring Suggestions (Informed by static & dynamic data)"]
        P["Pattern Recognition (Hybrid patterns)"]
    end
    E --> M
    E --> N
    E --> O
    E --> P

    subgraph "Output Actions (Examples)"
        Q["Code Generation (Applied to AST)"]
        R["Debug Guidance (Based on hybrid insights)"]
        S["Optimization Hints (Correlated with performance data)"]
        T["Architecture Advice (Holistic view)"]
    end
    H --> Q
    H --> R
    H --> S
    H --> T

    style C fill:#c8e6c9,color:#000
    style CompactedContext fill:#fff3e0,color:#000
    style H fill:#f3e5f5,color:#000
```

---

## 7. Cinema Debugger Data Flow with Hybrid Visualization (Revised)

Illustrates how the Cinema Debugger uses both static AST and correlated runtime event data.

```mermaid
graph LR
    subgraph "Data Inputs"
        A["Runtime Events with AST Correlation IDs (from TemporalStorage & EventCorrelator)"]
        G["Enhanced AST Repository (Static code structure, semantics, pre-correlated runtime summaries)"]
    end

    A --> B["Event Collector / Processor (Debugger specific)"]
    B --> C["Debugger's Internal Timeline State (Correlated events, variable snapshots)"]
    G --> H["Code Context Provider (Provides AST details for visualization)"]

    C --> E["Timeline Builder (Constructs hybrid execution timeline)"]
    H --> E

    E --> F["Visualization Engine (Renders hybrid views)"]

    subgraph "Cinema Debugger Modules (lib/elixir_scope/cinema_debugger/)"
        DebuggerMod["debugger.ex"]
        VisEngineMod["visualization_engine.ex"]
        TimeTravelMod["time_travel_controller.ex"]
        BreakpointManMod["interactive/breakpoint_manager.ex (Hybrid breakpoints)"]
        HypoTesterMod["interactive/hypothesis_tester.ex (Uses hybrid data)"]
    end
    F --> VisEngineMod

    subgraph "Hybrid Views (Examples - visualization_engine.ex & views/*)"
        direction LR
        N["AST View (Static structure)"]
        O["Execution Timeline View (Runtime events mapped to time)"]
        P["Correlation View (NEW - Explicit AST-Runtime links visualized)"]
        Q["Variable Lifecycle View (Runtime value changes over time, linked to AST scopes)"]
        R["Performance View (NEW - Performance metrics overlaid on AST/timeline)"]
    end
    F --> N
    F --> O
    F --> P
    F --> Q
    F --> R

    subgraph "Interactive Features (interactive/*)"
        direction LR
        S["Time Travel (Through correlated hybrid timeline)"]
        T["Hybrid Breakpoints (AST node + runtime conditions)"]
        U["Hypothesis Testing (Using static & runtime data)"]
        V["Causal Analysis (Using hybrid data from analysis/*)"]
    end
    F --> S
    F --> T
    F --> U
    F --> V

    subgraph "Analysis Modules (analysis/*)"
        PatternAnalyzer["pattern_analyzer.ex (Static+Runtime patterns)"]
        PerfAnalyzer["performance_analyzer.ex"]
        CausalAnalyzer["causal_analyzer.ex"]
        AnomalyDetector["anomaly_detector.ex (Hybrid data)"]
    end
    E --> PatternAnalyzer
    E --> PerfAnalyzer
    E --> CausalAnalyzer
    E --> AnomalyDetector


    style C fill:#e8f5e8,color:#000
    style F fill:#f3e5f5,color:#000
    style H fill:#fff3e0,color:#000
    style P fill:#ffcdd2,color:#000
    style R fill:#ffcdd2,color:#000
    style T fill:#ffcdd2,color:#000
```

---

## 8. Detailed AST Transformation Process (Revised for Hybrid Output)

Clarifies the transformation process leading to instrumented code ready for hybrid data capture.

```mermaid
graph TD
    A["Source Code"] --> B["Lexer/Parser"]
    B --> C["Raw AST"]
    C -- "Assigns unique ast_node_id" --> C_ID["Raw AST with Node IDs"]
    C_ID --> D["Semantic Enricher (Initial static enrichment, e.g. type info, scope)"]
    D --> E["Enhanced AST (Static)"]

    E --> F["Instrumentation Selector (Based on Config, Debug Flags)"]
    F --> G{"Instrumentation Enabled?"}

    G -->|Yes| H["AST Transformer (e.g., ElixirScope.AST.EnhancedTransformer)"]
    G -->|No| I["Direct Compilation Path (No ElixirScope Instrumentation)"]

    subgraph "Instrumentation Logic (within AST Transformer)"
        H --> J["Pattern Matcher (Identifies specific code structures to instrument)"]
        J --> K["Function Instrumenter (Wraps calls, captures args/return, passes ast_node_id, correlation_id)"]
        J --> L["Message Instrumenter (Logs sends/receives, passes ast_node_id, correlation_id)"]
        J --> M["State Instrumenter (Captures state changes, passes ast_node_id, correlation_id)"]
        J --> N["Concurrency Instrumenter (Tracks process events, passes ast_node_id, correlation_id)"]
    end

    K --> O["Instrumented AST (Contains calls to ElixirScope.Capture.InstrumentationRuntime with IDs)"]
    L --> O
    M --> O
    N --> O

    O --> P["Code Generator"]
    I --> P
    P --> Q["Bytecode (Instrumented or Non-Instrumented)"]

    subgraph "AST Metadata (Static)"
        R["Line Numbers"]
        S["Type Info"]
        T["Scope Data"]
        U["Pattern Data"]
    end
    D --> R
    D --> S
    D --> T
    D --> U

    subgraph "Instrumentation Rules (Input to Selector F)"
        V["Trace Functions"]
        W["Log Messages"]
        X["Monitor State"]
        Y["Track Processes"]
    end
    F --> V
    F --> W
    F --> X
    F --> Y

    style E fill:#e8f5e8,color:#000
    style O fill:#fff3e0,color:#000
    style H fill:#f3e5f5,color:#000
    style Q fill:#c5e1a5,color:#000
```

---

## 9. Comprehensive System Integration (Revised for Hybrid Flows)

High-level overview emphasizing the central role of the hybrid AST Repository and event correlation.

```mermaid
graph LR
    A["Developer IDE"] --> B["ElixirScope AST System (Compile-Time)"]
    C["Source Files"] --> B
    D["Git Repository"] --> B

    B --> E["Enhanced AST Repository (Static + Correlated Runtime Data)"]
    E --> F["Instrumentation Engine (Compile-Time AST Transformation)"]
    E --> G["LLM Integration (Hybrid Context Builder)"]
    E --> H["Cinema Debugger (Hybrid Visualization & Analysis)"]

    F -- "Produces Instrumented Bytecode" --> I["Runtime System (Execution of App Code)"]
    I -- "Generates Runtime Events with ast_node_id, correlation_id" --> J["Event Collection & Correlation Pipeline (InstrumentationRuntime, Ingestor, EventCorrelator)"]
    J -- "Correlated Events" --> K["Temporal Database (Events with AST Links)"]
    K --> H_Input["Input to Cinema Debugger"]
    J -- "Updates AST Repo via RuntimeCorrelator" --> E_Feedback["Feedback to AST Repository"]


    G --> L["LLM Context Builder (Uses E)"]
    L --> M["Code Compactor (Uses E)"]
    M --> N["AI Assistant (Queries LLM)"]

    H --> O["Time Travel UI (Uses K & E)"]
    H --> P["Causal Analysis (Uses K & E)"]
    H --> Q["Hypothesis Testing (Uses K & E)"]

    subgraph "Core Development Loop"
        R["Code"] --> S["Compile (with ElixirScope Instrumentation)"]
        S --> T["Run (Generates Correlated Events)"]
        T --> U["Debug (Cinema Debugger with Hybrid Data)"]
        U --> V["Analyze (LLM & Static/Dynamic Analysis from E)"]
        V --> R
    end

    B --> R
    F --> S
    I --> T
    H --> U
    N --> V
    E --> V


    subgraph "AI Capabilities (Powered by G & E)"
        W["Smart Completion"]
        X["Bug Prediction/Analysis"]
        Y["Refactoring Assistance"]
        Z["Pattern Suggestion (Hybrid)"]
    end
    N --> W
    N --> X
    N --> Y
    N --> Z

    subgraph "Debugging Features (Powered by H, K & E)"
        AA["Visual Hybrid Timeline"]
        BB["Process Inspector (Correlated)"]
        CC["Message Tracer (Correlated)"]
        DD["State Monitor (Correlated)"]
    end
    H --> AA
    H --> BB
    H --> CC
    H --> DD

    style E fill:#c8e6c9,color:#000
    style J fill:#b3e5fc,color:#000
    style H fill:#d1c4e9,color:#000
    style N fill:#f0f4c3,color:#000
    linkStyle 9 stroke:#ff0000,stroke-width:2px,color:red;
```