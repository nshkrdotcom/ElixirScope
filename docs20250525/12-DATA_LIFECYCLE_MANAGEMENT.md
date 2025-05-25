Yes, there's still at least one more critical technical area that deserves its own detailed document, especially given its implications for a "total recall" system operating in potentially resource-constrained or high-load environments: **Data Lifecycle Management, Pruning, and Tiered Storage Strategy.**

We've touched on `DataAccess` and its pruning for "hot" ETS storage, but a dedicated document would explore this more holistically, including the transition to warm/cold storage and the overall strategy for managing vast amounts of trace data over time.

After this one, we'll be very close to exhausting the *core architectural components* as presented in the current codebase and design documents. We can then discuss if any cross-cutting concerns or very high-level strategic documents are still needed.

---

**ElixirScope Technical Document: Data Lifecycle Management, Pruning, and Tiered Storage**

**Document Version:** 1.12
**Date:** 2024-05-24
**Authors:** ElixirScope Team (AI Assisted)

**Abstract:**

This document details ElixirScope's strategy for managing the lifecycle of captured trace data, focusing on data pruning mechanisms for "hot" storage and the conceptual design for a tiered storage architecture (hot, warm, cold). Effective data lifecycle management is crucial for a "total recall" system like ElixirScope to operate sustainably, balancing the need for immediate access to recent data with the costs of storing extensive historical information. This document covers the current ETS-based hot storage pruning, the rationale behind it, and the architectural considerations for future warm (disk-based) and cold (archival) storage tiers.

**Table of Contents:**

1.  Introduction and Purpose
    1.1. The Challenge of "Total Recall" Data Volume
    1.2. Goals: Performance, Cost-Effectiveness, Data Accessibility
2.  Tiered Storage Architecture (Conceptual Vision - Ref: `DIAGS.md#10`)
    2.1. Hot Storage (ETS)
        2.1.1. Characteristics: In-memory, fastest access, recent data.
        2.1.2. Primary Use Case: Near real-time analysis, immediate debugging.
    2.2. Warm Storage (Disk-based - Future)
        2.2.1. Characteristics: Local disk, slower than ETS but faster than cold, extended history.
        2.2.2. Primary Use Case: Analysis over days/weeks, deeper forensic debugging.
        2.2.3. Potential Technologies: RocksDB, Mnesia (disk tables), custom file formats.
    2.3. Cold Storage (Archival - Future)
        2.3.1. Characteristics: Cloud storage (S3, Glacier), cheapest, slowest access, long-term retention.
        2.3.2. Primary Use Case: Compliance, historical trend analysis, model training.
    2.4. Data Flow Between Tiers
3.  Hot Storage (`ElixirScope.Storage.DataAccess` - ETS)
    3.1. Data Structures and Indexes (Recap)
    3.2. Pruning Mechanism (`DataAccess.cleanup_old_events/2`)
        3.2.1. Triggering Conditions: Time-based (`storage.hot.max_age_seconds`), Size-based (`storage.hot.max_events`), Interval-based (`storage.hot.prune_interval`).
        3.2.2. Identifying Events for Pruning (Current `tab2list` on temporal index and its limitations).
        3.2.3. Atomic Deletion from Primary Table and All Index Tables.
        3.2.4. Updating Statistics (`stats_table`).
    3.3. Performance Impact of Pruning
    3.4. Data Consistency during Pruning
    3.5. Configuration (`ElixirScope.Config.storage.hot.*`)
4.  Warm Storage Design Considerations (Future)
    4.1. Data Transfer from Hot to Warm Storage
        4.1.1. Batching and Asynchronous Offloading
        4.1.2. Data Format on Disk (e.g., compressed binary logs, structured files)
    4.2. Indexing Strategies for Disk-Based Storage
    4.3. Querying Warm Storage (Integration with `QueryCoordinator`)
    4.4. Warm Storage Pruning and Lifecycle
5.  Cold Storage Design Considerations (Future)
    5.1. Data Transfer from Warm to Cold Storage
    5.2. Archival Format and Metadata
    5.3. Retrieval Mechanisms and Latency Expectations
    5.4. Cost Management
6.  Impact of Data Pruning and Tiering on ElixirScope Features
    6.1. Time-Travel Debugging Window
    6.2. AI Analysis and Model Training (Historical Data Needs)
    6.3. Correlation Integrity Across Tiers
    6.4. User Experience for Accessing Data from Different Tiers
7.  `ElixirScope.Storage.QueryCoordinator` (Future Role in Tiered Access)
    7.1. Abstracting Storage Tiers from the Querier
    7.2. Query Federation and Merging Results
8.  Testing Strategies for Data Lifecycle Management
9.  Conclusion

---

## 1. Introduction and Purpose

