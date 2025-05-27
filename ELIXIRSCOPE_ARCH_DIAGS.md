# ElixirScope Architecture Diagrams

## 1. High-Level System Architecture

```mermaid
graph TB
    subgraph "Developer Environment"
        IDE[IDE/Editor]
        CLI[Mix Tasks]
        IEX[IEx Session]
    end
    
    subgraph "Compile-Time Layer"
        COMPILER[Mix Compiler Hook]
        AST_TRANS[AST Transformer]
        AI_ORCH[AI Orchestrator]
        AST_REPO[AST Repository]
    end
    
    subgraph "Runtime Layer"
        RUNTIME[Instrumentation Runtime]
        INGEST[Event Ingestor]
        RING[Ring Buffer]
        PIPELINE[Pipeline Manager]
    end
    
    subgraph "Storage Layer"
        EVENT_STORE[EventStore<br/>6.2µs/event]
        TEMPORAL[Temporal Storage]
        HOT[Hot Storage<br/>ETS]
        WARM[Warm Storage<br/>Disk]
    end
    
    subgraph "Query & Analysis Layer"
        QUERY[Query Engine<br/><100ms]
        CORRELATOR[Runtime Correlator]
        ANALYZER[AI Analyzer]
    end
    
    subgraph "Cinema Debugger"
        BRIDGE[Temporal Bridge]
        STATE_RECON[State Reconstructor]
        CINEMA[Cinema Playback]
    end
    
    IDE --> COMPILER
    CLI --> COMPILER
    COMPILER --> AST_TRANS
    AST_TRANS <--> AI_ORCH
    AST_TRANS --> AST_REPO
    AST_TRANS --> RUNTIME
    
    RUNTIME --> INGEST
    INGEST --> RING
    RING --> PIPELINE
    PIPELINE --> EVENT_STORE
    EVENT_STORE --> TEMPORAL
    EVENT_STORE --> HOT
    HOT --> WARM
    
    TEMPORAL --> BRIDGE
    BRIDGE --> STATE_RECON
    STATE_RECON --> CINEMA
    
    AST_REPO --> CORRELATOR
    EVENT_STORE --> QUERY
    QUERY --> ANALYZER
    CORRELATOR --> QUERY
    
    style COMPILER fill:#f9f,stroke:#333,stroke-width:4px
    style EVENT_STORE fill:#9f9,stroke:#333,stroke-width:4px
    style BRIDGE fill:#99f,stroke:#333,stroke-width:4px
```

## 2. Compile-Time AST Transformation Pipeline

```mermaid
graph LR
    subgraph "Source Files"
        EX[.ex files]
        EXS[.exs files]
    end
    
    subgraph "AST Processing"
        PARSE[Parser<br/>Code.string_to_quoted/2]
        ANALYZE[Code Analyzer]
        PATTERN[Pattern Recognizer]
        COMPLEX[Complexity Analyzer]
        PLAN[Instrumentation Planner]
    end
    
    subgraph "AST Transformation"
        TRANS[AST Transformer]
        ENHANCE[Enhanced Transformer]
        INJECT[Injector Helpers]
    end
    
    subgraph "AST Storage"
        NODE_ID[Node ID Generator]
        MOD_DATA[Module Data]
        FUNC_DATA[Function Data]
        REPO[Repository<br/>ETS Tables]
    end
    
    subgraph "Output"
        INST_CODE[Instrumented Code]
        BUILD[_build directory]
    end
    
    EX --> PARSE
    EXS --> PARSE
    PARSE --> ANALYZE
    ANALYZE --> PATTERN
    ANALYZE --> COMPLEX
    PATTERN --> PLAN
    COMPLEX --> PLAN
    
    PLAN --> TRANS
    PLAN --> ENHANCE
    TRANS --> INJECT
    ENHANCE --> INJECT
    
    PARSE --> NODE_ID
    NODE_ID --> MOD_DATA
    NODE_ID --> FUNC_DATA
    MOD_DATA --> REPO
    FUNC_DATA --> REPO
    
    INJECT --> INST_CODE
    INST_CODE --> BUILD
    
    style PARSE fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    style TRANS fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    style REPO fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
```

## 3. Runtime Event Capture Flow

