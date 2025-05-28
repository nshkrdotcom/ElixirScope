Okay, here is a series of detailed Mermaid diagrams depicting the architecture and internal workings of key ElixirScope features, tailored for a technical audience.

---

## ElixirScope Mermaid Diagrams

This section provides a series of Mermaid diagrams illustrating the architecture, data flows, and internal mechanisms of key ElixirScope components. These diagrams are intended for a technical audience familiar with distributed systems, compiler design, and advanced software engineering concepts.

### 1. Overall System Architecture

```mermaid
graph TD
    subgraph Compile-Time Processing
        direction LR
        SRC[Source Code .ex/.exs] --> MIX_COMPILER{Mix.Tasks.Compile.ElixirScope}
        MIX_COMPILER --> ORCH[CompileTime.Orchestrator]
        ORCH --> AI_CA[AI.CodeAnalyzer]
        AI_CA --> PLAN[Instrumentation Plan]
        MIX_COMPILER --> PARSER[ASTRepository.Parser/NodeIdentifier]
        PARSER --> AST_W_IDS[AST with NodeIDs]
        AST_W_IDS --> TRANSFORMER[AST.EnhancedTransformer]
        PLAN ==> TRANSFORMER
        TRANSFORMER --> INSTR_AST[Instrumented AST .beam]

        AST_W_IDS --> STATIC_ANALYZERS[Static Analyzers]
        subgraph Static Analyzers
            direction LR
            SA1[ASTRepository.ASTAnalyzer]
            SA2[Enhanced.CFGGenerator]
            SA3[Enhanced.DFGGenerator]
            SA4[Enhanced.CPGBuilder]
        end
        STATIC_ANALYZERS --> ENH_REPO[EnhancedASTRepository]
        ENH_REPO <--> ETS_AST[(ETS: Static Data)]
    end

    subgraph Runtime System
        direction LR
        INSTR_AST -- Executes --> APP[User Application]
        APP -- Calls --> RUNTIME_API[Capture.InstrumentationRuntime]
        RUNTIME_API -- Events (ast_node_id) --> INGESTOR[Capture.Ingestor]
        INGESTOR --> RINGBUFFER[Capture.RingBuffer]
        RINGBUFFER --> WRITER_POOL[Capture.AsyncWriterPool]
        WRITER_POOL --> EVENT_STORE_SVC[Storage.EventStore Service]
        EVENT_STORE_SVC --> ETS_EVENTS[(ETS: Runtime Events)]

        RUNTIME_API -- AST-Aware Events --> TEMP_BRIDGE_ENH[Capture.TemporalBridgeEnhancement]
        TEMP_BRIDGE_ENH <--> RUNTIME_CORR[ASTRepository.RuntimeCorrelator]
        RUNTIME_CORR <--> ENH_REPO
        TEMP_BRIDGE_ENH <--> TEMP_STORAGE[Capture.TemporalStorage]
        TEMP_STORAGE <--> ETS_TEMP[(ETS: Temporal Events)]
    end

    subgraph Query & Analysis
        direction LR
        QE[QueryEngine.Engine] <--> EVENT_STORE_SVC
        QE_AST[QueryEngine.ASTExtensions] <--> QE
        QE_AST <--> ENH_REPO
        UI_API[UI/API Layer] --> QE_AST
        UI_API --> TEMP_BRIDGE_ENH

        AI_COMPONENTS[AI Components] <--> AI_BRIDGE[AI.Bridge]
        AI_BRIDGE <--> ENH_REPO
        AI_BRIDGE <--> QE_AST
        AI_COMPONENTS --> ORCH
    end

    subgraph Distributed Tracing
        direction TB
        NODE_COORD[Distributed.NodeCoordinator] <--> NODE_A[Node A: ElixirScope Instance]
        NODE_COORD <--> NODE_B[Node B: ElixirScope Instance]
        NODE_A <--> GLOBAL_CLOCK[Distributed.GlobalClock]
        NODE_B <--> GLOBAL_CLOCK
        NODE_A <--> EVENT_SYNC[Distributed.EventSynchronizer]
        NODE_B <--> EVENT_SYNC
    end

    style SRC fill:#f9f,stroke:#333,stroke-width:2px,color:#000
    style INSTR_AST fill:#f9f,stroke:#333,stroke-width:2px,color:#000
    style ETS_AST fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style ETS_EVENTS fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style ETS_TEMP fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
```

**Diagram 1 Description:** This diagram shows the high-level interaction between the compile-time processing, runtime system, query/analysis layer, and distributed tracing components. It highlights the flow of code and data from source to instrumented binaries, runtime event capture, storage, and subsequent analysis.

---

### 2. Enhanced AST Repository - Internal Structure and Data Flow

