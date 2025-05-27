# ElixirScope Architecture Diagrams

## 1. Overall System Architecture

```mermaid
graph TB
    subgraph "ElixirScope System"
        subgraph "Layer 1: Core Infrastructure"
            APP[Application]
            CONFIG[Config]
            EVENTS[Events]
            UTILS[Utils]
        end
        
        subgraph "Layer 2: Capture Pipeline"
            INGESTOR[Ingestor]
            RINGBUF[Ring Buffer]
            PIPELINE[Pipeline Manager]
            ASYNC_POOL[Async Writer Pool]
            CORRELATOR[Event Correlator]
            RUNTIME[Instrumentation Runtime]
        end
        
        subgraph "Layer 3: Storage & Data Access"
            DATA_ACCESS[Data Access]
            AST_REPO[AST Repository]
            FUNC_DATA[Function Data]
            MODULE_DATA[Module Data]
        end
        
        subgraph "Layer 4: AI Analysis Engine"
            AI_ORCHESTRATOR[AI Orchestrator]
            CODE_ANALYZER[Code Analyzer]
            COMPLEXITY[Complexity Analyzer]
            PATTERN_REC[Pattern Recognizer]
            INTELLIGENT[Intelligent Code Analyzer]
            PREDICTOR[Execution Predictor]
        end
        
        subgraph "Layer 5: LLM Integration"
            LLM_CLIENT[LLM Client]
            LLM_CONFIG[LLM Config]
            GEMINI[Gemini Provider]
            VERTEX[Vertex Provider]
            MOCK[Mock Provider]
        end
        
        subgraph "Layer 6: AST Processing"
            TRANSFORMER[AST Transformer]
            ENHANCED_TRANS[Enhanced Transformer]
            INJECTOR[Injector Helpers]
            PARSER[AST Parser]
        end
        
        subgraph "Layer 7: Compile-Time Integration"
            MIX_TASK[Mix Compile Task]
            COMPILE_ORCH[Compile-Time Orchestrator]
        end
        
        subgraph "Layer 8: Runtime Integration"
            PHOENIX_INT[Phoenix Integration]
            DISTRIBUTED[Distributed Systems]
        end
    end
    
    %% Data Flow
    RUNTIME --> INGESTOR
    INGESTOR --> RINGBUF
    RINGBUF --> ASYNC_POOL
    ASYNC_POOL --> CORRELATOR
    CORRELATOR --> DATA_ACCESS
    
    %% AI Flow
    AI_ORCHESTRATOR --> CODE_ANALYZER
    CODE_ANALYZER --> LLM_CLIENT
    LLM_CLIENT --> GEMINI
    LLM_CLIENT --> VERTEX
    LLM_CLIENT --> MOCK
    
    %% AST Flow
    MIX_TASK --> TRANSFORMER
    TRANSFORMER --> ENHANCED_TRANS
    ENHANCED_TRANS --> AST_REPO
    
    %% Configuration
    CONFIG --> APP
    CONFIG --> AI_ORCHESTRATOR
    CONFIG --> PIPELINE
```

## 2. Data Flow Architecture