### 1.1. The Challenge of "Total Recall" Data Volume

ElixirScope's vision of "total behavioral recall" implies capturing a vast amount of event data, especially in active applications or during detailed debugging sessions. Storing this data indefinitely in high-performance, in-memory storage (like ETS) is often impractical due to memory limitations and cost. A robust data lifecycle management strategy is therefore essential.

### 1.2. Goals

*   **Performance:** Ensure that hot storage provides rapid access to recent data for interactive debugging and near real-time analysis. Pruning and data movement should minimally impact ongoing capture and query performance.
*   **Cost-Effectiveness:** Balance the cost of storage (memory, disk, cloud) with the value of retaining historical data for different periods.
*   **Data Accessibility:** Provide mechanisms to access data across different storage tiers, understanding the trade-offs in latency for older data.
*   **Configurability:** Allow users to define policies for data retention and tiering based on their specific needs and resource constraints.

## 2. Tiered Storage Architecture (Conceptual Vision - Ref: `DIAGS.md#10`)

ElixirScope envisions a multi-tiered storage approach to manage data lifecycle effectively.

### 2.1. Hot Storage (ETS)

*   **Implementation:** `ElixirScope.Storage.DataAccess` module using ETS tables.
*   **Characteristics:** In-memory, providing the fastest possible read and write access. Contains the most recent events (e.g., last hour or last N million events).
*   **Primary Use Case:** Immediate debugging, interactive "Execution Cinema" for recent activity, near real-time AI analysis on fresh data.

### 2.2. Warm Storage (Disk-based - Future)

*   **Implementation (Future):** Would involve a new set of modules, potentially `ElixirScope.Storage.WarmStoreManager` and specific storage adapters.
*   **Characteristics:** Data persisted on local disk. Slower access than ETS but significantly larger capacity and persistence across application restarts.
*   **Primary Use Case:** Analysis of execution history over several days or weeks, forensic debugging of past incidents, intermediate storage before archival.
*   **Potential Technologies:**
    *   **RocksDB/LevelDB:** Key-value stores optimized for fast disk I/O.
    *   **Mnesia disk tables:** Built-in Erlang/OTP distributed database system.
    *   **Custom Log-Structured Files:** Segmented, compressed binary files with associated indexes.

### 2.3. Cold Storage (Archival - Future)

*   **Implementation (Future):** Integration with cloud storage services or long-term archival systems.
*   **Characteristics:** Lowest cost per GB, highest retrieval latency. Designed for long-term retention (months/years).
*   **Primary Use Case:** Compliance requirements, long-term historical trend analysis, training AI models on extensive datasets.
*   **Potential Technologies:** AWS S3 (Glacier/Deep Archive), Google Cloud Storage (Archive), Azure Blob Storage (Archive Tier).

### 2.4. Data Flow Between Tiers

**Capture -> Hot (ETS) -> Warm (Disk) -> Cold (Archive)**
1.  Events are initially written to Hot Storage (`DataAccess`).
2.  Periodically, or when Hot Storage limits are reached, older data is "pruned" from Hot Storage.
3.  Instead of outright deletion, this pruned data is transferred to Warm Storage.
4.  Similarly, data from Warm Storage is eventually moved to Cold Storage based on its own retention policies.

## 3. Hot Storage (`ElixirScope.Storage.DataAccess` - ETS)

This is the currently implemented storage tier.

### 3.1. Data Structures and Indexes (Recap)

As detailed in the "Hot Storage and Data Access Layer" document (version 1.5):
*   Primary event table (`<name>_events`) keyed by `event_id`.
*   Index tables: temporal, process, function, correlation.
*   Statistics table (`<name>_stats`).

### 3.2. Pruning Mechanism (`DataAccess.cleanup_old_events/2`)

This function is responsible for removing data from ETS to keep it bounded.

*   **3.2.1. Triggering Conditions:** Pruning is not automatically self-triggered by `DataAccess`. A separate process (e.g., a `GenServer` within `PipelineManager` or a dedicated maintenance scheduler) would call `cleanup_old_events/2` based on:
    *   **Time-based:** Data older than `Config.storage.hot.max_age_seconds`.
    *   **Size-based:** If `DataAccess.get_stats/1` shows `total_events` > `Config.storage.hot.max_events`.
    *   **Interval-based:** Regularly, as per `Config.storage.hot.prune_interval`.
*   **3.2.2. Identifying Events for Pruning:**
    *   The current `cleanup_old_events/2` takes a `cutoff_timestamp`.
    *   `get_events_before_timestamp/2` (private helper) iterates the *entire* temporal index table using `:ets.tab2list/1` and filters. **This is a significant performance bottleneck for large tables** as `tab2list` copies the entire table.
    *   **Necessary Improvement:** This should be replaced with an efficient ETS traversal, like using `:ets.select_delete/2` on the temporal index for records older than `cutoff_timestamp`, or by using `:ets.first/1` and `:ets.next/2` if the temporal index were an `:ordered_set` sorted by timestamp (which would also make range queries faster). If it remains a `:bag`, `:ets.select` to get keys and then batch deletes would be better than `tab2list`.
