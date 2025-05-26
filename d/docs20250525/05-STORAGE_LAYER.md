Okay, we've detailed the AI-driven instrumentation planning, the AST transformation engine that enacts that plan, the high-performance event capture pipeline (RingBuffer, Ingestor, AsyncWriter), and the event correlation engine.

The next highly relevant technical topic to dive into is the **Storage Layer**, specifically focusing on `ElixirScope.Storage.DataAccess` and how it supports the needs of the system, especially for "hot" data access, indexing, and eventual querying for the "Execution Cinema." This component is where all the captured and correlated data ultimately resides for active use.

---

**ElixirScope Technical Document: Hot Storage and Data Access Layer**

**Document Version:** 1.5
**Date:** 2024-05-24
**Authors:** ElixirScope Team (AI Assisted)

**Abstract:**

This document provides a detailed technical analysis of ElixirScope's "hot" storage and data access layer, primarily implemented by the `ElixirScope.Storage.DataAccess` module. This layer is responsible for the immediate and high-performance storage of processed and correlated trace events, utilizing ETS (Erlang Term Storage) for speed and efficient in-memory access. It details the ETS table structures, indexing strategies, data lifecycle management (including pruning), and the API for storing and retrieving event data. This layer is critical for providing fast access to recent execution history, which is essential for near real-time analysis and the initial phases of the "Execution Cinema" experience.

**Table of Contents:**

1.  Introduction and Purpose
    1.1. Role within ElixirScope's Data Lifecycle
    1.2. Design Goals: Fast Writes, Efficient Queries, Bounded Memory
2.  Architectural Placement (Diagram Reference: `DIAGS.md#1, #3, #4`)
    2.1. Interaction with `AsyncWriter` / `EventCorrelator` (Writers)
    2.2. Interaction with `QueryCoordinator` (Readers - Future)
3.  ETS Table Design and Schema (`ElixirScope.Storage.DataAccess`)
    3.1. Overview of ETS Usage
    3.2. Primary Event Table (`<name>_events`)
        3.2.1. Key: `event_id`
        3.2.2. Value: Full `ElixirScope.Events.t()` struct (or `CorrelatedEvent`)
        3.2.3. ETS Options: `:set`, `:public`, `:read_concurrency`, `:write_concurrency`
    3.3. Index Tables
        3.3.1. Temporal Index (`<name>_temporal`): `{timestamp, event_id}`
        3.3.2. Process Index (`<name>_process`): `{pid, event_id}`
        3.3.3. Function Index (`<name>_function`): `{{module, function}, event_id}`
        3.3.4. Correlation Index (`<name>_correlation`): `{correlation_id, event_id}`
        3.3.5. ETS Options for Index Tables: `:bag`, `:public`, `:read_concurrency`, `:write_concurrency`
    3.4. Statistics Table (`<name>_stats`)
        3.4.1. Storing metadata: event counts, timestamps, instrumentation plan
        3.4.2. ETS Options: `:set`, `:public`
    3.5. Data Types and Serialization Considerations within ETS
4.  Data Write Operations
    4.1. `store_event/2` (Single Event)
        4.1.1. Insertion into Primary Table
        4.1.2. Concurrent Updates to All Relevant Index Tables
        4.1.3. Statistics Updates
    4.2. `store_events/2` (Batch Events)
        4.2.1. Optimization for Bulk Inserts into ETS
        4.2.2. Atomic Nature of Batch Inserts (Considerations)
    4.3. Performance Characteristics of Writes
5.  Data Query Operations
    5.1. `get_event/2` (By `event_id`)
    5.2. Indexed Queries:
        5.2.1. `query_by_time_range/4` (Utilizing Temporal Index)
        5.2.2. `query_by_process/3` (Utilizing Process Index)
        5.2.3. `query_by_function/4` (Utilizing Function Index)
        5.2.4. `query_by_correlation/3` (Utilizing Correlation Index)
    5.3. Query Mechanics: Index Lookup followed by Primary Table Fetch
    5.4. Performance Characteristics of Queries
    5.5. (Future) Support for More Complex Queries via `QueryCoordinator`
