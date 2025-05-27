### Basic AST Processing Flow

```mermaid
graph TD
    A[Source Code] --> B[Elixir Compiler]
    B --> C[AST Generation]
    C --> D[AST Repository]
    D --> E[Compile-time Instrumentation]
    E --> F[Enhanced Bytecode]
    F --> G[Runtime Execution]
    G --> H[Debug Events]
    H --> I[Cinema Debugger]
    
    subgraph "Core AST Transformation"
        C
        D
        E
    end
    
    style C fill:#e1f5fe,color:#000
    style D fill:#e8f5e8,color:#000
    style E fill:#fff3e0,color:#000
    style I fill:#f3e5f5,color:#000
```

### AST Repository Components

```mermaid
graph LR
    A[Source Files] --> B[AST Parser]
    B --> C[Semantic Analyzer]
    C --> D[AST Repository]
    
    D --> E[Module ASTs]
    D --> F[Dependency Graph]
    D --> G[Call Graph]
    D --> H[Data Flow Graph]
    D --> I[Supervision Tree]
    D --> J[Semantic Metadata]
    
    E --> K[Function Definitions]
    E --> L[Type Specifications]
    E --> M[Pattern Matches]
    
    J --> N[Domain Concepts]
    J --> O[Business Rules]
    J --> P[Architectural Patterns]
    
    subgraph "AST Storage"
        E
        F
        G
        H
        I
        J
    end
    
    subgraph "Metadata Layers"
        N
        O
        P
    end
    
    style D fill:#e8f5e8,color:#000
    style J fill:#fff8e1,color:#000
```

### Compile-time Instrumentation Pipeline

```mermaid
graph TD
    A[Original AST] --> B[Pattern Detector]
    B --> C[Instrumentation Planner]
    C --> D[AST Transformer]
    D --> E[Instrumented AST]
    E --> F[Bytecode Generator]
    
    subgraph "Instrumentation Types"
        G[Function Tracing]
        H[Message Logging]
        I[State Tracking]
        J[Performance Metrics]
        K[Concurrency Events]
    end
    
    C --> G
    C --> H
    C --> I
    C --> J
    C --> K
    
    G --> D
    H --> D
    I --> D
    J --> D
    K --> D
    
    L[Configuration] --> C
    M[Debug Flags] --> C
    
    style A fill:#e3f2fd,color:#000
    style E fill:#e8f5e8,color:#000
    style C fill:#fff3e0,color:#000
```

### LLM Integration Architecture

```mermaid
graph TD
    A[AST Repository] --> B[Context Builder]
    B --> C[Code Compactor]
    C --> D[LLM Interface]
    D --> E[AI Response]
    E --> F[Response Processor]
    F --> G[AST Mapper]
    G --> H[Action Generator]
    
    subgraph "Context Generation"
        I[Architectural Overview]
        J[Domain Model]
        K[Code Patterns]
        L[Execution History]
    end
    
    B --> I
    B --> J
    B --> K
    B --> L
    
    subgraph "LLM Tasks"
        M[Code Completion]
        N[Bug Analysis]
        O[Refactoring Suggestions]
        P[Pattern Recognition]
    end
    
    D --> M
    D --> N
    D --> O
    D --> P
    
    subgraph "Output Actions"
        Q[Code Generation]
        R[Debug Guidance]
        S[Optimization Hints]
        T[Architecture Advice]
    end
    
    H --> Q
    H --> R
    H --> S
    H --> T
    
    style B fill:#e8f5e8,color:#000
    style C fill:#fff3e0,color:#000
    style G fill:#f3e5f5,color:#000
```



### Cinema Debugger Data Flow

