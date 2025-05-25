Okay, given the importance of the RingBuffer as the entry point for captured data, the next most relevant technical subject is the **Asynchronous Event Processing Pipeline**, specifically focusing on the `AsyncWriterPool` and `AsyncWriter` components, and their interaction with the `EventCorrelator` and `DataAccess` layers.

This pipeline is responsible for consuming events from the RingBuffer, processing them (enrichment, correlation), and storing them, all without blocking the primary application threads. Its efficiency and reliability are crucial for the overall system.

---

**ElixirScope Technical Document: Asynchronous Event Processing Pipeline**

**Document Version:** 1.2
**Date:** 2024-05-24
**Authors:** ElixirScope Team (AI Assisted)

**Abstract:**

This document details the architecture and implementation of ElixirScope's Asynchronous Event Processing Pipeline. This pipeline is responsible for consuming events from the high-performance Ring Buffers, enriching them, performing initial event correlation, and persisting them to the storage layer. It is designed to operate independently of the main application threads, ensuring that event capture overhead remains minimal. Key components include the `AsyncWriterPool`, individual `AsyncWriter` workers, and their interaction with the `EventCorrelator` and `Storage.DataAccess` modules.

**Table of Contents:**

1.  Introduction and Purpose
    1.1. Role in the ElixirScope Ecosystem
    1.2. Design Goals: Throughput, Resilience, Decoupling
2.  Pipeline Architecture Overview (Diagram Reference: `DIAGS.md#3. Event Capture Pipeline`)
    2.1. `ElixirScope.Capture.PipelineManager`
    2.2. `ElixirScope.Capture.AsyncWriterPool`
    2.3. `ElixirScope.Capture.AsyncWriter` (Worker)
    2.4. Interaction with `EventCorrelator`
    2.5. Interaction with `Storage.DataAccess`
3.  `AsyncWriterPool` Implementation
    3.1. Supervision and Worker Management
    3.2. Dynamic Scaling (Conceptual)
    3.3. Work Distribution / Ring Buffer Partitioning Strategy
    3.4. Metrics Aggregation
4.  `AsyncWriter` Worker Implementation
    4.1. GenServer-based Worker Lifecycle
    4.2. Ring Buffer Consumption
        4.2.1. Batch Reading (`RingBuffer.read_batch/3`)
        4.2.2. Maintaining Individual Read Positions
    4.3. Event Batch Processing Loop
    4.4. Event Enrichment (Placeholder for `EventCorrelator` Actions)
    4.5. Interaction with `EventCorrelator`
    4.6. Writing to `Storage.DataAccess`
    4.7. Error Handling and Resilience
    4.8. Backpressure Mechanisms (Conceptual)
5.  Event Correlation Stage (`ElixirScope.Capture.EventCorrelator`)
    5.1. Integration into the Async Pipeline
    5.2. Types of Correlations Handled
    5.3. State Management for Correlation (ETS Tables)
6.  Data Persistence Stage (`ElixirScope.Storage.DataAccess`)
    6.1. Batch Writing to ETS
    6.2. Index Management during Writes
7.  Performance Characteristics
    7.1. Target Throughput
    7.2. Latency of Asynchronous Path
    7.3. Impact of Batch Sizes and Worker Counts
8.  Configuration and Tunability
9.  Testing Strategies for the Async Pipeline
10. Conclusion

---

## 1. Introduction and Purpose

### 1.1. Role in the ElixirScope Ecosystem

Once events are captured from the instrumented application by the `InstrumentationRuntime` and `EventIngestor` and rapidly staged into the `RingBuffer`(s), the Asynchronous Event Processing Pipeline takes over. Its primary responsibility is to drain these `RingBuffer`(s) in a timely manner, perform necessary processing (like enrichment and correlation), and durably store the events for later querying and analysis by the "Execution Cinema" UI and AI engines.

This asynchronous nature is critical: it isolates the instrumented application from the variable latencies of event processing, correlation, and disk I/O (for warm/cold storage), ensuring that the act of capturing an event remains consistently fast and low-overhead.