```mermaid
flowchart TD
    subgraph "Source Code"
        ELIXIR_CODE[Elixir Source Files]
        PHOENIX_APP[Phoenix Application]
    end
    
    subgraph "Compile-Time Processing"
        MIX_COMPILER[Mix Compiler Task]
        AST_ANALYSIS[AST Analysis]
        AI_PLANNING[AI Planning]
        AST_TRANSFORMATION[AST Transformation]
        INSTRUMENTED_CODE[Instrumented Code]
    end
    
    subgraph "Runtime Execution"
        EXECUTING_CODE[Executing Application]
        RUNTIME_EVENTS[Runtime Events]
    end
    
    subgraph "Event Capture Pipeline"
        INGEST[Event Ingestion]
        BUFFER[Ring Buffer]
        ASYNC_PROC[Async Processing]
        CORRELATION[Event Correlation]
    end
    
    subgraph "Storage Layer"
        HOT_STORAGE[Hot Storage - ETS]
        WARM_STORAGE[Warm Storage - Disk]
        COLD_STORAGE[Cold Storage - Archive]
    end
    
    subgraph "Analysis & Intelligence"
        PATTERN_ANALYSIS[Pattern Analysis]
        PERFORMANCE_METRICS[Performance Metrics]
        AI_INSIGHTS[AI-Generated Insights]
        PREDICTIVE_ANALYTICS[Predictive Analytics]
    end
    
    subgraph "Query & Interface"
        QUERY_ENGINE[Query Engine]
        TIME_TRAVEL[Time Travel Debugging]
        VISUALIZATION[Data Visualization]
        API_INTERFACE[API Interface]
    end
    
    %% Compile-time flow
    ELIXIR_CODE --> MIX_COMPILER
    PHOENIX_APP --> MIX_COMPILER
    MIX_COMPILER --> AST_ANALYSIS
    AST_ANALYSIS --> AI_PLANNING
    AI_PLANNING --> AST_TRANSFORMATION
    AST_TRANSFORMATION --> INSTRUMENTED_CODE
    
    %% Runtime flow
    INSTRUMENTED_CODE --> EXECUTING_CODE
    EXECUTING_CODE --> RUNTIME_EVENTS
    RUNTIME_EVENTS --> INGEST
    INGEST --> BUFFER
    BUFFER --> ASYNC_PROC
    ASYNC_PROC --> CORRELATION
    
    %% Storage flow
    CORRELATION --> HOT_STORAGE
    HOT_STORAGE --> WARM_STORAGE
    WARM_STORAGE --> COLD_STORAGE
    
    %% Analysis flow
    HOT_STORAGE --> PATTERN_ANALYSIS
    HOT_STORAGE --> PERFORMANCE_METRICS
    PATTERN_ANALYSIS --> AI_INSIGHTS
    PERFORMANCE_METRICS --> PREDICTIVE_ANALYTICS
    
    %% Query flow
    HOT_STORAGE --> QUERY_ENGINE
    WARM_STORAGE --> QUERY_ENGINE
    QUERY_ENGINE --> TIME_TRAVEL
    QUERY_ENGINE --> VISUALIZATION
    QUERY_ENGINE --> API_INTERFACE
```

## 3. AI-Powered Analysis Pipeline

```mermaid
graph LR
    subgraph "Code Analysis Input"
        SOURCE_CODE[Source Code Files]
        AST_DATA[AST Structures]
        RUNTIME_DATA[Runtime Execution Data]
    end
    
    subgraph "AI Analysis Engine"
        CODE_ANALYZER[Code Analyzer]
        COMPLEXITY_ANALYZER[Complexity Analyzer]
        PATTERN_RECOGNIZER[Pattern Recognizer]
        INTELLIGENT_ANALYZER[Intelligent Code Analyzer]
    end
    
    subgraph "LLM Integration Layer"
        LLM_CLIENT[LLM Client]
        
        subgraph "Providers"
            GEMINI[Google Gemini]
            VERTEX[Vertex AI]
            MOCK[Mock Provider]
        end
        
        LLM_CLIENT --> GEMINI
        LLM_CLIENT --> VERTEX
        LLM_CLIENT --> MOCK
    end
    
    subgraph "Analysis Outputs"
        INSTRUMENTATION_PLAN[Instrumentation Plan]
        COMPLEXITY_METRICS[Complexity Metrics]
        PATTERN_INSIGHTS[Pattern Insights]
        PERFORMANCE_PREDICTIONS[Performance Predictions]
        REFACTORING_SUGGESTIONS[Refactoring Suggestions]
    end
    
    subgraph "Execution Prediction"
        EXECUTION_PREDICTOR[Execution Predictor]
        RESOURCE_PREDICTION[Resource Usage Prediction]
        CONCURRENCY_ANALYSIS[Concurrency Impact Analysis]
        BOTTLENECK_DETECTION[Bottleneck Detection]
    end
    
    %% Input flow
    SOURCE_CODE --> CODE_ANALYZER
    AST_DATA --> CODE_ANALYZER
    RUNTIME_DATA --> CODE_ANALYZER
    
    %% Analysis flow
    CODE_ANALYZER --> COMPLEXITY_ANALYZER
    CODE_ANALYZER --> PATTERN_RECOGNIZER
    CODE_ANALYZER --> INTELLIGENT_ANALYZER
    
    %% LLM integration
    INTELLIGENT_ANALYZER --> LLM_CLIENT
    
    %% Output generation
    COMPLEXITY_ANALYZER --> COMPLEXITY_METRICS
    PATTERN_RECOGNIZER --> PATTERN_INSIGHTS
    INTELLIGENT_ANALYZER --> INSTRUMENTATION_PLAN
    LLM_CLIENT --> REFACTORING_SUGGESTIONS
    
    %% Prediction flow
    RUNTIME_DATA --> EXECUTION_PREDICTOR
    EXECUTION_PREDICTOR --> RESOURCE_PREDICTION
    EXECUTION_PREDICTOR --> CONCURRENCY_ANALYSIS
    EXECUTION_PREDICTOR --> BOTTLENECK_DETECTION
    EXECUTION_PREDICTOR --> PERFORMANCE_PREDICTIONS
```

