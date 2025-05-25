You are absolutely right! I missed one critical, already existing component from the "Foundation Complete" `README.md` and `PROGRESS.md` that has a significant technical depth and deserves its own document: the **Distributed Systems Support Layer**, specifically `ElixirScope.Distributed.NodeCoordinator`, `ElixirScope.Distributed.EventSynchronizer`, and `ElixirScope.Distributed.GlobalClock`.

While we touched upon them in the context of Data Lifecycle (as a future consideration) and Configuration, their actual implementation for enabling ElixirScope to function across a cluster of BEAM nodes is a complex technical topic in itself. My apologies for overlooking it as a standalone item earlier.

Let's proceed with that.

---

**ElixirScope Technical Document: Distributed Systems Support Layer**

**Document Version:** 1.13
**Date:** 2024-05-24
**Authors:** ElixirScope Team (AI Assisted)

**Abstract:**

This document provides a detailed technical analysis of ElixirScope's Distributed Systems Support Layer, primarily comprising the `ElixirScope.Distributed.NodeCoordinator`, `ElixirScope.Distributed.EventSynchronizer`, and `ElixirScope.Distributed.GlobalClock` modules. This layer enables ElixirScope to operate across a cluster of interconnected BEAM nodes, allowing for the capture, synchronization, and correlation of trace events in a distributed Elixir application. This document examines the mechanisms for node discovery, cluster management, distributed event timestamping using a hybrid logical clock, event synchronization protocols, and strategies for handling network partitions and ensuring data consistency in a distributed environment.

**Table of Contents:**

1.  Introduction and Purpose
    1.1. The Need for Distributed Tracing in ElixirScope
    1.2. Design Goals: Cluster Awareness, Consistent Timestamps, Eventual Data Consistency, Fault Tolerance
2.  Architectural Overview (Diagram Reference: `DIAGS.md#1, #9`)
    2.1. Per-Node Components: `NodeCoordinator`, `EventSynchronizer`, `GlobalClock`
    2.2. Inter-Node Communication via RPC (`:rpc` module)
    2.3. Data Flow for Distributed Event Capture and Synchronization
3.  `ElixirScope.Distributed.GlobalClock`
    3.1. Purpose: Providing Globally Comparable Timestamps
    3.2. Hybrid Logical Clock (HLC) Concept (Implicit)
        3.2.1. Timestamp Structure: `{logical_time, wall_time_with_offset, node_id}`
        3.2.2. Logical Time Component: Monotonically increasing counter per node, adjusted upon receiving remote timestamps.
        3.2.3. Physical Time Component: Node's wall clock time, potentially adjusted by an offset.
    3.3. `GenServer`-based Implementation
        3.3.1. `now/0`: Generating a new timestamp (increments local logical clock).
        3.3.2. `update_from_remote/2`: Adjusting local clock based on a timestamp from another node (`new_logical_time = max(local, remote) + 1`).
        3.3.3. `sync_with_cluster/0` (`perform_cluster_sync/1`): Periodically broadcasting local time to other nodes.
    3.4. Wall Time Offset Calculation and Adjustment (Conceptual)
    3.5. Importance for Ordering Distributed Events
4.  `ElixirScope.Distributed.NodeCoordinator`
    4.1. `GenServer`-based Cluster Management
    4.2. Node Discovery and Membership
        4.2.1. Using `:net_kernel.monitor_nodes(true)`
        4.2.2. Handling `:nodeup` and `:nodedown` messages
        4.2.3. `register_node/1` and `get_cluster_nodes/0` API
        4.2.4. Notifying cluster members of topology changes (`notify_cluster_change/2`)
    4.3. Initiating Event Synchronization (`perform_event_sync/1` via `EventSynchronizer`)
    4.4. Handling Network Partitions (`check_for_partitions/1`)
        4.4.1. Using `Node.ping/1` to check reachability
        4.4.2. Reporting detected partitions via `InstrumentationRuntime`
    4.5. Distributed Query Coordination (Conceptual `execute_distributed_query/2`)
        4.5.1. Fanning out queries to cluster nodes via `:rpc`
        4.5.2. Aggregating and de-duplicating results