### 1.2. Design Goals: Throughput, Resilience, Decoupling

*   **Throughput:** The pipeline must be able to process events at a rate that matches or exceeds the ingestion rate into the `RingBuffer`(s) under normal conditions, preventing buffer overflows.
*   **Resilience:** Individual worker failures should not bring down the entire processing pipeline. The system should recover and continue processing. Errors during event processing (e.g., correlation issues, storage failures) should be handled gracefully, logged, and potentially retried without losing valid events where possible.
*   **Decoupling:** Clearly separates the concerns of fast, temporary event capture from the more complex and potentially slower tasks of correlation and persistent storage.

## 2. Pipeline Architecture Overview

The main components involved are visualized in `DIAGS.md#3. Event Capture Pipeline`.

### 2.1. `ElixirScope.Capture.PipelineManager`

*   **Role:** A top-level `Supervisor` (or a GenServer managing a dynamic supervisor) for the asynchronous processing components.
*   **Responsibilities:**
    *   Supervises the `AsyncWriterPool`.
    *   (Potentially) Supervises one or more `EventCorrelator` instances if they are run as separate processes from the writers.
    *   Manages the lifecycle (start, stop, restart) of these supervised components.
    *   May handle global configuration updates relevant to the async pipeline.
*   **State:** The `PipelineManager` itself primarily manages supervisor state. Its configuration and high-level operational statistics are stored in an ETS table (`:pipeline_manager_state`) as per its code.

### 2.2. `ElixirScope.Capture.AsyncWriterPool`

*   **Role:** A pool manager (implemented as a `GenServer`) responsible for creating, managing, and distributing work among a set of `AsyncWriter` worker processes.
*   **Responsibilities:**
    *   Starts a configurable number of `AsyncWriter` workers.
    *   Monitors workers and restarts them upon failure.
    *   Distributes the task of reading from one or more `RingBuffer`(s) among the workers. This could involve assigning specific buffers to workers or segments of a shared buffer (see Section 3.3).
    *   (Future) Supports dynamic scaling of the worker pool based on `RingBuffer` backlog or processing load.
    *   Aggregates metrics from individual workers.

### 2.3. `ElixirScope.Capture.AsyncWriter` (Worker)

*   **Role:** A `GenServer`-based worker process that performs the core tasks of reading from a `RingBuffer`, processing events, and initiating their storage.
*   **Responsibilities:**
    1.  Periodically polls its assigned `RingBuffer` (or segment) for new events.
    2.  Reads events in batches using `RingBuffer.read_batch/3`.
    3.  Maintains its own read position for the `RingBuffer`.
    4.  For each batch of events:
        *   Deserializes events if they are stored in a serialized format in the RingBuffer.
        *   Performs event enrichment (e.g., adding processing timestamps, worker ID).
        *   Passes events to the `EventCorrelator` to establish causal links.
        *   Writes the enriched and correlated events to `Storage.DataAccess`.
    5.  Handles errors during processing and reports metrics.

### 2.4. Interaction with `EventCorrelator`

After an `AsyncWriter` retrieves a batch of events, it sends these events (or relevant information from them) to the `ElixirScope.Capture.EventCorrelator`.
*   The `EventCorrelator` uses its internal state (call stacks, message registry) to link related events (e.g., function entry to exit, message send to receive).
*   It returns the events, now enriched with correlation IDs, parent IDs, and causal links.
*   This interaction is synchronous from the `AsyncWriter`'s perspective for a given batch: the writer waits for the correlator to process the batch before proceeding to storage. This ensures correlation data is established before events are made queryable.

### 2.5. Interaction with `Storage.DataAccess`

Once events are enriched and correlated, the `AsyncWriter` writes them to `Storage.DataAccess` using `DataAccess.store_events/2` (batch write).
*   `DataAccess` is responsible for inserting the event into the primary ETS table and updating all relevant secondary index tables (temporal, process, function, correlation).

## 3. `AsyncWriterPool` Implementation

The `ElixirScope.Capture.AsyncWriterPool` GenServer manages the lifecycle and work distribution of `AsyncWriter` workers.