## 4. Event Capture and Processing Pipeline

```mermaid
sequenceDiagram
    participant App as Application Code
    participant Runtime as Instrumentation Runtime
    participant Ingestor as Event Ingestor
    participant RingBuffer as Ring Buffer
    participant AsyncPool as Async Writer Pool
    participant Correlator as Event Correlator
    participant Storage as Data Storage
    
    Note over App, Storage: Event Capture Flow
    
    App->>Runtime: Function call/exit
    Runtime->>Runtime: Check if enabled
    Runtime->>Ingestor: Report event
    Ingestor->>RingBuffer: Write event (<1μs)
    
    Note over RingBuffer, AsyncPool: Asynchronous Processing
    
    AsyncPool->>RingBuffer: Read batch
    RingBuffer-->>AsyncPool: Events batch
    AsyncPool->>Correlator: Process events
    
    Note over Correlator, Storage: Correlation & Storage
    
    Correlator->>Correlator: Establish causality
    Correlator->>Storage: Store correlated events
    
    Note over App, Storage: Query Flow
    
    App->>Storage: Query events
    Storage-->>App: Return results
```

## 5. AST Transformation and Hybrid Architecture

```mermaid
graph TD
    subgraph "Compile-Time AST Processing"
        ORIGINAL_AST[Original AST]
        AST_PARSER[Enhanced AST Parser]
        NODE_ASSIGNMENT[AST Node ID Assignment]
        INSTRUMENTATION_MAPPING[Instrumentation Point Mapping]
    end
    
    subgraph "AI-Driven Planning"
        CODE_ANALYSIS[Code Analysis]
        INSTRUMENTATION_PLAN[Instrumentation Plan Generation]
        OPTIMIZATION[Performance Optimization]
    end
    
    subgraph "AST Transformation"
        BASE_TRANSFORMER[Base Transformer]
        ENHANCED_TRANSFORMER[Enhanced Transformer]
        INJECTOR_HELPERS[Injector Helpers]
        TRANSFORMED_AST[Instrumented AST]
    end
    
    subgraph "Runtime Correlation Infrastructure"
        AST_REPOSITORY[AST Repository]
        CORRELATION_INDEX[Correlation Index]
        RUNTIME_CORRELATOR[Runtime Correlator]
        FUNCTION_DATA[Function Data Store]
        MODULE_DATA[Module Data Store]
    end
    
    subgraph "Runtime Execution"
        INSTRUMENTED_CODE[Instrumented Code Execution]
        RUNTIME_EVENTS[Runtime Events]
        EVENT_CORRELATION[Event-AST Correlation]
        HYBRID_DEBUGGING[Hybrid Debugging Interface]
    end
    
    %% Compile-time flow
    ORIGINAL_AST --> AST_PARSER
    AST_PARSER --> NODE_ASSIGNMENT
    NODE_ASSIGNMENT --> INSTRUMENTATION_MAPPING
    
    %% AI planning
    ORIGINAL_AST --> CODE_ANALYSIS
    CODE_ANALYSIS --> INSTRUMENTATION_PLAN
    INSTRUMENTATION_PLAN --> OPTIMIZATION
    
    %% Transformation
    INSTRUMENTATION_MAPPING --> BASE_TRANSFORMER
    OPTIMIZATION --> ENHANCED_TRANSFORMER
    BASE_TRANSFORMER --> INJECTOR_HELPERS
    ENHANCED_TRANSFORMER --> INJECTOR_HELPERS
    INJECTOR_HELPERS --> TRANSFORMED_AST
    
    %% Repository setup
    NODE_ASSIGNMENT --> AST_REPOSITORY
    INSTRUMENTATION_MAPPING --> CORRELATION_INDEX
    AST_REPOSITORY --> FUNCTION_DATA
    AST_REPOSITORY --> MODULE_DATA
    
    %% Runtime correlation
    TRANSFORMED_AST --> INSTRUMENTED_CODE
    INSTRUMENTED_CODE --> RUNTIME_EVENTS
    RUNTIME_EVENTS --> RUNTIME_CORRELATOR
    CORRELATION_INDEX --> RUNTIME_CORRELATOR
    RUNTIME_CORRELATOR --> EVENT_CORRELATION
    EVENT_CORRELATION --> HYBRID_DEBUGGING
```

