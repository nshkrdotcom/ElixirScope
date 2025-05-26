Okay, I will create a series of detailed Mermaid architectural diagrams. I'll start by focusing on the current runtime-centric architecture as indicated by the latest documents like `CURSOR_REVAMP_DEBUG_PLAN.md` and `PROGRESS_SUMMARY.md`, and then extrapolate for future enhancements based on the broader vision outlined in documents like `008-g-prd.md` (ElixirScope PRD) and `CURSOR_PHASE_2_AI_ENGINE.md`.

Here's the first set of diagrams representing the **current state** of ElixirScope:

## Diagrams for Current State (Runtime Tracing Focused)

### 1. Overall System Architecture (Runtime-Focused)

This diagram shows the main components of ElixirScope with its runtime tracing primary mechanism.

> **Note:** Does not show its place within the unified architecture or the compile-time AST instrumentation path.

```mermaid
graph TD
    subgraph "User/Developer Interaction"
        direction LR
        UserAPI["ElixirScope.Runtime API<br>(trace/2, stop_trace/1, etc.)"]
        IExHelpers["IExHelpers (Future/Basic)"]
        MixTasks["Mix Tasks (elixir_scope.analyze)"]
    end

    subgraph "AI Layer (Runtime Plan Generation)"
        direction LR
        AICodeAnalyzer["AI.CodeAnalyzer<br>(Static Analysis, Patterns, Complexity)"]
        AIOrchestrator["AI.Orchestrator<br>(Generates Runtime Plans)"]
        AIPredictive["AI.Predictive.ExecutionPredictor<br>(Path/Resource Prediction)"]
        AIIntelligent["AI.Analysis.IntelligentCodeAnalyzer<br>(Semantic Analysis, Quality Score)"]
        AILlmClient["AI.LLM.Client<br>(LLM Interaction)"]

        AICodeAnalyzer --> AIOrchestrator
        AIPredictive -.-> AIOrchestrator
        AIIntelligent -.-> AIOrchestrator
        AIOrchestrator --> AILlmClient
    end

    subgraph "Runtime Tracing Control"
        direction LR
        RTController["Runtime.Controller<br>(Manages Tracing, Applies Plans)"]
        TracerMgr["Runtime.TracerManager"]
        StateMonMgr["Runtime.StateMonitorManager"]
        Safety["Runtime.Safety<br>(Limits, Circuit Breaker)"]
        Sampling["Runtime.Sampling<br>(Strategies)"]
        Matchers["Runtime.Matchers<br>(Match Spec DSL)"]

        UserAPI --> RTController
        MixTasks --> AIOrchestrator
        AIOrchestrator --> RTController

        RTController --> TracerMgr
        RTController --> StateMonMgr
        RTController --> Safety
        RTController --> Sampling
    end

    subgraph "BEAM Interaction (Tracers & Monitors)"
        direction LR
        Tracers["Runtime.Tracer Processes<br>(:dbg, :erlang.trace)"]
        StateMonitors["Runtime.StateMonitor Processes<br>(:sys.install)"]
        TargetApp["Target Elixir Application"]

        TracerMgr --> Tracers
        StateMonMgr --> StateMonitors
        Tracers --> TargetApp
        StateMonitors --> TargetApp
    end

    subgraph "Event Capture & Processing Pipeline"
        direction LR
        Ingestor["Capture.Ingestor<br>(Receives BEAM traces, Formats Events)"]
        RingBuffer["Capture.RingBuffer<br>(Lock-free Staging)"]
        AsyncWriterPool["Capture.AsyncWriterPool<br>(Consumes from RingBuffer)"]
        EventCorrelator["Capture.EventCorrelator<br>(Causal Linking)"]
        PipelineManager["Capture.PipelineManager<br>(Supervises Pool, Correlator)"]

        Tracers --> Ingestor
        StateMonitors --> Ingestor
        Ingestor --> RingBuffer
        RingBuffer --> AsyncWriterPool
        AsyncWriterPool --> EventCorrelator
        PipelineManager --> AsyncWriterPool
        PipelineManager -.-> EventCorrelator
    end

    subgraph "Storage Layer"
        DataAccess["Storage.DataAccess<br>(ETS for Hot Storage, Indexing)"]
        QueryCoord["Storage.QueryCoordinator<br>(Future - Query API)"]

        EventCorrelator --> DataAccess
        DataAccess --> QueryCoord
        IExHelpers -.-> QueryCoord
        AIPredictive --> QueryCoord
        AIIntelligent --> QueryCoord
    end

    subgraph "Core Utilities & Data"
        direction LR
        Config["ElixirScope.Config"]
        Events["ElixirScope.Events"]
        Utils["ElixirScope.Utils"]
        LlmConfig["AI.LLM.Config"]
        LlmResponse["AI.LLM.Response"]
        LlmProviders["AI.LLM.Providers.*"]
    end

    %% Styling
    classDef ai fill:#e1f5fe,stroke:#333,color:#000
    classDef runtime_control fill:#f3e5f5,stroke:#333,color:#000
    classDef beam_interaction fill:#fffde7,stroke:#333,color:#000
    classDef pipeline fill:#e8f5e9,stroke:#333,color:#000
    classDef storage fill:#fff3e0,stroke:#333,color:#000
    classDef core_utils fill:#fce4ec,stroke:#333,color:#000

    class AICodeAnalyzer,AIOrchestrator,AIPredictive,AIIntelligent,AILlmClient ai;
    class RTController,TracerMgr,StateMonMgr,Safety,Sampling,Matchers runtime_control;
    class Tracers,StateMonitors,TargetApp beam_interaction;
    class Ingestor,RingBuffer,AsyncWriterPool,EventCorrelator,PipelineManager pipeline;
    class DataAccess,QueryCoord storage;
    class Config,Events,Utils,LlmConfig,LlmResponse,LlmProviders core_utils;
```