### 3.1. Supervision and Worker Management

*   **Startup:** `AsyncWriterPool.init/1` starts a configured number (`pool_size`) of `AsyncWriter` children. Each child is typically started via `AsyncWriter.start_link/1`.
*   **Monitoring:** The pool monitors its child workers using `Process.monitor/1`.
*   **Failure Handling:** Upon receiving a `:DOWN` message for a worker, the pool:
    1.  Logs the failure.
    2.  Removes the dead worker from its active list.
    3.  Starts a new `AsyncWriter` worker to replace the failed one.
    4.  Updates work assignments if necessary.
    This ensures the pool maintains its configured size and processing capacity.

### 3.2. Dynamic Scaling (Conceptual)

While the current implementation might have a fixed pool size set at startup, a more advanced `AsyncWriterPool` could dynamically adjust the number of workers:
*   **Scale Up:** If `RingBuffer` fill levels (utilization) consistently exceed a high watermark, or if the aggregated processing rate of workers falls significantly behind the ingestion rate, the pool could start additional workers.
*   **Scale Down:** If workers are consistently idle or `RingBuffer` levels are very low, the pool could shut down surplus workers to save resources.
This requires monitoring metrics from both `RingBuffer`s and `AsyncWriter`s.

### 3.3. Work Distribution / Ring Buffer Partitioning Strategy

There are several ways the `AsyncWriterPool` can distribute the work of reading from `RingBuffer`(s):

*   **Multiple Distinct RingBuffers:** If ElixirScope uses multiple `RingBuffer` instances (e.g., one per scheduler, or sharded by some criteria), the pool can assign one or more specific `RingBuffer` instances to each `AsyncWriter`.
*   **Single Shared RingBuffer with Segmented Reading:** If there's a single logical (or very large) `RingBuffer`, the pool could divide the responsibility of reading from it.
    *   The current code in `AsyncWriterPool.assign_work_segments/2` assigns each worker a unique `index` (segment ID). An `AsyncWriter` could potentially use this segment ID to focus on a particular portion of events, for example, by processing events whose `event_id &&& num_workers == worker_segment_id`. However, this requires careful coordination to ensure all events are processed and read positions are managed correctly across segments without a global view.
    *   A more common approach for a single shared ring buffer is for each `AsyncWriter` to independently try to read batches. The lock-free nature of the `RingBuffer`'s read pointers (if designed for multiple readers, each advancing their own pointer, or a shared atomic read-claim pointer) allows this. The key is that each `AsyncWriter` maintains its *own* `current_position` for reading.
*   **The current implementation (`AsyncWriter` consuming from `state.config.ring_buffer`) implies that each `AsyncWriter` potentially reads from the *same* `RingBuffer` instance defined in its config.** If multiple workers are configured with the same `RingBuffer` instance, they *must* coordinate their read positions to avoid processing the same events multiple times or missing events. This coordination would typically involve:
    *   Each `AsyncWriter` maintaining its own private read cursor for that `RingBuffer`.
    *   Or, a more complex shared "claimable read index" managed by atomics, similar to the write pointer.
    The `AsyncWriter.set_position/2` call and internal `state.current_position` suggest each worker *does* track its own position. If they all share one buffer, the `AsyncWriterPool` or the `PipelineManager` would be responsible for initially setting distinct start positions or ensuring their read ranges don't overlap excessively, or that they can robustly handle re-processing if another worker crashes after reading but before "committing" its read.

### 3.4. Metrics Aggregation

The `AsyncWriterPool.get_metrics/1` function iterates through its list of active workers, calls `AsyncWriter.get_metrics/1` on each, and aggregates these into pool-wide statistics (e.g., total events read/processed, average processing rate across the pool).

## 4. `AsyncWriter` Worker Implementation

The `ElixirScope.Capture.AsyncWriter` is the workhorse of the asynchronous pipeline.

### 4.1. GenServer-based Worker Lifecycle