## 6. Distributed System Architecture

```mermaid
graph TB
    subgraph "Node 1"
        N1_APP[ElixirScope Application]
        N1_CAPTURE[Event Capture]
        N1_STORAGE[Local Storage]
        N1_COORDINATOR[Node Coordinator]
        N1_CLOCK[Global Clock]
    end
    
    subgraph "Node 2"
        N2_APP[ElixirScope Application]
        N2_CAPTURE[Event Capture]
        N2_STORAGE[Local Storage]
        N2_COORDINATOR[Node Coordinator]
        N2_CLOCK[Global Clock]
    end
    
    subgraph "Node 3"
        N3_APP[ElixirScope Application]
        N3_CAPTURE[Event Capture]
        N3_STORAGE[Local Storage]
        N3_COORDINATOR[Node Coordinator]
        N3_CLOCK[Global Clock]
    end
    
    subgraph "Distributed Coordination"
        EVENT_SYNC[Event Synchronizer]
        PARTITION_DETECTOR[Partition Detection]
        GLOBAL_QUERY[Distributed Query Engine]
    end
    
    %% Inter-node communication
    N1_COORDINATOR <--> N2_COORDINATOR
    N2_COORDINATOR <--> N3_COORDINATOR
    N1_COORDINATOR <--> N3_COORDINATOR
    
    %% Clock synchronization
    N1_CLOCK <--> N2_CLOCK
    N2_CLOCK <--> N3_CLOCK
    N1_CLOCK <--> N3_CLOCK
    
    %% Event synchronization
    N1_STORAGE --> EVENT_SYNC
    N2_STORAGE --> EVENT_SYNC
    N3_STORAGE --> EVENT_SYNC
    
    %% Partition detection
    N1_COORDINATOR --> PARTITION_DETECTOR
    N2_COORDINATOR --> PARTITION_DETECTOR
    N3_COORDINATOR --> PARTITION_DETECTOR
    
    %% Distributed queries
    N1_STORAGE --> GLOBAL_QUERY
    N2_STORAGE --> GLOBAL_QUERY
    N3_STORAGE --> GLOBAL_QUERY
```

