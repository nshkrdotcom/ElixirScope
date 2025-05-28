# ElixirScope AST Repository Architecture - Mermaid Diagrams

## 1. System Overview & Component Architecture

```mermaid
graph LR
    subgraph "ElixirScope AST Repository Enhanced System"
        subgraph "Input Layer"
            FS[File System]
            RT[Runtime Events]
            AST[Source Code AST]
        end
        
        subgraph "Processing Layer"
            FW[File Watcher<br/>Real-time monitoring]
            P[Parser<br/>AST → Node IDs]
            IM[Instrumentation Mapper<br/>Strategy selection]
        end
        
        subgraph "Analysis Engine"
            CFG[CFG Generator<br/>Control Flow]
            DFG[DFG Generator<br/>Data Flow]
            CPG[CPG Builder<br/>Unified Graph]
            CM[Complexity Metrics<br/>Multi-dimensional]
        end
        
        subgraph "Correlation Layer"
            RC[Runtime Correlator<br/><5ms lookup]
            TI[Temporal Index<br/>Time-based queries]
        end
        
        subgraph "Storage Layer"
            ER[Enhanced Repository<br/>ETS-based storage]
            EM[Enhanced Module Data]
            EF[Enhanced Function Data]
        end
        
        subgraph "Query Interface"
            QE[Query Engine<br/>Complex queries]
            API[Public API<br/>GenServer interface]
        end
    end
    
    FS --> FW
    RT --> RC
    AST --> P
    
    FW --> P
    P --> IM
    IM --> CFG
    IM --> DFG
    
    CFG --> CPG
    DFG --> CPG
    CPG --> CM
    
    RC --> TI
    RT --> RC
    
    CFG --> ER
    DFG --> ER
    CPG --> ER
    CM --> ER
    
    ER --> EM
    ER --> EF
    
    ER --> QE
    QE --> API
    
    style CFG fill:#e1f5fe,color:#000
    style DFG fill:#f3e5f5,color:#000
    style CPG fill:#fff3e0,color:#000
    style RC fill:#e8f5e8,color:#000
    style ER fill:#fff8e1,color:#000
```

## 2. Data Flow Architecture

```mermaid
flowchart TD
    subgraph "Source Processing Pipeline"
        SC[Source Code] --> PA[Parser<br/>assign_node_ids]
        PA --> IP[Extract<br/>Instrumentation Points]
        IP --> CI[Build<br/>Correlation Index]
    end
    
    subgraph "Graph Generation Pipeline"
        AST[Enhanced AST] --> CFG_GEN[CFG Generator]
        AST --> DFG_GEN[DFG Generator]
        
        CFG_GEN --> CFG_DATA[CFGData<br/>• Nodes<br/>• Edges<br/>• Complexity]
        DFG_GEN --> DFG_DATA[DFGData<br/>• Variables<br/>• Data Flows<br/>• SSA Form]
        
        CFG_DATA --> CPG_BUILD[CPG Builder]
        DFG_DATA --> CPG_BUILD
        
        CPG_BUILD --> CPG_DATA[CPGData<br/>• Unified Nodes<br/>• Cross-references<br/>• Analysis Results]
    end
    
    subgraph "Analysis Pipeline"
        CPG_DATA --> SEC[Security Analysis<br/>• Taint tracking<br/>• Vulnerabilities]
        CPG_DATA --> PERF[Performance Analysis<br/>• Bottlenecks<br/>• Optimization]
        CPG_DATA --> QUAL[Quality Analysis<br/>• Code smells<br/>• Maintainability]
    end
    
    subgraph "Storage Pipeline"
        SEC --> EFD[Enhanced Function Data]
        PERF --> EFD
        QUAL --> EFD
        
        EFD --> EMD[Enhanced Module Data]
        EMD --> REPO[Enhanced Repository<br/>ETS Tables]
    end
    
    subgraph "Runtime Correlation"
        RE[Runtime Events] --> RC[Runtime Correlator]
        CI --> RC
        RC --> REPO
    end
    
    SC --> AST
    
    style CFG_GEN fill:#e1f5fe,color:#000
    style DFG_GEN fill:#f3e5f5,color:#000
    style CPG_BUILD fill:#fff3e0,color:#000
```

## 3. Control Flow Graph (CFG) Generation Detail

