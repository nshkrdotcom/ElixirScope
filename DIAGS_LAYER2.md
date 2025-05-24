Looking at the comprehensive documentation and existing diagrams in DIAGS.md, I'll create additional diagrams specifically focused on Layer 2 implementation. These diagrams will help guide the development of the asynchronous processing and correlation layer.

# Additional Diagrams for Layer 2 Implementation

## 1. Layer 2 Detailed Component Architecture

```mermaid
graph TB
    subgraph "Layer 1: Capture (Existing)"
        RB1[RingBuffer 1]
        RB2[RingBuffer 2]
        RBN[RingBuffer N]
        
        ING[Ingestor]
        ING --> RB1
        ING --> RB2
        ING --> RBN
    end

    subgraph "Layer 2: Async Processing & Correlation"
        subgraph "Pipeline Manager"
            PM[PipelineManager]
            PM --> |supervises| AWP
            PM --> |monitors| BPM
            PM --> |configures| WPC
        end

        subgraph "Async Writer Pool"
            AWP[AsyncWriterPool Supervisor]
            W1[Writer Worker 1]
            W2[Writer Worker 2]
            WN[Writer Worker N]
            AWP --> W1
            AWP --> W2
            AWP --> WN
        end

        subgraph "Event Processing"
            W1 --> EC[EventCorrelator]
            W2 --> EC
            WN --> EC
            
            EC --> CID[Correlation ID Manager]
            EC --> CLM[Causal Link Manager]
            EC --> PST[Process State Tracker]
        end

        subgraph "Backpressure Management"
            BPM[BackpressureManager]
            BPM --> |monitors| RB1
            BPM --> |monitors| RB2
            BPM --> |monitors| RBN
            BPM --> |signals| AWP
        end

        subgraph "Worker Pool Config"
            WPC[WorkerPoolConfig]
            WPC --> |batch_size| W1
            WPC --> |batch_size| W2
            WPC --> |batch_size| WN
        end
    end

    subgraph "Storage Integration"
        EC --> DA[DataAccess]
        PST --> DA
        DA --> QC[QueryCoordinator]
    end

    RB1 -.-> |consume| W1
    RB2 -.-> |consume| W2
    RBN -.-> |consume| WN

    classDef layer1 fill:#e1f5fe,color:#000
    classDef layer2 fill:#f3e5f5,color:#000
    classDef storage fill:#e8f5e8,color:#000
    
    class RB1,RB2,RBN,ING layer1
    class PM,AWP,W1,W2,WN,EC,CID,CLM,PST,BPM,WPC layer2
    class DA,QC storage
```

## 2. Event Correlation State Machine

```mermaid
stateDiagram-v2
    [*] --> Raw: Event from RingBuffer
    
    Raw --> Deserializing: Worker consumes
    Deserializing --> Enriched: Add metadata
    
    Enriched --> Correlating: EventCorrelator
    
    state Correlating {
        [*] --> CheckType
        CheckType --> FunctionEntry: type = function_entry
        CheckType --> FunctionExit: type = function_exit
        CheckType --> MessageSend: type = message_send
        CheckType --> MessageReceive: type = message_receive
        CheckType --> StateChange: type = state_change
        
        FunctionEntry --> AssignCallID: Generate call_id
        FunctionExit --> LinkToEntry: Find matching call_id
        
        MessageSend --> AssignMessageID: Generate msg_id
        MessageReceive --> LinkToSend: Find matching msg_id
        
        StateChange --> LinkToCause: Find triggering event
        
        AssignCallID --> StoreCorrelation
        LinkToEntry --> StoreCorrelation
        AssignMessageID --> StoreCorrelation
        LinkToSend --> StoreCorrelation
        LinkToCause --> StoreCorrelation
    }
    
    Correlating --> Correlated: Links established
    Correlated --> Persisting: Write to DataAccess
    Persisting --> Persisted: Stored with indexes
    Persisted --> [*]
    
    Deserializing --> Error: Corrupted data
    Correlating --> Error: Missing correlation
    Persisting --> Error: Storage failure
    Error --> Retry: Backoff strategy
    Retry --> Raw: Re-process
    Error --> Drop: Max retries exceeded
```

## 3. Backpressure Control Flow

```mermaid
flowchart TD
    Start([Monitoring Loop])
    
    Start --> CheckBuffers{Check All RingBuffers}
    
    CheckBuffers --> CalcUtil[Calculate Utilization %]
    
    CalcUtil --> LowUtil{Utilization < 50%?}
    CalcUtil --> MedUtil{50% <= Util < 80%?}
    CalcUtil --> HighUtil{80% <= Util < 95%?}
    CalcUtil --> CritUtil{Utilization >= 95%?}
    
    LowUtil --> |Yes| Normal[Normal Operation]
    MedUtil --> |Yes| IncWorkers[Increase Workers]
    HighUtil --> |Yes| MaxWorkers[Max Workers + Batch Size]
    CritUtil --> |Yes| Emergency[Emergency Mode]
    
    Normal --> NormalConfig[
        - Standard batch size
        - Standard worker count
        - Normal flush interval
    ]
    
    IncWorkers --> IncConfig[
        - Spawn additional workers
        - Increase batch size 2x
        - Reduce flush interval
    ]
    
    MaxWorkers --> MaxConfig[
        - Maximum worker pool
        - Maximum batch size
        - Minimal flush interval
        - Alert monitoring
    ]
    
    Emergency --> EmergencyConfig[
        - Drop sampling activated
        - Critical events only
        - Direct write bypass
        - Alert operations team
    ]
    
    NormalConfig --> Sleep[Sleep 100ms]
    IncConfig --> Sleep[Sleep 50ms]
    MaxConfig --> Sleep[Sleep 10ms]
    EmergencyConfig --> Sleep[Sleep 5ms]
    
    Sleep --> Start
```

