# ElixirScope System Architecture Diagrams

## 1. Overall System Architecture

```mermaid
graph TB
    subgraph "Development Environment"
        IDE[IDE/Editor]
        ElixirLS[ElixirLS DAP]
        Mix[Mix Build Process]
    end

    subgraph "ElixirScope Core System"
        subgraph "Layer 0: AI Intelligence"
            CA[CodeAnalyzer]
            IP[InstrumentationPlanner]
            AO[AI.Orchestrator]
        end

        subgraph "Layer 1: Auto-Instrumentation"
            MT[Compiler.MixTask]
            AST[AST.Transformer]
            IH[InjectorHelpers]
        end

        subgraph "Layer 2: Event Capture Pipeline"
            IR[InstrumentationRuntime]
            VT[VMTracer]
            EI[EventIngestor]
            RB[RingBuffer]
        end

        subgraph "Layer 3: Processing & Storage"
            AWP[AsyncWriterPool]
            EC[EventCorrelator]
            DA[DataAccess]
            QC[QueryCoordinator]
        end

        subgraph "Layer 4: Analysis & Visualization"
            AE[AI.AnalysisEngine]
            CUI[CinemaUI]
            TW[Tidewave Integration]
        end
    end

    subgraph "Target Application"
        APP[Elixir Application]
        GS[GenServers]
        SUP[Supervisors]
        PHXL[Phoenix/LiveView]
    end

    %% Connections
    Mix --> MT
    MT --> AST
    AST --> APP
    
    CA --> IP
    IP --> MT
    AO --> CA
    
    APP --> IR
    APP --> VT
    IR --> EI
    VT --> EI
    EI --> RB
    
    RB --> AWP
    AWP --> EC
    EC --> DA
    DA --> QC
    
    QC --> AE
    QC --> CUI
    AE --> CUI
    CUI --> TW
    
    IDE --> ElixirLS
    ElixirLS -.-> QC
    CUI -.-> ElixirLS

    classDef ai fill:#e1f5fe
    classDef capture fill:#f3e5f5
    classDef storage fill:#e8f5e8
    classDef ui fill:#fff3e0
    
    class CA,IP,AO,AE ai
    class IR,VT,EI,RB capture
    class AWP,EC,DA,QC storage
    class CUI,TW ui
```

## 2. AI-Driven Instrumentation Flow

```mermaid
flowchart TD
    Start([Project Start]) --> Load[Load Source Code]
    Load --> Parse[Parse ASTs]
    Parse --> Analyze{AI Code Analysis}
    
    Analyze --> |GenServer Pattern| GS_Plan[GenServer State Tracing Plan]
    Analyze --> |Phoenix Pattern| PHX_Plan[Phoenix Request/LiveView Plan]
    Analyze --> |Message Flow| MSG_Plan[Message Passing Plan]
    Analyze --> |Performance Critical| PERF_Plan[Performance Monitoring Plan]
    
    GS_Plan --> Merge[Merge Plans]
    PHX_Plan --> Merge
    MSG_Plan --> Merge
    PERF_Plan --> Merge
    
    Merge --> Strategy{Instrumentation Strategy}
    Strategy --> |Full Trace| Full[Full Recall Mode]
    Strategy --> |Balanced| Balanced[Smart Sampling]
    Strategy --> |Minimal| Minimal[Error/State Only]
    
    Full --> Transform[AST Transformation]
    Balanced --> Transform
    Minimal --> Transform
    
    Transform --> Inject[Inject Runtime Calls]
    Inject --> Compile[Compile with Mix]
    Compile --> Deploy[Deploy Instrumented Code]
    
    Deploy --> Monitor{Runtime Monitoring}
    Monitor --> |Anomaly Detected| Replan[Re-plan Instrumentation]
    Monitor --> |Normal| Continue[Continue Capture]
    
    Replan --> Strategy
    Continue --> End([Instrumented Application Running])

    classDef ai fill:#e1f5fe
    classDef process fill:#f3e5f5
    classDef decision fill:#fff3e0
    
    class Analyze,GS_Plan,PHX_Plan,MSG_Plan,PERF_Plan,Merge ai
    class Transform,Inject,Compile,Deploy process
    class Strategy,Monitor decision
```