```mermaid
graph TD
    subgraph Project Processing
        direction TB
        POPULATOR[Enhanced.ProjectPopulator] -- Discovers & Reads --> FILES[Project Files .ex/.exs]
        FILES --> PARSER[ASTRepository.Parser/NodeIdentifier]
        PARSER -- AST with NodeIDs --> ANALYZER[ASTRepository.ASTAnalyzer]
        ANALYZER -- EnhancedModuleData --> REPO_API[EnhancedRepository API]

        ANALYZER -- Function ASTs --> GENERATORS[Graph Generators]
        subgraph Graph Generators
            direction TB
            CFG_GEN[Enhanced.CFGGenerator] --> CFG_DATA[CFGData]
            DFG_GEN[Enhanced.DFGGenerator] --> DFG_DATA[DFGData]
            CPG_GEN[Enhanced.CPGBuilder] -- AST, CFG, DFG --> CPG_DATA[CPGData]
        end
        CFG_DATA --> REPO_API
        DFG_DATA --> REPO_API
        CPG_DATA --> REPO_API
    end

    subgraph Repository Core
        direction TB
        REPO_API -- Stores/Updates --> REPO_GENSERVER[EnhancedRepository GenServer]
        REPO_GENSERVER <--> ETS_MODULES[(ETS: ast_modules_enhanced)]
        REPO_GENSERVER <--> ETS_FUNCTIONS[(ETS: ast_functions_enhanced)]
        REPO_GENSERVER <--> ETS_CPGS[(ETS: ast_cpgs)]
        REPO_GENSERVER <--> ETS_NODES[(ETS: ast_nodes_detailed)]
        REPO_GENSERVER <--> ETS_VARIABLES[(ETS: ast_variables_detailed)]
        REPO_GENSERVER <--> ETS_INDEXES[(ETS: Index Tables)]
        REPO_GENSERVER <--> MEM_MANAGER[ASTRepository.MemoryManager]
    end

    subgraph Synchronization
        direction TB
        FILE_WATCHER[Enhanced.FileWatcher] -- File Events --> SYNCHRONIZER[Enhanced.Synchronizer]
        SYNCHRONIZER -- Parses & Analyzes Changed File --> ANALYZER
        SYNCHRONIZER -- Updates --> REPO_API
    end

    subgraph Querying
        direction TB
        QUERY_BUILDER[ASTRepository.QueryBuilder] --> QUERY_SPEC[Query Specification]
        QUERY_SPEC --> QUERY_EXECUTOR[ASTRepository.QueryExecutor / Repo API]
        QUERY_EXECUTOR -- Accesses --> REPO_GENSERVER
        QUERY_EXECUTOR --> QUERY_RESULTS[Query Results]
    end

    style FILES fill:#f9f,stroke:#333,stroke-width:2px,color:#000
    style ETS_MODULES fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style ETS_FUNCTIONS fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style ETS_CPGS fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style ETS_NODES fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style ETS_VARIABLES fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style ETS_INDEXES fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
```

**Diagram 2 Description:** This diagram details the internal structure of the Enhanced AST Repository. It shows how `ProjectPopulator` and `FileWatcher`/`Synchronizer` feed data into the `ASTAnalyzer` and graph generators (`CFGGenerator`, `DFGGenerator`, `CPGBuilder`). The results are stored in the `EnhancedRepository GenServer`, which manages various ETS tables for modules, functions, CPGs, and indexes. The `MemoryManager` interacts with the repository for optimization, and the `QueryBuilder`/`QueryExecutor` provide the interface for accessing this static data.

---

### 3. Runtime Event Capture and AST Correlation Flow

```mermaid
graph TD
    APP_CODE[Instrumented Application Code] -- AST Node ID, Data --> RUNTIME_API[Capture.InstrumentationRuntime]

    subgraph InstrumentationRuntime Process Context
        direction LR
        CTX_MGMT{{Context Management}}
        CTX_MGMT --> ENABLED_CHECK{enabled?}
        CTX_MGMT --> CALL_STACK[ProcessDict: Call Stack]
        CTX_MGMT --> CORR_ID_MGMT[ProcessDict: Correlation ID]
    end

    RUNTIME_API -- Uses --> CTX_MGMT
    RUNTIME_API -- Raw Event Data --> INGESTOR[Capture.Ingestor]

    INGESTOR -- Formats --> EV_STRUCT[ElixirScope.Events Struct]
    EV_STRUCT -- Write --> RINGBUFFER[Capture.RingBuffer]

    RINGBUFFER --> ASYNC_WRITER_POOL[Capture.AsyncWriterPool]
    ASYNC_WRITER_POOL -- Batched Events --> EVENT_STORE_SVC[Storage.EventStore Service]
    EVENT_STORE_SVC -- Stores --> ETS_EVENTS[(ETS: Raw Events)]

    subgraph ACP["AST Correlation Path (Enhanced Instrumentation)"]
        direction LR
        RUNTIME_API -- AST-Aware Event --> ENH_INSTR[Capture.EnhancedInstrumentation]
        ENH_INSTR -- Evaluates --> BREAKPOINTS[Breakpoints/Watchpoints ETS]
        ENH_INSTR -- Event + AST_Node_ID --> RUNTIME_CORR[ASTRepository.RuntimeCorrelator]
        RUNTIME_CORR -- "Queries (AST Node ID)" --> ENH_REPO[EnhancedASTRepository]
        ENH_REPO -- AST/CPG Context --> RUNTIME_CORR
        RUNTIME_CORR -- Enhanced Event --> TEMP_BRIDGE_ENH[Capture.TemporalBridgeEnhancement]
        TEMP_BRIDGE_ENH -- Stores Correlated Event --> TEMP_STORAGE[Capture.TemporalStorage]
    end

    style APP_CODE fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style RUNTIME_API fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style BREAKPOINTS fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
```