6.  Data Lifecycle Management: Pruning and Hot Storage Limits
    6.1. Configuration: `storage.hot.max_events`, `storage.hot.max_age_seconds`, `storage.hot.prune_interval`
    6.2. `cleanup_old_events/2` Mechanism
        6.2.1. Identifying Events to Prune (Based on Timestamp)
        6.2.2. Removing Events from Primary Table and All Index Tables
        6.2.3. Updating Statistics Table
    6.3. Triggering Pruning (e.g., Periodic Timer, On Write if Max Events Exceeded)
    6.4. Impact of Pruning on Long-Lived Correlations and Analysis
7.  Instrumentation Plan Storage
    7.1. `get_instrumentation_plan/0`
    7.2. `store_instrumentation_plan/1`
    7.3. Use of the `stats_table` for Persisting the Plan
8.  Concurrency, Consistency, and Reliability
    8.1. ETS Concurrency Features (`read_concurrency`, `write_concurrency`)
    8.2. Atomicity of Operations (Single vs. Batch)
    8.3. Data Integrity within ETS
    8.4. Behavior on Node/Application Restart (ETS Data is In-Memory)
9.  Testing Strategies for `DataAccess`
10. Future Transition to Warm/Cold Storage
11. Conclusion

---

## 1. Introduction and Purpose

### 1.1. Role within ElixirScope's Data Lifecycle

The `ElixirScope.Storage.DataAccess` module serves as the primary interface for storing and retrieving "hot" (recent and frequently accessed) trace event data. After events are captured by the `Ingestor`, processed by the `AsyncWriter`s, and enriched by the `EventCorrelator`, `DataAccess` is responsible for durably (within the lifespan of the BEAM node) storing these events in a manner that allows for efficient querying. This hot storage layer is crucial for providing rapid feedback for near real-time analysis, basic timeline views, and immediate debugging insights before data is potentially offloaded to slower, more persistent "warm" or "cold" storage tiers.

### 1.2. Design Goals

*   **Fast Writes:** Must keep pace with the output of the `AsyncWriterPool`, supporting high-throughput batch writes.
*   **Efficient Queries:** Indexed access patterns must allow for quick retrieval of events based on common query dimensions (time, process, function, correlation).
*   **Bounded Memory:** Implement mechanisms to limit the memory footprint of hot storage, preventing the ElixirScope system from exhausting application memory.
*   **Concurrency:** Safely handle concurrent writes from multiple `AsyncWriter`s and concurrent reads from future query engines or UI components.

## 2. Architectural Placement

As seen in `DIAGS.md#1. Overall System Architecture` and `DIAGS.md#3. Event Capture Pipeline`, `DataAccess` sits after the `AsyncWriterPool` and `EventCorrelator` in the processing chain.

### 2.1. Interaction with `AsyncWriter` / `EventCorrelator` (Writers)

`AsyncWriter` workers, after receiving a batch of events that have been processed by the `EventCorrelator` (i.e., they are now `CorrelatedEvent`s or enriched `Event`s), will call `DataAccess.store_events/2` to persist the batch. This is the primary write path into hot storage.

### 2.2. Interaction with `QueryCoordinator` (Readers - Future)

The (future) `ElixirScope.Storage.QueryCoordinator` will be the primary client for reading data from `DataAccess`. It will use the various query functions provided by `DataAccess` to fetch events needed to satisfy user or AI analysis requests. For Phase 1, direct calls to `DataAccess` query functions (e.g., from IEx helpers) are possible.

## 3. ETS Table Design and Schema

`ElixirScope.Storage.DataAccess` uses a set of ETS tables to store events and their associated indexes, as detailed in `DIAGS.md#4. Event Storage and Indexing Structure`. All tables created by a `DataAccess` instance share a common base name (e.g., `elixir_scope_default`) for organization.

### 3.1. Overview of ETS Usage

ETS is chosen for hot storage due to its high performance for in-memory operations and its built-in support for concurrent access. The strategy involves a primary table for the full event data and multiple secondary tables acting as indexes.

### 3.2. Primary Event Table (`<name>_events`)

*   **Purpose:** Stores the complete event objects.
*   **Key:** `event_id` (unique identifier for the event).
*   **Value:** The `ElixirScope.Events.t()` struct (or the enriched `CorrelatedEvent` struct).
*   **ETS Options:**
    *   `:set`: Ensures unique `event_id`s.
    *   `:public`: Allows access from any process (e.g., `AsyncWriter`s, `QueryCoordinator`).
    *   `{:read_concurrency, true}`: Optimizes for concurrent reads.
    *   `{:write_concurrency, true}`: Optimizes for concurrent writes from multiple `AsyncWriter`s.

### 3.3. Index Tables