## 3. Event Capture Pipeline

```mermaid
graph LR
    subgraph "Instrumented Application"
        FC[Function Calls]
        GC[GenServer Callbacks]
        MC[Message Sends]
        SC[State Changes]
    end

    subgraph "Capture Layer"
        IR[InstrumentationRuntime]
        VT[VMTracer]
        EI[EventIngestor]
    end

    subgraph "Ring Buffer System"
        RB1[RingBuffer 1]
        RB2[RingBuffer 2]
        RB3[RingBuffer N]
    end

    subgraph "Async Processing"
        W1[Worker 1]
        W2[Worker 2]
        W3[Worker N]
        EC[EventCorrelator]
    end

    subgraph "Storage Tiers"
        HOT[(Hot Storage - ETS)]
        WARM[(Warm Storage - Disk)]
        COLD[(Cold Storage - Archive)]
    end

    FC --> IR
    GC --> IR
    MC --> VT
    SC --> IR
    
    IR --> EI
    VT --> EI
    
    EI --> RB1
    EI --> RB2
    EI --> RB3
    
    RB1 --> W1
    RB2 --> W2
    RB3 --> W3
    
    W1 --> EC
    W2 --> EC
    W3 --> EC
    
    EC --> HOT
    HOT --> WARM
    WARM --> COLD

    classDef source fill:#ffebee
    classDef capture fill:#e8f5e8
    classDef buffer fill:#fff3e0
    classDef process fill:#f3e5f5
    classDef storage fill:#e1f5fe
    
    class FC,GC,MC,SC source
    class IR,VT,EI capture
    class RB1,RB2,RB3 buffer
    class W1,W2,W3,EC process
    class HOT,WARM,COLD storage
```

## 4. Seven DAGs (Execution Cinema Model)

```mermaid
graph TB
    subgraph "Execution Cinema - Seven Synchronized DAGs"
        subgraph "Temporal DAG"
            T1[Event T1] --> T2[Event T2]
            T2 --> T3[Event T3]
            T3 --> T4[Event T4]
        end

        subgraph "Process Interaction DAG"
            P1[Process A] --> |message| P2[Process B]
            P2 --> |spawn| P3[Process C]
            P1 --> |link| P3
        end

        subgraph "State Evolution DAG"
            S1[Initial State] --> |event| S2[State Change 1]
            S2 --> |event| S3[State Change 2]
            S3 --> |event| S4[Final State]
        end

        subgraph "Code Execution DAG"
            C1[Module.func/2] --> C2[Helper.process/1]
            C2 --> C3[Repo.insert/1]
            C1 --> C4[Logger.info/1]
        end

        subgraph "Data Flow DAG"
            D1[Input Data] --> D2[Transformed Data]
            D2 --> D3[Validated Data]
            D3 --> D4[Persisted Data]
        end

        subgraph "Performance DAG"
            PF1[Start: 0ms] --> PF2[Function A: 5ms]
            PF2 --> PF3[Database: 50ms]
            PF3 --> PF4[End: 55ms]
        end

        subgraph "Causality DAG"
            CA1[Root Cause] --> CA2[Intermediate Effect]
            CA2 --> CA3[Side Effect 1]
            CA2 --> CA4[Side Effect 2]
            CA3 --> CA5[Final Outcome]
            CA4 --> CA5
        end
    end

    %% Cross-DAG Correlations
    T1 -.-> P1
    T2 -.-> P2
    P1 -.-> S1
    P2 -.-> S2
    C1 -.-> PF1
    CA1 -.-> T1

    classDef temporal fill:#ffebee
    classDef process fill:#e8f5e8
    classDef state fill:#fff3e0
    classDef code fill:#f3e5f5
    classDef data fill:#e1f5fe
    classDef performance fill:#fce4ec
    classDef causality fill:#f1f8e9
    
    class T1,T2,T3,T4 temporal
    class P1,P2,P3 process
    class S1,S2,S3,S4 state
    class C1,C2,C3,C4 code
    class D1,D2,D3,D4 data
    class PF1,PF2,PF3,PF4 performance
    class CA1,CA2,CA3,CA4,CA5 causality
```

## 5. Event Data Model (ERD)