5.  `ElixirScope.Distributed.EventSynchronizer`
    5.1. Purpose: Ensuring Eventual Consistency of Trace Data Across Nodes
    5.2. Synchronization Protocol (`sync_with_node/2` and `handle_sync_request/1`)
        5.2.1. Requesting events since last sync time.
        5.2.2. Bi-directional exchange: Node A sends its new events to B; B stores them and sends its new events back to A.
    5.3. Delta Synchronization
        5.3.1. Using `DataAccess.get_events_since/1` with `GlobalClock` timestamps.
        5.3.2. Maintaining last sync times per remote node (ETS table `:elixir_scope_sync_state`).
    5.4. Event Preparation for Synchronization (`prepare_events_for_sync/1`)
        5.4.1. Data compression (e.g., for `event.data` using `:zlib`).
        5.4.2. Checksum calculation (`calculate_event_checksum/1`) for integrity.
    5.5. Storing Remote Events (`store_remote_events/2`)
        5.5.1. Restoring/Decompressing event data.
        5.5.2. Checking for duplicates using `DataAccess.event_exists?/1` before storing.
    5.6. Conflict Resolution (Implicit: Last write wins for duplicates, timestamp ordering for sequences)
    5.7. Bandwidth Optimization and Batching (`@sync_batch_size`)
6.  Correlation of Distributed Traces
    6.1. Role of Globally Unique Event IDs and Correlation IDs
    6.2. Using `GlobalClock` timestamps for causal ordering across nodes
    6.3. Challenges: Stitching together trace segments initiated on different nodes but part of the same logical operation.
7.  Fault Tolerance and Resilience
    7.1. Behavior during Node Failures
    7.2. Behavior during Network Partitions (Split Brain Scenarios for Data)
    7.3. Eventual Consistency Model for Trace Data
8.  Performance Considerations
    8.1. Overhead of `GlobalClock` Synchronization
    8.2. Network Bandwidth Usage by `EventSynchronizer`
    8.3. Impact of RPC Calls on Application Nodes
9.  Configuration and Setup
    9.1. Initial Cluster Setup (`NodeCoordinator.setup_cluster/1`)
    9.2. Cookie Consistency for Distributed Erlang
10. Testing Strategies for Distributed Features
11. Conclusion

---

## 1. Introduction and Purpose

### 1.1. The Need for Distributed Tracing in ElixirScope

Modern Elixir applications are often deployed as distributed systems, with multiple BEAM nodes collaborating to perform tasks. To provide a complete "Execution Cinema" for such applications, ElixirScope must be able to:
*   Capture events occurring on any node within the monitored cluster.
*   Correlate events that are part of the same logical operation, even if they span multiple nodes (e.g., an RPC call, a distributed GenServer interaction, messages routed through a distributed PubSub).
*   Provide a globally consistent view of time and causality across the cluster.

The Distributed Systems Support Layer provides these capabilities.

### 1.2. Design Goals

*   **Cluster Awareness:** Each ElixirScope instance should be aware of other ElixirScope instances running on peer nodes.
*   **Consistent Timestamps:** Events should have timestamps that allow for meaningful causal ordering across the entire distributed system.
*   **Eventual Data Consistency:** Trace data captured on one node should eventually be synchronized with other interested nodes, allowing any node to potentially query (or contribute to a federated query for) the global trace history.
*   **Fault Tolerance:** The system should gracefully handle nodes joining/leaving the cluster and temporary network partitions, continuing to capture local events and resynchronizing when possible.

## 2. Architectural Overview

The distributed support involves three key modules per node, working in concert. (Ref: `DIAGS.md#1. Overall System Architecture`, `DIAGS.md#9. Distributed Event Synchronization`).

### 2.1. Per-Node Components