## 7. Phoenix Integration Architecture

```mermaid
graph LR
    subgraph "Phoenix Application"
        PHOENIX_ENDPOINT[Phoenix Endpoint]
        PHOENIX_ROUTER[Phoenix Router]
        PHOENIX_CONTROLLER[Phoenix Controller]
        PHOENIX_LIVEVIEW[Phoenix LiveView]
        PHOENIX_CHANNEL[Phoenix Channel]
        ECTO_REPO[Ecto Repository]
    end
    
    subgraph "ElixirScope Phoenix Integration"
        TELEMETRY_HANDLERS[Telemetry Handlers]
        HTTP_EVENTS[HTTP Request/Response Events]
        LIVEVIEW_EVENTS[LiveView Lifecycle Events]
        CHANNEL_EVENTS[Channel Message Events]
        ECTO_EVENTS[Database Query Events]
        CORRELATION_MANAGER[Correlation ID Manager]
    end
    
    subgraph "ElixirScope Core"
        INSTRUMENTATION_RUNTIME[Instrumentation Runtime]
        EVENT_INGESTOR[Event Ingestor]
        RING_BUFFER[Ring Buffer]
    end
    
    %% Phoenix to Integration
    PHOENIX_ENDPOINT --> TELEMETRY_HANDLERS
    PHOENIX_ROUTER --> TELEMETRY_HANDLERS
    PHOENIX_CONTROLLER --> TELEMETRY_HANDLERS
    PHOENIX_LIVEVIEW --> TELEMETRY_HANDLERS
    PHOENIX_CHANNEL --> TELEMETRY_HANDLERS
    ECTO_REPO --> TELEMETRY_HANDLERS
    
    %% Integration processing
    TELEMETRY_HANDLERS --> HTTP_EVENTS
    TELEMETRY_HANDLERS --> LIVEVIEW_EVENTS
    TELEMETRY_HANDLERS --> CHANNEL_EVENTS
    TELEMETRY_HANDLERS --> ECTO_EVENTS
    TELEMETRY_HANDLERS --> CORRELATION_MANAGER
    
    %% To ElixirScope Core
    HTTP_EVENTS --> INSTRUMENTATION_RUNTIME
    LIVEVIEW_EVENTS --> INSTRUMENTATION_RUNTIME
    CHANNEL_EVENTS --> INSTRUMENTATION_RUNTIME
    ECTO_EVENTS --> INSTRUMENTATION_RUNTIME
    CORRELATION_MANAGER --> INSTRUMENTATION_RUNTIME
    
    INSTRUMENTATION_RUNTIME --> EVENT_INGESTOR
    EVENT_INGESTOR --> RING_BUFFER
```

## 8. Storage and Query Architecture