**Diagram 3 Description:** This diagram illustrates the flow of runtime events. Instrumented application code calls `InstrumentationRuntime`. Basic event data flows through the `Ingestor`, `RingBuffer`, and `AsyncWriterPool` to the `EventStore`. For AST-aware events (from `EnhancedTransformer`), `EnhancedInstrumentation` handles breakpoint evaluation and forwards events with `ast_node_id` to `RuntimeCorrelator`. The `RuntimeCorrelator` queries the `EnhancedASTRepository` to fetch static context and produces an enhanced event, which is then passed to `TemporalBridgeEnhancement` for storage in `TemporalStorage`, enabling advanced debugging features.

---

### 4. CPG (Code Property Graph) Generation Process

```mermaid
graph TD
    FN_AST[Function AST with NodeIDs] --> CPG_BUILDER[Enhanced.CPGBuilder]

    subgraph Input Graphs
        direction LR
        FN_AST -- Gen --> CFG_GEN[Enhanced.CFGGenerator]
        CFG_GEN --> CFG_DATA[CFGData]

        FN_AST -- Gen --> DFG_GEN[Enhanced.DFGGenerator]
        DFG_GEN --> DFG_DATA["DFGData (SSA)"]
    end

    CFG_DATA --> CPG_BUILDER
    DFG_DATA --> CPG_BUILDER

    subgraph CPGBuilder Internals
        direction TB
        INIT[Initialize CPG State] --> AST_NODES_TO_CPG[1 AST Nodes to CPG Nodes + AST Edges]
        AST_NODES_TO_CPG --> OVERLAY_CFG[2 Overlay CFG: Augment CPG Nodes, Add CFG Edges]
        OVERLAY_CFG --> OVERLAY_DFG[3 Overlay DFG: Augment CPG Nodes, Add DFG Edges, Create Phi CPG Nodes]
        OVERLAY_DFG --> INTER_PROC["4 Inter-procedural Edges (Calls)"]
        INTER_PROC --> BUILD_INDEXES[5 Build Query Indexes]
        BUILD_INDEXES --> FINAL_CPG[Final CPGData Struct]
    end

    CPG_BUILDER --> CPG_DATA_OUT[CPGData Output]
    CPG_DATA_OUT -- Stored in --> ENH_REPO[EnhancedASTRepository]

    style FN_AST fill:#f9f,stroke:#333,stroke-width:2px,color:#000
    style CFG_DATA fill:#e6ffe6,stroke:#333,stroke-width:1px,color:#000
    style DFG_DATA fill:#e6e6ff,stroke:#333,stroke-width:1px,color:#000
    style CPG_DATA_OUT fill:#ffe6cc,stroke:#333,stroke-width:2px,color:#000
```

**Diagram 4 Description:** This diagram outlines the CPG generation process. A function's AST (with pre-assigned NodeIDs) is fed into the `CPGBuilder`. Internally, `CFGGenerator` and `DFGGenerator` produce their respective graphs from this AST. The `CPGBuilder` then executes a multi-phase process:
1.  Creates CPG nodes primarily from AST nodes and establishes AST structural edges.
2.  Overlays CFG information by augmenting existing CPG nodes with CFG data and translating CFG edges into CPG CFG-typed edges.
3.  Overlays DFG information, augmenting CPG nodes with DFG data (definitions, uses), creating DFG-typed edges, and potentially creating new synthetic CPG nodes for elements like SSA Phi functions.
4.  (Conceptually) Adds inter-procedural call edges.
5.  Builds query indexes for the unified graph.
The final `CPGData` struct is then stored in the `EnhancedASTRepository`.

---

### 5. Correlated Query Execution (Static + Dynamic)

```mermaid
graph TD
    USER_QUERY[User Query / AI Request] --> QE_AST[QueryEngine.ASTExtensions]

    subgraph Static Query Phase
        direction TB
        QE_AST -- Static Query Spec --> QUERY_BUILDER[ASTRepository.QueryBuilder]
        QUERY_BUILDER -- Optimized Spec --> QUERY_EXEC[ASTRepository.QueryExecutor / EnhancedRepository API]
        QUERY_EXEC -- Accesses --> ENH_REPO_DB[(EnhancedRepository ETS Tables: CPGs, Static Analysis)]
        ENH_REPO_DB -- Static Results --> QUERY_EXEC
        QUERY_EXEC -- Filtered Static Data (e.g., list of ast_node_ids, function_keys) --> QE_AST
    end

    subgraph Dynamic Query Phase
        direction TB
        QE_AST -- Parameterized Runtime Query (using join_keys from static phase) --> QE_ENGINE[QueryEngine.Engine]
        QE_ENGINE -- Accesses --> EVENT_STORE_SVC[Storage.EventStore Service / TemporalStorage]
        EVENT_STORE_SVC -- Runtime Events --> QE_ENGINE
        QE_ENGINE -- Filtered Runtime Events --> QE_AST
    end

    QE_AST -- Joins Static & Dynamic Results --> FINAL_RESULTS[Correlated Query Results]
    FINAL_RESULTS --> USER_AI[User / AI Component]

    style USER_QUERY fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style ENH_REPO_DB fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style EVENT_STORE_SVC fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style FINAL_RESULTS fill:#cfc,stroke:#333,stroke-width:2px,color:#000
```