## 4. Worker Pool Scaling Strategy

```mermaid
graph TD
    subgraph "Metrics Collection"
        M1[RingBuffer Utilization]
        M2[Processing Latency]
        M3[Memory Usage]
        M4[Event Rate]
    end
    
    subgraph "Scaling Decision Engine"
        SE[Scaling Engine]
        M1 --> SE
        M2 --> SE
        M3 --> SE
        M4 --> SE
        
        SE --> SD{Scaling Decision}
        SD --> |Scale Up| SU[Add Workers]
        SD --> |Scale Down| SDW[Remove Workers]
        SD --> |Maintain| MA[No Change]
    end
    
    subgraph "Worker Pool States"
        MIN[Min Workers: 2]
        NORM[Normal: 4-6]
        HIGH[High Load: 8-12]
        MAX[Max Workers: 16]
        
        MIN --> |High Load| NORM
        NORM --> |Higher Load| HIGH
        HIGH --> |Peak Load| MAX
        
        MAX --> |Load Decrease| HIGH
        HIGH --> |Load Decrease| NORM
        NORM --> |Low Load| MIN
    end
    
    SU --> |Check Limits| MAX
    SDW --> |Check Limits| MIN
```

## 5. Correlation ID Lifecycle

```mermaid
sequenceDiagram
    participant IC as Instrumented Code
    participant RT as InstrumentationRuntime
    participant RB as RingBuffer
    participant W as Worker
    participant EC as EventCorrelator
    participant CIM as CorrelationIDManager
    participant DA as DataAccess

    IC->>RT: function_entry(module, func, args)
    RT->>RT: Generate correlation_id
    RT->>RB: Write event with correlation_id
    
    Note over RB: Event waits in buffer
    
    W->>RB: Read batch
    W->>W: Deserialize events
    W->>EC: Process event
    
    EC->>CIM: Register correlation_id
    CIM->>CIM: Store {correlation_id, event_id, type}
    
    EC->>DA: Store correlated event
    
    IC->>RT: function_exit(result)
    RT->>RT: Retrieve correlation_id
    RT->>RB: Write exit event
    
    W->>RB: Read exit event
    W->>EC: Process exit event
    
    EC->>CIM: Lookup correlation_id
    CIM-->>EC: Return entry event_id
    EC->>EC: Create causal link
    EC->>DA: Store linked events
    
    Note over CIM: Periodic cleanup
    CIM->>CIM: Expire old correlations
```

## 6. Layer 2 Data Flow & Processing Pipeline

```mermaid
graph TB
    subgraph "Event Sources"
        E1[Function Events]
        E2[Process Events]
        E3[Message Events]
        E4[State Changes]
    end

    subgraph "Layer 1: Ring Buffers"
        RB[Ring Buffers<br/>Lock-free, High-speed]
    end

    subgraph "Layer 2: Processing Pipeline"
        subgraph "Stage 1: Consumption"
            BC[Batch Consumer]
            BC --> DES[Deserializer]
        end

        subgraph "Stage 2: Enrichment"
            DES --> ENR[Enricher]
            ENR --> |Add| PID[Process Info]
            ENR --> |Add| TS[Wall Time]
            ENR --> |Add| NODE[Node Info]
        end

        subgraph "Stage 3: Correlation"
            ENR --> CORR[Correlator]
            CORR --> FLC[Function Link<br/>Creator]
            CORR --> MLC[Message Link<br/>Creator]
            CORR --> SLC[State Link<br/>Creator]
        end

        subgraph "Stage 4: Persistence"
            FLC --> BATCH[Batch Writer]
            MLC --> BATCH
            SLC --> BATCH
            BATCH --> |Bulk Insert| STOR[Storage Layer]
        end
    end

    subgraph "Monitoring & Control"
        MON[Pipeline Monitor]
        MON -.-> |Backpressure| BC
        MON -.-> |Stats| BATCH
        STOR -.-> |Feedback| MON
    end

    E1 --> RB
    E2 --> RB
    E3 --> RB
    E4 --> RB

    RB --> BC

    classDef source fill:#ffebee,color:#000
    classDef buffer fill:#e1f5fe,color:#000
    classDef process fill:#f3e5f5,color:#000
    classDef storage fill:#e8f5e8,color:#000
    classDef monitor fill:#fff3e0,color:#000
    
    class E1,E2,E3,E4 source
    class RB buffer
    class BC,DES,ENR,CORR,FLC,MLC,SLC,BATCH process
    class STOR storage
    class MON monitor
```

