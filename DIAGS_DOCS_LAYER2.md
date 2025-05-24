# Layer 2 Implementation Guide: Asynchronous Processing & Event Correlation

## Executive Summary

This document provides comprehensive technical guidance for implementing Layer 2 of ElixirScope - the Asynchronous Processing & Event Correlation layer. Layer 2 is responsible for consuming events from Layer 1's high-performance ring buffers, enriching them with metadata, establishing causal relationships between events, and persisting them for querying. This layer is critical for transforming raw event streams into meaningful, correlated execution histories that power ElixirScope's "Execution Cinema" vision.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Specifications](#component-specifications)
3. [Implementation Guidelines](#implementation-guidelines)
4. [Data Structures & Schemas](#data-structures--schemas)
5. [Performance Requirements](#performance-requirements)
6. [Error Handling & Resilience](#error-handling--resilience)
7. [Testing Strategy](#testing-strategy)
8. [Integration Points](#integration-points)
9. [Configuration & Tuning](#configuration--tuning)
10. [Monitoring & Observability](#monitoring--observability)

## 1. Architecture Overview

### 1.1 Layer 2 Purpose

Layer 2 serves as the "off-ramp" from the ultra-fast event capture pipeline (Layer 1), providing:

- **Asynchronous Processing**: Decouples event capture from processing to maintain sub-microsecond ingestion latency
- **Event Correlation**: Establishes causal relationships between related events (function calls/returns, message sends/receives)
- **Data Enrichment**: Adds metadata and context that would be too expensive to capture in the hot path
- **Persistent Storage**: Moves events from temporary ring buffers to queryable storage
- **Backpressure Management**: Prevents system overload through intelligent flow control

### 1.2 Key Design Principles

1. **Decoupled Architecture**: No component in Layer 2 should block Layer 1's event ingestion
2. **Horizontal Scalability**: Worker pools should scale based on load
3. **Fault Tolerance**: Individual worker failures should not affect the overall pipeline
4. **Eventual Consistency**: Correlation can happen asynchronously; perfect ordering is not required
5. **Memory Efficiency**: Process events in batches to amortize overhead

## 2. Component Specifications

### 2.1 PipelineManager

**Module**: `ElixirScope.Capture.PipelineManager`

**Responsibilities**:
- Supervise all Layer 2 components using OTP supervision strategies
- Monitor system health and coordinate scaling decisions
- Manage configuration updates dynamically
- Provide a unified control interface for the pipeline

**Key Functions**:
```elixir
@spec start_link(keyword()) :: Supervisor.on_start()
@spec scale_workers(pos_integer()) :: :ok | {:error, term()}
@spec get_pipeline_stats() :: %{
  workers: pos_integer(),
  events_processed: non_neg_integer(),
  avg_latency_ms: float(),
  buffer_utilization: float()
}
@spec update_config(keyword()) :: :ok
```

**Implementation Notes**:
- Use a `Supervisor` with `:one_for_one` strategy for worker pool
- Implement as a GenServer that also acts as a supervisor
- Maintain runtime metrics in ETS for fast access
- Use `:telemetry` for emitting pipeline events

### 2.2 AsyncWriterPool

**Module**: `ElixirScope.Storage.AsyncWriterPool`

**Responsibilities**:
- Manage a pool of worker processes that consume from ring buffers
- Implement work-stealing for load balancing across workers
- Handle batch reading from ring buffers for efficiency
- Route events to EventCorrelator and then to storage

**Key Functions**:
```elixir
@spec start_link(keyword()) :: Supervisor.on_start()
@spec spawn_worker() :: {:ok, pid()} | {:error, :max_workers_reached}
@spec remove_worker(pid()) :: :ok
@spec get_worker_stats(pid()) :: %{
  events_processed: non_neg_integer(),
  current_batch_size: non_neg_integer(),
  processing_time_us: non_neg_integer()
}
```

**Worker Implementation**:
```elixir
defmodule ElixirScope.Storage.AsyncWriter do
  use GenServer
  
  # State structure
  @type state :: %{
    buffer_assignments: [RingBuffer.t()],
    batch_size: pos_integer(),
    flush_interval: pos_integer(),
    stats: map(),
    correlator: pid()
  }
  
  # Core processing loop
  def handle_info(:process_batch, state) do
    events = read_batch_from_buffers(state.buffer_assignments, state.batch_size)
    
    enriched_events = Enum.map(events, &enrich_event/1)
    correlated_events = EventCorrelator.correlate_batch(state.correlator, enriched_events)
    
    :ok = DataAccess.write_batch(correlated_events)
    
    schedule_next_batch(state.flush_interval)
    {:noreply, update_stats(state, length(events))}
  end
end
```

**Implementation Notes**:
- Use `ConsistentHash` or similar for buffer-to-worker assignment
- Implement exponential backoff when buffers are empty
- Track per-worker metrics for load balancing decisions
- Consider using `Task` for fire-and-forget write operations

### 2.3 EventCorrelator

**Module**: `ElixirScope.EventCorrelator`

**Responsibilities**:
- Establish causal relationships between events
- Manage correlation state (call stacks, message queues, process trees)
- Generate correlation IDs and maintain lookup tables
- Clean up expired correlation state to prevent memory leaks

**Key Functions**:
```elixir
@spec correlate_batch([Event.t()]) :: [CorrelatedEvent.t()]
@spec correlate_event(Event.t()) :: CorrelatedEvent.t()
@spec establish_link(event_id_1 :: binary(), event_id_2 :: binary(), link_type :: atom()) :: :ok
@spec get_correlation_chain(event_id :: binary()) :: [Event.t()]
@spec cleanup_expired_correlations() :: {:ok, cleaned_count :: non_neg_integer()}
```

**Correlation Strategies**:

1. **Function Call Correlation**:
```elixir
defmodule ElixirScope.EventCorrelator.FunctionStrategy do
  # Maintains call stack per process
  @spec handle_function_entry(Event.t()) :: CorrelatedEvent.t()
  def handle_function_entry(event) do
    call_id = generate_call_id()
    push_call_stack(event.pid, call_id)
    
    %CorrelatedEvent{
      event: event,
      correlation_id: call_id,
      parent_id: get_current_call_id(event.pid),
      correlation_type: :function_call
    }
  end
  
  @spec handle_function_exit(Event.t()) :: CorrelatedEvent.t()
  def handle_function_exit(event) do
    call_id = pop_call_stack(event.pid)
    
    %CorrelatedEvent{
      event: event,
      correlation_id: call_id,
      links: [{:completes, call_id}],
      correlation_type: :function_return
    }
  end
end
```

2. **Message Correlation**:
```elixir
defmodule ElixirScope.EventCorrelator.MessageStrategy do
  # Tracks messages in flight
  @spec handle_message_send(Event.t()) :: CorrelatedEvent.t()
  def handle_message_send(event) do
    msg_id = generate_message_id()
    register_message(msg_id, event)
    
    %CorrelatedEvent{
      event: event,
      correlation_id: msg_id,
      correlation_type: :message_send
    }
  end
  
  @spec handle_message_receive(Event.t()) :: CorrelatedEvent.t()
  def handle_message_receive(event) do
    msg_id = match_message(event)
    
    %CorrelatedEvent{
      event: event,
      correlation_id: msg_id,
      links: [{:receives, msg_id}],
      correlation_type: :message_receive
    }
  end
end
```

**State Management**:
- Use ETS tables for correlation state with TTL
- Implement periodic cleanup process
- Consider using `persistent_term` for frequently accessed correlation rules

### 2.4 BackpressureManager

**Module**: `ElixirScope.Capture.BackpressureManager`

**Responsibilities**:
- Monitor ring buffer utilization across all buffers
- Make scaling decisions based on multiple metrics
- Implement circuit breaker for overload protection
- Coordinate with PipelineManager for worker scaling

**Key Functions**:
```elixir
@spec start_link(keyword()) :: GenServer.on_start()
@spec check_pressure() :: :normal | :elevated | :high | :critical
@spec get_scaling_recommendation() :: {:scale_up, count} | {:scale_down, count} | :maintain
@spec enable_load_shedding() :: :ok
@spec disable_load_shedding() :: :ok
```

**Pressure Calculation Algorithm**:
```elixir
defp calculate_pressure(metrics) do
  %{
    buffer_utilization: buffer_util,
    processing_latency: latency,
    memory_usage: memory,
    error_rate: errors
  } = metrics
  
  cond do
    buffer_util > 0.95 or memory > 0.90 -> :critical
    buffer_util > 0.80 or latency > 50 -> :high
    buffer_util > 0.50 or latency > 20 -> :elevated
    true -> :normal
  end
end
```

**Scaling Strategy**:
```elixir
defp recommend_scaling(pressure, current_workers) do
  case pressure do
    :critical -> 
      {:scale_up, min(4, max_workers() - current_workers)}
    :high -> 
      {:scale_up, min(2, max_workers() - current_workers)}
    :elevated when current_workers < target_workers() -> 
      {:scale_up, 1}
    :normal when current_workers > min_workers() -> 
      {:scale_down, 1}
    _ -> 
      :maintain
  end
end
```

## 3. Implementation Guidelines

### 3.1 Development Order

1. **Phase 1: Core Pipeline (Week 1)**
   - Implement PipelineManager supervisor structure
   - Create basic AsyncWriter worker
   - Set up DataAccess write path
   - Basic batch processing from ring buffer

2. **Phase 2: Correlation Engine (Week 2)**
   - Implement EventCorrelator with function correlation
   - Add message correlation strategy
   - Create correlation state management
   - Implement basic cleanup

3. **Phase 3: Scaling & Backpressure (Week 3)**
   - Implement BackpressureManager
   - Add worker pool scaling logic
   - Implement load shedding strategies
   - Add circuit breaker pattern

4. **Phase 4: Production Hardening (Week 4)**
   - Add comprehensive error handling
   - Implement monitoring and metrics
   - Performance optimization
   - Integration testing

### 3.2 Code Organization

```
lib/elixir_scope/
├── capture/
│   ├── pipeline_manager.ex
│   └── backpressure_manager.ex
├── storage/
│   ├── async_writer_pool.ex
│   ├── async_writer.ex
│   └── event_correlator/
│       ├── event_correlator.ex
│       ├── strategies/
│       │   ├── function_strategy.ex
│       │   ├── message_strategy.ex
│       │   ├── process_strategy.ex
│       │   └── state_strategy.ex
│       └── correlation_state.ex
└── test/
    └── (corresponding test files)
```

### 3.3 Key Design Patterns

1. **Batch Processing**:
```elixir
def process_batch(buffer, batch_size) do
  case RingBuffer.read_batch(buffer, position, batch_size) do
    {[], _new_pos} -> 
      # Buffer empty, backoff
      Process.sleep(@backoff_ms)
      {:ok, 0}
    
    {events, new_pos} ->
      # Process events
      process_events(events)
      update_position(new_pos)
      {:ok, length(events)}
  end
end
```

2. **State Isolation**:
```elixir
# Each worker maintains its own state
defmodule AsyncWriter do
  defstruct [
    :id,
    :buffer_assignments,
    :position_map,  # %{buffer_ref => position}
    :stats,
    :correlator_ref
  ]
end
```

3. **Fault Tolerance**:
```elixir
def handle_info({:EXIT, worker_pid, reason}, state) do
  Logger.warning("Worker #{inspect(worker_pid)} died: #{inspect(reason)}")
  
  # Redistribute work
  reassign_buffers(worker_pid, state.workers)
  
  # Spawn replacement if needed
  maybe_spawn_replacement(state)
  
  {:noreply, state}
end
```

## 4. Data Structures & Schemas

### 4.1 Correlated Event Structure

```elixir
defmodule ElixirScope.CorrelatedEvent do
  @type t :: %__MODULE__{
    # Original event data
    event: Event.t(),
    
    # Correlation metadata
    correlation_id: binary(),
    parent_id: binary() | nil,
    root_id: binary() | nil,
    
    # Causal links
    links: [{link_type :: atom(), target_id :: binary()}],
    
    # Correlation type
    correlation_type: :function_call | :function_return | 
                     :message_send | :message_receive |
                     :state_change | :process_spawn | :process_exit,
    
    # Processing metadata
    correlated_at: non_neg_integer(),
    correlation_confidence: float()
  }
end
```

### 4.2 Correlation State Tables

```elixir
# ETS Table Schemas

# Call stack table: {pid, call_stack :: [call_id]}
:ets.new(:elixir_scope_call_stacks, [:set, :public])

# Message tracking: {message_id, {sender_pid, receiver_pid, timestamp, content_hash}}
:ets.new(:elixir_scope_messages, [:set, :public])

# Process relationships: {child_pid, parent_pid}
:ets.new(:elixir_scope_process_tree, [:set, :public])

# Active correlations: {correlation_id, {type, created_at, metadata}}
:ets.new(:elixir_scope_correlations, [:set, :public])
```

### 4.3 Pipeline Metrics Schema

```elixir
defmodule ElixirScope.PipelineMetrics do
  @type t :: %__MODULE__{
    # Throughput metrics
    events_per_second: float(),
    batches_per_second: float(),
    correlations_per_second: float(),
    
    # Latency metrics (in microseconds)
    processing_latency_p50: non_neg_integer(),
    processing_latency_p95: non_neg_integer(),
    processing_latency_p99: non_neg_integer(),
    
    # Buffer health
    buffer_utilization: %{binary() => float()},
    dropped_events: non_neg_integer(),
    
    # Worker pool status
    active_workers: non_neg_integer(),
    total_workers: non_neg_integer(),
    avg_worker_load: float(),
    
    # Correlation success
    correlation_success_rate: float(),
    orphaned_events: non_neg_integer(),
    
    # System resources
    memory_usage_mb: float(),
    ets_memory_mb: float()
  }
end
```

## 5. Performance Requirements

### 5.1 Throughput Targets

- **Sustained Load**: Handle 10,000+ events/second continuously
- **Peak Load**: Handle 50,000 events/second for 30-second bursts
- **Batch Processing**: Process batches of 100-1000 events efficiently
- **Correlation Rate**: Correlate 95%+ of events within 10ms

### 5.2 Latency Targets

- **P50 Processing Latency**: < 5ms from ring buffer to storage
- **P95 Processing Latency**: < 20ms
- **P99 Processing Latency**: < 50ms
- **Correlation Lookup**: < 1ms for recent events

### 5.3 Resource Constraints

- **Memory Usage**: < 500MB for Layer 2 components under normal load
- **CPU Usage**: < 20% of available cores under normal load
- **ETS Tables**: < 2GB total size before pruning triggers

### 5.4 Performance Optimization Strategies

1. **Batch Operations**:
```elixir
# Good: Batch ETS operations
def write_correlations(correlations) do
  :ets.insert(:elixir_scope_correlations, correlations)
end

# Bad: Individual inserts
def write_correlation(correlation) do
  :ets.insert(:elixir_scope_correlations, correlation)
end
```

2. **Minimize Allocations**:
```elixir
# Reuse binary references instead of copying
def enrich_event(%{data: data} = event) do
  %{event | enriched_data: enrich(data)}  # Reuses existing map
end
```

3. **Efficient Lookups**:
```elixir
# Use match specifications for complex queries
def find_related_events(correlation_id) do
  match_spec = [
    {{'$1', '$2', '$3'}, 
     [{'==', '$2', correlation_id}], 
     ['$1']}
  ]
  :ets.select(:elixir_scope_correlations, match_spec)
end
```

## 6. Error Handling & Resilience

### 6.1 Error Categories

1. **Transient Errors**: Network issues, temporary resource exhaustion
2. **Data Errors**: Malformed events, corruption
3. **System Errors**: OOM, ETS table limits
4. **Logic Errors**: Missing correlations, invalid state

### 6.2 Error Handling Strategies

```elixir
defmodule ElixirScope.ErrorHandler do
  require Logger

  def handle_error(:transient, error, context) do
    Logger.warning("Transient error: #{inspect(error)}", context: context)
    {:retry, exponential_backoff()}
  end

  def handle_error(:data_error, error, event) do
    Logger.error("Data error: #{inspect(error)}", event: inspect(event))
    {:skip, store_to_dead_letter_queue(event)}
  end

  def handle_error(:system_error, error, _context) do
    Logger.error("System error: #{inspect(error)}")
    {:escalate, notify_ops_team()}
  end

  def handle_error(:logic_error, error, event) do
    Logger.warning("Logic error: #{inspect(error)}")
    {:continue, mark_as_orphaned(event)}
  end
end
```

### 6.3 Circuit Breaker Implementation

```elixir
defmodule ElixirScope.CircuitBreaker do
  use GenServer

  @failure_threshold 5
  @timeout_ms 60_000

  def call(fun) do
    case GenServer.call(__MODULE__, :check_state) do
      :open -> {:error, :circuit_open}
      :half_open -> try_call(fun, :half_open)
      :closed -> try_call(fun, :closed)
    end
  end

  defp try_call(fun, state) do
    case fun.() do
      {:ok, result} ->
        GenServer.cast(__MODULE__, :success)
        {:ok, result}
      {:error, _} = error ->
        GenServer.cast(__MODULE__, :failure)
        error
    end
  end
end
```

### 6.4 Recovery Procedures

1. **Buffer Overflow Recovery**:
   - Switch to sampling mode
   - Increase worker pool
   - Alert operators
   - Log dropped event statistics

2. **Correlation State Recovery**:
   - Rebuild from persisted events
   - Mark uncertain correlations
   - Continue with best-effort correlation

3. **Worker Crash Recovery**:
   - Supervisor restarts worker
   - Redistribute buffer assignments
   - Resume from last known position

## 7. Testing Strategy

### 7.1 Unit Tests

```elixir
# Example: EventCorrelator unit test
defmodule ElixirScope.EventCorrelatorTest do
  use ExUnit.Case

  describe "function correlation" do
    test "correlates function entry and exit" do
      entry_event = create_function_entry_event()
      exit_event = create_function_exit_event()
      
      correlated_entry = EventCorrelator.correlate_event(entry_event)
      correlated_exit = EventCorrelator.correlate_event(exit_event)
      
      assert correlated_entry.correlation_id == correlated_exit.correlation_id
      assert {:completes, correlated_entry.event.id} in correlated_exit.links
    end
  end
end
```

### 7.2 Integration Tests

```elixir
defmodule ElixirScope.Layer2IntegrationTest do
  use ExUnit.Case

  @tag :integration
  test "full pipeline flow" do
    # Setup
    {:ok, buffer} = RingBuffer.new(size: 1024)
    {:ok, _pipeline} = PipelineManager.start_link(buffers: [buffer])
    
    # Generate test events
    events = generate_test_events(100)
    Enum.each(events, &RingBuffer.write(buffer, &1))
    
    # Wait for processing
    Process.sleep(100)
    
    # Verify
    stored_events = DataAccess.query_recent(100)
    assert length(stored_events) == 100
    assert Enum.all?(stored_events, &has_correlation?/1)
  end
end
```

### 7.3 Property-Based Tests

```elixir
defmodule ElixirScope.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "all events get correlated" do
    check all events <- list_of(event_generator(), min_length: 1) do
      process_events(events)
      correlated = get_correlated_events()
      
      assert length(correlated) == length(events)
      assert Enum.all?(correlated, &valid_correlation?/1)
    end
  end
end
```

### 7.4 Load Tests

```elixir
defmodule ElixirScope.LoadTest do
  use ExUnit.Case

  @tag :load
  test "sustains 10k events/sec for 10 minutes" do
    duration = :timer.minutes(10)
    rate = 10_000
    
    {:ok, stats} = LoadGenerator.run(
      duration: duration,
      events_per_second: rate,
      event_generator: &generate_realistic_event/0
    )
    
    assert stats.total_events >= rate * 60 * 10 * 0.95  # 95% minimum
    assert stats.p99_latency < 50_000  # 50ms
    assert stats.error_rate < 0.001  # 0.1%
  end
end
```

## 8. Integration Points

### 8.1 Layer 1 Integration

**Ring Buffer Consumer Interface**:
```elixir
defmodule ElixirScope.Storage.AsyncWriter do
  def consume_from_buffer(buffer, position) do
    case RingBuffer.read_batch(buffer, position, @batch_size) do
      {events, new_position} when events != [] ->
        process_batch(events)
        {:ok, new_position}
      
      {[], position} ->
        {:empty, position}
    end
  end
end
```

**Position Management**:
- Store positions in ETS for crash recovery
- Update atomically after successful processing
- Support position reset for replay scenarios

### 8.2 Storage Layer Integration

**DataAccess Interface**:
```elixir
defmodule ElixirScope.Storage.DataAccess do
  @callback write_events([CorrelatedEvent.t()]) :: :ok | {:error, term()}
  @callback write_correlation_links([{binary(), binary(), atom()}]) :: :ok
  @callback update_event_metadata(binary(), map()) :: :ok | {:error, term()}
end
```

**Batch Writing Strategy**:
```elixir
def write_batch_to_storage(events) do
  # Group by table/index
  grouped = Enum.group_by(events, &event_table/1)
  
  # Write to each table
  Enum.each(grouped, fn {table, table_events} ->
    :ets.insert(table, prepare_for_storage(table_events))
  end)
end
```

### 8.3 Query Layer Preparation

**Index Maintenance**:
```elixir
def maintain_indexes(event) do
  # Temporal index
  :ets.insert(:temporal_index, {event.timestamp, event.id})
  
  # Process index
  :ets.insert(:process_index, {event.pid, event.id})
  
  # Correlation index
  :ets.insert(:correlation_index, {event.correlation_id, event.id})
end
```

## 9. Configuration & Tuning

### 9.1 Configuration Schema

```elixir
defmodule ElixirScope.Config.Layer2 do
  @type t :: %{
    pipeline: %{
      min_workers: pos_integer(),
      max_workers: pos_integer(),
      target_workers: pos_integer()
    },
    processing: %{
      batch_size: pos_integer(),
      flush_interval_ms: pos_integer(),
      max_batch_wait_ms: pos_integer()
    },
    correlation: %{
      ttl_seconds: pos_integer(),
      cleanup_interval_ms: pos_integer(),
      max_correlation_depth: pos_integer()
    },
    backpressure: %{
      check_interval_ms: pos_integer(),
      scale_up_threshold: float(),
      scale_down_threshold: float(),
      emergency_threshold: float()
    },
    storage: %{
      write_batch_size: pos_integer(),
      write_timeout_ms: pos_integer()
    }
  }
end
```

### 9.2 Default Configuration

```elixir
def default_config do
  %{
    pipeline: %{
      min_workers: 2,
      max_workers: 16,
      target_workers: 4
    },
    processing: %{
      batch_size: 100,
      flush_interval_ms: 10,
      max_batch_wait_ms: 50
    },
    correlation: %{
      ttl_seconds: 300,  # 5 minutes
      cleanup_interval_ms: 60_000,  # 1 minute
      max_correlation_depth: 100
    },
    backpressure: %{
      check_interval_ms: 100,
      scale_up_threshold: 0.7,
      scale_down_threshold: 0.3,
      emergency_threshold: 0.95
    },
    storage: %{
      write_batch_size: 1000,
      write_timeout_ms: 5000
    }
  }
end
```

### 9.3 Tuning Guidelines

1. **For High Throughput**:
   - Increase `batch_size` to 500-1000
   - Increase `max_workers` based on CPU cores
   - Decrease `flush_interval_ms` to 5ms

2. **For Low Latency**:
   - Decrease `batch_size` to 10-50
   - Decrease `max_batch_wait_ms` to 10ms
   - Increase worker count for parallelism

3. **For Memory Efficiency**:
   - Decrease `correlation.ttl_seconds`
   - Increase `cleanup_interval_ms`
   - Limit `max_correlation_depth`

## 10. Monitoring & Observability

### 10.1 Key Metrics

```elixir
defmodule ElixirScope.Metrics.Layer2 do
  def emit_metrics do
    # Throughput metrics
    :telemetry.execute(
      [:elixir_scope, :layer2, :throughput],
      %{
        events_per_second: calculate_events_per_second(),
        batches_per_second: calculate_batches_per_second()
      },
      %{}
    )
    
    # Latency metrics
    :telemetry.execute(
      [:elixir_scope, :layer2, :latency],
      %{
        p50: get_latency_percentile(50),
        p95: get_latency_percentile(95),
        p99: get_latency_percentile(99)
      },
      %{}
    )
    
    # Health metrics
    :telemetry.execute(
      [:elixir_scope, :layer2, :health],
      %{
        buffer_utilization: calculate_buffer_utilization(),
        correlation_success_rate: calculate_correlation_success(),
        worker_utilization: calculate_worker_utilization()
      },
      %{}
    )
  end
end
```

### 10.2 Health Checks

```elixir
defmodule ElixirScope.HealthCheck.Layer2 do
  def check_health do
    checks = [
      check_worker_pool(),
      check_buffer_health(),
      check_correlation_state(),
      check_storage_connection()
    ]
    
    case Enum.find(checks, &match?({:error, _}, &1)) do
      nil -> {:ok, "Layer 2 healthy"}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp check_worker_pool do
    case AsyncWriterPool.get_stats() do
      %{active_workers: n} when n > 0 -> :ok
      _ -> {:error, "No active workers"}
    end
  end
end
```

### 10.3 Debug Endpoints

```elixir
defmodule ElixirScope.Debug.Layer2 do
  def get_pipeline_state do
    %{
      workers: list_workers_with_stats(),
      buffers: list_buffers_with_positions(),
      correlation_state: get_correlation_summary(),
      recent_errors: get_recent_errors(100)
    }
  end
  
  def trace_event(event_id) do
    # Show complete processing history for an event
    %{
      ingestion_time: get_ingestion_time(event_id),
      processing_worker: get_processing_worker(event_id),
      correlation_attempts: get_correlation_attempts(event_id),
      storage_time: get_storage_time(event_id),
      final_correlations: get_final_correlations(event_id)
    }
  end
end
```

## Implementation Checklist

### Week 1: Core Pipeline
- [ ] Implement PipelineManager with basic supervision
- [ ] Create AsyncWriterPool supervisor
- [ ] Implement AsyncWriter worker with batch processing
- [ ] Basic integration with RingBuffer reading
- [ ] Simple DataAccess write path
- [ ] Unit tests for each component

### Week 2: Event Correlation
- [ ] Design correlation state schema
- [ ] Implement EventCorrelator main module
- [ ] Create FunctionStrategy for call correlation
- [ ] Create MessageStrategy for message correlation
- [ ] Implement correlation state cleanup
- [ ] Integration tests for correlation accuracy

### Week 3: Scaling & Resilience
- [ ] Implement BackpressureManager
- [ ] Add worker scaling logic to PipelineManager
- [ ] Implement circuit breaker pattern
- [ ] Add load shedding strategies
- [ ] Create health check system
- [ ] Load tests for scaling behavior

### Week 4: Production Readiness
- [ ] Comprehensive error handling for all edge cases
- [ ] Telemetry integration for all key metrics
- [ ] Configuration hot-reloading support
- [ ] Performance profiling and optimization
- [ ] Documentation for operations team
- [ ] End-to-end integration tests
- [ ] Deployment and rollback procedures

## Appendix A: Common Implementation Patterns

### A.1 Supervision Tree Structure

```elixir
defmodule ElixirScope.Capture.PipelineManager do
  use Supervisor

  def init(_opts) do
    children = [
      # Core components
      {ElixirScope.Storage.AsyncWriterPool, name: AsyncWriterPool},
      {ElixirScope.EventCorrelator, name: EventCorrelator},
      {ElixirScope.Capture.BackpressureManager, name: BackpressureManager},
      
      # Cleanup processes
      {ElixirScope.EventCorrelator.Cleaner, name: CorrelationCleaner},
      
      # Metrics collector
      {ElixirScope.Metrics.Layer2Collector, name: MetricsCollector}
    ]

    Supervisor.init(children, strategy: :one_for_one, max_restarts: 10, max_seconds: 60)
  end
end
```

### A.2 Worker Pool Pattern

```elixir
defmodule ElixirScope.Storage.AsyncWriterPool do
  use Supervisor

  def start_worker do
    spec = {ElixirScope.Storage.AsyncWriter, id: make_ref()}
    Supervisor.start_child(__MODULE__, spec)
  end

  def stop_worker(worker_pid) do
    Supervisor.terminate_child(__MODULE__, worker_pid)
  end

  def rebalance_workers do
    current_workers = Supervisor.which_children(__MODULE__)
    target = calculate_target_workers()
    
    cond do
      length(current_workers) < target ->
        for _ <- 1..(target - length(current_workers)), do: start_worker()
      
      length(current_workers) > target ->
        excess = length(current_workers) - target
        current_workers
        |> Enum.take(excess)
        |> Enum.each(fn {_, pid, _, _} -> stop_worker(pid) end)
      
      true ->
        :ok
    end
  end
end
```

### A.3 Batch Processing Pattern

```elixir
defmodule ElixirScope.Storage.AsyncWriter do
  defstruct [
    :buffer_refs,
    :positions,
    :batch_accumulator,
    :last_flush_time
  ]

  def handle_info(:process_batch, state) do
    state = 
      state
      |> read_from_buffers()
      |> accumulate_batch()
      |> maybe_flush_batch()
      |> schedule_next_batch()
    
    {:noreply, state}
  end

  defp accumulate_batch(%{batch_accumulator: acc} = state) do
    new_events = read_available_events(state)
    %{state | batch_accumulator: acc ++ new_events}
  end

  defp maybe_flush_batch(%{batch_accumulator: acc} = state) when length(acc) >= @batch_size do
    flush_batch(state)
  end

  defp maybe_flush_batch(%{last_flush_time: last_flush} = state) do
    if System.monotonic_time(:millisecond) - last_flush > @flush_interval_ms do
      flush_batch(state)
    else
      state
    end
  end

  defp flush_batch(%{batch_accumulator: []} = state), do: state
  
  defp flush_batch(%{batch_accumulator: batch} = state) do
    # Process and store
    batch
    |> EventCorrelator.correlate_batch()
    |> DataAccess.write_batch()
    
    %{state | 
      batch_accumulator: [],
      last_flush_time: System.monotonic_time(:millisecond)
    }
  end
end
```

### A.4 Correlation State Management

```elixir
defmodule ElixirScope.EventCorrelator.State do
  @moduledoc """
  Manages correlation state with automatic cleanup
  """

  def init do
    # Create ETS tables
    :ets.new(:call_stacks, [:public, :named_table])
    :ets.new(:message_registry, [:public, :named_table])
    :ets.new(:correlation_metadata, [:public, :named_table, {:write_concurrency, true}])
    
    # Schedule cleanup
    schedule_cleanup()
  end

  def push_call(pid, call_id) do
    case :ets.lookup(:call_stacks, pid) do
      [{^pid, stack}] ->
        :ets.insert(:call_stacks, {pid, [call_id | stack]})
      [] ->
        :ets.insert(:call_stacks, {pid, [call_id]})
    end
    
    # Track correlation lifetime
    :ets.insert(:correlation_metadata, {call_id, :call, System.monotonic_time()})
  end

  def cleanup_expired do
    now = System.monotonic_time()
    ttl = :timer.seconds(300)
    
    expired = :ets.select(:correlation_metadata, [
      {{'$1', '$2', '$3'}, 
       [{:<, {:+, '$3', ttl}, now}], 
       ['$1']}
    ])
    
    Enum.each(expired, &cleanup_correlation/1)
    
    schedule_cleanup()
  end
end
```

## Appendix B: Performance Optimization Techniques

### B.1 Lock-Free Data Structures

```elixir
defmodule ElixirScope.LockFree.Queue do
  @moduledoc """
  Lock-free queue implementation using atomics
  """
  
  def new(size) do
    %{
      buffer: :atomics.new(size, signed: false),
      head: :atomics.new(1, signed: false),
      tail: :atomics.new(1, signed: false),
      size: size
    }
  end

  def enqueue(queue, item) do
    tail = :atomics.get(queue.tail, 1)
    next_tail = rem(tail + 1, queue.size)
    head = :atomics.get(queue.head, 1)
    
    if next_tail == head do
      {:error, :full}
    else
      :atomics.put(queue.buffer, tail + 1, :erlang.term_to_binary(item))
      :atomics.put(queue.tail, 1, next_tail)
      :ok
    end
  end
end
```

### B.2 Zero-Copy Event Processing

```elixir
defmodule ElixirScope.ZeroCopy do
  @moduledoc """
  Techniques for minimizing data copying
  """

  def process_event_reference(event_ref) do
    # Work with references instead of copying data
    enriched_ref = enrich_in_place(event_ref)
    correlation = lookup_correlation(event_ref.correlation_id)
    
    # Only materialize when writing
    %{
      event_ref: enriched_ref,
      correlation: correlation,
      lazy_eval: fn -> materialize_event(enriched_ref) end
    }
  end

  defp enrich_in_place(event_ref) do
    # Add metadata without copying the entire event
    %{event_ref | 
      metadata: %{
        processed_at: System.monotonic_time(),
        worker_id: self()
      }
    }
  end
end
```

### B.3 Efficient Batch Operations

```elixir
defmodule ElixirScope.BatchOptimizations do
  @moduledoc """
  Optimized batch processing techniques
  """

  def process_batch_parallel(events) do
    # Split batch across cores
    chunk_size = div(length(events), System.schedulers_online())
    
    events
    |> Enum.chunk_every(chunk_size)
    |> Task.async_stream(&process_chunk/1, 
        max_concurrency: System.schedulers_online(),
        ordered: false)
    |> Enum.flat_map(fn {:ok, result} -> result end)
  end

  def write_batch_optimized(events) do
    # Group by destination table for bulk inserts
    events
    |> Enum.group_by(&destination_table/1)
    |> Enum.each(fn {table, table_events} ->
      bulk_insert(table, table_events)
    end)
  end

  defp bulk_insert(table, events) do
    # Use single ETS operation for entire batch
    records = Enum.map(events, &to_ets_record/1)
    :ets.insert(table, records)
  end
end
```

## Appendix C: Troubleshooting Guide

### C.1 Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| High Memory Usage | ETS tables growing unbounded | 1. Check correlation cleanup is running<br>2. Verify TTL settings<br>3. Monitor for memory leaks in worker state |
| Correlation Misses | Events not being linked | 1. Check timing windows for correlation<br>2. Verify event ordering assumptions<br>3. Increase correlation state TTL |
| Worker Pool Instability | Frequent worker restarts | 1. Check for unhandled exceptions<br>2. Monitor for OOM kills<br>3. Review error logs for patterns |
| Backpressure Triggering | Frequent scaling events | 1. Profile batch processing time<br>2. Check for blocking operations<br>3. Review batch size configuration |
| Data Loss | Missing events in storage | 1. Check ring buffer overflow stats<br>2. Verify worker crash recovery<br>3. Monitor circuit breaker state |

### C.2 Debug Commands

```elixir
# Check pipeline health
ElixirScope.Debug.Layer2.check_health()

# Trace a specific event through the pipeline
ElixirScope.Debug.Layer2.trace_event("event_id_123")

# Get worker statistics
ElixirScope.Debug.Layer2.worker_stats()

# Dump correlation state
ElixirScope.Debug.Layer2.dump_correlation_state()

# Force correlation cleanup
ElixirScope.EventCorrelator.force_cleanup()

# Analyze backpressure metrics
ElixirScope.Debug.Layer2.backpressure_analysis()
```

### C.3 Performance Profiling

```elixir
defmodule ElixirScope.Profile.Layer2 do
  def profile_processing_path do
    :fprof.start()
    :fprof.trace([:start, {:procs, :all}])
    
    # Run test load
    generate_test_events(1000)
    Process.sleep(1000)
    
    :fprof.trace([:stop])
    :fprof.profile()
    :fprof.analyse(dest: 'layer2_profile.txt')
  end

  def measure_correlation_overhead do
    events = generate_test_events(10_000)
    
    {time_with, _} = :timer.tc(fn ->
      Enum.map(events, &EventCorrelator.correlate_event/1)
    end)
    
    {time_without, _} = :timer.tc(fn ->
      Enum.map(events, & &1)  # No-op
    end)
    
    overhead_us = (time_with - time_without) / length(events)
    IO.puts("Correlation overhead: #{overhead_us}μs per event")
  end
end
```

## Appendix D: Operational Runbook

### D.1 Deployment Checklist

- [ ] Verify Layer 1 (ring buffers) are operational
- [ ] Check ETS table limits are sufficient
- [ ] Confirm storage layer is ready
- [ ] Set initial worker pool size based on load estimates
- [ ] Configure monitoring dashboards
- [ ] Set up alerts for key metrics
- [ ] Document rollback procedure
- [ ] Prepare load test scenarios

### D.2 Monitoring Setup

```yaml
# Prometheus metrics to track
metrics:
  - name: elixir_scope_layer2_events_processed_total
    type: counter
    description: Total events processed
    
  - name: elixir_scope_layer2_processing_duration_seconds
    type: histogram
    description: Event processing duration
    
  - name: elixir_scope_layer2_correlation_success_rate
    type: gauge
    description: Percentage of successfully correlated events
    
  - name: elixir_scope_layer2_worker_pool_size
    type: gauge
    description: Current number of active workers
    
  - name: elixir_scope_layer2_buffer_utilization_percent
    type: gauge
    description: Ring buffer utilization percentage

# Grafana dashboard panels
dashboards:
  - title: "Layer 2 Overview"
    panels:
      - "Events/sec (rate)"
      - "Processing Latency (p50, p95, p99)"
      - "Worker Pool Status"
      - "Correlation Success Rate"
      - "Buffer Utilization"
      - "Memory Usage"
```

### D.3 Capacity Planning

```elixir
defmodule ElixirScope.CapacityPlanning do
  @doc """
  Calculate required resources based on expected load
  """
  def calculate_requirements(events_per_second) do
    %{
      min_workers: calculate_min_workers(events_per_second),
      recommended_workers: calculate_recommended_workers(events_per_second),
      ets_memory_mb: estimate_ets_memory(events_per_second),
      ring_buffer_size: calculate_buffer_size(events_per_second),
      correlation_ttl_seconds: calculate_correlation_ttl(events_per_second)
    }
  end

  defp calculate_min_workers(eps) do
    # Assume each worker can process 2000 events/sec
    max(2, div(eps, 2000))
  end

  defp calculate_recommended_workers(eps) do
    # Add 50% headroom
    max(4, div(eps * 3, 2000 * 2))
  end

  defp estimate_ets_memory(eps) do
    # Assume 1KB per event, 5 minute retention
    events_in_memory = eps * 300
    div(events_in_memory, 1000)  # MB
  end
end
```

## Conclusion

This comprehensive guide provides all the technical details needed to implement Layer 2 of ElixirScope. The key to success is maintaining the balance between performance (processing 10k+ events/sec) and functionality (accurate correlation, resilience, scalability).

Start with the basic pipeline, add correlation incrementally, and continuously measure performance. The modular design allows for iterative improvement without disrupting the overall system.

Remember that Layer 2 is the bridge between the ultra-fast capture of Layer 1 and the rich querying capabilities that will be built on top. Getting this layer right is crucial for the success of the entire ElixirScope system.