```mermaid
graph TB
    subgraph "Event Sources"
        FUNCTION_EVENTS[Function Execution Events]
        STATE_EVENTS[State Change Events]
        MESSAGE_EVENTS[Message Passing Events]
        PERFORMANCE_EVENTS[Performance Events]
        ERROR_EVENTS[Error Events]
    end
    
    subgraph "Storage Tiers"
        subgraph "Hot Storage (ETS)"
            PRIMARY_TABLE[Primary Events Table]
            TEMPORAL_INDEX[Temporal Index]
            PROCESS_INDEX[Process Index]
            FUNCTION_INDEX[Function Index]
            CORRELATION_INDEX[Correlation Index]
        end
        
        subgraph "Warm Storage (Disk)"
            COMPRESSED_FILES[Compressed Event Files]
            METADATA_INDEX[Metadata Index]
        end
        
        subgraph "Cold Storage (Archive)"
            ARCHIVED_DATA[Archived Historical Data]
        end
    end
    
    subgraph "Query Engine"
        QUERY_PARSER[Query Parser]
        INDEX_OPTIMIZER[Index Optimizer]
        RESULT_MERGER[Result Merger]
        TIME_TRAVEL_ENGINE[Time Travel Engine]
    end
    
    subgraph "Query Types"
        TEMPORAL_QUERIES[Temporal Range Queries]
        PROCESS_QUERIES[Process-based Queries]
        CORRELATION_QUERIES[Correlation Queries]
        STATE_RECONSTRUCTION[State Reconstruction]
        MESSAGE_FLOW_ANALYSIS[Message Flow Analysis]
    end
    
    %% Event ingestion
    FUNCTION_EVENTS --> PRIMARY_TABLE
    STATE_EVENTS --> PRIMARY_TABLE
    MESSAGE_EVENTS --> PRIMARY_TABLE
    PERFORMANCE_EVENTS --> PRIMARY_TABLE
    ERROR_EVENTS --> PRIMARY_TABLE
    
    %% Index creation
    PRIMARY_TABLE --> TEMPORAL_INDEX
    PRIMARY_TABLE --> PROCESS_INDEX
    PRIMARY_TABLE --> FUNCTION_INDEX
    PRIMARY_TABLE --> CORRELATION_INDEX
    
    %% Storage tiers
    PRIMARY_TABLE --> COMPRESSED_FILES
    COMPRESSED_FILES --> ARCHIVED_DATA
    
    %% Query processing
    TEMPORAL_QUERIES --> QUERY_PARSER
    PROCESS_QUERIES --> QUERY_PARSER
    CORRELATION_QUERIES --> QUERY_PARSER
    STATE_RECONSTRUCTION --> QUERY_PARSER
    MESSAGE_FLOW_ANALYSIS --> QUERY_PARSER
    
    QUERY_PARSER --> INDEX_OPTIMIZER
    INDEX_OPTIMIZER --> RESULT_MERGER
    RESULT_MERGER --> TIME_TRAVEL_ENGINE
    
    %% Query execution
    TIME_TRAVEL_ENGINE --> TEMPORAL_INDEX
    TIME_TRAVEL_ENGINE --> PROCESS_INDEX
    TIME_TRAVEL_ENGINE --> FUNCTION_INDEX
    TIME_TRAVEL_ENGINE --> CORRELATION_INDEX
```

## 9. Performance and Monitoring

```mermaid
graph LR
    subgraph "Performance Monitoring"
        CAPTURE_METRICS[Capture Performance]
        STORAGE_METRICS[Storage Performance]
        QUERY_METRICS[Query Performance]
        AI_METRICS[AI Processing Performance]
    end
    
    subgraph "System Health"
        RING_BUFFER_HEALTH[Ring Buffer Utilization]
        MEMORY_USAGE[Memory Usage Tracking]
        CPU_UTILIZATION[CPU Utilization]
        DISK_USAGE[Disk Usage Monitoring]
    end
    
    subgraph "Quality Metrics"
        EVENT_LOSS_RATE[Event Loss Rate]
        CORRELATION_ACCURACY[Correlation Accuracy]
        LATENCY_PERCENTILES[Latency Percentiles]
        THROUGHPUT_RATES[Throughput Rates]
    end
    
    subgraph "Adaptive Optimization"
        SAMPLING_CONTROLLER[Dynamic Sampling Control]
        BACKPRESSURE_MANAGER[Backpressure Management]
        RESOURCE_SCALER[Resource Scaling]
        ALERT_SYSTEM[Alert System]
    end
    
    %% Monitoring connections
    CAPTURE_METRICS --> RING_BUFFER_HEALTH
    STORAGE_METRICS --> MEMORY_USAGE
    QUERY_METRICS --> CPU_UTILIZATION
    AI_METRICS --> DISK_USAGE
    
    %% Quality tracking
    RING_BUFFER_HEALTH --> EVENT_LOSS_RATE
    MEMORY_USAGE --> CORRELATION_ACCURACY
    CPU_UTILIZATION --> LATENCY_PERCENTILES
    DISK_USAGE --> THROUGHPUT_RATES
    
    %% Adaptive responses
    EVENT_LOSS_RATE --> SAMPLING_CONTROLLER
    CORRELATION_ACCURACY --> BACKPRESSURE_MANAGER
    LATENCY_PERCENTILES --> RESOURCE_SCALER
    THROUGHPUT_RATES --> ALERT_SYSTEM
```