*   **`init/1`:** Initializes the worker's state, including its configuration (batch size, poll interval, `RingBuffer` reference), initial read position (often 0), and statistics counters. It schedules the first `:poll` message.
*   **`handle_info(:poll, state)`:** This is the main work loop trigger. It calls `process_batch/1`.
*   **`handle_call`:** Used for state inspection (`get_state`, `get_metrics`), control (`set_position`, `stop`).

### 4.2. Ring Buffer Consumption

#### 4.2.1. Batch Reading (`RingBuffer.read_batch/3`)

Inside `process_batch/1`, the `AsyncWriter` calls `RingBuffer.read_batch(ring_buffer, state.current_position, state.config.batch_size)`.
*   `ring_buffer`: The reference to the `RingBuffer` instance it's consuming from.
*   `state.current_position`: The position from which this worker should start reading. This is crucial for ensuring the worker doesn't re-process events it has already handled.
*   `state.config.batch_size`: The maximum number of events to read in one go.

The call returns `{events_read_from_buffer, new_read_position_for_this_worker}`.

#### 4.2.2. Maintaining Individual Read Positions

The `AsyncWriter` updates its `state.current_position` with the `new_read_position_for_this_worker` returned by `RingBuffer.read_batch/3`. This is essential for sequential processing of the event stream by this specific worker.

### 4.3. Event Batch Processing Loop

Within `process_batch/1`, if `events_read_from_buffer` is not empty:
1.  The worker's `events_read` and `batches_processed` statistics are updated.
2.  The `process_events/2` function is called with the batch.

The `process_events/2` function (in `AsyncWriter`) then:
1.  (If `state.config[:simulate_errors]` is true for tests, it might raise an error).
2.  Iterates through the events in the batch. For each event:
    *   Calls `AsyncWriter.enrich_event/1` (a public function in `AsyncWriter` itself, perhaps should be in a dedicated `Enricher` module or part of `EventCorrelator` logic). This adds a basic `correlation_id` (currently a simple unique integer, not the sophisticated one from `EventCorrelator`), `enriched_at` timestamp, `processed_by` node, and `processing_order`.
    *   **Missing Critical Step:** The current `AsyncWriter.process_events` seems to only enrich and then implicitly assumes the events are "processed". It **must** then pass these events to the `EventCorrelator` and subsequently to `Storage.DataAccess`. The `PROGRESS.md` shows `EventCorrelator` and `DataAccess` as complete, so this interaction path needs to be explicit in `AsyncWriter`.

**Corrected Flow (Conceptual):**
```elixir
defp process_events(events, state) do
  enriched_events = Enum.map(events, &enrich_base_metadata(&1, state))

  # Pass to EventCorrelator
  # This call would block until correlation is done for this batch
  correlated_events_batch = ElixirScope.Capture.EventCorrelator.correlate_batch(
    Process.whereis(ElixirScope.Capture.EventCorrelator), # Assuming named correlator
    enriched_events
  )

  # Write to DataAccess
  case ElixirScope.Storage.DataAccess.store_events(correlated_events_batch) do
    {:ok, num_stored} ->
      # Update successful processing count, etc.
      Logger.debug("AsyncWriter stored #{num_stored} events.")
      # Return successfully processed events or count for metric updates
      correlated_events_batch # or num_stored
    {:error, reason} ->
      Logger.error("AsyncWriter failed to store events: #{inspect(reason)}")
      # Handle error, maybe retry, log, or discard batch
      # Update error stats
      reraise # or handle appropriately
  end
end
```

### 4.4. Event Enrichment

The current `AsyncWriter.enrich_event/1` function performs basic enrichment. More sophisticated enrichment, especially correlation ID assignment based on causal links, is the responsibility of the `EventCorrelator`. The `AsyncWriter` might add processing-pipeline-specific metadata (worker ID, processing timestamp) before or after correlation.

### 4.5. Interaction with `EventCorrelator`

As outlined above, the `AsyncWriter` should send batches of (possibly minimally enriched) events to the `EventCorrelator.correlate_batch/2` function. The `EventCorrelator` would then apply its logic using its ETS tables to link events and assign appropriate correlation IDs, parent IDs, etc., returning the batch of now fully correlated events.

