Okay, we've covered the foundational RingBuffer and the Asynchronous Event Processing Pipeline that consumes from it. The next logical and highly relevant technical topic is the **Event Correlation Engine (`ElixirScope.Capture.EventCorrelator`)** in more depth.

While we touched upon its interaction with `AsyncWriter`s, a dedicated document on its internal workings, state management, correlation logic, and performance considerations is crucial. This component is the heart of transforming a flat stream of events into a meaningful, causally-linked "Execution Cinema" dataset.

---

**ElixirScope Technical Document: Event Correlation Engine**

**Document Version:** 1.3
**Date:** 2024-05-24
**Authors:** ElixirScope Team (AI Assisted)

**Abstract:**

This document provides an in-depth technical examination of the `ElixirScope.Capture.EventCorrelator`. This engine is a central component in the ElixirScope system, responsible for establishing causal relationships and contextual links between disparate trace events captured from the application. By analyzing event sequences and specific event attributes, the `EventCorrelator` transforms a raw stream of events into a rich, interconnected dataset, which is foundational for time-travel debugging, constructing the "Seven DAGs," and enabling the "Execution Cinema" experience. This document details its architecture, correlation strategies, state management using ETS, performance considerations, and its integration within the asynchronous processing pipeline.

**Table of Contents:**

1.  Introduction and Purpose
    1.1. The Role of Correlation in ElixirScope
    1.2. Goals: Causal Accuracy, Performance, Scalability
2.  Architecture and System Placement (Diagram Reference: `DIAGS.md#1, #3, #7`)
    2.1. `GenServer`-based Implementation
    2.2. Interaction with `AsyncWriter` Workers
    2.3. Output: `CorrelatedEvent` Structs
3.  Core Correlation Logic and Strategies
    3.1. Function Call Correlation
        3.1.1. Per-Process Call Stack Management
        3.1.2. Linking Entry, Exit, and Exception Events
        3.1.3. Handling Nested and Recursive Calls
        3.1.4. Assigning `correlation_id`, `parent_id`, `root_id`
    3.2. Message Passing Correlation
        3.2.1. Message Signature Generation
        3.2.2. Linking `MessageSend` to `MessageReceive` Events
        3.2.3. Handling GenServer `call`/`cast`/`reply` patterns
    3.3. Process Lifecycle Correlation
        3.3.1. Linking `ProcessSpawn` to Parent and Child Contexts
        3.3.2. Associating `ProcessExit` with Process Lifetime Events
    3.4. State Change Correlation
        3.4.1. Linking `StateChange` events to Triggering Messages or Function Calls
    3.5. Asynchronous Operation Correlation (e.g., `Task.async`)
    3.6. Handling Uncorrelated or Partially Correlated Events
4.  State Management for Correlation
    4.1. ETS Table Schemas and Purpose (Diagram Reference: `DIAGS.md#4`)
        4.1.1. `call_stacks_table` (`pid => [correlation_id_stack]`)
        4.1.2. `message_registry_table` (`message_signature => message_record`)
        4.1.3. `correlation_metadata_table` (`correlation_id => metadata_map`)
        4.1.4. `correlation_links_table` (`correlation_id => {:link_type, target_id}` (bag))
    4.2. Concurrency Access Patterns to ETS Tables
    4.3. Data TTL and Automatic Cleanup (`handle_info(:cleanup_expired, state)`)
        4.3.1. Pruning `correlation_metadata_table`
        4.3.2. Cleaning up `call_stacks_table` (stale stacks)
        4.3.3. Pruning `message_registry_table` (unmatched messages)
        4.3.4. Removing Dangling Links from `correlation_links_table`
5.  The `CorrelatedEvent` Data Structure
    5.1. Fields: `event`, `correlation_id`, `parent_id`, `root_id`, `links`, `correlation_type`, `correlated_at`, `correlation_confidence`
    5.2. Populating Causal Links
6.  Performance and Scalability Considerations
    6.1. `GenServer` Bottleneck Potential and Mitigation
    6.2. ETS Table Performance under Load
    6.3. Complexity of Correlation Logic vs. Event Throughput
    6.4. Memory Footprint of Correlation State
    6.5. Batch Processing (`correlate_batch/2`) Benefits