## 7. EventCorrelator Internal Architecture

```mermaid
graph LR
    subgraph "EventCorrelator Module"
        subgraph "Input Processing"
            IN[Incoming Event]
            IN --> ET{Event Type<br/>Router}
        end

        subgraph "Correlation Strategies"
            ET --> |function| FS[Function Strategy]
            ET --> |message| MS[Message Strategy]
            ET --> |state| SS[State Strategy]
            ET --> |process| PS[Process Strategy]
            
            FS --> FCT[Function Call Tracker]
            MS --> MCT[Message Correlation Tracker]
            SS --> SCT[State Change Tracker]
            PS --> PCT[Process Lifecycle Tracker]
        end

        subgraph "Link Management"
            FCT --> LM[Link Manager]
            MCT --> LM
            SCT --> LM
            PCT --> LM
            
            LM --> CL[Create Link]
            LM --> UL[Update Link]
            LM --> QL[Query Links]
        end

        subgraph "State Management"
            ST1[Call Stack State]
            ST2[Message Queue State]
            ST3[Process Tree State]
            ST4[State History Cache]
            
            FCT -.-> ST1
            MCT -.-> ST2
            PCT -.-> ST3
            SCT -.-> ST4
        end

        subgraph "Output"
            CL --> OUT[Correlated Event]
            UL --> OUT
            OUT --> |includes| LINKS[Causal Links]
            OUT --> |includes| CTXID[Context IDs]
            OUT --> |includes| META[Correlation Metadata]
        end
    end

    classDef input fill:#ffebee,color:#000
    classDef strategy fill:#e3f2fd,color:#000
    classDef state fill:#fff3e0,color:#000
    classDef output fill:#e8f5e8,color:#000
    
    class IN,ET input
    class FS,MS,SS,PS,FCT,MCT,SCT,PCT strategy
    class ST1,ST2,ST3,ST4 state
    class OUT,LINKS,CTXID,META output
```

## 8. Performance Monitoring Dashboard (Conceptual)

```mermaid
graph LR
    subgraph "Layer 2 Metrics Dashboard"
        subgraph "Throughput Metrics"
            EPS[Events/Second<br/>Current: 45,230]
            BPS[Batches/Second<br/>Current: 452]
            CPS[Correlations/Second<br/>Current: 38,450]
        end

        subgraph "Latency Metrics"
            P50[P50 Latency<br/>2.3ms]
            P95[P95 Latency<br/>8.7ms]
            P99[P99 Latency<br/>15.2ms]
        end

        subgraph "Buffer Health"
            RBU[Buffer Utilization<br/>RB1: 23%<br/>RB2: 31%<br/>RB3: 18%]
            DROP["Dropped Events<br/>0 (last hour)"]
        end

        subgraph "Worker Pool Status"
            WC[Worker Count<br/>Active: 6/16]
            WL[Worker Load<br/>Avg: 67%]
            WQ[Queue Depth<br/>Avg: 234 events]
        end

        subgraph "Correlation Success"
            CSR[Success Rate<br/>99.2%]
            MCE["Missing Correlations<br/>342 (last hour)"]
            OCE["Orphaned Events<br/>128 (last hour)"]
        end

        subgraph "System Resources"
            MEM[Memory Usage<br/>Layer 2: 487MB]
            CPU[CPU Usage<br/>Layer 2: 12%]
            ETS[ETS Tables<br/>Size: 1.2GB]
        end
    end

    subgraph "Alerts & Actions"
        A1[🟢 All Systems Normal]
        A2[🟡 High Buffer Utilization > 80%]
        A3[🔴 Correlation Failures > 5%]
        A4[🟡 Memory Pressure Warning]
    end

    RBU -.-> A2
    CSR -.-> A3
    MEM -.-> A4

    classDef metric fill:#e3f2fd,color:#000
    classDef alert fill:#fff3e0,color:#000
    classDef good fill:#c8e6c9,color:#000
    classDef warn fill:#fff9c4,color:#000
    classDef bad fill:#ffcdd2,color:#000
    
    class EPS,BPS,CPS,P50,P95,P99,WC,WL,WQ,CSR,MEM,CPU,ETS metric
    class A1 good
    class A2,A4 warn
    class A3 bad
```

These diagrams provide detailed guidance for implementing Layer 2, covering:

1. **Component Architecture**: How all Layer 2 components interact
2. **State Machines**: Event correlation workflow
3. **Control Flows**: Backpressure management logic
4. **Scaling Strategies**: Dynamic worker pool management
5. **Sequence Diagrams**: Correlation ID lifecycle
6. **Data Flow**: Complete processing pipeline
7. **Internal Architecture**: EventCorrelator implementation details
8. **Monitoring**: Key metrics to track for Layer 2 health

These complement the existing diagrams in DIAGS.md and provide the implementation-level detail needed to build Layer 2 successfully.