### 2. AI-Driven Runtime Instrumentation Flow

This diagram details how AI analyzes code and translates that into runtime tracing commands.

> **Note:** Focuses only on runtime; should incorporate AI planning for AST instrumentation.

```mermaid
flowchart TD
    A[Project Codebase] --> B{AI.CodeAnalyzer};
    B --> C{AI.PatternRecognizer};
    B --> D{AI.ComplexityAnalyzer};
    C --> E[Structural Patterns];
    D --> F[Complexity Metrics];
    E --> G{AI.Orchestrator};
    F --> G;
    H["ElixirScope.Config<br>(Strategies, Overrides)"] --> G;

    G --> I["Generate Runtime Tracing Plan<br>(Target PIDs, MFAs, Match Specs, OTP Monitoring Rules)"];
    I --> J{Runtime.Controller};
    J --> K[Apply Plan to<br>TracerManager & StateMonitorManager];

    subgraph "Future Enhancement"
        L["Runtime Feedback<br>(Performance, Anomalies)"] -.-> G;
    end

    classDef ai fill:#e1f5fe,stroke:#333,color:#000
    classDef runtime_control fill:#f3e5f5,stroke:#333,color:#000
    classDef data fill:#fffde7,stroke:#333,color:#000

    class B,C,D,G,I,L ai;
    class J,K runtime_control;
    class A,E,F,H data;
```

### 3. Runtime Event Capture Pipeline (from BEAM to Ingestor)

Focuses on how events sourced from BEAM's tracing mechanisms are captured.

> **Note:** Accurate for runtime path, but needs to show the convergent path from AST instrumentation via `Capture.InstrumentationRuntime`.