7.  Error Handling and Resilience
    7.1. Handling Malformed or Unexpected Events
    7.2. Consistency of Correlation State during Restarts (if persisted)
8.  Configuration Options
    8.1. `cleanup_interval_ms`
    8.2. `correlation_ttl_ms`
    8.3. `max_correlations`
9.  Testing Strategies for Correlation Logic
10. Future Enhancements (e.g., distributed correlation, advanced pattern matching)
11. Conclusion

---

## 1. Introduction and Purpose

### 1.1. The Role of Correlation in ElixirScope

While the `Ingestor` and `RingBuffer` ensure fast and reliable capture of raw events, these events, in isolation, provide limited insight into the complex dynamics of a concurrent Elixir application. The `ElixirScope.Capture.EventCorrelator` is the engine that imbues this raw data with meaning by establishing contextual and causal relationships between events.

Its primary functions are:
*   To identify events that are part of the same logical operation or trace (e.g., a single function call, a message exchange).
*   To link events sequentially and hierarchically (e.g., parent function call to nested calls, message send to receive).
*   To assign consistent `correlation_id`s that group related events, and `parent_id` / `root_id` to trace execution flows.
*   To build a graph of `links` between events, which forms the basis for constructing the Seven Execution DAGs visualized in the "Execution Cinema".

The output of the `EventCorrelator` is a stream of `CorrelatedEvent` structs, which contain the original event data plus this vital relational metadata.

### 1.2. Goals: Causal Accuracy, Performance, Scalability

*   **Causal Accuracy:** The correlations established must accurately reflect the actual causal relationships within the application's execution.
*   **Performance:** Correlation must be performed efficiently to keep up with the event stream from the `AsyncWriterPool` and avoid becoming a bottleneck. The target for individual event correlation is generally sub-millisecond, but batch processing helps amortize costs.
*   **Scalability:** The correlation state (e.g., open call stacks, pending messages) must be managed in a way that scales with the number of active processes and events, with robust cleanup mechanisms.

## 2. Architecture and System Placement

### 2.1. `GenServer`-based Implementation