These tables store pointers (event IDs) to the events in the primary table, allowing for faster lookups on common query fields. They generally use `:bag` type because multiple events can share the same index key (e.g., many events for the same PID).

*   **3.3.1. Temporal Index (`<name>_temporal`)**
    *   **Key-Value:** `{timestamp :: integer(), event_id :: ElixirScope.Events.event_id()}`
    *   **Purpose:** Efficiently query events within a specific time range.
*   **3.3.2. Process Index (`<name>_process`)**
    *   **Key-Value:** `{pid :: pid(), event_id :: ElixirScope.Events.event_id()}`
    *   **Purpose:** Quickly find all events related to a specific process.
*   **3.3.3. Function Index (`<name>_function`)**
    *   **Key-Value:** `{{module :: module(), function :: atom()}, event_id :: ElixirScope.Events.event_id()}`
    *   **Purpose:** Find all events originating from a particular function (typically `FunctionEntry` / `FunctionExit` events).
*   **3.3.4. Correlation Index (`<name>_correlation`)**
    *   **Key-Value:** `{correlation_id :: term(), event_id :: ElixirScope.Events.event_id()}`
    *   **Purpose:** Retrieve all events belonging to the same logical trace or operation.
*   **ETS Options for Index Tables (Common):**
    *   `:bag`: Allows multiple `event_id`s for the same key.
    *   `:public`, `{:read_concurrency, true}`, `{:write_concurrency, true}`: Same reasons as the primary table.

### 3.4. Statistics Table (`<name>_stats`)

*   **Purpose:** Stores operational metadata and global statistics about the data store.
*   **Key-Value Examples:**
    *   `{:total_events, count :: non_neg_integer()}`
    *   `{:max_events, limit :: non_neg_integer()}`
    *   `{:oldest_timestamp, timestamp :: integer() | nil}`
    *   `{:newest_timestamp, timestamp :: integer() | nil}`
    *   `{:last_cleanup, timestamp :: integer()}`
    *   `{:instrumentation_plan, plan :: map()}` (as used by `AI.Orchestrator`)
*   **ETS Options:** `:set`, `:public`. Concurrency options might be less critical here as updates are less frequent or use `:ets.update_counter/3`.

### 3.5. Data Types and Serialization Considerations within ETS

*   Elixir terms (structs, lists, maps, etc.) are stored directly in ETS.
*   Large terms (e.g., captured function arguments, state) are already truncated by `ElixirScope.Capture.Ingestor` using `Utils.truncate_data/2` before reaching `DataAccess` to manage memory within ETS.
*   No further serialization is typically done by `DataAccess` before ETS insertion.

## 4. Data Write Operations

### 4.1. `store_event/2` (Single Event)

1.  The `event.id` is used as the key for the primary table. The event struct is the value.
2.  An entry `{event.timestamp, event.id}` is inserted into the temporal index.
3.  If `extract_pid(event)` yields a PID, `{pid, event.id}` is inserted into the process index.
4.  If `extract_function_info(event)` yields `{module, function}`, `{{module, function}, event.id}` is inserted into the function index.
5.  If `extract_correlation_id(event)` yields a `correlation_id`, `{correlation_id, event.id}` is inserted into the correlation index.
6.  Relevant counters in the `stats_table` (e.g., `:total_events`, `:newest_timestamp`) are updated.

### 4.2. `store_events/2` (Batch Events)

This is the preferred method for `AsyncWriter`s.
1.  It iterates through the list of events.
2.  For each event, it prepares the key-value pairs for the primary table and all applicable index tables.
3.  It then performs batch inserts into each ETS table using `:ets.insert(table_tid, list_of_tuples)`. This is generally more efficient than many individual inserts.
4.  Updates statistics in `stats_table` in a batch-aware manner (e.g., update `:total_events` by `length(events)`, set `:newest_timestamp` to the max timestamp in the batch).

### 4.3. Performance Characteristics of Writes

*   ETS writes are very fast for in-memory operations.
*   Using `:write_concurrency` helps when multiple `AsyncWriter` workers are writing simultaneously.
*   The main overhead comes from updating multiple index tables for each event. Batching helps amortize the overhead of ETS calls.
*   The performance here must be sufficient to not cause the `AsyncWriterPool` to become a bottleneck for the `RingBuffer`s.

## 5. Data Query Operations