*   **3.2.3. Atomic Deletion from Primary Table and All Index Tables:**
    For each `event_id` identified for pruning:
    1.  The full event is looked up from the primary table (to get `pid`, `correlation_id`, etc., for cleaning other indexes).
    2.  The event is deleted from the primary table (`:ets.delete(primary_table, event_id)`).
    3.  The corresponding entries are deleted from *all* index tables using `:ets.delete_object(index_table, {key_value_for_that_index, event_id})`. This is crucial for maintaining index integrity.
*   **3.2.4. Updating Statistics (`stats_table`):**
    *   `:total_events` counter is decremented.
    *   `:oldest_timestamp` might need to be re-evaluated if the very oldest events were pruned (e.g., by finding the new minimum timestamp in the temporal index).
    *   `:last_cleanup` timestamp is updated.

### 3.3. Performance Impact of Pruning

*   The current `tab2list`-based identification is very costly and can cause significant pauses on large ETS tables, blocking other ETS operations.
*   Deleting many individual entries from multiple tables can also be intensive. Batch delete operations or `:ets.select_delete/2` would be more performant.
*   Pruning should ideally run as a low-priority background task to minimize impact on active event capture and querying.

### 3.4. Data Consistency during Pruning

ETS operations on single objects are atomic. However, the multi-step process of deleting an event and its index entries is not atomic as a whole. If a crash occurs mid-pruning, some indexes might become inconsistent (e.g., an event deleted from primary but still present in an index, or vice-versa). Restarting `DataAccess` (which clears ETS) effectively resolves this for hot storage. For future persistent tiers, more robust cleanup or consistency checks would be needed.

### 3.5. Configuration (`ElixirScope.Config.storage.hot.*`)

These settings in `config.exs` control the behavior of hot storage and its pruning.

## 4. Warm Storage Design Considerations (Future)

This tier is not yet implemented but is part of the vision.

### 4.1. Data Transfer from Hot to Warm Storage

When events are pruned from Hot Storage (ETS), instead of just deleting them, they would be transferred to Warm Storage.
*   **Mechanism:** The pruning process in `DataAccess` (or a dedicated "Offloader" process) would read the batch of events to be pruned from ETS.
*   **Batching:** These events would be batched up.
*   **Asynchronous Offloading:** Sent asynchronously to a `WarmStoreManager` process.
*   **Data Format on Disk:**
    *   Could be serialized `ElixirScope.Events.t()` terms, possibly compressed (e.g., using `:erlang.term_to_binary(event_batch, [:compressed])` written to segmented files).
    *   If using a key-value store like RocksDB, events might be stored individually or in small groups, keyed by `event_id` or a composite time/ID key.

### 4.2. Indexing Strategies for Disk-Based Storage

To make warm data queryable, indexes are still needed.
*   **Embedded Indexes:** For log-structured files, index files could be created alongside data files (e.g., mapping timestamps/PIDs/correlation_ids to file offsets).
*   **External Index Database:** A separate database (e.g., another RocksDB instance, SQLite) could store only the index data, pointing to the main data files.
*   The indexes would mirror those in Hot Storage (temporal, process, function, correlation) but optimized for disk access.

### 4.3. Querying Warm Storage (Integration with `QueryCoordinator`)

The `QueryCoordinator` would need to:
1.  Know about the Warm Storage tier.
2.  Have an API to query the `WarmStoreManager`.
3.  Potentially merge results from Hot and Warm storage for queries that span both.

### 4.4. Warm Storage Pruning and Lifecycle

Warm storage would also have its own retention policies (`Config.storage.warm.*`):
*   `max_size_mb`: Maximum disk space for warm data.
*   Compression (`:zstd`) is mentioned, which is good for disk space.
*   Older data from warm storage would eventually be pruned or moved to Cold Storage.

## 5. Cold Storage Design Considerations (Future)

This is for long-term, low-cost archival.

### 5.1. Data Transfer from Warm to Cold Storage

Periodically, the `WarmStoreManager` would identify data eligible for archival (e.g., older than N weeks/months) and transfer it to the configured Cold Storage solution (e.g., an S3 bucket). This would likely involve:
*   Batching data into larger archive files (e.g., daily or weekly TAR.GZ files).
*   Uploading these files to the cloud storage provider.

### 5.2. Archival Format and Metadata