```mermaid
flowchart TD
    subgraph "CFG Generation Process"
        FAST[Function AST] --> VAL[Validate AST Structure]
        VAL --> INIT[Initialize State<br/>• Entry node<br/>• Scope tracking<br/>• Node counter]
        
        INIT --> PROC[Process Function Body]
        
        subgraph "AST Node Processing"
            PROC --> CASE{Node Type?}
            
            CASE -->|def/defp| FUNC[Process Function<br/>• Extract parameters<br/>• Analyze body]
            CASE -->|case| CASE_PROC[Process Case<br/>• Pattern matching<br/>• Multiple branches]
            CASE -->|if| IF_PROC[Process Conditional<br/>• True/false branches<br/>• Guard analysis]
            CASE -->|pipe| PIPE_PROC[Process Pipe<br/>• Data flow tracking<br/>• Sequential ops]
            CASE -->|try| TRY_PROC[Process Exception<br/>• Rescue clauses<br/>• After blocks]
            CASE -->|comprehension| COMP_PROC[Process Comprehension<br/>• Generator analysis<br/>• Filter conditions]
        end
        
        FUNC --> CREATE_NODES[Create CFG Nodes<br/>• Assign unique IDs<br/>• Set predecessors/successors]
        CASE_PROC --> CREATE_NODES
        IF_PROC --> CREATE_NODES
        PIPE_PROC --> CREATE_NODES
        TRY_PROC --> CREATE_NODES
        COMP_PROC --> CREATE_NODES
        
        CREATE_NODES --> CREATE_EDGES[Create CFG Edges<br/>• Sequential flow<br/>• Conditional branches<br/>• Exception paths]
        
        CREATE_EDGES --> COMPLEXITY[Calculate Complexity<br/>• Decision points method<br/>• Cognitive complexity<br/>• Nesting depth]
        
        COMPLEXITY --> PATH_ANALYSIS[Path Analysis<br/>• All execution paths<br/>• Critical paths<br/>• Unreachable nodes]
        
        PATH_ANALYSIS --> CFG_RESULT[CFGData Structure<br/>• Complete graph<br/>• Metrics<br/>• Analysis results]
    end
    
    style CREATE_NODES fill:#e1f5fe,color:#000
    style CREATE_EDGES fill:#e1f5fe,color:#000
    style COMPLEXITY fill:#fff3e0,color:#000
```

## 4. Data Flow Graph (DFG) Generation Detail

```mermaid
flowchart TD
    subgraph "DFG Generation with SSA"
        FAST[Function AST] --> INIT[Initialize State<br/>• Variable tracking<br/>• Scope stack<br/>• SSA versioning]
        
        INIT --> ANALYZE[Analyze AST for Data Flow]
        
        subgraph "Variable Analysis"
            ANALYZE --> VAR_DEF[Variable Definitions<br/>• Parameters<br/>• Assignments<br/>• Pattern matches]
            
            VAR_DEF --> SSA[SSA Form Creation<br/>• Version variables<br/>• x → x_0, x_1, x_2]
            
            SSA --> VAR_USE[Variable Uses<br/>• References<br/>• Function arguments<br/>• Guards]
            
            VAR_USE --> DATA_FLOW[Data Flow Edges<br/>• Definition → Use<br/>• Transformation chains]
        end
        
        subgraph "Advanced Analysis"
            DATA_FLOW --> PHI[Phi Node Generation<br/>• Control flow merges<br/>• Variable unification]
            
            PHI --> CAPTURE[Closure Analysis<br/>• Captured variables<br/>• Scope tracking]
            
            CAPTURE --> SHADOW[Shadowing Detection<br/>• Variable conflicts<br/>• Scope violations]
            
            SHADOW --> MUTATION[Mutation Tracking<br/>• Variable reassignment<br/>• State changes]
        end
        
        MUTATION --> LIFETIME[Variable Lifetime<br/>• Birth to death tracking<br/>• Usage frequency]
        
        LIFETIME --> UNUSED[Unused Variable Detection<br/>• Dead code analysis<br/>• Optimization hints]
        
        UNUSED --> DFG_RESULT[DFGData Structure<br/>• Complete data flow<br/>• Analysis results<br/>• Optimization hints]
    end
    
    style SSA fill:#f3e5f5,color:#000
    style PHI fill:#f3e5f5,color:#000
    style CAPTURE fill:#e8f5e8,color:#000
```