**Diagram 5 Description:** This diagram illustrates how `QueryEngine.ASTExtensions` handles correlated queries that combine static and dynamic data.
1.  A static query part is formulated (possibly via `QueryBuilder`) and executed against the `EnhancedASTRepository` to retrieve static code elements (e.g., functions meeting complexity criteria, CPG nodes matching a pattern).
2.  Join keys (like `ast_node_id`s or `function_key`s) are extracted from these static results.
3.  These join keys are used to parameterize a runtime query template, which is then executed by `QueryEngine.Engine` against the `EventStore` or `TemporalStorage`.
4.  `ASTExtensions` then joins the results from the static and dynamic query phases to produce the final correlated output.

---

### 6. Advanced Debugging Feature: Structural Breakpoint Flow

```mermaid
graph TD
    subgraph Setup Phase
        DEV_UI[Developer UI/API] -- Breakpoint Spec (AST Pattern, Condition) --> ENH_INSTR_API[Capture.EnhancedInstrumentation API]
        ENH_INSTR_API -- :set_structural_breakpoint --> ENH_INSTR_GEN[EnhancedInstrumentation GenServer]
        ENH_INSTR_GEN -- Stores --> BP_ETS[(ETS: Breakpoint Definitions)]
    end

    subgraph Runtime Event
        APP_CODE[Instrumented App Code] -- AST_Node_ID, Event Data --> RUNTIME_API[Capture.InstrumentationRuntime]
        RUNTIME_API -- Forwards AST-Aware Event --> ENH_INSTR_GEN
    end

    subgraph Breakpoint Evaluation
        direction LR
        ENH_INSTR_GEN -- Receives Event --> EVAL_LOGIC{Breakpoint Evaluation Logic}
        EVAL_LOGIC -- Retrieves Active BPs --> BP_ETS
        EVAL_LOGIC -- For Current AST_Node_ID, Queries --> ENH_REPO[EnhancedASTRepository]
        ENH_REPO -- AST/CPG Info for Node --> EVAL_LOGIC
        EVAL_LOGIC -- Matches AST Pattern & Condition --> TRIGGER_CHECK{Pattern Match & Condition Met?}
    end

    TRIGGER_CHECK -- Yes --> DEBUG_ACTION["Debugger Action (e.g., Pause, Log, Notify UI)"]
    TRIGGER_CHECK -- No --> CONTINUE[Continue Execution]

    style APP_CODE fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style BP_ETS fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style DEBUG_ACTION fill:#fcc,stroke:#333,stroke-width:2px,color:#000
```

**Diagram 6 Description:** This diagram shows the flow for structural breakpoints:
1.  **Setup**: A developer defines a structural breakpoint (an AST pattern and a condition) via a UI or API, which is stored by the `EnhancedInstrumentation` GenServer in an ETS table.
2.  **Runtime Event**: Instrumented code executes, and `InstrumentationRuntime` reports an AST-aware event (with `ast_node_id`) to `EnhancedInstrumentation`.
3.  **Evaluation**:
    *   `EnhancedInstrumentation` retrieves active structural breakpoint definitions.
    *   For the current event's `ast_node_id`, it queries `EnhancedASTRepository` to get the static AST/CPG information for that specific node.
    *   It then attempts to match the AST information against each active breakpoint's pattern and checks if the specified condition (e.g., pattern match failure, exception occurred) is met.
4.  **Action**: If a breakpoint's pattern and condition are satisfied, a debugger action is triggered (e.g., pausing execution, logging detailed context, notifying a UI). Otherwise, execution continues normally. Data flow breakpoints and semantic watchpoints would follow similar principles but use DFG/CPG data for their specific matching logic.


---

### 7. Enhanced Instrumentation - Breakpoint/Watchpoint Logic

