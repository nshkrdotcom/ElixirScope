# Detailed Plan for Diagram Updates and Deletions

**Date:** 2025-05-25

This document outlines the planned modifications to various diagram files within the ElixirScope project.

---

**File 1: `DIAGS.md`**

*   **Diagrams to Update:**
    1.  **Title:** `### 1. Overall System Architecture (Runtime-Focused)`
        *   **Action:** Insert the following note after any existing description and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Does not show its place within the unified architecture or the compile-time AST instrumentation path.
            ```
    2.  **Title:** `### 2. AI-Driven Runtime Instrumentation Flow`
        *   **Action:** Insert the following note after any existing description and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Focuses only on runtime; should incorporate AI planning for AST instrumentation.
            ```
    3.  **Title:** `### 3. Runtime Event Capture Pipeline (from BEAM to Ingestor)`
        *   **Action:** Insert the following note after any existing description and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Accurate for runtime path, but needs to show the convergent path from AST instrumentation via `Capture.InstrumentationRuntime`.
            ```
*   **Diagrams to Delete:** None in this file.
*   **Diagrams to Keep As-Is:**
    *   `### 4. Asynchronous Event Processing and Storage Pipeline`
    *   `### 5. Simplified ElixirScope Data Model (ERD-like)`
    *   `### 6. Runtime API Control Flow`
    *   `### 7. LLM Integration Architecture`
    *   `### 8. Predictive & Intelligent Analysis Engines (Conceptual Interaction)`
    *   `### 9. "Execution Cinema" UI & Querying Architecture (Future)`
    *   `### 10. Advanced AI Analysis Engine Integration (Future)`
    *   `### 11. Distributed Tracing & Data Synchronization (Focus on Existing Components)`

---

**File 2: `docs/DIAGS.md`**

*   **Diagrams to Update:**
    1.  **Title:** `## 2. AI-Driven Instrumentation Flow`
        *   **Action:** Insert the following note after the title and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Focuses on AST transformation; should be integrated with runtime path selection as per unified architecture.
            ```
    2.  **Title:** `## 3. Event Capture Pipeline`
        *   **Action:** Insert the following note after the title and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Needs to clearly show the convergent flow from both AST and Runtime sources into the shared Ingestor.
            ```
    3.  **Title:** `## 5. Event Data Model (ERD)`
        *   **Action:** Insert the following note after the title and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Clarify if this is a future QueryCoordinator schema; current primary event model is simpler (see DIAGS.md #5).
            ```
    4.  **Title:** `## 8. Phase Implementation Roadmap`
        *   **Action:** Insert the following note after the title and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Gantt chart dates (2025-2027) are past/future-dated; needs to reflect current unified architecture progress.
            ```
*   **Diagrams to Delete:**
    1.  **Title:** `## 1. Overall System Architecture`
        *   **Action:** Delete the entire section for this diagram, from its `## 1. Overall System Architecture` heading down to and including the closing ` ``` ` of its Mermaid code block.
*   **Diagrams to Keep As-Is:**
    *   `## 4. Seven DAGs (Execution Cinema Model)`
    *   `## 6. ElixirLS Integration Architecture`
    *   `## 7. Execution Cinema UI Component Architecture`

---

**File 3: `docs_extra/DIAGS_PHASE2_COMPLETE.md`**

*   **Diagrams to Update:**
    1.  **Title:** `## 2. Event Flow Sequence`
        *   **Action:** Insert the following note after the title and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Primarily runtime flow; needs to include AST instrumentation path via `Capture.InstrumentationRuntime`.
            ```
    2.  **Title:** `## 9. Performance Critical Path`
        *   **Action:** Insert the following note after the title and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Focuses on runtime; needs to incorporate AST instrumentation path.
            ```
    3.  **Title:** `## 10. Supervision Tree`
        *   **Action:** Insert the following note after the title and before the ` ```mermaid ` block:
            ```markdown
            > **Note:** Shows a partial tree; should be integrated into a unified system supervision tree including runtime/AST control.
            ```
*   **Diagrams to Delete:**
    1.  **Title:** `## 1. Overall System Architecture`
        *   **Action:** Delete the entire section for this diagram, from its `## 1. Overall System Architecture` heading down to and including the closing ` ``` ` of its Mermaid code block.
    2.  **Title:** `## 4. Event Correlation State Machine`
        *   **Action:** Delete the entire section for this diagram, from its `## 4. Event Correlation State Machine` heading down to and including the closing ` ``` ` of its Mermaid code block.
*   **Diagrams to Keep As-Is:**
    *   `## 3. RingBuffer Lock-free Operations`
    *   `## 5. AsyncWriterPool Work Distribution`
    *   `## 6. Storage Layer Index Structure`
    *   `## 7. Configuration Flow`
    *   `## 8. Error Handling and Recovery`

---