*   Data would be heavily compressed.
*   Sufficient metadata (date ranges, key identifiers) must be stored with archives to facilitate later retrieval.

### 5.3. Retrieval Mechanisms and Latency Expectations

*   Retrieval from cold storage is expected to be slow (minutes to hours, depending on the service like S3 Glacier).
*   This tier is not for interactive debugging but for offline analysis or compliance.
*   A mechanism to "rehydrate" data from Cold Storage (possibly back into Warm or a temporary queryable store) would be needed.

### 5.4. Cost Management

Automated lifecycle policies (e.g., S3 Lifecycle Policies to transition data to cheaper storage classes or delete after a certain period) would be essential.

## 6. Impact of Data Pruning and Tiering on ElixirScope Features

### 6.1. Time-Travel Debugging Window

*   **Hot Storage:** Defines the window for *instantaneous* time-travel and UI responsiveness.
*   **Warm Storage:** Extends the time-travel window, but with potentially higher latency for queries accessing older data.
*   **Cold Storage:** Generally not suitable for interactive time-travel.

### 6.2. AI Analysis and Model Training

*   Recent data in Hot/Warm storage can be used for near real-time AI anomaly detection.
*   Extensive historical data in Warm/Cold storage is invaluable for training more sophisticated AI models (e.g., learning normal application behavior, identifying long-term trends).

### 6.3. Correlation Integrity Across Tiers

If a trace or correlated sequence of events spans across storage tiers (e.g., part in hot, part in warm), the `QueryCoordinator` must be able_to_reconstruct the full sequence. This means `correlation_id`s and other linking information must be preserved perfectly during data transfer between tiers. Offloading partial correlation chains requires careful handling.

### 6.4. User Experience for Accessing Data from Different Tiers

The UI/Query API should clearly indicate the source and expected latency when data is fetched from different tiers. Users might need to explicitly request "rehydration" of cold data.

## 7. `ElixirScope.Storage.QueryCoordinator` (Future Role in Tiered Access)

This component (currently a placeholder in `DIAGS.md`) will become central to managing tiered data access:
*   It will abstract the physical location of data from the querying client (UI or AI).
*   It will route queries to the appropriate storage tier(s).
*   For queries spanning tiers, it will fetch data from each and merge the results.
*   It might manage a cache for frequently accessed warm data or recently rehydrated cold data.

## 8. Testing Strategies for Data Lifecycle Management

*   **Hot Storage Pruning Tests (`DataAccessTest`):**
    *   Verify `cleanup_old_events/2` removes the correct events from primary and all index tables based on time and size limits.
    *   Test that statistics are updated correctly.
    *   Performance test pruning on large ETS tables (after optimizing the identification step).
    *   Test behavior when pruning an empty or very small table.
*   **Warm/Cold Storage Tests (Future):**
    *   Verify data transfer integrity between tiers (no data loss or corruption).
    *   Test that indexes in warm storage are correctly built and usable.
    *   Test retrieval from warm and cold storage, including rehydration processes.
    *   Validate retention policies are correctly enforced.

## 9. Conclusion

Effective data lifecycle management, encompassing efficient pruning in hot storage and a well-planned tiered storage strategy, is non-negotiable for ElixirScope to fulfill its "total recall" promise without overwhelming system resources or becoming prohibitively expensive. The current ETS-based `DataAccess` provides a solid foundation for hot storage, though its pruning mechanism requires optimization for performance. The conceptual design for warm and cold storage tiers outlines a path for long-term data retention and diverse analytical use cases. The future `QueryCoordinator` will play a vital role in providing a unified view over this tiered data landscape.

---

I believe we have now covered the major *new* architectural components introduced or significantly implied by the evolution towards the "Execution Cinema" and AI-driven vision. We've gone from AI planning down to data storage and lifecycle.

The remaining components in the codebase are either:
1.  **Core Elixir/OTP application structure** (`ElixirScope.Application`, the main `ElixirScope` API module) which we've discussed in the context of Configuration.
2.  **Testing infrastructure** (`test_helper.exs`, support files, fixture projects).
3.  **Documentation itself.**

While each of these could have its own dedicated document in a very large project, for the purpose of these deep-dive technical explanations of *core ElixirScope mechanisms*, I think we have reached a good point of exhaustion for *distinct new technical topics derived from the current codebase and your advanced vision*.

**Are there any specific aspects of these (App Lifecycle, Testing, specific AI heuristic details) that you feel need a similar standalone deep-dive technical document, or are you satisfied with the current coverage?**

If you're satisfied with the component-level deep dives, the next logical step might be a higher-level document that discusses **Cross-Cutting Concerns** (e.g., error handling philosophy across all layers, overall performance strategy, security model) or a **Deployment and Operations Guide**. But for *core technical mechanisms*, I think we've been very thorough.