```mermaid
graph LR
    subgraph User Interaction / Setup
        UI_API[Developer UI/API] -- Breakpoint/Watchpoint Definition --> ENH_INSTR_API[Capture.EnhancedInstrumentation API]
        ENH_INSTR_API -- Stores Definition --> ETS_BP_WP_DEFS[(ETS: Breakpoint/Watchpoint Definitions)]
    end

    subgraph Runtime Event Processing
        direction LR
        INSTR_RUNTIME[Capture.InstrumentationRuntime] -- AST-Aware Event (ast_node_id, data) --> ENH_INSTR_GEN[EnhancedInstrumentation GenServer]
        ENH_INSTR_GEN -- Retrieves Definitions --> ETS_BP_WP_DEFS
        ENH_INSTR_GEN -- For AST Context, Queries --> ENH_REPO[EnhancedASTRepository]
        ENH_REPO -- AST/CPG Node Details --> ENH_INSTR_GEN
    end

    subgraph Evaluation Logic within EnhancedInstrumentation
        direction TB
        ENH_INSTR_GEN --> STRUCT_BP_EVAL{Structural Breakpoint Eval}
        STRUCT_BP_EVAL -- Matches AST Pattern & Condition? --> DECISION_S{Trigger?}
        ENH_INSTR_GEN --> DF_BP_EVAL{Data Flow Breakpoint Eval}
        DF_BP_EVAL -- Matches Variable Flow & Conditions? (uses DFG from ENH_REPO) --> DECISION_DF{Trigger?}
        ENH_INSTR_GEN --> SEM_WP_EVAL{Semantic Watchpoint Eval}
        SEM_WP_EVAL -- Tracks Variable through AST Scope & Constructs? (uses CPG from ENH_REPO) --> VALUE_HIST[Update Value History]
        VALUE_HIST --> ETS_BP_WP_DEFS  
    end

    DECISION_S -- Yes --> DEBUG_ACTION["Debugger Action (Pause, Log, Notify)"]
    DECISION_DF -- Yes --> DEBUG_ACTION
    SEM_WP_EVAL -- Value Change & Condition Met? --> DEBUG_ACTION

    style UI_API fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style ETS_BP_WP_DEFS fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style DEBUG_ACTION fill:#fcc,stroke:#333,stroke-width:2px,color:#000
```

**Diagram 7 Description:** This diagram focuses on the advanced debugging features managed by `EnhancedInstrumentation`.
1.  **Setup**: Developers define structural breakpoints, data flow breakpoints, or semantic watchpoints via a UI or API. These definitions are stored by `EnhancedInstrumentation` (likely in ETS tables).
2.  **Runtime Event**: `InstrumentationRuntime` sends AST-aware events (containing `ast_node_id` and runtime data) to the `EnhancedInstrumentation` GenServer.
3.  **Evaluation**:
    *   `EnhancedInstrumentation` retrieves active breakpoint/watchpoint definitions.
    *   For the current event and its associated `ast_node_id`, it queries the `EnhancedASTRepository` to get the necessary static context (AST node details, DFG snippets, CPG context).
    *   **Structural Breakpoints**: It evaluates if the static properties of the current AST node match the breakpoint's AST pattern and if the runtime condition (e.g., exception occurred, specific value matched) is met.
    *   **Data Flow Breakpoints**: It uses DFG information to check if the specified variable's flow meets the defined conditions at the current AST node.
    *   **Semantic Watchpoints**: It uses CPG information to track the specified variable through relevant AST constructs, updating its value history. If a watched condition is met (e.g., value changes in a specific way), it can trigger an action.
4.  **Action**: If any breakpoint/watchpoint triggers, a debugger action is initiated (e.g., pausing the process, logging detailed information, sending a notification to the UI).

---

### 8. AI-Driven Instrumentation Planning Flow

```mermaid
graph TD
    subgraph Initial Analysis / User Request
        direction LR
        CODEBASE[Project Codebase] --> POPULATOR[Enhanced.ProjectPopulator]
        POPULATOR -- Initial Analysis --> ENH_REPO[EnhancedASTRepository]
        USER_CONFIG["User Config/Request (e.g., focus areas, performance targets)"]
    end

    subgraph AI Orchestration
        direction TB
        ORCH[CompileTime.Orchestrator] -- Receives --> USER_CONFIG
        ORCH -- "Fetches Static Context" --> ENH_REPO
        ORCH -- "Fetches Runtime History (Optional)" --> QE_AST[QueryEngine.ASTExtensions]

        ORCH -- Sends Analysis Request --> AI_COMPONENTS[AI Analysis Components]
        subgraph AI Analysis Components
            direction LR
            AIC_CA[AI.CodeAnalyzer]
            AIC_PR[AI.PatternRecognizer]
            AIC_COMPLEX[AI.ComplexityAnalyzer]
            AIC_PREDICT["AI.Predictive.ExecutionPredictor (for existing runtime data)"]
        end
        AI_COMPONENTS -- Analysis Results & Recommendations --> ORCH
    end

    subgraph Plan Generation & Refinement
        direction TB
        ORCH --> PLAN_GEN[Initial Instrumentation Plan Generation]
        PLAN_GEN -- Based on AI recs, user config --> RAW_PLAN[Raw Plan]
        RAW_PLAN --> PLAN_OPT["Plan Optimization (balancing coverage, overhead, priorities)"]
        PLAN_OPT --> FINAL_PLAN[Finalized Instrumentation Plan]
        FINAL_PLAN -- Stored/Cached by Orchestrator or in DataAccess --> PLAN_STORAGE[(Instrumentation Plan Storage)]
    end

    PLAN_STORAGE -- Used by --> MIX_COMPILER{Mix.Tasks.Compile.ElixirScope}

    style CODEBASE fill:#f9f,stroke:#333,stroke-width:2px,color:#000
    style USER_CONFIG fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style AI_COMPONENTS fill:#d1c4e9,stroke:#311b92,stroke-width:2px,color:#000
    style FINAL_PLAN fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px,color:#000
```