## 5. Runtime Correlation Architecture

```mermaid
sequenceDiagram
    participant RT as Runtime Event
    participant RC as Runtime Correlator
    participant CI as Correlation Index
    participant TI as Temporal Index
    participant DA as Data Access
    participant REPO as Repository
    
    Note over RT,REPO: Event Correlation Flow (<5ms target)
    
    RT->>RC: Runtime Event<br/>{correlation_id, data}
    
    RC->>RC: Extract correlation_id
    
    alt Cache Hit
        RC->>CI: Lookup correlation_id
        CI-->>RC: AST node_id
    else Cache Miss
        RC->>REPO: correlate_event(event)
        REPO-->>RC: AST node_id
        RC->>CI: Cache correlation
    end
    
    RC->>DA: Store enriched event
    RC->>TI: Update temporal index<br/>{timestamp, correlation}
    
    RC-->>RT: {:ok, ast_node_id}
    
    Note over RC: Performance Tracking
    RC->>RC: Update statistics<br/>• Total correlations<br/>• Success rate<br/>• Avg duration
    
    Note over TI: Temporal Queries Enable
    TI->>TI: Time-range queries<br/>• Debug sessions<br/>• Performance analysis
```

## 6. Storage and Query Architecture

```mermaid
graph TB
    subgraph "ETS Storage Layer"
        subgraph "Core Tables"
            MOD_T[":ast_modules_enhanced<br/>Module storage"]
            FUNC_T[":ast_functions_enhanced<br/>Function storage"]
            META_T[":ast_metadata<br/>AST node metadata"]
        end
        
        subgraph "Index Tables"
            FILE_IDX[":ast_module_by_file<br/>File → Module mapping"]
            NAME_IDX[":ast_function_by_name<br/>Name-based queries"]
            COMP_IDX[":ast_function_by_complexity<br/>Complexity buckets"]
            CALL_IDX[":ast_calls_by_target<br/>Reference tracking"]
        end
        
        subgraph "Correlation Tables"
            CORR_IDX[":correlation_index<br/>ID → AST mapping"]
            TEMP_IDX[":temporal_correlation<br/>Time-based queries"]
            INSTR_PTS[":instrumentation_points<br/>Runtime hooks"]
        end
    end
    
    subgraph "Query Interface"
        QE[Query Engine] --> EXEC[Query Executor]
        
        EXEC --> FILTER["Apply Filters<br/>• Complexity: {:gt, 10}<br/>• Module match<br/>• Pattern search"]
        
        FILTER --> SORT[Apply Sorting<br/>• By complexity<br/>• By name<br/>• By frequency]
        
        SORT --> LIMIT[Apply Limits<br/>• Pagination<br/>• Performance control]
        
        LIMIT --> RESULT[Query Results]
    end
    
    subgraph "API Layer"
        PUB_API[Public API<br/>GenServer interface]
        
        PUB_API --> STORE[store_module/2<br/>store_function/4]
        PUB_API --> GET[get_module/2<br/>get_function/4]
        PUB_API --> QUERY[query_functions/2<br/>find_references/4]
        PUB_API --> HEALTH[health_check/1<br/>get_statistics/1]
    end
    
    STORE --> MOD_T
    STORE --> FUNC_T
    STORE --> META_T
    
    GET --> MOD_T
    GET --> FUNC_T
    
    QUERY --> QE
    
    PUB_API --> FILE_IDX
    PUB_API --> NAME_IDX
    PUB_API --> COMP_IDX
    
    style MOD_T fill:#fff8e1,color:#000
    style FUNC_T fill:#fff8e1,color:#000
    style QE fill:#e8f5e8,color:#000
```

## 7. File System Integration Architecture