```mermaid
graph LR
    subgraph "Target Application"
        P1[Process A]
        P2["Process B (GenServer)"]
    end

    subgraph "BEAM Tracing Primitives"
        DBG[":dbg<br>(Trace Points, Process Tracing)"]
        SYS[":sys.install<br>(OTP Debug Handler)"]
        ETRACE[":erlang.trace<br>(Low-level Tracing)"]
    end

    subgraph "ElixirScope Tracing Infrastructure"
        TRM[Runtime.TracerManager] --> TR(Runtime.Tracer Process);
        SMM[Runtime.StateMonitorManager] --> SM(Runtime.StateMonitor Process);
        TR -.-> DBG;
        TR -.-> ETRACE;
        SM -.-> SYS;
    end

    subgraph "Event Ingestion"
        ING["Capture.Ingestor<br>(ingest_generic_event/7)"]
        RB[Capture.RingBuffer]
    end

    P1 -- "Function Calls, Messages" --> DBG;
    P1 -- "Function Calls, Messages" --> ETRACE;
    P2 -- "State Changes, Callbacks" --> SYS;

    DBG -- "Raw Trace Messages" --> TR;
    ETRACE -- "Raw Trace Messages" --> TR;
    SYS -- "OTP Debug Messages" --> SM;

    TR -- "Formatted ElixirScope Events" --> ING;
    SM -- "Formatted ElixirScope Events" --> ING;
    ING --> RB;

    classDef beam fill:#fffde7,stroke:#333,color:#000
    classDef elixirscope_runtime fill:#f3e5f5,stroke:#333,color:#000
    classDef capture_pipeline fill:#e8f5e9,stroke:#333,color:#000

    class DBG,SYS,ETRACE beam;
    class TRM,TR,SMM,SM elixirscope_runtime;
    class ING,RB capture_pipeline;
```

### 4. Asynchronous Event Processing and Storage Pipeline

This diagram picks up from the RingBuffer and shows how events are processed and stored.

```mermaid
graph TD
    RB[Capture.RingBuffer] --> AWP[Capture.AsyncWriterPool];
    AWP --> AW1["AsyncWriter 1 (Worker)"];
    AWP --> AWN["AsyncWriter N (Worker)"];

    subgraph "Per AsyncWriter Worker"
        AW1_RB[Read Batch from RingBuffer] --> AW1_EN["Enrich Event (Basic Metadata)"];
        AW1_EN --> AW1_CORR["Call EventCorrelator.correlate_batch/2"];
        AW1_CORR --> AW1_STORE["Call DataAccess.store_events/2"];
    end

    EC["Capture.EventCorrelator<br>(Manages Correlation State via ETS: call_stacks, message_registry, etc.)"];
    DA["Storage.DataAccess<br>(Writes to ETS: primary_events, temporal_idx, pid_idx, etc.)"];

    AW1_CORR --> EC;
    AW1_STORE --> DA;

    classDef pipeline_component fill:#e8f5e9,stroke:#333,color:#000
    classDef storage_component fill:#fff3e0,stroke:#333,color:#000
    classDef important_call fill:#fce4ec,stroke:#333,color:#000

    class RB,AWP,AW1,AWN,AW1_RB,AW1_EN pipeline_component;
    class EC,DA storage_component;
    class AW1_CORR,AW1_STORE important_call;
```

### 5. Simplified ElixirScope Data Model (ERD-like)

Illustrates key event types and their core attributes, including correlation fields.

```mermaid
erDiagram
    BaseEvent {
        string event_id PK
        bigint timestamp
        bigint wall_time
        atom node
        pid process_pid
        string correlation_id "Links related events"
        string parent_call_id "Links to parent function call"
        atom event_type
        map data "Specific event payload"
    }

    FunctionEntryData {
        atom module
        atom function
        int arity
        list args "Truncated arguments"
        string call_id "Unique ID for this call instance"
    }

    FunctionExitData {
        atom module
        atom function
        int arity
        string call_id "Matches FunctionEntry.call_id"
        any result "Truncated return or exception"
        bigint duration_ns
        atom exit_reason
    }

    MessageSendData {
        pid sender_pid
        pid receiver_pid
        any message "Truncated message content"
        string message_id "Unique message instance ID"
    }

    MessageReceiveData {
        pid receiver_pid
        pid sender_pid
        any message "Truncated message content"
        string message_id "Matches MessageSendData.message_id"
    }

    StateChangeData {
        pid server_pid
        atom callback "e.g., :handle_call"
        any old_state_ref "Ref or truncated old state"
        any new_state_ref "Ref or truncated new state"
        any state_diff
    }

    StateSnapshotData {
        pid server_pid
        any state "Full state snapshot (truncated)"
        string session_id "Time-travel session ID"
        atom checkpoint_type
    }

    BaseEvent ||--o{ FunctionEntryData : "data when :function_entry"
    BaseEvent ||--o{ FunctionExitData : "data when :function_exit"
    BaseEvent ||--o{ MessageSendData : "data when :message_send"
    BaseEvent ||--o{ MessageReceiveData : "data when :message_receive"
    BaseEvent ||--o{ StateChangeData : "data when :state_change"
    BaseEvent ||--o{ StateSnapshotData : "data when :state_snapshot"
```