Queries generally involve a two-step process: first querying an index table to get a list of `event_id`s, and then looking up these `event_id`s in the primary event table to retrieve the full event structs.

### 5.1. `get_event/2` (By `event_id`)

A direct `:ets.lookup(storage.primary_table, event_id)` operation. Very fast.

### 5.2. Indexed Queries

*   **5.2.1. `query_by_time_range/4`:**
    *   The current implementation uses `:ets.tab2list(storage.temporal_index)` and then filters/sorts in Elixir. **This is inefficient for large tables.**
    *   **Improvement Needed:** Should use `:ets.select/2` with match specifications on the temporal index table to directly retrieve `event_id`s within the timestamp range. Example: `ms = :ets.fun2ms(fn {{ts, id}} when ts >= StartTime, ts =< EndTime -> id end)`. Sorting may still be needed post-select if `:ordered_set` is not used for the temporal index (which would keep it sorted by timestamp).
*   **5.2.2. `query_by_process/3`:**
    *   Uses `:ets.lookup(storage.process_index, pid)` to get all `event_id`s for that PID.
    *   Then fetches events from the primary table. Efficient due to direct key lookup on the index.
*   **5.2.3. `query_by_function/4`:**
    *   Uses `:ets.lookup(storage.function_index, {module, function})`. Efficient.
*   **5.2.4. `query_by_correlation/3`:**
    *   Uses `:ets.lookup(storage.correlation_index, correlation_id)`. Efficient.

### 5.3. Query Mechanics

The common pattern:
1.  `event_ids = :ets.lookup(index_table, index_key) |> Enum.map(&elem(&1, 1)) |> Enum.take(limit)`
2.  `events = Enum.map(event_ids, fn eid -> elem(:ets.lookup(primary_table, eid), 0) |> elem(1) end)`

### 5.4. Performance Characteristics of Queries

*   Direct `event_id` lookups and index lookups by exact key are very fast.
*   Range queries (like time range) depend heavily on efficient ETS selection or traversal. The current `tab2list` approach for time range is a performance concern for large datasets.
*   Fetching full events after getting IDs involves N lookups in the primary table, which is acceptable if N is not excessively large (controlled by `limit`).

### 5.5. (Future) Support for More Complex Queries via `QueryCoordinator`

The `QueryCoordinator` will build upon these basic `DataAccess` queries to:
*   Combine results from multiple indexes (e.g., "events for PID X within time range Y").
*   Traverse correlation links to build execution graphs (DAGs).
*   Aggregate data.
*   Handle queries spanning hot and warm/cold storage.

## 6. Data Lifecycle Management: Pruning and Hot Storage Limits

To prevent unbounded memory growth, `DataAccess` implements pruning.

### 6.1. Configuration

From `ElixirScope.Config` (`storage.hot.*`):
*   `max_events`: A target maximum number of events to keep in hot storage.
*   `max_age_seconds`: Events older than this are candidates for pruning.
*   `prune_interval`: How often the pruning process should attempt to run.

### 6.2. `cleanup_old_events/2` Mechanism

1.  Takes a `cutoff_timestamp`.
2.  **Identifies Events to Prune:** Iterates the temporal index (currently inefficiently via `get_events_before_timestamp` which uses `tab2list`) to find `event_id`s of events older than `cutoff_timestamp`.
3.  **Removes Events:** For each identified `event_id`:
    *   Retrieves the full event from the primary table (to get details like `pid`, `correlation_id`, etc., needed for index cleanup).
    *   Deletes the event from the primary table (`:ets.delete/2`).
    *   Deletes the corresponding entries from *all* index tables (`:ets.delete_object/2` to remove specific key-value pairs from `:bag` tables).
4.  **Updates Statistics:** Decrements `:total_events` counter and updates `:last_cleanup` timestamp in `stats_table`.

### 6.3. Triggering Pruning

Pruning isn't automatically triggered by `DataAccess` itself in the current code. It would typically be invoked periodically by a separate process (e.g., managed by `PipelineManager` or a dedicated maintenance GenServer) based on `prune_interval` or if `get_stats/1` shows `total_events` exceeding `max_events`.

### 6.4. Impact of Pruning on Long-Lived Correlations and Analysis

When events are pruned from hot storage:
*   Correlation chains that include these pruned events will become incomplete.
*   Time-travel debugging into periods covered by pruned data will not be possible from hot storage.
This underscores the need for a warm/cold storage strategy where pruned events are archived rather than just deleted, allowing for later, slower analysis if needed.