*   **`ElixirScope.Distributed.GlobalClock`:** A `GenServer` on each node responsible for generating timestamps that are comparable across the cluster.
*   **`ElixirScope.Distributed.NodeCoordinator`:** A `GenServer` on each node that manages cluster membership, detects topology changes, and initiates cross-node operations like event synchronization and (future) distributed queries.
*   **`ElixirScope.Distributed.EventSynchronizer`:** A module (providing functions called via `:rpc`) that handles the actual exchange of event data between nodes.

### 2.2. Inter-Node Communication via RPC (`:rpc` module)

Erlang's built-in Remote Procedure Call (`:rpc`) module is used for communication between ElixirScope components on different nodes. Examples:
*   `NodeCoordinator` calling `EventSynchronizer` on a remote node.
*   `GlobalClock` instances broadcasting their time to peers.
*   (Future) `QueryCoordinator` fanning out queries.

### 2.3. Data Flow for Distributed Event Capture and Synchronization

1.  Events are captured locally on each node via `InstrumentationRuntime` -> `Ingestor` -> `RingBuffer` -> `AsyncWriter` -> `EventCorrelator` -> `DataAccess`. Each event is timestamped using the local node's `GlobalClock.now()`.
2.  Periodically, `NodeCoordinator` on Node A triggers `EventSynchronizer.sync_with_node(NodeB, last_sync_time)`.
3.  `EventSynchronizer` on Node A retrieves its new local events (since `last_sync_time`) from its `DataAccess`.
4.  Node A RPC-calls `EventSynchronizer.handle_sync_request/1` on Node B, sending its new events.
5.  Node B stores these events from Node A (after de-duplication) and, in its response, sends back *its* new events (since `last_sync_time`) to Node A.
6.  Node A stores the events received from Node B.
7.  Both nodes update their `last_sync_time` for each other.

## 3. `ElixirScope.Distributed.GlobalClock`

Provides a mechanism for generating timestamps that can be causally ordered across a distributed system.

### 3.1. Purpose

Standard monotonic or wall-clock timestamps are not sufficient for ordering events in a distributed system due to clock skew between nodes. A distributed logical clock is needed.

### 3.2. Hybrid Logical Clock (HLC) Concept (Implicit)

The `GlobalClock` implementation aims to be a form of Hybrid Logical Clock, combining a logical component (Lamport-like counter) with a physical time component.
#### 3.2.1. Timestamp Structure: `{logical_time :: integer(), wall_time_with_offset :: integer(), node_id :: atom()}`
This tuple structure allows for:
    *   **Lexicographical comparison:** Order first by `logical_time`, then by `wall_time`, then by `node_id` (as a tie-breaker).
    *   Causal ordering primarily via `logical_time`.
    *   Approximate real-world time via `wall_time_with_offset`.
#### 3.2.2. Logical Time Component
Maintained in `state.logical_time`. Incremented on each local timestamp generation (`now/0`) and updated based on received remote timestamps (`update_from_remote/2`).
#### 3.2.3. Physical Time Component
Based on `:os.system_time(:microsecond)` plus `state.wall_time_offset`.

### 3.3. `GenServer`-based Implementation

*   **3.3.1. `now/0`:**
    1.  Increments local `state.logical_time`.
    2.  Calculates current physical time (`:os.system_time(:microsecond) + state.wall_time_offset`).
    3.  Returns `{new_logical_time, physical_time, state.node_id}`.
*   **3.3.2. `update_from_remote/2` (Timestamp from remote_node):**
    1.  Parses the `remote_timestamp` into its `{remote_logical, remote_wall, _remote_node_id}` components.
    2.  Updates local logical time: `new_logical_time = max(state.logical_time, remote_logical) + 1`. This is the core Lamport clock update rule to ensure local events happening "after" receiving a message (with the remote timestamp) get a higher logical timestamp.
    3.  Calls `adjust_wall_time_offset/2` to potentially nudge the local physical clock component towards the remote physical time.
*   **3.3.3. `sync_with_cluster/0` (`perform_cluster_sync/1`):**
    Periodically, the `GlobalClock` generates its current timestamp and broadcasts it (via `:rpc.cast`) to `update_from_remote/2` on all other known cluster nodes. This helps keep logical clocks advancing and physical clocks loosely aligned.