### 6. Runtime API Control Flow

Shows how user API calls flow through the runtime control system.

```mermaid
sequenceDiagram
    participant User as User/Developer
    participant RuntimeAPI as ElixirScope.Runtime
    participant Controller as Runtime.Controller
    participant TracerMgr as Runtime.TracerManager
    participant StateMonMgr as Runtime.StateMonitorManager
    participant Tracer as Runtime.Tracer
    participant StateMon as Runtime.StateMonitor

    User->>RuntimeAPI: trace(MyModule, level: :detailed)
    RuntimeAPI->>Controller: {:start_trace, MyModule, opts} (call)
    Controller->>TracerMgr: {:add_trace, trace_ref, MyModule, opts} (call)
    TracerMgr->>Tracer: start_link(trace_ref, MyModule, opts)
    Tracer->>Tracer: Setup :dbg/:erlang.trace
    Tracer-->>TracerMgr: :ok
    TracerMgr-->>Controller: :ok
    Controller-->>RuntimeAPI: {:ok, trace_ref}
    RuntimeAPI-->>User: {:ok, trace_ref}

    User->>RuntimeAPI: enable_time_travel(MyGenServerPID)
    RuntimeAPI->>Controller: {:enable_time_travel, MyGenServerPID, opts} (call)
    Controller->>StateMonMgr: {:start_time_travel_session, session_id, MyGenServerPID, opts} (call)
    StateMonMgr->>StateMon: start_link(session_id, MyGenServerPID, opts)
    StateMon->>StateMon: :sys.install on MyGenServerPID
    StateMon-->>StateMonMgr: :ok
    StateMonMgr-->>Controller: :ok
    Controller-->>RuntimeAPI: {:ok, session_id}
    RuntimeAPI-->>User: {:ok, session_id}
```

### 7. LLM Integration Architecture

Illustrates the interaction of ElixirScope's LLM client with providers.

```mermaid
graph TD
    subgraph "ElixirScope AI Layer"
        AppLogic["Application Logic<br>(e.g., AI.Orchestrator, AI.IntelligentCodeAnalyzer)"]
        LlmClient["AI.LLM.Client<br>(analyze_code/2, explain_error/2)"]
        LlmConfig["AI.LLM.Config<br>(Provider Selection, API Keys, URLs)"]
        LlmResponse["AI.LLM.Response<br>(Standardized Format)"]

        AppLogic --> LlmClient
        LlmClient --> LlmConfig
        LlmClient --> LlmResponse
    end

    subgraph "LLM Providers (via AI.LLM.Provider Behaviour)"
        ProviderGemini["Providers.Gemini"]
        ProviderVertex["Providers.Vertex"]
        ProviderMock["Providers.Mock"]

        LlmClient --> ProviderGemini
        LlmClient --> ProviderVertex
        LlmClient --> ProviderMock
    end

    subgraph "External LLM Services"
        GeminiAPI["Google Gemini API"]
        VertexAPI["Google Vertex AI API"]
    end

    ProviderGemini --> GeminiAPI
    ProviderVertex --> VertexAPI

    classDef app_ai fill:#e1f5fe,stroke:#333,color:#000
    classDef llm_internal fill:#f3e5f5,stroke:#333,color:#000
    classDef llm_external fill:#fffde7,stroke:#333,color:#000

    class AppLogic app_ai;
    class LlmClient,LlmConfig,LlmResponse,ProviderGemini,ProviderVertex,ProviderMock llm_internal;
    class GeminiAPI,VertexAPI llm_external;
```

### 8. Predictive & Intelligent Analysis Engines (Conceptual Interaction)

Shows how the advanced AI analysis modules (from Layers 8 & 9 documentation) would interact with the system. These modules exist in code.

