# ElixirScope: AI-Powered Execution Cinema Debugger (Prototyping Phase)

## 1. Introduction & Vision

Welcome to ElixirScope! This project aims to create a **next-generation debugging and observability platform for Elixir applications running on the BEAM/OTP**. Our grand vision, detailed in the **[ElixirScope: Grand Vision for Next-Generation BEAM/OTP Debugging (`docs/100-c.md`)](docs/100-c.md)**, is to revolutionize how developers understand, debug, and optimize complex concurrent and distributed Elixir systems. We are striving to build an **"Execution Cinema"** – an experience where developers can intuitively navigate through their application's execution history with total behavioral recall, guided by AI-powered analysis.

The formal **[Product Requirements Document (PRD) for ElixirScope (`docs/008-g-prd.md`)](docs/008-g-prd.md)** outlines the full scope, target audience, features (phased approach), and success metrics.

**Current Stage:** We are in the **initial design and prototyping phase**, focusing on establishing a robust foundational architecture. This README, along with the referenced documents, captures the current thinking, key design decisions, and the planned structure for Phase 1.

## 2. The "Execution Cinema" Concept

The core of ElixirScope is the "Execution Cinema," which aims to provide:

*   **Total Behavioral Recall:** Capturing a comprehensive history of application execution, including function calls, state changes, messages, and process interactions.
*   **Multi-Dimensional Analysis:** Correlating events across seven synchronized dimensions or "DAGs" (Directed Acyclic Graphs) as visualized in **[DIAGS.md (`DIAGS.md#4-seven-dags-execution-cinema-model`)](DIAGS.md#4-seven-dags-execution-cinema-model)**:
    1.  Temporal DAG
    2.  Process Interaction DAG
    3.  State Evolution DAG
    4.  Code Execution DAG
    5.  Data Flow DAG
    6.  Performance DAG
    7.  Causality DAG
*   **Visual Time-Travel Interface:** An intuitive UI (detailed conceptually in **[DIAGS.md (`DIAGS.md#7-execution-cinema-ui-component-architecture`)](DIAGS.md#7-execution-cinema-ui-component-architecture)**) allowing developers to "scrub" through execution history, zoom from system-wide views to individual variable changes, and understand complex concurrent behaviors.
*   **AI-Driven Insights:** Leveraging AI for automatic instrumentation, pattern recognition, anomaly detection, and root cause analysis.

The differentiation from traditional debuggers is further explored in **[ElixirScope PRD - Response to Grok's "ElixirDebugger" PRD Analysis (`docs/009-g-prd-responseToGrok.md`)](docs/009-g-prd-responseToGrok.md)**, which clarifies our unique AI-first, historical analysis approach.

## 3. Core Architectural Pillars (Under Design & Prototyping)

Our current foundational design, primarily detailed in **[Fully Revised Core Code Structure for the Foundation (`docs/006-g-foundation-responseToClaude.md`)](docs/006-g-foundation-responseToClaude.md)**, revolves around several key pillars:

### 3.1. AI-Driven Instrumentation Strategy (The "Brain")

*   **Concept:** AI analyzes the codebase to understand its structure, semantics, and critical paths, then generates an optimal instrumentation plan. This moves beyond manual or purely rule-based instrumentation.
*   **Components (as per `docs/006-g-foundation-responseToClaude.md`):**
    *   `ElixirScope.AI.CodeAnalyzer`: Ingests source code/ASTs, uses LLMs/heuristics for analysis.
    *   `ElixirScope.AI.InstrumentationPlanner`: Takes analysis and config to create a declarative instrumentation strategy (what to trace, how deeply).
    *   `ElixirScope.AI.Orchestrator`: Manages the AI analysis/planning lifecycle.
*   **Relevant Discussions:**
    *   The shift towards AI as a primary driver is discussed in **[Analysis of Claude's Answers (`docs/003-g-elixirls-responseToClaude.md`)](docs/003-g-elixirls-responseToClaude.md)**, which evaluates advanced AI concepts like RAG systems and LLM-driven instrumentation decisions.
    *   The initial vision for AI's role is also in **[ElixirScope: Grand Vision (`docs/100-c.md`)](docs/100-c.md)**.

### 3.2. Intelligent Auto-Instrumentation Engine (The "Hands")

*   **Concept:** Apply the AI's instrumentation plan at compile-time by transforming the Abstract Syntax Tree (AST) of the Elixir code.
*   **Components (as per `docs/006-g-foundation-responseToClaude.md`):**
    *   `ElixirScope.Compiler.MixTask`: Custom Mix compiler to integrate into the build process.
    *   `ElixirScope.AST.Transformer`: Core logic for modifying ASTs to inject tracing calls.
    *   `ElixirScope.AST.InjectorHelpers`: Utilities for generating `quote` blocks for instrumentation.
*   **Diagram:** The **[AI-Driven Instrumentation Flow (`DIAGS.md#2-ai-driven-instrumentation-flow`)](DIAGS.md#2-ai-driven-instrumentation-flow)** illustrates this process.
*   **Implementation Details:** Layer 3 of the **[Foundation Layer Technical Checklist (`docs/105-c-layers.md`)](docs/105-c-layers.md)** outlines the build-out of this engine.

### 3.3. High-Performance Event Capture & Ingestion

*   **Concept:** A decoupled, extremely low-overhead pipeline to capture events from instrumented code and VM-level tracers, staging them for asynchronous processing. The goal is <1µs overhead per event on the hot path.
*   **Components (as per `docs/006-g-foundation-responseToClaude.md`):**
    *   `ElixirScope.Capture.InstrumentationRuntime`: Lightweight functions called by injected code.
    *   `ElixirScope.Capture.VMTracer`: Minimal BEAM tracing (`:erlang.trace`, `:sys.trace`).
    *   `ElixirScope.Capture.Ingestor`: Stateless, fast event reception, serialization, and writing to ring buffers.
    *   `ElixirScope.Capture.RingBuffer`: Lock-free, concurrent-safe binary ring buffers (likely using `:persistent_term` and `:atomics`).
    *   `ElixirScope.Capture.PipelineManager`: Supervises buffers and asynchronous writers.
*   **Diagram:** The **[Event Capture Pipeline (`DIAGS.md#3-event-capture-pipeline`)](DIAGS.md#3-event-capture-pipeline)** provides a visual.
*   **Implementation Details:** Layers 1 & 2 of the **[Foundation Layer Technical Checklist (`docs/105-c-layers.md`)](docs/105-c-layers.md)** detail this critical path.

### 3.4. Asynchronous Storage, Correlation & DAG Population

*   **Concept:** Process captured events asynchronously to enrich, correlate, and store them, laying the groundwork for the 7 Execution Cinema DAGs.
*   **Components (as per `docs/006-g-foundation-responseToClaude.md`):**
    *   `ElixirScope.Storage.AsyncWriterPool`: Workers consuming from ring buffers.
    *   `ElixirScope.EventCorrelator`: Establishes causal links and correlation IDs.
    *   `ElixirScope.Storage.DataAccess`: Abstraction over storage (ETS for hot, disk for warm/cold).
    *   `ElixirScope.Storage.QueryCoordinator`: API for data retrieval and on-demand DAG construction.
*   **Data Model:** The foundational **[Event Data Model (ERD) (`DIAGS.md#5-event-data-model-erd`)](DIAGS.md#5-event-data-model-erd)** shows the types of entities and relationships we aim to store.
*   **Implementation Details:** Layer 2 and parts of Layer 6 of the **[Foundation Layer Technical Checklist (`docs/105-c-layers.md`)](docs/105-c-layers.md)** cover this.
*   **Architectural Justification:** The **[ElixirScope Gap Analysis & Revised Foundation (`docs/104-c-foundation.md`)](docs/104-c-foundation.md)** (especially Layer 2: Multi-Dimensional Event Correlation) highlights the need for this advanced correlation beyond simple event storage.

## 4. Prototyping the Foundation (Phase 1 Focus)

Our current efforts are concentrated on building the foundational Phase 1 as outlined in the **[ElixirScope PRD (`docs/008-g-prd.md`)](docs/008-g-prd.md)**. The **[Fully Revised Core Code Structure for the Foundation (`docs/006-g-foundation-responseToClaude.md`)](docs/006-g-foundation-responseToClaude.md)** serves as the primary architectural blueprint for this phase.

The implementation is guided by the detailed **[ElixirScope Foundation Layer: Technical Implementation Checklist (`docs/105-c-layers.md`)](docs/105-c-layers.md)**, which breaks down the foundation into seven progressive sub-layers (0-6), each with specific technical tasks and testing strategies.

The overarching system architecture, including interactions between these foundational components and future layers, is depicted in the **[Overall System Architecture diagram (`DIAGS.md#1-overall-system-architecture`)](DIAGS.md#1-overall-system-architecture)**.

## 5. Key Design Discussions and Rationale

The current design is the result of evaluating our initial ElixirScope implementation against the more ambitious "Execution Cinema" vision.

*   **The Gap and The Shift:** The **[Analysis of ElixirScope plans (`docs/200-grok-plan.md`)](docs/200-grok-plan.md)** provides a synthesis of earlier plans, highlights the gap between a traditional tracer and the Execution Cinema, and justifies the revised, more AI-centric foundational architecture. This is further detailed in the **[Gap Analysis & Revised Foundation document (`docs/104-c-foundation.md`)](docs/104-c-foundation.md)**.
*   **Emphasis on AI as a Core Driver:** The foundational architecture, particularly the AI and AST transformation layers, reflects a deliberate shift. Instead of AI being purely an analytical add-on, it's envisioned as the "brain" guiding instrumentation. This evolution is discussed in **[Analysis of Claude's Answers (`docs/003-g-elixirls-responseToClaude.md`)](docs/003-g-elixirls-responseToClaude.md)**.
*   **Performance-Critical Ingestion Path:** The design of `Ingestor` -> `RingBuffer` -> `AsyncWriterPool` aims for an ultra-low overhead hot path to enable "total recall" without significantly impacting the target application. This design choice is central to `docs/006-g-foundation-responseToClaude.md`.
*   **Contrast with Traditional Debugging:** Our approach is fundamentally different from breakpoint-style debuggers. The rationale and clarification are explored in **[ElixirScope PRD - Response to Grok's "ElixirDebugger" PRD Analysis (`docs/009-g-prd-responseToGrok.md`)](docs/009-g-prd-responseToGrok.md)**.

## 6. Diagrams for Understanding

The **[DIAGS.md (`DIAGS.md`)](DIAGS.md)** file is a critical resource containing:

*   **Overall System Architecture:** The big picture.
*   **AI-Driven Instrumentation Flow:** How AI plans and AST transformation work together.
*   **Event Capture Pipeline:** The flow from instrumented code to storage.
*   **Seven DAGs (Execution Cinema Model):** The conceptual data model for multi-dimensional analysis.
*   **Event Data Model (ERD):** The structure of persisted events.
*   **ElixirLS Integration Architecture (Future):** How ElixirScope might orchestrate ElixirLS.
*   **Execution Cinema UI Component Architecture (Conceptual):** The vision for the UI.
*   **Phase Implementation Roadmap (Conceptual):** High-level project phases.

## 7. Advanced Concepts & Future Integrations

While prototyping the foundation, we keep future capabilities in mind:

*   **ElixirLS Orchestration:** A long-term goal where ElixirScope's AI uses its historical knowledge to proactively drive ElixirLS's debugging session (breakpoints, stepping). This advanced vision is detailed in **[ElixirScope + ElixirLS Integration: Automated Intelligent Debugging (`docs/101-c-elixirls.md`)](docs/101-c-elixirls.md)** and analyzed in **[Analysis of Claude's Answers (`docs/003-g-elixirls-responseToClaude.md`)](docs/003-g-elixirls-responseToClaude.md)**.

## 8. Navigating This Documentation Set

To get a full understanding of ElixirScope:

1.  Start with the **[Grand Vision (`docs/100-c.md`)](docs/100-c.md)** and the **[PRD (`docs/008-g-prd.md`)](docs/008-g-prd.md)**.
2.  Review the **[Overall System Architecture in DIAGS.md (`DIAGS.md`)](DIAGS.md)**.
3.  Understand the current foundational plan from **[Revised Core Code Structure (`docs/006-g-foundation-responseToClaude.md`)](docs/006-g-foundation-responseToClaude.md)**.
4.  For implementation details of the foundation, refer to the **[Technical Implementation Checklist (`docs/105-c-layers.md`)](docs/105-c-layers.md)**.
5.  For rationale and evolution of design, consult **[Analysis of Plans (`docs/200-grok-plan.md`)](docs/200-grok-plan.md)**, **[Gap Analysis (`docs/104-c-foundation.md`)](docs/104-c-foundation.md)**, and the "response" documents (`docs/003-g-elixirls-responseToClaude.md`, `docs/009-g-prd-responseToGrok.md`).

## 9. Conclusion

ElixirScope is an ambitious project aiming to significantly advance the state-of-the-art in BEAM/OTP debugging. We are currently focused on prototyping a highly performant and intelligent foundational layer that will enable the "Execution Cinema" vision. This documentation set reflects our current designs, discussions, and plans for this exciting endeavor.