```mermaid
erDiagram
    EVENT {
        bigint event_id PK
        bigint timestamp
        bigint wall_time
        atom node
        pid process_id
        string correlation_id
        bigint parent_id FK
        atom event_type
        binary data
    }

    FUNCTION_EXECUTION {
        bigint id PK
        bigint timestamp
        bigint wall_time
        atom module
        atom function
        integer arity
        binary args
        binary return_value
        bigint duration_ns
        pid caller_pid
        string correlation_id
        atom event_type
    }

    PROCESS_EVENT {
        bigint id PK
        bigint timestamp
        bigint wall_time
        pid process_id
        pid parent_pid
        atom event_type
        binary metadata
    }

    MESSAGE_EVENT {
        bigint id PK
        bigint timestamp
        bigint wall_time
        pid from_pid
        pid to_pid
        binary message
        string message_id
        atom event_type
    }

    STATE_CHANGE {
        bigint id PK
        bigint timestamp
        pid server_pid
        atom callback
        binary old_state
        binary new_state
        binary state_diff
        string trigger_message
        bigint trigger_call_id
    }

    PERFORMANCE_METRIC {
        bigint id PK
        bigint timestamp
        bigint wall_time
        atom metric_name
        float value
        binary metadata
        atom unit
        string source_context
    }

    ERROR_EVENT {
        bigint id PK
        bigint timestamp
        atom error_type
        atom error_class
        string error_message
        binary stacktrace
        binary context
        atom recovery_action
    }

    CORRELATION_LINK {
        bigint id PK
        bigint source_event_id FK
        bigint target_event_id FK
        atom link_type
        binary metadata
        bigint timestamp
    }

    DAG_NODE {
        bigint id PK
        atom dag_type
        bigint event_id FK
        integer depth_level
        binary dag_metadata
        bigint timestamp
    }

    DAG_EDGE {
        bigint id PK
        atom dag_type
        bigint source_node_id FK
        bigint target_node_id FK
        atom edge_type
        binary edge_metadata
        float weight
    }

    EVENT ||--o{ CORRELATION_LINK : "source"
    EVENT ||--o{ CORRELATION_LINK : "target"
    EVENT ||--o{ DAG_NODE : "represents"
    DAG_NODE ||--o{ DAG_EDGE : "source"
    DAG_NODE ||--o{ DAG_EDGE : "target"
    EVENT ||--o{ FUNCTION_EXECUTION : "extends"
    EVENT ||--o{ PROCESS_EVENT : "extends"
    EVENT ||--o{ MESSAGE_EVENT : "extends"
    EVENT ||--o{ STATE_CHANGE : "extends"
    EVENT ||--o{ PERFORMANCE_METRIC : "extends"
    EVENT ||--o{ ERROR_EVENT : "extends"
```

## 6. ElixirLS Integration Architecture

```mermaid
graph TB
    subgraph "IDE Environment"
        IDE[VS Code / Editor]
        ELS[ElixirLS Language Server]
        DAP[Debug Adapter Protocol]
    end

    subgraph "ElixirScope System"
        subgraph "Analysis Engine"
            AI[AI Analysis Engine]
            CA[Crash Analyzer]
            PA[Performance Analyzer]
            RD[Race Detector]
        end

        subgraph "Integration Layer"
            ELI[ElixirLS Integration]
            DO[Debug Orchestrator]
            SC[Strategy Controller]
        end

        subgraph "Data Layer"
            QC[Query Coordinator]
            TD[Trace Database]
            CUI[Cinema UI]
        end
    end

    subgraph "Target Application"
        APP[Instrumented App]
        BP[Breakpoint Manager]
        DR[Debug Runtime]
    end

    %% Data Flow
    APP --> TD
    TD --> AI
    AI --> CA
    AI --> PA
    AI --> RD
    
    CA --> DO
    PA --> DO
    RD --> DO
    
    DO --> SC
    SC --> ELI
    ELI --> DAP
    
    DAP --> ELS
    ELS --> IDE
    
    %% Bidirectional Debug Control
    IDE --> ELS
    ELS --> DAP
    DAP --> ELI
    ELI --> BP
    BP --> APP
    
    %% Context Sharing
    QC --> ELI
    CUI -.-> ELI

    classDef ide fill:#e3f2fd
    classDef elixirscope fill:#e8f5e8
    classDef analysis fill:#fff3e0
    classDef integration fill:#f3e5f5
    classDef target fill:#ffebee
    
    class IDE,ELS,DAP ide
    class AI,CA,PA,RD analysis
    class ELI,DO,SC integration
    class QC,TD,CUI elixirscope
    class APP,BP,DR target
```