### 4.6. Writing to `Storage.DataAccess`

After correlation, the `AsyncWriter` takes the batch of `CorrelatedEvent`s and calls `ElixirScope.Storage.DataAccess.store_events/2` to persist them. `DataAccess` handles the ETS inserts and index updates.

### 4.7. Error Handling and Resilience

*   The `process_batch` function in `AsyncWriter` has a `try/rescue` block.
*   If `RingBuffer.read_batch/3` fails (e.g., `ring_buffer` ref is invalid), an error is logged, and `error_count` is incremented.
*   If `process_events/2` (which would include correlation and storage) fails:
    *   The error is logged.
    *   `error_count` is incremented.
    *   **Crucially, the `state.current_position` should NOT be advanced if the batch processing failed catastrophically before storage.** This would allow the batch to be retried on the next poll. If only a partial failure occurs (e.g., some events in a batch fail to store), more sophisticated retry or dead-letter-queue logic would be needed. The current code simply logs and increments `error_count`, implicitly moving past the batch.

### 4.8. Backpressure Mechanisms (Conceptual)

If `AsyncWriter`s consistently fall behind (e.g., `RingBuffer`s are always near full, or `DataAccess` writes are very slow), a backpressure mechanism would be needed:
*   `AsyncWriter`s could monitor the `RingBuffer` fill rate or their own internal queue size (if they buffer before `EventCorrelator`/`DataAccess`).
*   If thresholds are exceeded, they could:
    *   Reduce their polling rate.
    *   Signal the `AsyncWriterPool` or `PipelineManager` to reduce overall event acceptance or trigger adaptive sampling at the `Ingestor` level.
This is an advanced feature not explicitly detailed in the current foundation.

## 5. Event Correlation Stage (`ElixirScope.Capture.EventCorrelator`)

### 5.1. Integration into the Async Pipeline

The `EventCorrelator` acts as a processing stage invoked by `AsyncWriter`s. It's a GenServer that receives batches of events. Its `handle_call({:correlate_batch, events}, _from, state)` is the entry point.
1. It iterates through the batch, calling `correlate_single_event/2` for each.
2. `correlate_single_event/2` determines the event type and dispatches to specific correlation logic (e.g., `correlate_function_call`, `correlate_message_send`).
3. This logic uses the ETS tables (`call_stacks_table`, `message_registry_table`, etc.) to find related events and establish links.
4. It populates fields like `correlation_id`, `parent_id`, `root_id`, and `links` in the `CorrelatedEvent` struct.
5. Statistics on correlation activity are updated.

### 5.2. Types of Correlations Handled