```mermaid
graph TD
    subgraph "ElixirScope Core"
        DataAccess["Storage.DataAccess<br>(Historical Trace Data)"]
        QueryCoord["Storage.QueryCoordinator<br>(Future - Access to DataAccess)"]
        RuntimeController["Runtime.Controller<br>(Live System Control)"]
    end

    subgraph "AI Analysis & Prediction Layer (Conceptual)"
        ExecPredictor["AI.Predictive.ExecutionPredictor<br>(predict_path/3, predict_resources/1)"]
        IntelligentAnalyzer["AI.Analysis.IntelligentCodeAnalyzer<br>(analyze_semantics/1, assess_quality/1)"]
        LlmClient["AI.LLM.Client"]
    end

    subgraph "User/System Interaction"
        UserIDE["User / IDE Plugin"]
        AIOrchestrator["AI.Orchestrator<br>(For Instrumentation Planning)"]
    end

    DataAccess -- "Historical Data" --> QueryCoord
    QueryCoord -- "Queried Data" --> ExecPredictor
    QueryCoord -- "Queried Data" --> IntelligentAnalyzer

    IntelligentAnalyzer -- "Semantic Analysis, Quality Scores" --> UserIDE
    IntelligentAnalyzer -- "Code Understanding" --> LlmClient
    ExecPredictor -- "Predicted Paths, Resource Needs" --> UserIDE
    ExecPredictor -- "Risk Assessment" --> AIOrchestrator

    AIOrchestrator -- "Instrumentation Plan" --> RuntimeController

    classDef core_data fill:#fff3e0,stroke:#333,color:#000
    classDef ai_analysis fill:#e1f5fe,stroke:#333,color:#000
    classDef user_interaction fill:#fce4ec,stroke:#333,color:#000

    class DataAccess,QueryCoord,RuntimeController core_data;
    class ExecPredictor,IntelligentAnalyzer,LlmClient ai_analysis;
    class UserIDE,AIOrchestrator user_interaction;
```

## Diagrams for Future State

### 9. "Execution Cinema" UI & Querying Architecture

This conceptual diagram shows how the future UI will interact with the backend to display trace data and enable time-travel debugging.

```mermaid
graph TD
    subgraph "User Interface (Execution Cinema - Future)"
        CinemaUI["Phoenix LiveView UI"]
        TimelineView["Timeline View Component"]
        ProcessView["Process/DAG View Component"]
        StateView["State Inspection Component"]
        CodeView["Code Context Component"]
        Controls["Playback & Filter Controls"]

        CinemaUI --> TimelineView
        CinemaUI --> ProcessView
        CinemaUI --> StateView
        CinemaUI --> CodeView
        CinemaUI --> Controls
    end

    subgraph "Backend Services"
        QueryCoordinator["Storage.QueryCoordinator<br>(Handles UI Queries, DAG Construction)"]
        DataAccess["Storage.DataAccess<br>(Hot/Warm/Cold Tiers)"]
        EventCorrelator["Capture.EventCorrelator<br>(Provides Correlation Links)"]
        TimeTravelEngine["TimeTravel.ReplayEngine<br>(State Reconstruction - Future)"]
        AIAnalysisEngine["AI.AnalysisEngine<br>(Insights, Anomaly Detection - Future)"]
    end

    Controls -- "Time Scrub, Filters" --> QueryCoordinator
    TimelineView -- "Fetch Events for Range" --> QueryCoordinator
    ProcessView -- "Fetch Process Interactions" --> QueryCoordinator
    StateView -- "Request State at Timestamp" --> TimeTravelEngine
    TimeTravelEngine -- "Fetch Snapshots & Events" --> DataAccess
    QueryCoordinator -- "Fetch Raw/Correlated Events" --> DataAccess
    DataAccess -- "Correlation Data" --> EventCorrelator
    AIAnalysisEngine -- "Request Trace Data" --> QueryCoordinator
    CinemaUI -- "Display AI Insights" --> AIAnalysisEngine

    classDef ui fill:#e0f7fa,stroke:#333,color:#000
    classDef backend_query fill:#f3e5f5,stroke:#333,color:#000
    classDef backend_data fill:#fff3e0,stroke:#333,color:#000
    classDef backend_ai fill:#e1f5fe,stroke:#333,color:#000

    class CinemaUI,TimelineView,ProcessView,StateView,CodeView,Controls ui;
    class QueryCoordinator,TimeTravelEngine backend_query;
    class DataAccess,EventCorrelator backend_data;
    class AIAnalysisEngine backend_ai;
```