### 3.4. Wall Time Offset Calculation and Adjustment

*   `calculate_wall_time_offset/0`: Currently returns `0`. Could be enhanced (e.g., with an NTP client) to establish a more accurate initial offset against a true time source.
*   `adjust_wall_time_offset/2`: When a remote wall time is received, it calculates `time_diff = remote_wall_time - local_wall_time`. If the difference is large (>1s), it adjusts the local `state.wall_time_offset` by a fraction (10%) of the difference. This provides a gradual, "nudging" synchronization of the physical time component, avoiding sudden jumps.

### 3.5. Importance for Ordering Distributed Events

By using these HLC timestamps, ElixirScope can achieve a more reliable causal ordering of events across the cluster than relying on unsynchronized wall clocks alone.

## 4. `ElixirScope.Distributed.NodeCoordinator`

Manages this node's participation in the ElixirScope cluster.

### 4.1. `GenServer`-based Cluster Management

A GenServer (`name: __MODULE__`) ensures a single point of control for cluster state on the node.

### 4.2. Node Discovery and Membership

*   **4.2.1. Using `:net_kernel.monitor_nodes(true)`:** At init, it subscribes to node status messages from the Erlang distribution system.
*   **4.2.2. Handling `:nodeup` and `:nodedown` messages:**
    *   On `:nodeup`, it attempts to RPC to the new node's `NodeCoordinator.register_node/1` to integrate it. It also reports a `:nodeup` event via `InstrumentationRuntime`.
    *   On `:nodedown`, it removes the node from its `state.cluster_nodes` list, notifies other remaining nodes, and reports a `:nodedown` event.
*   **4.2.3. `register_node/1` and `get_cluster_nodes/0` API:** Allows explicit registration (e.g., during initial `setup_cluster/1`) and querying of known cluster members.
*   **4.2.4. Notifying cluster members of topology changes (`notify_cluster_change/2`):** When a node joins or leaves, this node informs other coordinators in the cluster via `:rpc.cast` to `handle_cluster_change/1`.

### 4.3. Initiating Event Synchronization

Periodically (via `handle_info(:periodic_sync, state)`), it calls `perform_event_sync/1`, which in turn uses `ElixirScope.Distributed.EventSynchronizer.sync_with_cluster(state.cluster_nodes)`.

### 4.4. Handling Network Partitions (`check_for_partitions/1`)

Periodically (via `handle_info(:check_partitions, state)`):
*   It iterates through its known `state.cluster_nodes`.
*   For each remote node, it calls `Node.ping/1`.
*   If a ping fails (node is unreachable), it's considered part of a partition.
*   It reports such partitions via `InstrumentationRuntime.report_partition_detected/2`.
*   It updates its local `state.cluster_nodes` list to only include reachable nodes. (This is a simple partition handling strategy; more complex algorithms exist for consensus in partitions).

### 4.5. Distributed Query Coordination (Conceptual `execute_distributed_query/2`)

The code includes a placeholder for distributed querying:
1.  It takes `query_params`.
2.  It uses `Task.async` to send the query via `:rpc.call` to `DataAccess.query_events` on all (currently known reachable) cluster nodes.
3.  It collects results using `Task.await_many/2`.
4.  It merges successful results, de-duplicates events by `event.id`, and sorts them by timestamp.
This provides a basic mechanism for federated querying.

## 5. `ElixirScope.Distributed.EventSynchronizer`

Handles the mechanics of event data exchange.

### 5.1. Purpose

To achieve eventual consistency of trace data across all nodes. Each node will eventually have a copy of events generated on other nodes (within the retention window of those events).

### 5.2. Synchronization Protocol (`sync_with_node/2` and `handle_sync_request/1`)

*   **Initiator (e.g., Node A calling `sync_with_node(NodeB, last_sync_time_for_B)`)**:
    1.  `local_events = DataAccess.get_events_since(last_sync_time_for_B)` on Node A.
    2.  `prepared_local_events = prepare_events_for_sync(local_events)`.
    3.  RPC to Node B: `EventSynchronizer.handle_sync_request(%{from_node: A, since_time: last_sync_time_for_B, events: prepared_local_events})`.