**Diagram 8 Description:** This diagram details the AI-driven instrumentation planning process orchestrated by `CompileTime.Orchestrator`.
1.  **Initial Context**: The `Orchestrator` may start with an existing analysis of the codebase from `EnhancedASTRepository` (populated by `ProjectPopulator`) and user-defined configuration or specific requests (e.g., focus on performance for certain modules). Optionally, it can query historical runtime data via `QueryEngine.ASTExtensions` to understand past behavior.
2.  **AI Analysis**: The `Orchestrator` sends this context to various AI components:
    *   `AI.CodeAnalyzer`: For general code understanding, quality assessment.
    *   `AI.PatternRecognizer`: To identify OTP patterns, architectural styles.
    *   `AI.ComplexityAnalyzer`: To gauge complexity of different code parts.
    *   `AI.Predictive.ExecutionPredictor`: If runtime data is available, to predict hotspots or problematic areas.
    These components return their analyses and recommendations.
3.  **Plan Generation**: The `Orchestrator` generates an initial instrumentation plan based on AI recommendations and user configuration. This plan might specify which modules/functions to instrument, what granularity (function, expression, variable), and what data to capture.
4.  **Plan Refinement**: The raw plan is optimized to balance desired coverage, performance overhead targets, and user-defined priorities.
5.  **Storage**: The finalized plan is stored (e.g., by `DataAccess` or cached by the `Orchestrator`) and used by the `Mix.Tasks.Compile.ElixirScope` compiler during AST transformation.

---

### 9. Temporal Bridge Enhancement - AST-Aware Time-Travel

```mermaid
graph TD
    subgraph Event Ingestion
        RUNTIME_API[Capture.InstrumentationRuntime] -- "AST-Aware Event (event, ast_node_id)" --> TEMP_BRIDGE_ENH_API[TemporalBridgeEnhancement API]
        TEMP_BRIDGE_ENH_API -- :correlate_event --> TEMP_BRIDGE_ENH_GS[TemporalBridgeEnhancement GenServer]
    end

    subgraph State Reconstruction Query
        USER_DEBUGGER[User/Debugger UI] -- "Request: reconstruct_state_with_ast(session, timestamp)" --> TEMP_BRIDGE_ENH_API
    end

    subgraph Internal Processing in TemporalBridgeEnhancement
        TEMP_BRIDGE_ENH_GS -- "1 Get base state at timestamp" --> BASE_TEMP_BRIDGE[Capture.TemporalBridge]
        BASE_TEMP_BRIDGE -- Raw State / Triggering Event --> TEMP_BRIDGE_ENH_GS

        TEMP_BRIDGE_ENH_GS -- "2 Get events around timestamp for context" --> TEMP_STORAGE["Capture.TemporalStorage (Events by Session/Time)"]
        TEMP_STORAGE -- Relevant Events --> TEMP_BRIDGE_ENH_GS

        TEMP_BRIDGE_ENH_GS -- "3 For triggering event's ast_node_id, get AST/CPG context" --> RUNTIME_CORR[ASTRepository.RuntimeCorrelator]
        RUNTIME_CORR -- Queries --> ENH_REPO[EnhancedASTRepository]
        ENH_REPO -- Static Code Context --> RUNTIME_CORR
        RUNTIME_CORR -- AST/CPG Context --> TEMP_BRIDGE_ENH_GS

        TEMP_BRIDGE_ENH_GS -- "4 Build Enhanced State (State + AST/CPG Context + Var Flow)" --> ENH_STATE[AST-Enhanced State]
        ENH_STATE -- Cache in ETS --> ETS_AST_STATE_CACHE[(ETS: AST State Cache)]
    end

    ENH_STATE --> USER_DEBUGGER

    style RUNTIME_API fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style USER_DEBUGGER fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style ENH_REPO fill:#f57c00,stroke:#e65100,stroke-width:1px,color:#000
    style TEMP_STORAGE fill:#fff3e0,stroke:#e65100,stroke-width:1px,color:#000
    style ETS_AST_STATE_CACHE fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style ENH_STATE fill:#c8e6c9,stroke:#1b5e20,stroke-width:2px,color:#000
```

**Diagram 9 Description:** This diagram illustrates how `TemporalBridgeEnhancement` provides AST-aware time-travel debugging.
1.  **Event Ingestion**: `InstrumentationRuntime` sends AST-aware events (containing `ast_node_id`) to `TemporalBridgeEnhancement`. These are eventually stored in `TemporalStorage`.
2.  **State Reconstruction Request**: A user or debugger requests to reconstruct state at a specific `timestamp` for a `session_id`.
3.  **Internal Processing**:
    *   The `TemporalBridgeEnhancement` GenServer first calls the base `TemporalBridge` (if integrated, or directly queries `TemporalStorage`) to get the raw process state and the triggering event at/before the requested `timestamp`.
    *   It fetches relevant surrounding events from `TemporalStorage` for broader context.
    *   Using the `ast_node_id` from the triggering event (or other relevant events), it calls `RuntimeCorrelator` to get the static AST/CPG context from the `EnhancedASTRepository`.
    *   It then combines the raw runtime state with the static code context, potentially analyzing variable flow from the event sequence to build an "AST-Enhanced State."
    *   This enhanced state is cached for performance.