The `EventCorrelator` is implemented as a `GenServer`. This choice provides:
*   **State Encapsulation:** The ETS table references and internal statistics are managed within the GenServer's state.
*   **Serialized Access for Critical State (Potentially):** While ETS handles its own concurrency, if certain global correlation decisions needed to be strictly serialized, the GenServer model would provide that (though reliance is more on ETS's concurrency).
*   **Managed Lifecycle:** It can be supervised within the `PipelineManager` or `ElixirScope.Application`'s supervision tree.

### 2.2. Interaction with `AsyncWriter` Workers

`AsyncWriter` workers are the primary clients of the `EventCorrelator`.
1.  An `AsyncWriter` reads a batch of raw events from a `RingBuffer`.
2.  It calls `EventCorrelator.correlate_batch(correlator_pid, event_batch)`.
3.  The `EventCorrelator` processes this batch synchronously from the `AsyncWriter`'s perspective (i.e., the `AsyncWriter` waits for the `handle_call` to return).
4.  The `EventCorrelator` returns the batch of events, now transformed into (or enriched as) `CorrelatedEvent` structs.
5.  The `AsyncWriter` then passes these `CorrelatedEvent`s to `Storage.DataAccess`.

### 2.3. Output: `CorrelatedEvent` Structs

The key output is the `ElixirScope.Capture.EventCorrelator.CorrelatedEvent` struct, which wraps the original event and adds:
*   `correlation_id`: Identifies the overarching trace or operation this event belongs to.
*   `parent_id`: For hierarchical relationships (e.g., a nested function call's parent).
*   `root_id`: The `correlation_id` of the initial event in a chain.
*   `links`: A list of explicit causal links, e.g., `[{:called_from, parent_corr_id}, {:completes, entry_corr_id}]`.
*   `correlation_type`: The primary nature of this event's correlation (e.g., `:function_call`, `:message_receive`).
*   `correlation_confidence`: A score indicating the certainty of the correlation.

## 3. Core Correlation Logic and Strategies

The `EventCorrelator`'s `correlate_single_event/2` function dispatches to specific handlers based on the incoming event's type (determined by `determine_event_type/1`).

### 3.1. Function Call Correlation

This is one of the most fundamental correlation types. `DIAGS.md#7. Event Correlation State Machine` depicts the general flow.

#### 3.1.1. Per-Process Call Stack Management

*   The `call_stacks_table` ETS table stores `pid => [correlation_id_of_current_call, correlation_id_of_parent_call, ...]`.
*   When a `FunctionEntry` event arrives for a `pid`:
    1.  A new, unique `correlation_id` is generated for this function call instance.
    2.  The `pid`'s current call stack is retrieved from `call_stacks_table`.
    3.  The new `correlation_id` is pushed onto the head of this stack.
    4.  The updated stack is written back to `call_stacks_table` for that `pid`.
*   The `correlation_id` at the head of the stack is the current active call for that process.

#### 3.1.2. Linking Entry, Exit, and Exception Events

*   **Entry:** The new `correlation_id` generated for the `FunctionEntry` becomes its primary identifier.
*   **Exit/Exception:** When a `FunctionExit` event (or an exception event implicitly terminating a function) arrives for a `pid`:
    1.  The `pid`'s call stack is retrieved.
    2.  The `correlation_id` at the head of the stack (the one corresponding to the function now exiting) is popped. This popped `correlation_id` is assigned to the `FunctionExit` event.
    3.  The updated (shorter) stack is written back to `call_stacks_table`.
    This ensures the `FunctionEntry` and its corresponding `FunctionExit` share the same `correlation_id`.
*   The `InstrumentationRuntime` is responsible for passing the `call_id` (which is effectively the `correlation_id` of the entry event) to the `report_function_exit` call. The `EventCorrelator` then uses this to link them and manage the stack.

#### 3.1.3. Handling Nested and Recursive Calls

The per-process call stack naturally handles nesting:
*   Outer call `A` enters: `corr_A` pushed. Stack: `[corr_A | T]`.
*   `A` calls `B`: `corr_B` pushed. Stack: `[corr_B, corr_A | T]`. `corr_B`'s `parent_id` is `corr_A`.
*   `B` exits: `corr_B` popped. Stack: `[corr_A | T]`.
*   `A` exits: `corr_A` popped. Stack: `T`.

Recursion is also handled as each recursive invocation gets a new `correlation_id` and is pushed/popped from the stack.

#### 3.1.4. Assigning `correlation_id`, `parent_id`, `root_id`

*   `correlation_id`: The ID generated for the `FunctionEntry` event, shared by its `FunctionExit`.
*   `parent_id`: When a `FunctionEntry` (e.g., `corr_B`) is processed, if the call stack for its `pid` is not empty, the `correlation_id` at the head of the stack (e.g., `corr_A`) becomes `corr_B`'s `parent_id`.
*   `root_id`: This is traced by traversing `parent_id` links up to the initial call in a chain. If an event has no `parent_id`, its `correlation_id` is its `root_id`.

### 3.2. Message Passing Correlation

#### 3.2.1. Message Signature Generation

To link a `MessageSend` event with its corresponding `MessageReceive` event (which might occur in a different process and at a later time), a **message signature** is created. As per `EventCorrelator.create_message_signature/1`:
`{sender_pid, receiver_pid, :erlang.phash2(message_content)}`.
This signature aims to uniquely identify a specific message instance.

#### 3.2.2. Linking `MessageSend` to `MessageReceive` Events

1.  **On `MessageSend` event:**
    *   A new `correlation_id` (let's call it `corr_send`) is generated for the send operation.
    *   The message signature is calculated.
    *   A record `%{correlation_id: corr_send, from_pid:, to_pid:, timestamp:, signature:}` is inserted into `message_registry_table` keyed by the `message_signature`.
2.  **On `MessageReceive` event:**
    *   The message signature is calculated for the received message.
    *   The `message_registry_table` is looked up using this signature.
    *   If a matching record is found (meaning a prior `MessageSend` with the same signature was registered):
        *   The `correlation_id` from the matched record (`corr_send`) is assigned to this `MessageReceive` event.
        *   A link like `{:receives, corr_send}` is added to the `MessageReceive` event's `CorrelatedEvent`.
        *   (Optional) The entry in `message_registry_table` can be removed or marked as matched to prevent re-correlation if messages are not unique.
    *   If no match is found, a new `correlation_id` is generated for the `MessageReceive` event (it's an "orphan" receive or the send was not traced).

#### 3.2.3. Handling GenServer `call`/`cast`/`reply` patterns

*   `GenServer.call/3`: Is a `MessageSend` (the call message) followed by a `MessageReceive` (the reply). The standard message correlation can link these if the reply message content can be correlated to the call message signature (e.g., via a unique reference `make_ref()` included in both).
*   `GenServer.cast/2`: Is a `MessageSend`.
*   The `FunctionExecution` events for `handle_call`/`handle_cast` will have their own correlation IDs. The `EventCorrelator` needs to link the `MessageReceive` event (that triggered the callback) to the `FunctionEntry` of the `handle_call`/`handle_cast`. This is typically done by ensuring the `InstrumentationRuntime` active during the callback uses the correlation ID of the triggering message.

### 3.3. Process Lifecycle Correlation

*   **`ProcessSpawn`:** The event itself contains `spawned_pid` and `parent_pid`. The `EventCorrelator` can generate a `correlation_id` for the spawn event and establish links like `{:spawns, spawned_pid_context_id}` from the parent's current active correlation context, and `{:spawned_by, parent_context_id}` for the child's initial context.
*   **`ProcessExit`:** Can be linked to the process's overall lifecycle correlation established at spawn time.

### 3.4. State Change Correlation

`StateChange` events for GenServers should be linked to the specific message or function call that triggered the callback leading to the state change.
*   When `InstrumentationRuntime.report_state_change` is called from an instrumented callback, it should have access to the `correlation_id` of the currently executing function (the callback itself). This `correlation_id` is then associated with the `StateChange` event.

### 3.5. Asynchronous Operation Correlation (e.g., `Task.async`)

Correlating operations that span `Task.async` boundaries can be challenging.
*   If the `Task.async` call itself is instrumented, its `correlation_id` can be captured.
*   Propagating this `correlation_id` into the context of the spawned task process requires mechanisms like passing it as an argument or using a distributed tracing context propagation library (more advanced). ElixirScope's current foundation focuses on per-process stacks.

### 3.6. Handling Uncorrelated or Partially Correlated Events

Not all events can be perfectly correlated (e.g., a message received before its sender was traced, or events from untraced parts of the system).
*   These events still get their own `correlation_id`.
*   Their `correlation_confidence` score in `CorrelatedEvent` will be lower.
*   They will have fewer links in their `links` list.

## 4. State Management for Correlation

The `EventCorrelator` relies heavily on ETS tables for fast, concurrent access to its state.

### 4.1. ETS Table Schemas and Purpose

*   **`call_stacks_table` (`pid => [correlation_id_stack]`):**
    *   Type: `:set` (as PIDs are unique keys).
    *   Access: Read and write (full stack update) on every function entry/exit for a given PID.
    *   Concurrency: PIDs are distinct, so operations on different PIDs are independent. Operations on the *same* PID are serialized by the `EventCorrelator` GenServer if it processes events one by one, or require care if events for the same PID could be processed by multiple correlator instances (not the current model).
*   **`message_registry_table` (`message_signature => message_record`):**
    *   Type: `:set`.
    *   Access: Write on `MessageSend`, read (and potentially delete) on `MessageReceive`.
    *   Concurrency: Message signatures can be diverse; concurrent access to different signatures is fine.
*   **`correlation_metadata_table` (`correlation_id => metadata_map`):**
    *   Type: `:set`, `{:write_concurrency, true}`.
    *   Access: Write when a new correlation chain starts. Read for building chains or debugging. Deleted during cleanup.
*   **`correlation_links_table` (`correlation_id => {:link_type, target_id}`):**
    *   Type: `:bag` (a `correlation_id` can have multiple links).
    *   Access: Write whenever a link is established. Read for chain building. Objects deleted during cleanup.

### 4.2. Concurrency Access Patterns to ETS Tables

*   Since `EventCorrelator` is a single `GenServer` processing batches of events, access to its ETS tables *through its own internal logic* is effectively serialized per batch.
*   The ETS tables themselves are configured for concurrent access (`:public`, `read_concurrency`, `write_concurrency`), which is relevant if other processes were to query them directly (e.g., for debugging the correlator, or if future designs involve more distributed correlation logic).

### 4.3. Data TTL and Automatic Cleanup (`handle_info(:cleanup_expired, state)`)

This is crucial to prevent unbounded growth of the ETS tables.
1.  **Trigger:** A recurring `Process.send_after` message (`:cleanup_expired`).
2.  **Mechanism:**
    *   Iterate through `correlation_metadata_table`.
    *   For each entry, check `metadata.created_at` against `now - config.correlation_ttl_ms`.
    *   If expired:
        *   Delete from `correlation_metadata_table`.
        *   Delete all associated entries from `correlation_links_table` where this `correlation_id` is the key.
        *   (Harder) Proactively clean from `call_stacks_table`: Iterate stacks and remove this ID. This is complex; often stacks are implicitly cleaned as functions exit. Stale stacks for dead PIDs are a concern.
        *   Clean from `message_registry_table`: Iterate and remove messages older than TTL or whose `correlation_id` is now expired.
*   **Efficiency:** Full table scans for cleanup can be expensive. Strategies like time-sharded ETS tables or maintaining separate "active" vs. "recently expired" sets could optimize this for very large numbers of correlations. The current code in `EventCorrelator` iterates `correlation_metadata_table` and then `message_registry_table`.

## 5. The `CorrelatedEvent` Data Structure

This struct is the primary output of the `EventCorrelator`.
```elixir
defmodule ElixirScope.Capture.EventCorrelator.CorrelatedEvent do
  defstruct [
    :event,                    # Original ElixirScope.Events.t()
    :correlation_id,           # ID for this specific operation/trace instance
    :parent_id,                # ID of the parent operation (e.g., outer function call)
    :root_id,                  # ID of the top-most operation in this causal chain
    :links,                    # List of tuples: [{:link_type, target_correlation_id}]
                               # e.g., [{:called_from, p_id}, {:triggered_message, m_id}]
    :correlation_type,         # :function_call, :message_send, :state_change etc.
    :correlated_at,            # Timestamp when correlation was established
    :correlation_confidence    # Float 0.0-1.0 indicating certainty of correlation
  ]
end
```
Populating `links` involves adding tuples like `{:called_from, parent_id}`, `{:completes, entry_id}`, `{:sends_message_to, receiver_corr_id, message_signature_or_id}`, `{:receives_message_from, sender_corr_id, message_signature_or_id}`.

## 6. Performance and Scalability Considerations

### 6.1. `GenServer` Bottleneck Potential and Mitigation

A single `EventCorrelator` GenServer processing all events serially (per batch) can become a bottleneck if the event rate is extremely high or correlation logic is complex.
*   **Mitigation 1 (Current): Batching.** `correlate_batch/2` processes multiple events per `GenServer.call`, reducing per-event call overhead.
*   **Mitigation 2 (Future): Sharding.** Multiple `EventCorrelator` instances, each handling a subset of PIDs or correlation IDs (e.g., sharded by `pid_hash % num_correlators`). This requires careful management of state that needs a global view (like message matching across PIDs handled by different correlators).
*   **Mitigation 3 (Future): Offloading.** Perform very simple correlation in `AsyncWriter` and defer complex, cross-cutting correlation to a later, possibly distributed, batch processing stage.

### 6.2. ETS Table Performance under Load

ETS is generally very fast, but:
*   Frequent writes to the same key in a `:set` table (e.g., updating a PID's call stack) can still cause some contention, though ETS is optimized for this.
*   Large numbers of objects in `:bag` tables (`correlation_links_table`) can slow down lookups if not indexed well (though lookups are by key, matching specific objects in a bag can take time).
*   Cleanup scans (`:ets.tab2list/1` or `:ets.select/2`) can be expensive on very large tables.

### 6.3. Complexity of Correlation Logic vs. Event Throughput

More sophisticated correlation logic (e.g., trying multiple heuristics to match messages, complex state analysis) will increase processing time per event, reducing throughput. This is a trade-off between correlation richness and speed.

### 6.4. Memory Footprint of Correlation State

The ETS tables storing call stacks, message registries, metadata, and links can consume significant memory. The TTL-based cleanup is vital. The `max_correlations` config is a conceptual limit that should trigger more aggressive cleanup or sampling if hit.

### 6.5. Batch Processing (`correlate_batch/2`) Benefits

Reduces `GenServer.call` overhead per event. Allows for optimizations within the batch (e.g., pre-fetching all relevant call stacks for PIDs present in the batch).

## 7. Error Handling and Resilience

*   **Malformed Events:** `correlate_single_event` should be robust to unexpected event structures, logging errors and assigning low `correlation_confidence` rather than crashing. The `determine_event_type/1` fallback to `:unknown` helps here.
*   **State Consistency:** If `EventCorrelator` crashes and restarts, its in-memory ETS state is lost (unless ETS tables are disk-based, which is not typical for this kind of volatile state). This means ongoing correlations might be broken. New events will start fresh. For critical production use, persisting correlation state or having mechanisms to rebuild it from stored events might be needed (very advanced).
*   **Timeouts:** Calls from `AsyncWriter` to `EventCorrelator.correlate_batch` should have timeouts to prevent `AsyncWriter`s from blocking indefinitely if the `EventCorrelator` is stuck.

## 8. Configuration Options

From `ElixirScope.Capture.EventCorrelator`'s `@default_config`:
*   `cleanup_interval_ms`: How often the cleanup task runs.
*   `correlation_ttl_ms`: How long correlation metadata and links are kept before being eligible for cleanup. Determines the "memory window" for active correlations.
*   `max_correlations`: A conceptual threshold. If the number of active correlations (e.g., size of `correlation_metadata_table`) exceeds this, more aggressive cleanup or adaptive sampling might be triggered.

## 9. Testing Strategies for Correlation Logic

Referenced by `test/elixir_scope/capture/event_correlator_test.exs`.
*   **Unit tests for specific scenarios:**
    *   Simple function call (entry/exit).
    *   Nested function calls.
    *   Recursive function calls.
    *   Message send and receive (match found).
    *   Message receive (no matching send).
    *   Multiple messages between same PIDs.
    *   GenServer call/cast sequences with state changes.
*   **Property-based tests:** Generate random sequences of events for a set of PIDs and verify invariants (e.g., call stacks are always consistent, correlation IDs are correctly propagated).
*   **Concurrency tests:** Multiple `AsyncWriter` (mocked) tasks sending batches to the `EventCorrelator` concurrently.
*   **Cleanup tests:** Verify that expired correlations are correctly removed and do not leak memory.
*   **Performance tests:** Measure throughput of `correlate_batch/2` under load and average time per event.

## 10. Future Enhancements

*   **Distributed Correlation:** Handling correlations for operations that span multiple BEAM nodes. This would require `EventCorrelator` instances to communicate or share state, or a central distributed correlation service.
*   **Advanced Pattern Matching:** Beyond simple call/message linking, identify higher-level OTP patterns (e.g., supervisor restarts linked to worker crashes, `GenServer.multi_call` patterns).
*   **Configurable Correlation Rules:** Allow users to define custom correlation logic for application-specific patterns.
*   **Integration with AI Analysis:** Feed correlation graph data to AI engines for deeper insights.

## 11. Conclusion

The `ElixirScope.Capture.EventCorrelator` is a cornerstone of ElixirScope's intelligence. It transforms a simple chronological event stream into a causally-linked graph of execution. Its effective and performant operation, reliant on careful state management in ETS and robust correlation heuristics, is fundamental to enabling the rich analytical and visual capabilities envisioned for the "Execution Cinema." While the current GenServer-based model with batching provides a solid foundation, scalability for extremely high event rates might necessitate future architectural refinements like sharding or more distributed processing of correlation tasks.