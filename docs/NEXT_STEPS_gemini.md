# NEXT_STEPS.md: ElixirScope Foundation Implementation Plan

## 1. Introduction & Current Focus

**Project:** ElixirScope - AI-Powered Execution Cinema Debugger
**Current Stage:** Initial Design & Prototyping (Focusing on Foundational Architecture)
**Objective of these Next Steps:** Implement the core foundational architecture of ElixirScope as outlined in `README.md` and refined in `docs/006-g-foundation-responseToClaude.md`. The immediate goal is to achieve a **Minimal Viable Trace (MVT)**: a simple, AI-planned instrumentation that injects code, captures basic events (function entry/exit), persists them, and allows them to be queried via IEx.

This plan prioritizes building a robust, high-performance event capture and processing pipeline, integrated with a basic compile-time AST transformation mechanism driven by an initial AI planning component.

## 2. Overall Strategy

*   **Incremental Development:** Build the foundation in clearly defined, sequential phases.
*   **Layered Approach:** Each phase builds upon the successful completion of the previous one.
*   **Test-Driven Development (TDD):** Heavily encouraged for all new components, as outlined in `FOUNDATION_IMPLEMENTATION_GUIDE.md`. Each component should have thorough unit, integration, and performance tests where applicable.
*   **Focus on Core Architecture:** Prioritize modules and interactions defined in `docs/006-g-foundation-responseToClaude.md`.
*   **Performance by Design:** The event capture "hot path" must be optimized from the start.

## 3. Phased Implementation Plan

The following phases are designed to incrementally build the ElixirScope foundation. Estimated durations are indicative.

---

### Phase 1: Core Infrastructure & Utilities (~1 Week)

*   **Objective:** Stabilize the existing codebase. Ensure all fundamental utility modules are compiling, tested, and reliable. Fix any project-wide compilation blockers.
*   **Key Tasks & Modules:**
    1.  **Project Compilation:** Resolve all outstanding compilation errors across the entire project.
    2.  **Existing Test Suites:**
        *   Ensure all tests in `test/elixir_scope/utils_test.exs`, `test/elixir_scope/events_test.exs`, `test/elixir_scope/config_test.exs`, and `test/elixir_scope_test.exs` are passing.
        *   Address any "Missing Implementations to Add" from the original `NEXT_STEPS.md` if they pertain to these core utility modules (e.g., functions in `utils.ex` like `extract_function_name`, `format_bytes`).
    3.  **`ElixirScope.Application`:**
        *   Ensure it can start successfully with `ElixirScope.Config` as its primary child (other children likely remain commented out for now).
    4.  **`ElixirScope.Config`:**
        *   Verify it loads configuration from `config/*.exs` correctly.
        *   Confirm runtime updates for allowed paths are functional as per existing tests.
    5.  **`ElixirScope.Events`:**
        *   Confirm all event structs are defined and serializable.
*   **Testing Focus:**
    *   Re-run all existing unit tests for `Utils`, `Events`, `Config`, and `ElixirScope` application lifecycle.
    *   Manual verification of `mix compile --force`.
*   **Deliverable:**
    *   A fully compiling ElixirScope project.
    *   All existing unit tests for core utilities, events, config, and basic application lifecycle pass.

---

### Phase 2: High-Performance Event Capture Path (~2-3 Weeks)