4.  **Response**: The AST-Enhanced State is returned to the user/debugger, allowing them to see not just variable values but also the corresponding code structure that was active.

---

### 10. Distributed Event Synchronization and Correlation

```mermaid
graph TD
    subgraph NA["Node A (Event Origination)"]
        APP_A[App on Node A] --> RUNTIME_A["InstrumentationRuntime (Node A)"]
        RUNTIME_A --> EVENT_A["Event (local_ts_A, global_ts_A, ast_node_id_A)"]
        EVENT_A --> STORAGE_A["Local EventStore/TemporalStorage (Node A)"]
    end

    subgraph NB["Node B (Remote Interaction)"]
        APP_B[App on Node B] --> RUNTIME_B["InstrumentationRuntime (Node B)"]
        RUNTIME_B --> EVENT_B["Event (local_ts_B, global_ts_B, ast_node_id_B)"]
        EVENT_B --> STORAGE_B["Local EventStore/TemporalStorage (Node B)"]
    end

    subgraph SGV["Synchronization & Global View"]
        direction TB
        NODE_COORD_A["NodeCoordinator (Node A)"] <--> GLOBAL_CLOCK_A["GlobalClock (Node A)"]
        NODE_COORD_B["NodeCoordinator (Node B)"] <--> GLOBAL_CLOCK_B["GlobalClock (Node B)"]

        GLOBAL_CLOCK_A <--> GLOBAL_CLOCK_B -- (Clock Sync Protocol)

        NODE_COORD_A <--> EVENT_SYNC_A["EventSynchronizer (Node A)"]
        NODE_COORD_B <--> EVENT_SYNC_B["EventSynchronizer (Node B)"]

        EVENT_SYNC_A -- "Sync Events (with global_ts)" --> EVENT_SYNC_B
        EVENT_SYNC_B -- "Sync Events (with global_ts)" --> EVENT_SYNC_A

        STORAGE_A -- Merged View --> DIST_QUERY_ENGINE[Distributed Query Engine / Correlator]
        STORAGE_B -- Merged View --> DIST_QUERY_ENGINE
        DIST_QUERY_ENGINE -- Accesses Global Timestamps --> GLOBAL_CLOCK_A
    end

    APP_A -- RPC/Msg --> APP_B

    style APP_A fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style APP_B fill:#ccf,stroke:#333,stroke-width:2px,color:#000
    style GLOBAL_CLOCK_A fill:#ffe0b2,stroke:#ef6c00,stroke-width:1px,color:#000
    style GLOBAL_CLOCK_B fill:#ffe0b2,stroke:#ef6c00,stroke-width:1px,color:#000
    style DIST_QUERY_ENGINE fill:#c5cae9,stroke:#283593,stroke-width:2px,color:#000
```

**Diagram 10 Description:** This diagram focuses on distributed tracing and event correlation.
1.  **Local Capture**: Applications on Node A and Node B generate events via their local `InstrumentationRuntime`. Each event is timestamped with both a local monotonic timestamp and a global logical timestamp obtained from the local `GlobalClock`.
2.  **Global Clock Sync**: `GlobalClock` instances on each node periodically synchronize with each other to maintain a consistent (though possibly loose) global time understanding. Hybrid Logical Clocks are used.
3.  **Event Synchronization**: `NodeCoordinator` on each node triggers its `EventSynchronizer`.
    *   `EventSynchronizer` fetches local events (since its last sync with a particular remote node) from its local `EventStore`/`TemporalStorage`.
    *   It sends these events (including their global timestamps) to `EventSynchronizer` instances on other nodes.
    *   When receiving events, it stores them locally, potentially resolving conflicts or duplicates based on event IDs and global timestamps.
4.  **Distributed Correlation & Query**:
    *   A distributed query engine (or a coordinating `RuntimeCorrelator` instance) can query data across multiple nodes.
    *   It uses the global timestamps to order events correctly from different nodes, reconstructing a globally consistent view of distributed interactions (e.g., an RPC from Node A to Node B).
    *   Correlation IDs that span nodes are key to linking parts of a distributed trace.

---

### 11. Memory Management and Optimization Cycle