```mermaid
graph TD
    A[Runtime Events] --> B[Event Collector]
    B --> C[Temporal Storage]
    C --> D[Event Processor]
    D --> E[Timeline Builder]
    E --> F[Visualization Engine]
    
    G[AST Repository] --> H[Code Context Provider]
    H --> F
    
    subgraph "Event Types"
        I[Function Calls]
        J[Message Passing]
        K[State Changes]
        L[Process Events]
        M[Error Events]
    end
    
    B --> I
    B --> J
    B --> K
    B --> L
    B --> M
    
    subgraph "Temporal Views"
        N[Timeline View]
        O[Process View]
        P[Message Flow]
        Q[State Evolution]
        R[Causal Graph]
    end
    
    F --> N
    F --> O
    F --> P
    F --> Q
    F --> R
    
    subgraph "Interactive Features"
        S[Time Travel]
        T[Breakpoints]
        U[Hypothesis Testing]
        V[Root Cause Analysis]
    end
    
    F --> S
    F --> T
    F --> U
    F --> V
    
    style C fill:#e8f5e8,color:#000
    style F fill:#f3e5f5,color:#000
    style H fill:#fff3e0,color:#000
```

### Detailed AST Transformation Process

```mermaid
graph TD
    A[Source Code] --> B[Lexer/Parser]
    B --> C[Raw AST]
    C --> D[Semantic Enricher]
    D --> E[Enhanced AST]
    
    E --> F[Instrumentation Selector]
    F --> G{Debug Mode?}
    
    G -->|Yes| H[AST Transformer]
    G -->|No| I[Direct Compilation]
    
    H --> J[Pattern Matcher]
    J --> K[Function Instrumenter]
    J --> L[Message Instrumenter]
    J --> M[State Instrumenter]
    J --> N[Concurrency Instrumenter]
    
    K --> O[Instrumented AST]
    L --> O
    M --> O
    N --> O
    
    O --> P[Code Generator]
    I --> P
    P --> Q[Bytecode]
    
    subgraph "AST Metadata"
        R[Line Numbers]
        S[Type Info]
        T[Scope Data]
        U[Pattern Data]
    end
    
    D --> R
    D --> S
    D --> T
    D --> U
    
    subgraph "Instrumentation Rules"
        V[Trace Functions]
        W[Log Messages]
        X[Monitor State]
        Y[Track Processes]
    end
    
    F --> V
    F --> W
    F --> X
    F --> Y
    
    style E fill:#e8f5e8,color:#000
    style O fill:#fff3e0,color:#000
    style H fill:#f3e5f5,color:#000
```

### Comprehensive System Integration

```mermaid
graph TD
    A[Developer IDE] --> B[AST System]
    C[Source Files] --> B
    D[Git Repository] --> B
    
    B --> E[AST Repository]
    E --> F[Instrumentation Engine]
    E --> G[LLM Integration]
    E --> H[Cinema Debugger]
    
    F --> I[Runtime System]
    I --> J[Event Collection]
    J --> K[Temporal Database]
    K --> H
    
    G --> L[Context Builder]
    G --> M[Code Compactor]
    G --> N[AI Assistant]
    
    H --> O[Time Travel UI]
    H --> P[Causal Analysis]
    H --> Q[Hypothesis Testing]
    
    subgraph "Development Loop"
        R[Code] --> S[Compile]
        S --> T[Run]
        T --> U[Debug]
        U --> V[Analyze]
        V --> R
    end
    
    B --> R
    F --> S
    I --> T
    H --> U
    N --> V
    
    subgraph "AI Capabilities"
        W[Smart Completion]
        X[Bug Prediction]
        Y[Refactoring Help]
        Z[Pattern Suggestion]
    end
    
    N --> W
    N --> X
    N --> Y
    N --> Z
    
    subgraph "Debugging Features"
        AA[Visual Timeline]
        BB[Process Inspector]
        CC[Message Tracer]
        DD[State Monitor]
    end
    
    H --> AA
    H --> BB
    H --> CC
    H --> DD
    
    style B fill:#e8f5e8,color:#000
    style E fill:#fff3e0,color:#000
    style H fill:#f3e5f5,color:#000
    style N fill:#e1f5fe,color:#000
```