```mermaid
sequenceDiagram
    participant FS as File System
    participant FW as File Watcher
    participant SYNC as Synchronizer
    participant PP as Project Populator
    participant REPO as Repository
    
    Note over FS,REPO: Real-time File Synchronization
    
    FS->>FW: File Change Event<br/>{path, events}
    
    FW->>FW: should_process_file?<br/>• Check extensions (.ex, .exs)<br/>• Apply ignore patterns<br/>• Validate file size
    
    alt File Should Be Processed
        FW->>FW: Debounce Logic<br/>• Aggregate changes<br/>• Prevent thrashing
        
        FW->>SYNC: sync_file(path)
        
        SYNC->>PP: parse_and_analyze_file(path)
        
        PP->>PP: Parse AST<br/>Code.string_to_quoted/2
        
        PP->>PP: Generate Analysis<br/>• CFG generation<br/>• DFG generation<br/>• Complexity metrics
        
        PP-->>SYNC: {:ok, enhanced_module_data}
        
        SYNC->>REPO: store_module(module_data)
        REPO-->>SYNC: :ok
        
        SYNC-->>FW: :ok
        
        FW->>FW: Update Statistics<br/>• Files processed<br/>• Success rate<br/>• Performance metrics
    else File Ignored
        FW->>FW: Log ignored file<br/>Continue monitoring
    end
    
    Note over FW: Batch Processing Support
    FW->>SYNC: sync_files([paths])<br/>Batch operations
    
    Note over FW: Error Recovery
    FW->>FW: Handle failures<br/>• Retry logic<br/>• Graceful degradation
```

## 8. Performance and Monitoring Architecture

```mermaid
graph LR
    subgraph "Performance Monitoring System"
        subgraph "Metrics Collection"
            PERF_T[Performance Tracking<br/>• Operation durations<br/>• Memory usage<br/>• Success rates]
            
            STATS[Statistics Aggregation<br/>• Rolling averages<br/>• Percentiles<br/>• Trend analysis]
            
            HEALTH[Health Monitoring<br/>• Component status<br/>• Resource utilization<br/>• Error rates]
        end
        
        subgraph "Performance Targets"
            CFG_TARGET[CFG Generation<br/>Target: <100ms<br/>Memory: <1MB]
            
            DFG_TARGET[DFG Analysis<br/>Target: <200ms<br/>Memory: <2MB]
            
            CPG_TARGET[CPG Building<br/>Target: <500ms<br/>Memory: <5MB]
            
            CORR_TARGET[Runtime Correlation<br/>Target: <5ms<br/>Cache hit: >95%]
            
            STORAGE_TARGET[Module Storage<br/>Target: <50ms<br/>Query: <100ms]
        end
        
        subgraph "Optimization Strategies"
            CACHE[ETS Caching<br/>• Correlation cache<br/>• Query result cache<br/>• AST metadata cache]
            
            BATCH[Batch Processing<br/>• File synchronization<br/>• Event correlation<br/>• Statistics updates]
            
            INDEX[Smart Indexing<br/>• Complexity buckets<br/>• Name-based lookup<br/>• File-to-module mapping]
            
            PARALLEL[Parallel Processing<br/>• Multi-core utilization<br/>• Async operations<br/>• Task supervision]
        end
    end
    
    subgraph "Memory Management"
        MEM_LIMIT[Memory Limits<br/>Repository: 500MB<br/>Cache: 100MB]
        
        CLEANUP[Periodic Cleanup<br/>• LRU eviction<br/>• Unused data removal<br/>• Defragmentation]
        
        GC[Garbage Collection<br/>• Process-level GC<br/>• ETS table cleanup<br/>• Memory monitoring]
    end
    
    CFG_TARGET --> PERF_T
    DFG_TARGET --> PERF_T
    CPG_TARGET --> PERF_T
    CORR_TARGET --> PERF_T
    STORAGE_TARGET --> PERF_T
    
    PERF_T --> STATS
    STATS --> HEALTH
    
    HEALTH --> CACHE
    HEALTH --> BATCH
    HEALTH --> INDEX
    HEALTH --> PARALLEL
    
    MEM_LIMIT --> CLEANUP
    CLEANUP --> GC
    
    style CFG_TARGET fill:#e1f5fe,color:#000
    style DFG_TARGET fill:#f3e5f5,color:#000
    style CPG_TARGET fill:#fff3e0,color:#000
    style CORR_TARGET fill:#e8f5e8,color:#000
```

These diagrams provide a comprehensive architectural overview suitable for senior engineers, covering the system's layered architecture, data flow patterns, detailed component interactions, and performance characteristics. Each diagram focuses on a specific aspect while showing how components integrate within the larger system.