## 7. Execution Cinema UI Component Architecture

```mermaid
graph TB
    subgraph "Execution Cinema UI"
        subgraph "Timeline Controls"
            TS[Timeline Scrubber]
            TC[Time Controls]
            TF[Time Filters]
        end

        subgraph "Multi-Perspective Views"
            SV[System View - Process Constellation]
            PV[Process View - Message Flows]
            CV[Code View - Function Execution]
            STV[State View - Data Evolution]
            PerfV[Performance View - Bottlenecks]
            CausV[Causality View - Root Cause]
        end

        subgraph "Interaction Layer"
            ES[Event Selector]
            ZC[Zoom Controller]
            FC[Filter Controller]
            AI_UI[AI Insights Panel]
        end

        subgraph "Data Integration"
            QE[Query Engine]
            DAG_R[DAG Renderer]
            RT[Real-time Updater]
        end
    end

    subgraph "Backend Services"
        QC[Query Coordinator]
        EC[Event Correlator]
        AE[AI Analysis Engine]
        Storage[(Storage Layer)]
    end

    %% UI Interactions
    TS --> ES
    TC --> QE
    TF --> FC
    ES --> ZC
    
    %% View Synchronization
    SV -.-> PV
    PV -.-> CV
    CV -.-> STV
    STV -.-> PerfV
    PerfV -.-> CausV
    CausV -.-> SV

    %% Data Flow
    QE --> QC
    QC --> Storage
    Storage --> EC
    EC --> DAG_R
    DAG_R --> SV
    DAG_R --> PV
    DAG_R --> CV
    
    AE --> AI_UI
    RT --> QE

    classDef ui fill:#e3f2fd
    classDef view fill:#e8f5e8
    classDef control fill:#fff3e0
    classDef backend fill:#f3e5f5
    
    class TS,TC,TF,ES,ZC,FC ui
    class SV,PV,CV,STV,PerfV,CausV view
    class QE,DAG_R,RT,AI_UI control
    class QC,EC,AE,Storage backend
```

## 8. Phase Implementation Roadmap

```mermaid
gantt
    title ElixirScope Implementation Phases
    dateFormat YYYY-MM
    axisFormat %Y-%m

    section Phase 1: Foundation
    AI Code Analysis        :p1-ai, 2024-01, 2024-03
    AST Transformation      :p1-ast, 2024-02, 2024-04
    Event Capture Pipeline  :p1-cap, 2024-03, 2024-05
    Storage Foundation      :p1-stor, 2024-04, 2024-06
    Basic Query API         :p1-api, 2024-05, 2024-06

    section Phase 2: Cinema Core
    DAG Materialization     :p2-dag, 2024-07, 2024-09
    Basic Cinema UI         :p2-ui, 2024-08, 2024-11
    State Reconstruction    :p2-state, 2024-09, 2024-11
    Time Travel Features    :p2-time, 2024-10, 2024-12

    section Phase 3: Advanced UX
    Advanced Visualizations :p3-viz, 2025-01, 2025-04
    AI Analysis Engine      :p3-ai, 2025-02, 2025-05
    Phoenix Integration     :p3-phx, 2025-03, 2025-06
    Intelligent Filtering   :p3-filter, 2025-04, 2025-06

    section Phase 4: Production
    Production Hardening    :p4-prod, 2025-07, 2025-10
    Distributed Tracing     :p4-dist, 2025-08, 2025-11
    ElixirLS Orchestration  :p4-els, 2025-09, 2025-12
    Performance Optimization:p4-perf, 2025-10, 2025-12
```

These diagrams provide a comprehensive visual representation of the ElixirScope system, from high-level architecture through detailed data models and implementation phases. Each diagram focuses on a different aspect of the system to help understand the complex interactions between AI-driven instrumentation, event capture, multi-dimensional analysis, and the innovative "Execution Cinema" visualization approach.