```mermaid
sequenceDiagram
    participant APP as Application Code
    participant IR as Instrumentation Runtime
    participant ING as Ingestor
    participant RB as Ring Buffer
    participant PM as Pipeline Manager
    participant ES as EventStore
    participant TB as Temporal Bridge
    
    APP->>IR: report_function_entry()
    activate IR
    IR->>IR: Generate correlation_id
    IR->>IR: Capture timestamp
    IR->>IR: Create event struct
    IR->>ING: ingest_event(event)
    deactivate IR
    
    activate ING
    ING->>RB: write(event)
    ING->>ING: Check batch size
    deactivate ING
    
    Note over RB: Lock-free circular buffer<br/>Atomic operations
    
    RB-->>PM: Batch ready
    activate PM
    PM->>PM: Process batch
    PM->>ES: store_events(batch)
    PM->>TB: forward_events(batch)
    deactivate PM
    
    activate ES
    ES->>ES: Index by timestamp
    ES->>ES: Index by correlation_id
    ES->>ES: Store in ETS
    deactivate ES
    
    activate TB
    TB->>TB: Correlate with AST
    TB->>TB: Update state tracking
    deactivate TB
```

## 4. Data Storage Architecture

```mermaid
graph TB
    subgraph "Ingestion Layer"
        EVENTS[Runtime Events]
        BUFFER[Ring Buffer<br/>Lock-free<br/>100k events/sec]
    end
    
    subgraph "Hot Storage - ETS"
        HOT_EVENTS[Recent Events<br/><30 min]
        HOT_STATE[Process States]
        HOT_INDEX[Indexes<br/>- By Time<br/>- By Process<br/>- By Correlation]
    end
    
    subgraph "Warm Storage - Disk"
        WARM_EVENTS[Compressed Events<br/>30min - 24hr]
        WARM_INDEX[Secondary Indexes]
    end
    
    subgraph "Cold Storage - Archive"
        COLD_EVENTS[Historical Data<br/>>24hr]
        COLD_META[Metadata Only]
    end
    
    subgraph "Specialized Storage"
        TEMPORAL[Temporal Storage<br/>AST Correlation]
        AST_REPO[AST Repository<br/>Module/Function Data]
    end
    
    EVENTS --> BUFFER
    BUFFER --> HOT_EVENTS
    HOT_EVENTS --> WARM_EVENTS
    WARM_EVENTS --> COLD_EVENTS
    
    HOT_EVENTS --> HOT_STATE
    HOT_EVENTS --> HOT_INDEX
    
    HOT_EVENTS --> TEMPORAL
    AST_REPO --> TEMPORAL
    
    style BUFFER fill:#ffeb3b,stroke:#f57f17,stroke-width:3px
    style HOT_EVENTS fill:#ff9800,stroke:#e65100,stroke-width:2px
    style TEMPORAL fill:#03a9f4,stroke:#01579b,stroke-width:2px
```

## 5. Query Engine Architecture

```mermaid
graph LR
    subgraph "Query Interface"
        API[Query API]
        PARSER[Query Parser]
        OPTIMIZER[Query Optimizer]
    end
    
    subgraph "Query Execution"
        PLANNER[Execution Planner]
        SCANNER[Index Scanner]
        FILTER[Filter Engine]
        AGGREGATOR[Aggregator]
    end
    
    subgraph "Data Sources"
        HOT_DATA[Hot Storage]
        WARM_DATA[Warm Storage]
        AST_DATA[AST Repository]
        RUNTIME_DATA[Runtime Correlator]
    end
    
    subgraph "Results"
        FORMATTER[Result Formatter]
        CACHE[Query Cache]
        STREAM[Result Stream]
    end
    
    API --> PARSER
    PARSER --> OPTIMIZER
    OPTIMIZER --> PLANNER
    
    PLANNER --> SCANNER
    SCANNER --> HOT_DATA
    SCANNER --> WARM_DATA
    SCANNER --> AST_DATA
    
    SCANNER --> FILTER
    FILTER --> AGGREGATOR
    AGGREGATOR --> FORMATTER
    
    RUNTIME_DATA --> FILTER
    
    FORMATTER --> CACHE
    FORMATTER --> STREAM
    
    style API fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    style PLANNER fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style CACHE fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
```

## 6. Cinema Debugger Time-Travel Architecture