*   **Function Execution:** Linking `function_entry` to `function_exit` via a per-process call stack. Nested calls establish parent-child relationships.
*   **Message Passing:** Linking `message_send` to `message_receive` using a message signature (sender PID, receiver PID, hash of message content).
*   (Implicitly) State changes to the events that triggered them (if the triggering event's correlation ID is propagated).

### 5.3. State Management for Correlation (ETS Tables)

As detailed in the previous document and its own code:
*   `call_stacks_table`: `pid => [correlation_id_stack]`
*   `message_registry_table`: `message_signature => message_record_with_correlation_id`
*   `correlation_metadata_table`: `correlation_id => %{type:, created_at:, pid:, ...}`
*   `correlation_links_table`: `correlation_id => {:link_type, target_id}` (bag table)

Periodic cleanup (`handle_info(:cleanup_expired, state)`) is essential to prevent these tables from growing indefinitely.

## 6. Data Persistence Stage (`ElixirScope.Storage.DataAccess`)

### 6.1. Batch Writing to ETS

`AsyncWriter`s should use `DataAccess.store_events/2` for efficiency. This function:
1.  Takes a list of `CorrelatedEvent`s (or base `Event` structs).
2.  Prepares batch inserts for the primary table and all index tables.
3.  Executes `:ets.insert/2` with list arguments for each table.
4.  Updates global statistics in the `stats_table` (total events, newest timestamp).

### 6.2. Index Management during Writes

`DataAccess.store_events/2` (and `store_event/2`) correctly extracts keys for each index (PID, timestamp, {module, function}, correlation ID) from each event and inserts corresponding entries into the index tables. This ensures events are immediately queryable on these dimensions after being stored.

## 7. Performance Characteristics

### 7.1. Target Throughput

The asynchronous pipeline must be able to sustain a processing rate equal to or greater than the RingBuffer ingestion rate. If the RingBuffer can handle 1M events/sec, the combined throughput of all `AsyncWriter`s (including correlation and storage time per event) needs to match this.

### 7.2. Latency of Asynchronous Path

The time from an event being written to the `RingBuffer` to it being persisted in `DataAccess` and queryable. This will be higher than the ingestion latency but should still be in the low milliseconds range on average to provide near real-time visibility.

### 7.3. Impact of Batch Sizes and Worker Counts

*   **Batch Size (AsyncWriter config):** Larger batches can improve throughput for `EventCorrelator` and `DataAccess` by reducing per-call overhead but increase latency for individual events within that batch and consume more memory per worker cycle.
*   **Worker Count (AsyncWriterPool config):** More workers can increase overall throughput if processing is CPU-bound or involves I/O waits, but too many can lead to contention for shared resources (CPU, ETS table access, `EventCorrelator` GenServer calls). Optimal numbers need tuning.

## 8. Configuration and Tunability

Key parameters affecting this pipeline are found in `ElixirScope.Config`:
*   `capture.ring_buffer.size`, `capture.ring_buffer.num_buffers`
*   `capture.processing.batch_size` (for `AsyncWriter`)
*   `capture.processing.flush_interval` (effectively `AsyncWriter`'s `:poll_interval_ms`)
*   `capture.processing.max_queue_size` (implies a backlog limit before backpressure)
*   `storage.hot.max_events`, `storage.hot.max_age_seconds` (affect `DataAccess` pruning)
*   (Implicitly) `AsyncWriterPool` size (currently hardcoded/default in `AsyncWriterPool`'s default config).

## 9. Testing Strategies for the Async Pipeline

*   **Unit Tests:**
    *   `AsyncWriterTest`: Test polling logic, batch processing calls, error handling for RingBuffer reads.
    *   `AsyncWriterPoolTest`: Test worker startup, monitoring, restart, scaling, metric aggregation.
    *   `EventCorrelatorTest`: Test various event sequences for correct correlation link generation.
*   **Integration Tests:**
    *   Test the flow: `RingBuffer` -> `AsyncWriter` -> `EventCorrelator` -> `DataAccess`. Verify events written to RingBuffer end up correctly correlated and stored.
    *   Test with multiple `AsyncWriter` workers consuming from a shared `RingBuffer` (if that's the model) or from distinct buffers.
*   **Load Tests:**
    *   Sustain high event rates into the `RingBuffer` and measure if the async pipeline can keep up.
    *   Monitor `RingBuffer` fill levels, `AsyncWriter` processing rates, and `EventCorrelator` call queue length (if applicable).
    *   Test behavior under backpressure or when `DataAccess` writes become slow.
*   **Resilience Tests (Chaos Engineering):**
    *   Kill `AsyncWriter` workers: verify `AsyncWriterPool` restarts them and processing resumes.
    *   Kill `EventCorrelator`: verify how `AsyncWriter`s handle its unavailability (e.g., retry, buffer, or drop and log).
    *   Simulate `DataAccess` write failures: verify `AsyncWriter` error handling.

## 10. Conclusion

ElixirScope's Asynchronous Event Processing Pipeline is a vital system for bridging high-speed event capture with the requirements of comprehensive event correlation and storage. Its design using a pool of `AsyncWriter` workers consuming from `RingBuffer`(s) and interacting with a central `EventCorrelator` and `DataAccess` layer provides the necessary decoupling and parallelism. The successful implementation and tuning of this pipeline are key to achieving ElixirScope's goals of total recall and providing rich, correlated data for the "Execution Cinema" experience. Continued focus on the interactions between these components, robust error handling, and performance optimization will be crucial.