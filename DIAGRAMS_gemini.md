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

These diagrams provide a foundational visual understanding. Each component and interaction can be further detailed with more specific sequence diagrams or state charts if needed.