```mermaid
stateDiagram-v2
    [*] --> Capturing: Start Debugging
    
    state Capturing {
        Runtime --> EventCapture
        EventCapture --> TemporalStorage
        TemporalStorage --> StateSnapshots
    }
    
    Capturing --> Playback: Request Time Travel
    
    state Playback {
        TimeSelection --> StateRetrieval
        StateRetrieval --> StateReconstruction
        StateReconstruction --> Visualization
    }
    
    Playback --> Analysis: Analyze State
    
    state Analysis {
        StateComparison --> DiffGeneration
        DiffGeneration --> RootCause
        RootCause --> Recommendations
    }
    
    Analysis --> Capturing: Continue Debugging
    Analysis --> [*]: End Session
```

## 7. AI Integration Architecture

```mermaid
graph TB
    subgraph "AI Orchestration"
        ORCH[AI Orchestrator]
        SELECTOR[Provider Selector]
    end
    
    subgraph "LLM Providers"
        GEMINI[Gemini API]
        VERTEX[Vertex AI]
        MOCK[Mock Provider]
    end
    
    subgraph "Analysis Components"
        CODE_AN[Code Analyzer]
        PATTERN_REC[Pattern Recognizer]
        COMPLEX_AN[Complexity Analyzer]
        PREDICT[Predictive Analyzer]
    end
    
    subgraph "ML Models"
        EMBED[AST Embeddings]
        PERF_MODEL[Performance Model]
        ERROR_MODEL[Error Prediction]
    end
    
    subgraph "Outputs"
        PLAN[Instrumentation Plan]
        INSIGHTS[Code Insights]
        RECOMMEND[Recommendations]
    end
    
    ORCH --> SELECTOR
    SELECTOR --> GEMINI
    SELECTOR --> VERTEX
    SELECTOR --> MOCK
    
    ORCH --> CODE_AN
    ORCH --> PATTERN_REC
    ORCH --> COMPLEX_AN
    
    CODE_AN --> PREDICT
    PATTERN_REC --> PREDICT
    COMPLEX_AN --> PREDICT
    
    PREDICT --> EMBED
    PREDICT --> PERF_MODEL
    PREDICT --> ERROR_MODEL
    
    PREDICT --> PLAN
    PREDICT --> INSIGHTS
    PREDICT --> RECOMMEND
    
    style ORCH fill:#e1bee7,stroke:#6a1b9a,stroke-width:3px
    style PREDICT fill:#c5e1a5,stroke:#33691e,stroke-width:2px
```

## 8. Revolutionary AST Repository (Phase 3)

```mermaid
graph TB
    subgraph "AST Population"
        FILES[Project Files]
        WATCHER[File Watcher]
        PARSER[AST Parser]
        ANALYZER[AST Analyzer]
    end
    
    subgraph "Graph Storage"
        NODES[AST Nodes]
        EDGES[Relationships]
        PROPS[Properties]
        INDEX[Graph Indexes]
    end
    
    subgraph "Code Property Graphs"
        AST[AST Structure]
        CFG[Control Flow Graph]
        DFG[Data Flow Graph]
        CPG[Unified CPG]
    end
    
    subgraph "Advanced Features"
        EMBED[Vector Embeddings]
        SIMILAR[Similarity Search]
        PATTERNS[Pattern Detection]
        PREDICT[Predictive Analysis]
    end
    
    FILES --> PARSER
    WATCHER --> PARSER
    PARSER --> ANALYZER
    ANALYZER --> NODES
    
    NODES --> EDGES
    EDGES --> PROPS
    PROPS --> INDEX
    
    NODES --> AST
    AST --> CFG
    AST --> DFG
    CFG --> CPG
    DFG --> CPG
    
    CPG --> EMBED
    EMBED --> SIMILAR
    CPG --> PATTERNS
    PATTERNS --> PREDICT
    
    style CPG fill:#ffecb3,stroke:#ff6f00,stroke-width:3px
    style PREDICT fill:#b2dfdb,stroke:#00695c,stroke-width:2px
```

## 9. Event Correlation & State Management

