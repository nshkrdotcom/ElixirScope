defmodule ElixirScope.Capture.EventCorrelator do
  @moduledoc """
  EventCorrelator establishes causal relationships between events in the ElixirScope
  execution cinema system.

  Key responsibilities:
  - Correlate function call entry/exit events using call stacks
  - Correlate message send/receive events
  - Maintain correlation state with automatic cleanup
  - Provide correlation chains for debugging and analysis
  - Track correlation metrics and health status

  The correlator uses ETS tables for fast correlation state management:
  - Call stacks per process for function correlation
  - Message registry for message correlation
  - Correlation metadata for tracking and cleanup
  - Correlation links for establishing relationships

  Performance targets:
  - <500ns per event correlation
  - Support for 10,000+ events/second
  - Memory-bounded with automatic cleanup
  """

  use GenServer
  require Logger

  alias ElixirScope.Events
  alias ElixirScope.Utils

  # Default configuration
  @default_config %{
    cleanup_interval_ms: 60_000,    # Clean up every minute
    correlation_ttl_ms: 300_000,    # 5 minute TTL for correlations
    max_correlations: 100_000       # Maximum active correlations
  }

  defstruct [
    :config,
    :call_stacks_table,
    :message_registry_table,
    :correlation_metadata_table,
    :correlation_links_table,
    :start_time,
    :stats
  ]

  defmodule CorrelatedEvent do
    @moduledoc """
    Enhanced event structure with correlation metadata and causal links.
    """
    defstruct [
      :event,                    # Original event
      :correlation_id,           # Unique correlation ID
      :parent_id,               # Parent correlation ID (for nested calls)
      :root_id,                 # Root correlation ID (for call chains)
      :links,                   # List of causal links: [{type, target_id}]
      :correlation_type,        # Type of correlation
      :correlated_at,          # When correlation was established
      :correlation_confidence  # Confidence level (0.0 - 1.0)
    ]
  end

  ## Public API

  @doc """
  Starts the EventCorrelator with the given configuration.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Correlates a single event, establishing causal relationships.
  """
  def correlate_event(pid, event) do
    GenServer.call(pid, {:correlate_event, event})
  end

  @doc """
  Correlates multiple events in batch for better performance.
  """
  def correlate_batch(pid, events) do
    GenServer.call(pid, {:correlate_batch, events})
  end

  @doc """
  Gets correlation metadata for a given correlation ID.
  """
  def get_correlation_metadata(pid, correlation_id) do
    GenServer.call(pid, {:get_correlation_metadata, correlation_id})
  end

  @doc """
  Gets the correlation chain for a given correlation ID.
  """
  def get_correlation_chain(pid, correlation_id) do
    GenServer.call(pid, {:get_correlation_chain, correlation_id})
  end

  @doc """
  Manually triggers cleanup of expired correlations.
  """
  def cleanup_expired_correlations(pid) do
    GenServer.call(pid, :cleanup_expired_correlations)
  end

  @doc """
  Gets correlation metrics.
  """
  def get_metrics(pid) do
    GenServer.call(pid, :get_metrics)
  end

  @doc """
  Performs a health check.
  """
  def health_check(pid) do
    GenServer.call(pid, :health_check)
  end

  @doc """
  Gets the current state (for testing).
  """
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Gracefully stops the correlator.
  """
  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  ## GenServer Implementation

  @impl true
  def init(opts) do
    # Merge with defaults
    config = case opts do
      [] -> @default_config
      %{} = config_map -> Map.merge(@default_config, config_map)
      _other -> @default_config
    end

    # Create ETS tables for correlation state
    call_stacks_table = :ets.new(:call_stacks, [:set, :public])
    message_registry_table = :ets.new(:message_registry, [:set, :public])
    correlation_metadata_table = :ets.new(:correlation_metadata, [:set, :public, {:write_concurrency, true}])
    correlation_links_table = :ets.new(:correlation_links, [:bag, :public])

    # Initialize stats
    stats = %{
      total_correlations_created: 0,
      function_correlations: 0,
      message_correlations: 0,
      total_correlation_time_ns: 0
    }

    state = %__MODULE__{
      config: config,
      call_stacks_table: call_stacks_table,
      message_registry_table: message_registry_table,
      correlation_metadata_table: correlation_metadata_table,
      correlation_links_table: correlation_links_table,
      start_time: Utils.monotonic_timestamp(),
      stats: stats
    }

    # Schedule periodic cleanup
    schedule_cleanup(config.cleanup_interval_ms)

    Logger.debug("EventCorrelator started with config: #{inspect(config)}")

    {:ok, state}
  end

  @impl true
  def handle_call({:correlate_event, event}, _from, state) do
    start_time = System.monotonic_time()
    
    correlated_event = correlate_single_event(event, state)
    
    # Update stats
    correlation_time = System.monotonic_time() - start_time
    updated_stats = update_correlation_stats(state.stats, correlated_event.correlation_type, correlation_time)
    updated_state = %{state | stats: updated_stats}

    {:reply, correlated_event, updated_state}
  end

  @impl true
  def handle_call({:correlate_batch, events}, _from, state) do
    start_time = System.monotonic_time()
    
    correlated_events = Enum.map(events, &correlate_single_event(&1, state))
    
    # Update batch stats
    correlation_time = System.monotonic_time() - start_time
    avg_time_per_event = correlation_time / length(events)
    
    updated_stats = Enum.reduce(correlated_events, state.stats, fn correlated, acc_stats ->
      update_correlation_stats(acc_stats, correlated.correlation_type, avg_time_per_event)
    end)
    
    updated_state = %{state | stats: updated_stats}

    {:reply, correlated_events, updated_state}
  end

  @impl true
  def handle_call({:get_correlation_metadata, correlation_id}, _from, state) do
    metadata = case :ets.lookup(state.correlation_metadata_table, correlation_id) do
      [{^correlation_id, metadata}] -> metadata
      [] -> nil
    end

    {:reply, metadata, state}
  end

  @impl true
  def handle_call({:get_correlation_chain, correlation_id}, _from, state) do
    chain = build_correlation_chain(correlation_id, state, [])
    {:reply, chain, state}
  end

  @impl true
  def handle_call(:cleanup_expired_correlations, _from, state) do
    cleaned_count = perform_cleanup(state)
    {:reply, {:ok, cleaned_count}, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    active_correlations = :ets.info(state.correlation_metadata_table, :size)
    avg_correlation_time = if state.stats.total_correlations_created > 0 do
      state.stats.total_correlation_time_ns / state.stats.total_correlations_created
    else
      0.0
    end

    metrics = %{
      total_correlations_created: state.stats.total_correlations_created,
      active_correlations: active_correlations,
      function_correlations: state.stats.function_correlations,
      message_correlations: state.stats.message_correlations,
      average_correlation_time_ns: avg_correlation_time
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:health_check, _from, state) do
    active_correlations = :ets.info(state.correlation_metadata_table, :size)
    memory_usage = calculate_memory_usage(state)
    uptime_ms = (Utils.monotonic_timestamp() - state.start_time) / 1_000_000

    correlation_rate = if uptime_ms > 0 do
      state.stats.total_correlations_created / (uptime_ms / 1000)
    else
      0.0
    end

    health = %{
      status: :healthy,
      active_correlations: active_correlations,
      memory_usage_bytes: memory_usage,
      uptime_ms: uptime_ms,
      correlation_rate: correlation_rate
    }

    {:reply, health, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:stop, _from, state) do
    Logger.info("EventCorrelator shutting down gracefully")
    cleanup_ets_tables(state)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    perform_cleanup(state)
    schedule_cleanup(state.config.cleanup_interval_ms)
    {:noreply, state}
  end

  ## Private Functions

  defp correlate_single_event(event, state) do
    correlation_start = Utils.monotonic_timestamp()

    case determine_event_type(event) do
      {:function_execution, :call} ->
        correlate_function_call(event, state)

      {:function_execution, :return} ->
        correlate_function_return(event, state)

      {:message, :send} ->
        correlate_message_send(event, state)

      {:message, :receive} ->
        correlate_message_receive(event, state)

      :unknown ->
                 # Create a low-confidence correlation for unknown events
         %CorrelatedEvent{
           event: event,
           correlation_id: Utils.generate_id(),
          parent_id: nil,
          root_id: nil,
          links: [],
          correlation_type: :unknown,
          correlated_at: correlation_start,
          correlation_confidence: 0.1
        }
    end
  end

  defp determine_event_type(%Events.FunctionExecution{event_type: :call}), do: {:function_execution, :call}
  defp determine_event_type(%Events.FunctionExecution{event_type: :return}), do: {:function_execution, :return}
  defp determine_event_type(%Events.MessageEvent{event_type: :send}), do: {:message, :send}
  defp determine_event_type(%Events.MessageEvent{event_type: :receive}), do: {:message, :receive}
  defp determine_event_type(_), do: :unknown

  defp correlate_function_call(event, state) do
    correlation_id = Utils.generate_id()  # Use generate_id instead of generate_correlation_id
    pid = extract_pid(event)
    
    # Get current call stack for this process
    current_stack = get_call_stack(state.call_stacks_table, pid)
    parent_id = case current_stack do
      [parent | _] -> parent
      [] -> nil
    end

    # Push this call onto the stack
    push_call_stack(state.call_stacks_table, pid, correlation_id)

    # Store correlation metadata
    metadata = %{
      correlation_id: correlation_id,
      type: :function_call,
      created_at: Utils.monotonic_timestamp(),
      pid: pid,
      module: event.module,
      function: event.function
    }
    :ets.insert(state.correlation_metadata_table, {correlation_id, metadata})

    # Create correlation links
    links = if parent_id do
      :ets.insert(state.correlation_links_table, {correlation_id, {:called_from, parent_id}})
      [{:called_from, parent_id}]
    else
      []
    end

    %CorrelatedEvent{
      event: event,
      correlation_id: correlation_id,
      parent_id: parent_id,
      root_id: find_root_id(parent_id, state) || correlation_id,
      links: links,
      correlation_type: :function_call,
      correlated_at: Utils.monotonic_timestamp(),
      correlation_confidence: 1.0
    }
  end

  defp correlate_function_return(event, state) do
    pid = extract_pid(event)
    
    # Pop the call stack to get the matching call correlation ID
    correlation_id = case event.correlation_id do
      nil ->
        # If no correlation ID provided, pop from stack
        pop_call_stack(state.call_stacks_table, pid)
      
      existing_id ->
        # Use provided correlation ID and remove from stack
        remove_from_call_stack(state.call_stacks_table, pid, existing_id)
        existing_id
    end

    # Create completion link
    links = if correlation_id do
      :ets.insert(state.correlation_links_table, {correlation_id, {:completes, correlation_id}})
      [{:completes, correlation_id}]
    else
      []
    end

    %CorrelatedEvent{
      event: event,
      correlation_id: correlation_id,
      parent_id: nil,
      root_id: correlation_id,
      links: links,
      correlation_type: :function_return,
      correlated_at: Utils.monotonic_timestamp(),
      correlation_confidence: if(correlation_id, do: 1.0, else: 0.5)
    }
  end

  defp correlate_message_send(event, state) do
    correlation_id = Utils.generate_id()
    
    # Register the message for future correlation
    message_signature = create_message_signature(event)
    message_record = %{
      correlation_id: correlation_id,
      from_pid: event.from_pid,
      to_pid: event.to_pid,
      timestamp: event.timestamp,
      signature: message_signature
    }
    
    :ets.insert(state.message_registry_table, {message_signature, message_record})

    # Store correlation metadata
    metadata = %{
      correlation_id: correlation_id,
      type: :message_send,
      created_at: Utils.monotonic_timestamp(),
      pid: event.from_pid
    }
    :ets.insert(state.correlation_metadata_table, {correlation_id, metadata})

    %CorrelatedEvent{
      event: event,
      correlation_id: correlation_id,
      parent_id: nil,
      root_id: correlation_id,
      links: [],
      correlation_type: :message_send,
      correlated_at: Utils.monotonic_timestamp(),
      correlation_confidence: 1.0
    }
  end

  defp correlate_message_receive(event, state) do
    message_signature = create_message_signature(event)
    
    # Look for matching send event
    case :ets.lookup(state.message_registry_table, message_signature) do
      [{^message_signature, message_record}] ->
        # Found matching send
        correlation_id = message_record.correlation_id
        
        # Create receive link
        links = [{:receives, correlation_id}]
        :ets.insert(state.correlation_links_table, {correlation_id, {:received_by, correlation_id}})
        
        %CorrelatedEvent{
          event: event,
          correlation_id: correlation_id,
          parent_id: nil,
          root_id: correlation_id,
          links: links,
          correlation_type: :message_receive,
          correlated_at: Utils.monotonic_timestamp(),
          correlation_confidence: 1.0
        }
      
             [] ->
         # No matching send found
         correlation_id = Utils.generate_id()
        
        metadata = %{
          correlation_id: correlation_id,
          type: :message_receive,
          created_at: Utils.monotonic_timestamp(),
          pid: event.to_pid
        }
        :ets.insert(state.correlation_metadata_table, {correlation_id, metadata})
        
        %CorrelatedEvent{
          event: event,
          correlation_id: correlation_id,
          parent_id: nil,
          root_id: correlation_id,
          links: [],
          correlation_type: :message_receive,
          correlated_at: Utils.monotonic_timestamp(),
          correlation_confidence: 0.5
        }
    end
  end

  defp extract_pid(%Events.FunctionExecution{caller_pid: pid}), do: pid
  defp extract_pid(%Events.MessageEvent{from_pid: pid}), do: pid
  defp extract_pid(_), do: self()

  defp get_call_stack(table, pid) do
    case :ets.lookup(table, pid) do
      [{^pid, stack}] -> stack
      [] -> []
    end
  end

  defp push_call_stack(table, pid, correlation_id) do
    current_stack = get_call_stack(table, pid)
    updated_stack = [correlation_id | current_stack]
    :ets.insert(table, {pid, updated_stack})
  end

  defp pop_call_stack(table, pid) do
    case get_call_stack(table, pid) do
      [top | rest] ->
        :ets.insert(table, {pid, rest})
        top
      [] ->
        nil
    end
  end

  defp remove_from_call_stack(table, pid, correlation_id) do
    current_stack = get_call_stack(table, pid)
    updated_stack = List.delete(current_stack, correlation_id)
    :ets.insert(table, {pid, updated_stack})
  end

  defp create_message_signature(event) do
    # Create a signature based on sender, receiver, and message content hash
    content_hash = :erlang.phash2(event.message)
    {event.from_pid, event.to_pid, content_hash}
  end

  defp find_root_id(nil, _state), do: nil
  defp find_root_id(correlation_id, state) do
    case :ets.lookup(state.correlation_metadata_table, correlation_id) do
      [{^correlation_id, _metadata}] ->
        # Look for parent links
        case :ets.lookup(state.correlation_links_table, correlation_id) do
          [] -> correlation_id  # This is the root
          links ->
            parent_link = Enum.find(links, fn {_, {type, _}} -> type == :called_from end)
            case parent_link do
              {_, {:called_from, parent_id}} -> find_root_id(parent_id, state)
              _ -> correlation_id
            end
        end
      [] ->
        correlation_id
    end
  end

  defp build_correlation_chain(correlation_id, state, acc) do
    case :ets.lookup(state.correlation_metadata_table, correlation_id) do
      [{^correlation_id, metadata}] ->
        new_acc = [metadata | acc]
        
        # Look for parent links
        case :ets.lookup(state.correlation_links_table, correlation_id) do
          [] -> new_acc
          links ->
            parent_link = Enum.find(links, fn {_, {type, _}} -> type == :called_from end)
            case parent_link do
              {_, {:called_from, parent_id}} -> build_correlation_chain(parent_id, state, new_acc)
              _ -> new_acc
            end
        end
      [] ->
        acc
    end
  end

  defp update_correlation_stats(stats, correlation_type, correlation_time) do
    %{stats |
      total_correlations_created: stats.total_correlations_created + 1,
      total_correlation_time_ns: stats.total_correlation_time_ns + correlation_time,
      function_correlations: stats.function_correlations + function_increment(correlation_type),
      message_correlations: stats.message_correlations + message_increment(correlation_type)
    }
  end

  defp function_increment(type) when type in [:function_call, :function_return], do: 1
  defp function_increment(_), do: 0

  defp message_increment(type) when type in [:message_send, :message_receive], do: 1
  defp message_increment(_), do: 0

  defp schedule_cleanup(interval_ms) do
    Process.send_after(self(), :cleanup_expired, interval_ms)
  end

  defp perform_cleanup(state) do
    now = Utils.monotonic_timestamp()
    ttl_threshold = now - (state.config.correlation_ttl_ms * 1_000_000)  # Convert to nanoseconds
    
    # Find expired correlations by iterating through all metadata
    all_correlations = :ets.tab2list(state.correlation_metadata_table)
    
    expired_correlations = 
      all_correlations
      |> Enum.filter(fn {_correlation_id, metadata} ->
        metadata.created_at < ttl_threshold
      end)
      |> Enum.map(fn {correlation_id, _metadata} -> correlation_id end)
    
    # Remove expired correlations
    Enum.each(expired_correlations, fn correlation_id ->
      :ets.delete(state.correlation_metadata_table, correlation_id)
      :ets.delete(state.correlation_links_table, correlation_id)
    end)
    
    # Clean up call stacks and message registry
    cleanup_call_stacks(state.call_stacks_table, expired_correlations)
    cleanup_message_registry(state.message_registry_table, ttl_threshold)
    
    length(expired_correlations)
  end

  defp cleanup_call_stacks(table, expired_correlations) do
    # Remove expired correlation IDs from all call stacks
    all_stacks = :ets.tab2list(table)
    
    Enum.each(all_stacks, fn {pid, stack} ->
      cleaned_stack = Enum.reject(stack, &(&1 in expired_correlations))
      if cleaned_stack != stack do
        :ets.insert(table, {pid, cleaned_stack})
      end
    end)
  end

  defp cleanup_message_registry(table, ttl_threshold) do
    # Remove expired messages from registry
    all_messages = :ets.tab2list(table)
    
    expired_messages = 
      all_messages
      |> Enum.filter(fn {_signature, message_record} ->
        message_record.timestamp < ttl_threshold
      end)
      |> Enum.map(fn {signature, _message_record} -> signature end)
    
    Enum.each(expired_messages, fn signature ->
      :ets.delete(table, signature)
    end)
  end

  defp calculate_memory_usage(state) do
    :ets.info(state.call_stacks_table, :memory) +
    :ets.info(state.message_registry_table, :memory) +
    :ets.info(state.correlation_metadata_table, :memory) +
    :ets.info(state.correlation_links_table, :memory)
  end

  defp cleanup_ets_tables(state) do
    :ets.delete(state.call_stacks_table)
    :ets.delete(state.message_registry_table)
    :ets.delete(state.correlation_metadata_table)
    :ets.delete(state.correlation_links_table)
  end
end 