## 7. Instrumentation Plan Storage

`DataAccess` is also used by `ElixirScope.AI.Orchestrator` to persist and retrieve the active instrumentation plan.
*   `store_instrumentation_plan(plan)`: Inserts `{:instrumentation_plan, plan}` into `stats_table`.
*   `get_instrumentation_plan()`: Looks up `:instrumentation_plan` in `stats_table`.
This allows the plan to be available across application restarts (if `stats_table` were persisted, though it's ETS and thus in-memory) or to different parts of the ElixirScope system (like the `MixTask`). Given `stats_table` is ETS, the plan is effectively session-specific unless explicitly reloaded/regenerated.

## 8. Concurrency, Consistency, and Reliability

### 8.1. ETS Concurrency Features

`:read_concurrency` and `:write_concurrency` allow ETS to internally optimize parallel access, reducing contention. However, they don't make all sequences of operations atomic.

### 8.2. Atomicity of Operations

*   **Single ETS operations** (e.g., `:ets.insert/2`, `:ets.lookup/2`, `:ets.delete/2`) are atomic.
*   **`DataAccess.store_event/2` is NOT atomic as a whole:** It involves multiple ETS inserts (primary + indexes). A crash midway could leave indexes inconsistent with the primary table. For hot, high-volume tracing data, this might be an accepted risk, prioritizing speed over transactional integrity for every single event.
*   **`DataAccess.store_events/2` (batch):** Batch ETS inserts (`:ets.insert(tid, list_of_tuples)`) are more efficient but their atomicity regarding *all* tuples in the list needs careful consideration (ETS typically processes them one by one, but the call itself is a single Erlang operation). If one tuple fails, the state of others might be inconsistent. The current code wraps the batch insert in a `try/catch`, suggesting it treats the batch as a whole but doesn't offer rollback.

### 8.3. Data Integrity within ETS

If the application crashes, all ETS data (being in-memory) is lost. ElixirScope's hot storage is ephemeral. Integrity concerns within a session relate to ensuring index updates are not missed.

### 8.4. Behavior on Node/Application Restart

All data in ETS tables managed by `DataAccess` is lost upon application/node termination. A warm storage layer (disk-based) is necessary for persistence across restarts.

## 9. Testing Strategies for `DataAccess`

(Referencing `elixir_scope/storage/data_access_test.exs` if it existed)
*   **Unit Tests:**
    *   Verify `store_event/2` correctly populates primary table and ALL index tables.
    *   Verify `store_events/2` (batch) works correctly.
    *   Test each `query_by_X/Y` function returns correct results based on known data.
    *   Test `get_stats/1`.
    *   Test `cleanup_old_events/2`: ensure correct events are removed from all tables and stats are updated.
*   **Concurrency Tests:** Multiple processes writing and reading from `DataAccess` concurrently. Verify data integrity and absence of race conditions.
*   **Performance Tests:**
    *   Benchmark write throughput (single and batch).
    *   Benchmark query latency for different query types and data sizes.
    *   Benchmark pruning performance.
*   **Edge Case Tests:** Empty event lists, querying non-existent keys, pruning an empty table, etc.

## 10. Future Transition to Warm/Cold Storage

The current `DataAccess` using ETS is the "hot" tier. For the full vision:
*   Pruned events from `DataAccess` would be passed to a "Warm Storage Manager."
*   This manager would write them to a disk-based store (e.g., RocksDB, Mnesia disk tables, custom file format).
*   `QueryCoordinator` would need to be able to query across both hot (ETS) and warm (disk) tiers, merging results.
*   Eventually, a "Cold Storage Manager" might move data from warm to even cheaper, slower archival storage (e.g., S3).

## 11. Conclusion

`ElixirScope.Storage.DataAccess` provides a crucial high-performance in-memory storage solution for recent trace events using ETS. Its multi-index design allows for flexible and relatively fast querying of hot data. While the current implementation of `query_by_time_range` and `cleanup_old_events` needs optimization (moving away from `tab2list`), the overall structure is sound for its purpose as a hot store. The lack of transactional integrity across multiple ETS table updates for a single event is a trade-off for write performance. Its in-memory nature means data is ephemeral, highlighting the importance of planned warm/cold storage tiers for long-term persistence and analysis. This layer successfully serves the immediate needs of the asynchronous processing pipeline and lays the groundwork for future querying by the "Execution Cinema" UI.