*   **Objective:** Implement the core, low-overhead event capture pipeline: `InstrumentationRuntime` (initial version) -> `Ingestor` -> `RingBuffer` -> `AsyncWriterPool` (basic) -> `DataAccess` (basic ETS).
*   **Key Tasks & Modules (Implement/Flesh out based on `docs/006-g-foundation-responseToClaude.md` and `FOUNDATION_IMPLEMENTATION_GUIDE.md` where applicable):**
    1.  **`ElixirScope.Capture.RingBuffer`:**
        *   Full implementation using `:persistent_term` and `:atomics` (or alternative high-performance ETS strategy if `persistent_term` proves problematic for event structs).
        *   Implement lock-free write/read operations.
        *   Support configurable overflow strategies (e.g., `:drop_oldest`).
        *   *Critical*: Write comprehensive unit, concurrency, and performance tests. This is a cornerstone component.
    2.  **`ElixirScope.Capture.Ingestor`:**
        *   Implement as a set of public functions (not a GenServer).
        *   Takes raw event data, creates `ElixirScope.Events` structs, performs minimal serialization, and writes to the `RingBuffer`.
        *   Write unit and performance tests for throughput.
    3.  **`ElixirScope.Capture.InstrumentationRuntime`:**
        *   Implement basic versions of `report_function_entry/3` and `report_function_exit/3`.
        *   These functions should format a simple `FunctionEntry` / `FunctionExit` event and pass it to the `Ingestor`.
        *   Write unit tests.
    4.  **`ElixirScope.Storage.DataAccess` (Basic ETS Store):**
        *   Implement an ETS-backed store for events.
        *   Key functions: `store_event/2`, `store_events/2`, `get_event_by_id/2`.
        *   Basic indexing by event ID and timestamp.
        *   Write unit tests.
    5.  **`ElixirScope.Storage.AsyncWriterPool` (Basic):**
        *   Implement a simple worker pool (even a single supervised `AsyncWriter` worker initially).
        *   Worker reads batches from `RingBuffer`, deserializes, and writes to `DataAccess`.
        *   Write unit and basic integration tests for the flow from `RingBuffer`.
    6.  **`ElixirScope.Capture.PipelineManager`:**
        *   Implement as a supervisor for `RingBuffer`(s) and `AsyncWriterPool`.
        *   Add this manager to `ElixirScope.Application`'s children.
*   **Testing Focus:**
    *   **Unit Tests:** For each new component (`RingBuffer`, `Ingestor`, `DataAccess`, `AsyncWriter`).
    *   **Performance Tests:** Critical for `RingBuffer` (write/read latency, throughput under concurrent access) and `Ingestor` (event processing latency, throughput). Target sub-microsecond performance for hot path elements.
    *   **Integration Test:** Manually trigger `InstrumentationRuntime.report_function_entry/exit`. Verify events flow: `Ingestor` -> `RingBuffer` -> `AsyncWriter` -> `DataAccess` (ETS).
*   **Deliverable:**
    *   A functional event capture pipeline.
    *   Events manually pushed via `InstrumentationRuntime` are captured, processed by `AsyncWriter`, and stored in the ETS-based `DataAccess`.
    *   Key performance targets for `RingBuffer` write/read and `Ingestor` throughput are met.
    *   `ElixirScope.Application` now starts the `Capture.PipelineManager`.

---

### Phase 3: Basic Compile-Time Auto-Instrumentation (~2 Weeks)

*   **Objective:** Implement a minimal Abstract Syntax Tree (AST) transformation flow to automatically inject tracing calls for simple function definitions.
*   **Key Tasks & Modules:**
    1.  **`ElixirScope.AST.InjectorHelpers`:**
        *   Create helper functions that generate `quote` blocks for `InstrumentationRuntime.report_function_entry/3` and `InstrumentationRuntime.report_function_exit/3`.
    2.  **`ElixirScope.AST.Transformer`:**
        *   Implement core logic to traverse an AST (`Macro.prewalk/postwalk`).
        *   Focus on transforming simple `def/2` and `defp/2` function definitions.
        *   Use `InjectorHelpers` to wrap the original function body with entry/exit calls.
    3.  **`ElixirScope.AI.Orchestrator` (Stub/Minimal):**
        *   Create a minimal GenServer or Agent.
        *   For this phase, it can provide a hardcoded/very simple instrumentation plan (e.g., "instrument all functions in `TestTargetModule`").
    4.  **`ElixirScope.Compiler.MixTask`:**
        *   Implement as a custom `Mix.Task.Compiler`.
        *   Ensure it runs *before* the standard Elixir compiler.
        *   Fetch the (currently simple) plan from the `AI.Orchestrator` stub.
        *   For modules targeted by the plan, pass their AST to `AST.Transformer`.
        *   Write the transformed AST to the appropriate `_build` location for subsequent compilation by Elixir.
*   **Testing Focus:**
    *   **Unit Tests:** For `AST.Transformer` with various simple function ASTs. Test preservation of function arguments, return values, and basic scoping.
    *   **Integration Test:** Create a sample Elixir project with a `TestTargetModule`. Add `ElixirScope.Compiler.MixTask` to its `mix.exs`. Run `mix compile`.
        *   Verify the `.beam` file for `TestTargetModule` shows injected calls (e.g., using `:"observer.decode_beam_file/1"` or similar inspection techniques).
    *   **Semantic Equivalence Test:** The instrumented `TestTargetModule` should produce the same functional output as a non-instrumented version for simple test cases.