## 10. Module Dependency Graph

```mermaid
graph TD
    %% Core modules
    APP[Application] --> CONFIG[Config]
    APP --> EVENTS[Events]
    APP --> UTILS[Utils]
    
    %% Capture layer
    CONFIG --> PIPELINE[Pipeline Manager]
    PIPELINE --> RING_BUFFER[Ring Buffer]
    PIPELINE --> ASYNC_POOL[Async Writer Pool]
    PIPELINE --> INGESTOR[Ingestor]
    PIPELINE --> CORRELATOR[Event Correlator]
    
    ASYNC_POOL --> ASYNC_WRITER[Async Writer]
    INGESTOR --> RING_BUFFER
    CORRELATOR --> EVENTS
    
    %% Storage layer
    INGESTOR --> DATA_ACCESS[Data Access]
    DATA_ACCESS --> EVENTS
    
    %% AST processing
    AST_TRANSFORMER[AST Transformer] --> AST_INJECTOR[Injector Helpers]
    AST_ENHANCED[Enhanced Transformer] --> AST_TRANSFORMER
    AST_PARSER[Parser] --> AST_REPO[AST Repository]
    AST_REPO --> FUNCTION_DATA[Function Data]
    AST_REPO --> MODULE_DATA[Module Data]
    AST_REPO --> RUNTIME_CORRELATOR[Runtime Correlator]
    
    %% AI components
    AI_ORCHESTRATOR[AI Orchestrator] --> CODE_ANALYZER[Code Analyzer]
    CODE_ANALYZER --> COMPLEXITY_ANALYZER[Complexity Analyzer]
    CODE_ANALYZER --> PATTERN_RECOGNIZER[Pattern Recognizer]
    AI_ORCHESTRATOR --> INTELLIGENT_ANALYZER[Intelligent Code Analyzer]
    AI_ORCHESTRATOR --> EXECUTION_PREDICTOR[Execution Predictor]
    
    %% LLM integration
    INTELLIGENT_ANALYZER --> LLM_CLIENT[LLM Client]
    LLM_CLIENT --> LLM_PROVIDER[LLM Provider]
    LLM_PROVIDER --> GEMINI_PROVIDER[Gemini Provider]
    LLM_PROVIDER --> VERTEX_PROVIDER[Vertex Provider]
    LLM_PROVIDER --> MOCK_PROVIDER[Mock Provider]
    
    %% Compile-time
    COMPILE_ORCHESTRATOR[Compile-Time Orchestrator] --> AI_ORCHESTRATOR
    MIX_TASK[Mix Task] --> AST_TRANSFORMER
    MIX_TASK --> COMPILE_ORCHESTRATOR
    
    %% Runtime integration
    INSTRUMENTATION_RUNTIME[Instrumentation Runtime] --> INGESTOR
    PHOENIX_INTEGRATION[Phoenix Integration] --> INSTRUMENTATION_RUNTIME
    
    %% Distributed
    NODE_COORDINATOR[Node Coordinator] --> EVENT_SYNCHRONIZER[Event Synchronizer]
    NODE_COORDINATOR --> GLOBAL_CLOCK[Global Clock]
    EVENT_SYNCHRONIZER --> DATA_ACCESS
    
    %% Dependencies
    UTILS --> CONFIG
    UTILS --> EVENTS
    EVENTS --> UTILS
```

These diagrams provide a comprehensive view of the ElixirScope architecture, showing how the various components interact to provide AI-powered execution cinema debugging capabilities. The architecture is designed for high performance, scalability, and intelligent analysis of Elixir applications.