### 10. Advanced AI Analysis Engine Integration (Future)

Based on `CURSOR_PHASE_2_AI_ENGINE.md`, this shows the interaction of more advanced AI components.

```mermaid
graph TD
    subgraph "Captured Data"
        TraceDB["DataAccess / QueryCoordinator<br>(Correlated Event History)"]
    end

    subgraph "AI Analysis Engines (Future)"
        PatternRecognizer["AI.PatternRecognizer<br>(Execution Patterns, Anti-patterns)"]
        PerformanceAnalyzer["AI.PerformanceAnalyzer<br>(Bottlenecks, Resource Usage)"]
        BugDetector["AI.BugDetector<br>(Anomalies, Error Signatures)"]
        RecommendationEngine["AI.RecommendationEngine<br>(Fixes, Optimizations)"]
        LlmService["AI.LLM.Client<br>(Contextual Understanding, Explanations)"]
    end

    subgraph "AI Orchestration & Output"
        AIOrchestrator["AI.Orchestrator<br>(Manages Analysis Pipelines)"]
        CinemaUI["Execution Cinema UI<br>(Displays Insights)"]
        Alerting["Alerting System"]
    end

    TraceDB --> PatternRecognizer;
    TraceDB --> PerformanceAnalyzer;
    TraceDB --> BugDetector;

    PatternRecognizer --> AIOrchestrator;
    PerformanceAnalyzer --> AIOrchestrator;
    BugDetector --> AIOrchestrator;

    AIOrchestrator --> LlmService;
    LlmService --> RecommendationEngine;
    RecommendationEngine --> AIOrchestrator;

    AIOrchestrator --> CinemaUI;
    AIOrchestrator --> Alerting;

    classDef data_source fill:#fff3e0,stroke:#333,color:#000
    classDef ai_engine fill:#e1f5fe,stroke:#333,color:#000
    classDef ai_control fill:#f3e5f5,stroke:#333,color:#000

    class TraceDB data_source;
    class PatternRecognizer,PerformanceAnalyzer,BugDetector,RecommendationEngine,LlmService ai_engine;
    class AIOrchestrator,CinemaUI,Alerting ai_control;
```

### 11. Distributed Tracing & Data Synchronization (Focus on Existing Components)

This diagram details how the existing distributed components interact.

```mermaid
graph TD
    subgraph "Node A"
        NCA[NodeCoordinator A]
        ESA[EventSynchronizer A]
        GCA[GlobalClock A]
        DAA[DataAccess A]
        AppA[Application A Events] --> DAA
    end

    subgraph "Node B"
        NCB[NodeCoordinator B]
        ESB[EventSynchronizer B]
        GCB[GlobalClock B]
        DAB[DataAccess B]
        AppB[Application B Events] --> DAB
    end

    NCA <-->|Node Discovery & Ping| NCB
    NCA -- Periodically Calls --> ESA
    NCB -- Periodically Calls --> ESB

    ESA -- ":rpc call EventSynchronizer.handle_sync_request" --> ESB
    ESB -- "Sends its new events in reply" --> ESA

    ESA -- "Stores events from B" --> DAA
    ESB -- "Stores events from A" --> DAB

    GCA -- ":rpc cast GlobalClock.update_from_remote" --> GCB
    GCB -- ":rpc cast GlobalClock.update_from_remote" --> GCA

    DAA -->|get_events_since| ESA
    DAB -->|get_events_since| ESB

    classDef distributed_control fill:#fce4ec,stroke:#333,color:#000
    classDef data_sync fill:#e8eaf6,stroke:#333,color:#000
    classDef local_storage fill:#e0f2f1,stroke:#333,color:#000

    class NCA,NCB,GCA,GCB distributed_control;
    class ESA,ESB data_sync;
    class DAA,DAB,AppA,AppB local_storage;
```

These diagrams should provide a good architectural overview of ElixirScope, covering its current runtime-centric design and its future evolution towards the "Execution Cinema" vision. The level of detail aims to be useful for understanding component interactions and data flows.