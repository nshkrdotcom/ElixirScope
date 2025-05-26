I'll create a comprehensive set of Mermaid diagrams to visualize the ElixirScope implementation architecture and flows.

## 2. Event Flow Sequence

> **Note:** Primarily runtime flow; needs to include AST instrumentation path via `Capture.InstrumentationRuntime`.

```mermaid
sequenceDiagram
    participant IC as Instrumented Code
    participant RT as InstrumentationRuntime
    participant ING as Ingestor
    participant RB as RingBuffer
    participant AW as AsyncWriter
    participant EC as EventCorrelator
    participant DA as DataAccess
    
    IC->>RT: report_function_entry()
    RT->>RT: Check enabled?
    RT->>RT: Generate correlation_id
    RT->>ING: ingest_function_call()
    ING->>ING: Truncate large data
    ING->>ING: Add timestamps
    ING->>RB: write(event)
    RB->>RB: Atomic claim position
    RB->>RB: Store in ETS
    
    Note over RB,AW: Async Processing
    
    AW->>RB: read_batch()
    RB->>AW: Return events
    AW->>AW: Enrich events
    AW->>EC: correlate_batch()
    EC->>EC: Build call stacks
    EC->>EC: Match messages
    EC->>DA: store_events()
    DA->>DA: Update all indexes
```

## 3. RingBuffer Lock-free Operations

```mermaid
graph LR
    subgraph "Atomics (Lock-free)"
        WP[Write Position<br/>@write_pos]
        RP[Read Position<br/>@read_pos]
        TW[Total Writes<br/>@total_writes]
        TR[Total Reads<br/>@total_reads]
        DE[Dropped Events<br/>@dropped_events]
    end
    
    subgraph "ETS Buffer Table"
        E0[Index 0: Event]
        E1[Index 1: Event]
        E2[Index 2: Event]
        EN[Index N: Event]
    end
    
    subgraph "Operations"
        W[Write Thread]
        R1[Reader Thread 1]
        R2[Reader Thread 2]
    end
    
    W -->|"CAS increment"| WP
    W -->|"position & mask"| E0
    R1 -->|"Read"| RP
    R1 -->|"position & mask"| E1
    R2 -->|"Read"| RP
    R2 -->|"position & mask"| E2
    
    style WP fill:#ffcccc,color:#000
    style RP fill:#ccffcc,color:#000
```

## 5. AsyncWriterPool Work Distribution

```mermaid
graph TB
    subgraph "AsyncWriterPool"
        PM[Pool Manager]
        WA[Worker Assignments]
    end
    
    subgraph "Workers"
        W1[Worker 1<br/>Segment 0]
        W2[Worker 2<br/>Segment 1]
        W3[Worker 3<br/>Segment 2]
        W4[Worker 4<br/>Segment 3]
    end
    
    subgraph "RingBuffer Positions"
        POS[0..N positions]
        S1[Segment 1<br/>0-250]
        S2[Segment 2<br/>251-500]
        S3[Segment 3<br/>501-750]
        S4[Segment 4<br/>751-1000]
    end
    
    PM --> W1
    PM --> W2
    PM --> W3
    PM --> W4
    
    W1 --> S1
    W2 --> S2
    W3 --> S3
    W4 --> S4
    
    W1 -.->|Monitor| PM
    W2 -.->|Monitor| PM
    W3 -.->|Monitor| PM
    W4 -.->|Monitor| PM
    
    style W1 fill:#ff9999,color:#000
    style W2 fill:#99ff99,color:#000
    style W3 fill:#9999ff,color:#000
    style W4 fill:#ffff99,color:#000
```

## 6. Storage Layer Index Structure

```mermaid
graph TD
    subgraph "Primary Storage"
        PT[Primary Table<br/>event_id → Event]
    end
    
    subgraph "Index Tables"
        TI[Temporal Index<br/>timestamp → event_id]
        PI[Process Index<br/>pid → event_ids]
        FI["Function Index<br/>{module, function} → event_ids"]
        CI[Correlation Index<br/>correlation_id → event_ids]
    end
    
    subgraph "Query Types"
        Q1[Time Range Query]
        Q2[Process Query]
        Q3[Function Query]
        Q4[Correlation Query]
    end
    
    Q1 --> TI
    TI --> PT
    
    Q2 --> PI
    PI --> PT
    
    Q3 --> FI
    FI --> PT
    
    Q4 --> CI
    CI --> PT
    
    style PT fill:#ffcccc,color:#000
    style TI fill:#ccffcc,color:#000
    style PI fill:#ccccff,color:#000
    style FI fill:#ffffcc,color:#000
    style CI fill:#ffccff,color:#000
```

## 7. Configuration Flow