```mermaid
flowchart LR
    subgraph "Event Sources"
        FN_ENTRY[Function Entry]
        FN_EXIT[Function Exit]
        VAR_CHANGE[Variable Change]
        MSG_SEND[Message Send]
        STATE_CHG[State Change]
    end
    
    subgraph "Correlation Engine"
        CORR_ID[Correlation ID Gen]
        AST_MAP[AST Node Mapper]
        TIME_SYNC[Time Synchronizer]
        CAUSALITY[Causality Tracker]
    end
    
    subgraph "State Management"
        SNAPSHOT[State Snapshots]
        DIFF_ENGINE[Diff Engine]
        HISTORY[State History]
        RECON[State Reconstructor]
    end
    
    subgraph "Query Interface"
        TIME_QUERY[Time-based Query]
        STATE_QUERY[State Query]
        FLOW_QUERY[Message Flow Query]
    end
    
    FN_ENTRY --> CORR_ID
    FN_EXIT --> CORR_ID
    VAR_CHANGE --> CORR_ID
    MSG_SEND --> CORR_ID
    STATE_CHG --> CORR_ID
    
    CORR_ID --> AST_MAP
    CORR_ID --> TIME_SYNC
    AST_MAP --> CAUSALITY
    TIME_SYNC --> CAUSALITY
    
    CAUSALITY --> SNAPSHOT
    SNAPSHOT --> DIFF_ENGINE
    DIFF_ENGINE --> HISTORY
    HISTORY --> RECON
    
    RECON --> TIME_QUERY
    RECON --> STATE_QUERY
    CAUSALITY --> FLOW_QUERY
```

## 10. Performance Monitoring Architecture

```mermaid
graph TB
    subgraph "Metrics Collection"
        RUNTIME_METRICS[Runtime Metrics<br/>- Function Duration<br/>- Memory Usage<br/>- Message Queue]
        SYSTEM_METRICS[System Metrics<br/>- CPU Usage<br/>- Scheduler Util<br/>- IO Stats]
        APP_METRICS[App Metrics<br/>- Request Rate<br/>- Error Rate<br/>- Throughput]
    end
    
    subgraph "Aggregation"
        WINDOW[Time Windows<br/>1s, 10s, 1m, 5m]
        STATS[Statistics<br/>p50, p95, p99<br/>min, max, avg]
        ANOMALY[Anomaly Detection]
    end
    
    subgraph "Analysis"
        HOTSPOT[Hotspot Detection]
        BOTTLENECK[Bottleneck Analysis]
        TREND[Trend Analysis]
        PREDICT_PERF[Performance Prediction]
    end
    
    subgraph "Actions"
        ALERTS[Alert Generation]
        AUTO_SCALE[Auto-scaling Hints]
        OPTIMIZE[Optimization Suggestions]
    end
    
    RUNTIME_METRICS --> WINDOW
    SYSTEM_METRICS --> WINDOW
    APP_METRICS --> WINDOW
    
    WINDOW --> STATS
    STATS --> ANOMALY
    
    ANOMALY --> HOTSPOT
    ANOMALY --> BOTTLENECK
    STATS --> TREND
    TREND --> PREDICT_PERF
    
    HOTSPOT --> ALERTS
    BOTTLENECK --> OPTIMIZE
    PREDICT_PERF --> AUTO_SCALE
    
    style ANOMALY fill:#ffcdd2,stroke:#c62828,stroke-width:2px
    style OPTIMIZE fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
```

## Key Architecture Principles

1. **Separation of Concerns**: Clear boundaries between compile-time and runtime components
2. **Performance-First Design**: Lock-free data structures, minimal overhead instrumentation
3. **Scalability**: Tiered storage, efficient indexing, batch processing
4. **Extensibility**: Plugin architecture for AI providers, analysis modules
5. **Correlation**: Strong linking between static (AST) and dynamic (runtime) data
6. **Time-Travel Capability**: Comprehensive state tracking and reconstruction
7. **AI Integration**: Pluggable LLM providers with fallback strategies
8. **Query Optimization**: Multi-level caching, index-based retrieval

## Performance Characteristics

- **Event Ingestion**: <100µs per event overhead
- **Storage**: 6.2µs per event write to EventStore
- **Query**: <100ms for complex queries across 1000 events
- **Memory**: ~50MB overhead for typical applications
- **AST Processing**: <100ms for medium-sized modules
- **State Reconstruction**: <10ms for typical GenServer states

## Future Architecture Enhancements (Phase 3+)

- **Graph Database Integration**: Neo4j/ArangoDB for AST relationships
- **Distributed Tracing**: Cross-node event correlation
- **ML Pipeline**: Real-time model training on event streams
- **Web UI Integration**: Phoenix LiveView real-time dashboard
- **IDE Integration**: LSP protocol support for in-editor debugging