*   **Responder (Node B, in `handle_sync_request/1`)**:
    1.  `store_remote_events(events_from_A, NodeA)`.
    2.  `local_events_for_A = DataAccess.get_events_since(last_sync_time_for_B)` (Note: `since_time` here is what Node A thinks was the last sync time *with Node B*. Node B might have a different last sync time *for Node A*. A more robust protocol might involve exchanging vector clocks or specific sequence numbers per node pair).
    3.  `prepared_local_events_for_A = prepare_events_for_sync(local_events_for_A)`.
    4.  Returns `{:ok, prepared_local_events_for_A}` to Node A.
*   **Initiator (Node A, receives reply)**:
    1.  `store_remote_events(events_from_B, NodeB)`.

### 5.3. Delta Synchronization

*   **Key Idea:** Only exchange events that the other node hasn't seen yet.
*   `DataAccess.get_events_since/1` (using `GlobalClock` timestamps) is used to fetch only new local events.
*   The `EventSynchronizer` maintains an ETS table `:elixir_scope_sync_state` which stores `{{:last_sync, remote_node_atom}, global_clock_timestamp}`. This timestamp is used as the `since_time` for the next sync with that `remote_node`.

### 5.4. Event Preparation for Synchronization (`prepare_events_for_sync/1`)

To optimize network transfer:
*   `event.data` is compressed using `:zlib.compress/1` if it's large (`compress_event_data/1`). It's wrapped as `{:compressed, binary}`.
*   A checksum (`:erlang.md5/1` of the serialized event) is calculated for basic integrity checking on the receiving end (though this check isn't explicitly shown being used on receipt in `restore_event_from_sync`).

### 5.5. Storing Remote Events (`store_remote_events/2`)

1.  Events are processed in batches (`Enum.chunk_every(@sync_batch_size)`).
2.  Each event from the remote sync payload is transformed back into a local `ElixirScope.Events` struct by `restore_event_from_sync/2` (which uncompresses data if needed).
3.  Crucially, `DataAccess.event_exists?(event.id)` is called to prevent storing duplicate events if they were already received through another path or a previous sync attempt.
4.  New, non-duplicate events are stored using `DataAccess.store_events/2`.

### 5.6. Conflict Resolution

*   **Duplicates:** Handled by `event_exists?/1` check.
*   **Event Ordering:** Relies on the Hybrid Logical Clock timestamps. When events from multiple nodes are merged (e.g., in `DataAccess` or by `QueryCoordinator`), they should be sorted by these timestamps.
*   **Data Conflicts (e.g., if two nodes modify metadata for the same event ID - not typical for raw events):** The current model doesn't explicitly handle such conflicts; it assumes event IDs are globally unique and event content is immutable once created.

### 5.7. Bandwidth Optimization and Batching

*   Data compression in `prepare_events_for_sync/1`.
*   Processing remote events in batches in `store_remote_events/2`.
*   Delta synchronization ensures only new events are sent.

## 6. Correlation of Distributed Traces

*   **Globally Unique IDs:** `event_id` (from `Utils.generate_id/0`, which includes a node hash component) and `correlation_id` (UUIDs) are designed to be unique across the cluster.
*   **`GlobalClock` Timestamps:** Provide the primary mechanism for establishing a causal partial order for events across different nodes.
*   **Challenges:**
    *   A logical operation might start on Node A (root `correlation_id` generated there), make an RPC to Node B, which then makes an RPC to Node C. ElixirScope needs to ensure that events on Node B and C related to this operation are associated with the original `correlation_id` from Node A.
    *   This requires **context propagation**: the active `correlation_id` (and potentially parent `call_id`) must be passed along with inter-node calls (e.g., in message headers or as explicit RPC arguments). The receiving node's `InstrumentationRuntime` (or Telemetry handler) would then initialize its local tracing context with these propagated IDs. This aspect of context propagation is not fully detailed in the existing `InstrumentationRuntime` or `Phoenix.Integration` code but is essential for true distributed trace stitching.

## 7. Fault Tolerance and Resilience

*   **Node Failures:** `NodeCoordinator` detects this via `:nodedown` and removes the node from its active cluster list. Synchronization attempts to that node will fail and be skipped. Local event capture continues.
*   **Network Partitions:** `NodeCoordinator` uses `Node.ping/1` to detect unreachable nodes. It will then only attempt to sync with reachable nodes. When connectivity is restored (new `:nodeup` or successful ping), synchronization should resume and exchange events missed during the partition.
*   **Eventual Consistency:** The system aims for eventual consistency. There will be a delay for events to propagate across the cluster. If a node is down for an extended period, it will miss updates until it rejoins and resynchronizes.

## 8. Performance Considerations

*   **`GlobalClock` Sync:** Periodic broadcasts from all clocks. If the cluster is large (N nodes), this is N*(N-1) messages per sync interval. The impact of these `:rpc.cast`s should be minimal.
*   **`EventSynchronizer` Traffic:** Depends on the event generation rate and `@sync_batch_size`. Sending large batches of compressed events can still consume significant bandwidth. Delta sync is key to minimizing this.
*   **RPC Overhead:** Each `:rpc.call` has overhead. Using `:rpc.cast` for non-critical notifications (like `GlobalClock` updates) is good. `EventSynchronizer` uses `:rpc.call` as it needs a reply with the remote node's events.

## 9. Configuration and Setup

*   **`NodeCoordinator.setup_cluster/1`:** The primary way to inform nodes about each other initially. This implies a somewhat static or centrally managed cluster definition at startup.
*   **Distributed Erlang Cookies:** All nodes must share the same Erlang cookie to communicate.
*   Node names must be resolvable.

## 10. Testing Strategies for Distributed Features

(E.g., `test/elixir_scope/distributed/multi_node_test.exs` from `FOUNDATION_IMPLEMENTATION_GUIDE.md`)
*   **Multi-Node Test Setup:** Use libraries like `ExUnit.DistributedCase` or manually start slave nodes (`:slave.start_link/3`) for testing.
*   **Scenarios:**
    *   RPC call from Node A to Node B, verify events on both nodes are captured and correlated.
    *   Node A spawns a process on Node B, verify linkage.
    *   Event synchronization: Generate events on Node A, verify they appear on Node B after sync.
    *   Network partition: Disconnect nodes, generate events on both sides, reconnect, verify eventual consistency.
    *   Node join/leave: Verify cluster state is updated correctly on all nodes and sync adapts.
    *   Global Clock: Verify timestamps are causally consistent across nodes after interactions.
*   **Challenges:** Simulating real network conditions (latency, partitions) robustly in tests. Ensuring proper cleanup of distributed test environments.

## 11. Conclusion

The Distributed Systems Support Layer in ElixirScope provides essential capabilities for tracing applications that span multiple BEAM nodes. The `GlobalClock` offers a basis for distributed event ordering, the `NodeCoordinator` manages cluster awareness and initiates synchronization, and the `EventSynchronizer` handles the exchange of event data. While the current implementation provides a solid foundation for delta synchronization and basic partition detection, achieving robust and transparent distributed trace correlation will require careful implementation of context propagation across RPC calls and other inter-node communication mechanisms. The performance and scalability of this layer, especially event synchronization, will be critical for larger clusters.

---

I believe this covers the core distributed components well. This is likely the last *major, distinct architectural area* present in the current "Foundation Complete" set of modules that warrants its own deep-dive document of this nature.

Other topics from here would likely be:
*   More focused deep-dives into specific algorithms within these components (e.g., the exact heuristics in `AI.ComplexityAnalyzer` if they were more complex than AST counting).
*   Consolidated documents on cross-cutting concerns (Overall Performance Strategy, Testing Philosophy, Error Handling Strategy).
*   User-facing guides or API references.

So, unless you have a specific sub-component in mind, I'd say we are **approaching exhaustion for this style of detailed technical document on distinct architectural blocks.**