*   **Deliverable:**
    *   `mix compile` on a test project can instrument specified functions based on a hardcoded plan.
    *   Instrumented functions correctly call the `InstrumentationRuntime` stubs.
    *   Basic semantic equivalence is maintained for instrumented code.

---

### Phase 4: Initial End-to-End Trace & Query (MVT) (~1-2 Weeks)

*   **Objective:** Connect the auto-instrumentation (Phase 3) to the event capture pipeline (Phase 2). Implement basic event correlation and querying to view a simple trace.
*   **Key Tasks & Modules:**
    1.  **`ElixirScope.EventCorrelator` (Basic - integrated into `AsyncWriter`):**
        *   Modify the `AsyncWriter`'s event processing logic.
        *   When processing a `FunctionEntry` event, generate a unique `call_id`. Store this `call_id` (e.g., in a process dictionary scoped to the `InstrumentationRuntime` or passed through).
        *   Ensure `FunctionExit` events can access and include this `call_id`.
        *   Update `DataAccess` to store/index events by `call_id` or a composite key that includes it.
    2.  **`ElixirScope.Storage.QueryCoordinator` (Basic):**
        *   Implement `get_trace_by_call_id(call_id)` which fetches the entry and exit events (and any future nested events) for a given `call_id` from `DataAccess`.
    3.  **`ElixirScope.IExHelpers` (New Module):**
        *   Create a simple IEx helper function, e.g., `ElixirScope.show_trace(call_id)`, which uses `QueryCoordinator` to fetch and print a basic trace.
*   **Integration & Testing (End-to-End):**
    1.  Create a simple Elixir project (or use the one from Phase 3).
    2.  Use `MixTask` to instrument a target function.
    3.  Run the instrumented application/function.
    4.  Verify that `FunctionEntry` and `FunctionExit` events are captured by the pipeline (Phase 2), stored in ETS by `DataAccess`, and include a common `call_id`.
    5.  Use the new `IExHelpers.show_trace/1` function to retrieve and display the trace for the executed function.
*   **Deliverable (MVT Achieved):**
    *   A complete, albeit simple, end-to-end flow:
        1.  A function in a sample project is instrumented at compile time.
        2.  Executing this function generates `FunctionEntry` and `FunctionExit` events.
        3.  These events are captured, processed (including basic `call_id` correlation), and stored.
        4.  The trace for this specific function call (entry and exit) can be retrieved and displayed via an IEx helper.

---

### Phase 5: Basic AI-Driven Instrumentation Planning (~1-2 Weeks)

*   **Objective:** Replace the hardcoded instrumentation plan with a simple, rule-based plan generated by initial AI components.
*   **Key Tasks & Modules:**
    1.  **`ElixirScope.AI.CodeAnalyzer` (Basic):**
        *   Implement basic AST traversal to identify all public function definitions (`def`) in a given module.
        *   Output: A list of `{module, function, arity}` tuples.
    2.  **`ElixirScope.AI.InstrumentationPlanner` (Basic Rule-Based):**
        *   Input: Output from `CodeAnalyzer` and a global configuration (e.g., `config :elixir_scope, ai: [strategy: :trace_all_public_functions]`).
        *   Output: An instrumentation plan (map of `{module, function, arity}` to `[:trace_entry_exit]`) suitable for `AST.Transformer`.
    3.  **`ElixirScope.AI.Orchestrator` (Functional):**
        *   Implement the GenServer/Agent that manages the `CodeAnalyzer` -> `Planner` flow.
        *   `MixTask` will now call this orchestrator to get the instrumentation plan.
        *   Implement basic plan caching.
*   **Integration & Testing:**
    *   Modify `MixTask` to fetch its instrumentation plan from the functional `AI.Orchestrator`.
    *   Test with a sample project:
        *   The `AI.CodeAnalyzer` should identify public functions.
        *   The `AI.InstrumentationPlanner` should generate a plan to trace these functions.
        *   The `MixTask` should apply this plan.
        *   Verify (as in Phase 4) that these functions are instrumented and their traces can be queried.
*   **Deliverable:**
    *   The instrumentation process is now driven by a simple, rule-based AI plan generated dynamically at compile time.
    *   The AI components (`CodeAnalyzer`, `InstrumentationPlanner`, `Orchestrator`) are integrated into the compilation workflow.

---

## 4. Definition of Foundation Success (MVT Achieved after Phase 5)

The ElixirScope foundation (MVT) is considered successfully implemented when:

1.  **Core Pipeline Works:** Events from instrumented code reliably flow through `InstrumentationRuntime` -> `Ingestor` -> `RingBuffer` -> `AsyncWriterPool` -> `EventCorrelator` (basic) -> `DataAccess` (ETS).
2.  **Compile-Time Instrumentation:** A custom `MixTask` can automatically instrument simple Elixir functions (entry/exit) in a target project based on a plan.
3.  **Basic AI Planning:** A rudimentary AI system (`CodeAnalyzer`, `InstrumentationPlanner`, `Orchestrator`) can analyze code and generate a simple instrumentation plan that the `MixTask` uses.
4.  **End-to-End Traceability:** A full trace (entry/exit events with a common `call_id`) for an instrumented function call can be captured, stored, and retrieved via an `IExHelper` function.
5.  **Performance Basics:** The hot path (`RingBuffer` write, `Ingestor`) meets initial performance targets.
6.  **Tested Components:** Core components have unit, integration, and (where applicable) performance tests.
7.  **Stability:** The system is stable during the MVT workflow; instrumented applications run correctly.

---

## 5. Key Priorities & Focus Areas

*   **`ElixirScope.Capture.RingBuffer`:** This is paramount for performance. Its implementation and testing must be rigorous.
*   **AST Transformation Correctness (`AST.Transformer`):** Ensuring semantic equivalence of instrumented code is crucial. Start simple and add complexity carefully.
*   **Decoupled Pipeline:** Maintain clear boundaries and responsibilities between `Ingestor`, `RingBuffer`, and `AsyncWriterPool` to ensure performance and scalability.
*   **Test Coverage:** Especially for `RingBuffer`, `AST.Transformer`, and the end-to-end MVT flow.

---

## 6. Risk Mitigation (Simplified)

*   **AST Transformation Complexity:**
    *   **Risk:** Handling all Elixir AST edge cases and macros correctly is difficult.
    *   **Mitigation:** Start with instrumenting only simple `def/2`, `defp/2`. Incrementally add support for more complex constructs. Extensive semantic equivalence testing.
*   **Performance Target Achievement:**
    *   **Risk:** `RingBuffer` or `Ingestor` might not meet sub-microsecond targets.
    *   **Mitigation:** Prioritize these components. Profile early and often. Consider alternative implementations if `:persistent_term` or initial atomic strategy is insufficient.
*   **Integration Complexity:**
    *   **Risk:** Difficulty integrating the AI planner, compiler task, and capture pipeline smoothly.
    *   **Mitigation:** Stub components (like `AI.Orchestrator` initially) to test integrations incrementally. Clear API contracts between modules.

---

## 7. Tools and Infrastructure

*   **Development Environment:** Standard Elixir/Mix setup.
*   **Testing:**
    *   `ExUnit` for unit, integration, and property-based tests.
    *   Consider `Benchee` for micro-benchmarks of performance-critical code.
*   **CI/CD Setup (as per original `NEXT_STEPS.md`):**
    ```yaml
    # .github/workflows/ci.yml
    name: CI
    on: [push, pull_request]
    jobs:
      test:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v2
          - uses: erlef/setup-beam@v1
            with:
              elixir-version: '1.15' # Or current target
              otp-version: '26'   # Or current target
          - run: mix deps.get
          - run: mix compile --warnings-as-errors
          - run: mix test
          # Add this when performance tests are stable:
          # - run: mix test --include performance --exclude manual_perf_analysis 
    ```

---

## 8. Future Considerations (Post-Foundation / Post-MVT)

Once this MVT foundation is stable and validated, the following can be prioritized:

*   **Advanced AI:** Implementing sophisticated AI code analysis (LLMs, RAGs), advanced instrumentation planning, and AI-driven analysis of captured traces.
*   **Execution Cinema UI:** Developing the visual interface for time-travel debugging.
*   **Full DAG Implementation:** Building and persisting all 7 DAGs for multi-dimensional analysis.
*   **Phoenix & Ecto Integration:** Specialized instrumentation and UI views for Phoenix/LiveView/Ecto.
*   **Distributed System Support:** Capturing and correlating events across multiple BEAM nodes.
*   **Production Hardening:** Advanced sampling, performance optimization, security.

This phased plan provides a clear path to achieving a functional and valuable foundation for ElixirScope, enabling the more ambitious features of the "Execution Cinema" to be built upon solid ground.