```mermaid
graph LR
    MEM_MANAGER[ASTRepository.MemoryManager GenServer]

    subgraph Periodic Checks
        direction TB
        MEM_MANAGER -- Schedules --> TIMER_MEM_CHECK[:memory_check Timer]
        TIMER_MEM_CHECK -- Triggers --> MEM_MANAGER
        MEM_MANAGER -- Schedules --> TIMER_CLEANUP[:cleanup Timer]
        TIMER_CLEANUP -- Triggers --> MEM_MANAGER
        MEM_MANAGER -- Schedules --> TIMER_COMPRESS[:compression Timer]
        TIMER_COMPRESS -- Triggers --> MEM_MANAGER
    end

    subgraph Memory Monitoring & Pressure Handling
        MEM_MANAGER -- :monitor_memory_usage --> SYS_INFO["System Memory Info (erlang.memory, /proc/meminfo)"]
        MEM_MANAGER -- :monitor_memory_usage --> REPO_TABLES_INFO[EnhancedRepository ETS Table Info]
        SYS_INFO --> MEM_STATS_CALC{Calculate Memory Stats & Pressure Level}
        REPO_TABLES_INFO --> MEM_STATS_CALC
        MEM_STATS_CALC -- memory_stats, pressure_level --> MEM_MANAGER
        MEM_MANAGER -- If Pressure High, Calls --> PRESSURE_HANDLER[:memory_pressure_handler Logic]
    end

    subgraph Pressure Handler Actions
        direction TB
        PRESSURE_HANDLER -- Level 1 --> CACHE_CLEAR_QUERY["Clear Query Cache (@query_cache_table)"]
        PRESSURE_HANDLER -- Level 2 --> CACHE_CLEAR_QUERY
        PRESSURE_HANDLER -- Level 2 --> COMPRESS_DATA["Compress Old Analysis Data (via :compress_old_analysis)"]
        PRESSURE_HANDLER -- Level 3 --> CACHE_CLEAR_ALL["Clear All Caches (@query_cache, @analysis_cache, @cpg_cache)"]
        PRESSURE_HANDLER -- Level 3 --> CLEANUP_MODULES["Remove Unused Module Data (via :cleanup_unused_data)"]
        PRESSURE_HANDLER -- Level 4 --> CACHE_CLEAR_ALL
        PRESSURE_HANDLER -- Level 4 --> CLEANUP_MODULES_AGGRESSIVE[Aggressive Cleanup]
        PRESSURE_HANDLER -- Level 4 --> FORCE_GC["Force erlang:garbage_collect()"]
    end

    subgraph Cleanup & Compression Logic
        MEM_MANAGER -- :cleanup_unused_data --> ACCESS_TRACKING[(ETS: @access_tracking_table - Module Access Times/Counts)]
        ACCESS_TRACKING --> FIND_STALE{Find Stale/Unused Modules}
        FIND_STALE -- Modules to Clean --> REPO_API_DEL[EnhancedRepository API: Delete Module Data]

        MEM_MANAGER -- :compress_old_analysis --> ACCESS_TRACKING
        ACCESS_TRACKING --> FIND_INFREQUENT{Find Infrequently Accessed Analysis Data}
        FIND_INFREQUENT -- Data to Compress --> COMPRESSION_LOGIC["Compression (e.g., :zlib on AST/CPG parts)"]
        COMPRESSION_LOGIC -- Compressed Data --> REPO_API_UPDATE[EnhancedRepository API: Update with Compressed Data]
    end

    style SYS_INFO fill:#e3f2fd,stroke:#0d47a1,stroke-width:1px,color:#000
    style REPO_TABLES_INFO fill:#e3f2fd,stroke:#0d47a1,stroke-width:1px,color:#000
    style ACCESS_TRACKING fill:#lightgrey,stroke:#333,stroke-width:2px,color:#fff
    style CACHE_CLEAR_QUERY fill:#fff9c4,stroke:#f57f17,stroke-width:1px,color:#000
    style COMPRESS_DATA fill:#fff9c4,stroke:#f57f17,stroke-width:1px,color:#000
```

**Diagram 11 Description:** This diagram illustrates the `MemoryManager`'s operations for the `EnhancedASTRepository`.
1.  **Periodic Tasks**: The `MemoryManager` GenServer schedules periodic timers for memory checks, data cleanup, and data compression.
2.  **Memory Monitoring**:
    *   When `:memory_check` triggers, it collects memory statistics from the Erlang VM (`erlang.memory`) and by inspecting the sizes of ETS tables used by the `EnhancedRepository`.
    *   It calculates overall usage and determines the current memory pressure level.
    *   If pressure exceeds thresholds, it invokes the `:memory_pressure_handler` logic.
3.  **Pressure Handling**: Based on the pressure level, specific actions are taken:
    *   Level 1: Clears query caches.
    *   Level 2: Additionally compresses older/infrequently accessed analysis data (like detailed CPGs or DFG results).
    *   Level 3: Clears all caches and removes unused/stale module data from the `EnhancedRepository`.
    *   Level 4: Performs emergency cleanup (more aggressive data removal) and forces system-wide garbage collection.
4.  **Cleanup & Compression**:
    *   The `:cleanup_unused_data` logic (triggered periodically or by pressure handler) consults an access tracking ETS table (which logs when modules/functions were last accessed or analyzed). It identifies stale data and instructs the `EnhancedRepository` to delete it.
    *   The `:compress_old_analysis` logic similarly uses access tracking to find infrequently used, large analysis artifacts (e.g., full ASTs, detailed CPGs) and compresses them in place within the `EnhancedRepository` (e.g., using `:zlib`). The `EnhancedRepository` would then need to handle decompressing this data on demand.

---

These diagrams should provide a solid visual foundation for understanding ElixirScope's more intricate components and their interactions.