```mermaid
graph TD
    subgraph "Configuration Sources"
        CF[config.exs]
        ENV[Environment Variables]
        RT[Runtime Updates]
    end
    
    subgraph "Config Server"
        CS[ConfigServer GenServer]
        VAL[Validation]
        CACHE[Cached Config]
    end
    
    subgraph "Updatable Paths"
        SR[sampling_rate]
        STR[strategy]
        BS[batch_size]
        FI[flush_interval]
        QT[query_timeout]
    end
    
    CF --> CS
    ENV --> CS
    RT --> CS
    
    CS --> VAL
    VAL --> CACHE
    
    CACHE --> SR
    CACHE --> STR
    CACHE --> BS
    CACHE --> FI
    CACHE --> QT
    
    style VAL fill:#ff9999,color:#000
    style CACHE fill:#99ff99,color:#000
```

## 8. Error Handling and Recovery

```mermaid
graph LR
    subgraph "Error Sources"
        BE[Buffer Full]
        WF[Worker Failure]
        CE[Correlation Error]
        SE[Storage Error]
    end
    
    subgraph "Handling Strategies"
        DO[Drop Oldest]
        DN[Drop Newest]
        BL[Block]
        RW[Restart Worker]
        LC[Low Confidence]
        RT[Retry]
    end
    
    subgraph "Recovery Actions"
        INC[Increment Counters]
        LOG[Log Warning]
        MON[Monitor Restart]
        DEG[Degraded Mode]
    end
    
    BE --> DO
    BE --> DN
    BE --> BL
    
    WF --> RW
    WF --> MON
    
    CE --> LC
    CE --> LOG
    
    SE --> RT
    SE --> DEG
    
    DO --> INC
    DN --> INC
    RW --> LOG
    LC --> INC
```

## 9. Performance Critical Path

> **Note:** Focuses on runtime; needs to incorporate AST instrumentation path.

```mermaid
graph TD
    subgraph "Hot Path (<1μs target)"
        EN[enabled?<br/>Process Dict]
        GEN[generate_id<br/>Bitwise Ops]
        TS[timestamp<br/>Monotonic]
        TR[truncate_data<br/>Size Check]
        WR[write<br/>Atomic CAS]
    end
    
    subgraph "Async Path"
        RB[read_batch<br/>Batch Fetch]
        ENR[enrich<br/>Add Metadata]
        COR[correlate<br/>Build Links]
        STR[store<br/>Update Indexes]
    end
    
    EN -->|"<50ns"| GEN
    GEN -->|"<100ns"| TS
    TS -->|"<200ns"| TR
    TR -->|"<500ns"| WR
    
    WR -.->|"Async"| RB
    RB --> ENR
    ENR --> COR
    COR --> STR
    
    style EN fill:#ff9999,color:#000
    style GEN fill:#ff9999,color:#000
    style TS fill:#ff9999,color:#000
    style TR fill:#ff9999,color:#000
    style WR fill:#ff9999,color:#000
```

## 10. Supervision Tree

> **Note:** Shows a partial tree; should be integrated into a unified system supervision tree including runtime/AST control.

```mermaid
graph TD
    APP[ElixirScope.Application<br/>:one_for_one]
    
    CFG[Config<br/>GenServer]
    PM[PipelineManager<br/>Supervisor]
    
    AWP[AsyncWriterPool<br/>GenServer]
    EC[EventCorrelator<br/>GenServer]
    
    AW1[AsyncWriter 1]
    AW2[AsyncWriter 2]
    AWN[AsyncWriter N]
    
    APP --> CFG
    APP --> PM
    
    PM --> AWP
    PM --> EC
    
    AWP --> AW1
    AWP --> AW2
    AWP --> AWN
    
    APP -.->|Restart| CFG
    APP -.->|Restart| PM
    PM -.->|Restart| AWP
    PM -.->|Restart| EC
    AWP -.->|Monitor & Restart| AW1
    AWP -.->|Monitor & Restart| AW2
    AWP -.->|Monitor & Restart| AWN
    
    style APP fill:#ffcccc,color:#000
    style PM fill:#ccccff,color:#000
    style AWP fill:#ccffcc,color:#000
```

These diagrams illustrate:

1. **Overall Architecture**: Shows all layers and components
2. **Event Flow**: Detailed sequence from instrumentation to storage
3. **Lock-free Operations**: How the RingBuffer achieves high performance
4. **Correlation State Machine**: How events are causally linked
5. **Work Distribution**: How AsyncWriterPool manages workers
6. **Storage Indexes**: Multi-dimensional query support
7. **Configuration Flow**: Sources and validation
8. **Error Handling**: Strategies for different failure modes
9. **Performance Path**: Critical hot path optimizations
10. **Supervision Tree**: Fault tolerance structure

The diagrams use color coding:
- Red: Performance critical components
- Blue: Async/background processing
- Green: Storage and persistence
- Yellow: Configuration and management
