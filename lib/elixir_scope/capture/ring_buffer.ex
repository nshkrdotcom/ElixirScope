defmodule ElixirScope.Capture.RingBuffer do
  @moduledoc """
  High-performance lock-free ring buffer for event ingestion.
  
  Uses :atomics for lock-free operations and :persistent_term for metadata storage.
  Designed for >100k events/sec throughput with bounded memory usage.
  
  Key features:
  - Lock-free writes using atomic compare-and-swap
  - Bounded memory with configurable overflow behavior
  - Multiple reader support with position tracking
  - Minimal allocation overhead
  - Graceful degradation under extreme load
  """

  import Bitwise
  alias ElixirScope.Events

  @type buffer_id :: atom()
  @type position :: non_neg_integer()
  @type overflow_strategy :: :drop_oldest | :drop_newest | :block

  @default_size 1024  # 1K events, power of 2 for efficient modulo (reduced for memory)
  @default_overflow :drop_oldest

  defstruct [
    :id,
    :size,
    :mask,
    :overflow_strategy,
    :atomics_ref,
    :buffer_table
  ]

  @type t :: %__MODULE__{
    id: buffer_id(),
    size: pos_integer(),
    mask: non_neg_integer(),
    overflow_strategy: overflow_strategy(),
    atomics_ref: :atomics.atomics_ref(),
    buffer_table: :ets.tab()
  }

  # Atomic indices
  @write_pos 1
  @read_pos 2
  @total_writes 3
  @total_reads 4
  @dropped_events 5

  @doc """
  Creates a new ring buffer with the specified configuration.
  
  ## Options
  - `:size` - Buffer size (must be power of 2, default: #{@default_size})
  - `:overflow_strategy` - What to do when buffer is full (default: #{@default_overflow})
  - `:name` - Optional name for the buffer (default: generates unique name)
  
  ## Examples
      iex> {:ok, buffer} = RingBuffer.new(size: 1024)
      iex> RingBuffer.size(buffer)
      1024
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(opts \\ []) do
    size = Keyword.get(opts, :size, @default_size)
    overflow_strategy = Keyword.get(opts, :overflow_strategy, @default_overflow)
    name = Keyword.get(opts, :name, generate_buffer_name())

    with :ok <- validate_size(size),
         :ok <- validate_overflow_strategy(overflow_strategy) do
      
      # Create atomics for lock-free operations
      atomics_ref = :atomics.new(5, [])
      
      # Initialize positions
      :atomics.put(atomics_ref, @write_pos, 0)
      :atomics.put(atomics_ref, @read_pos, 0)
      :atomics.put(atomics_ref, @total_writes, 0)
      :atomics.put(atomics_ref, @total_reads, 0)
      :atomics.put(atomics_ref, @dropped_events, 0)

      # Create ETS table for buffer storage
      table_name = :"elixir_scope_buffer_#{name}"
      buffer_table = :ets.new(table_name, [:public, :set, {:read_concurrency, true}])
      
      buffer = %__MODULE__{
        id: name,
        size: size,
        mask: size - 1,  # For efficient modulo with power of 2
        overflow_strategy: overflow_strategy,
        atomics_ref: atomics_ref,
        buffer_table: buffer_table
      }
      
      {:ok, buffer}
    end
  end

  @doc """
  Writes an event to the ring buffer.
  
  This is the critical hot path - optimized for minimal latency.
  Target: <1µs per write operation.
  
  ## Examples
      iex> {:ok, buffer} = RingBuffer.new()
      iex> event = %Events.FunctionExecution{function: :test}
      iex> :ok = RingBuffer.write(buffer, event)
  """
  @spec write(t(), Events.event()) :: :ok | {:error, :buffer_full}
  def write(%__MODULE__{} = buffer, event) do
    # Fast path: try to claim a write position
    case claim_write_position(buffer) do
      {:ok, position} ->
        # Write event to claimed position
        index = position &&& buffer.mask
        
        # Store event in ETS table
        :ets.insert(buffer.buffer_table, {index, event})
        
        # Increment total writes counter
        :atomics.add(buffer.atomics_ref, @total_writes, 1)
        :ok
        
      {:error, :buffer_full} ->
        handle_overflow(buffer, event)
    end
  end

  @doc """
  Reads the next available event from the buffer.
  
  Returns `{:ok, event, new_position}` or `:empty` if no events available.
  """
  @spec read(t(), position()) :: {:ok, Events.event(), position()} | :empty
  def read(%__MODULE__{} = buffer, read_position \\ 0) do
    write_pos = :atomics.get(buffer.atomics_ref, @write_pos)
    
    if read_position < write_pos do
      index = read_position &&& buffer.mask
      
      case :ets.lookup(buffer.buffer_table, index) do
        [{^index, event}] ->
          :atomics.add(buffer.atomics_ref, @total_reads, 1)
          {:ok, event, read_position + 1}
        [] -> 
          # This shouldn't happen if write_pos is accurate, but be defensive
          :empty
      end
    else
      :empty
    end
  end

  @doc """
  Reads multiple events in batch for better throughput.
  
  Returns `{events, new_position}` where events is a list of up to `count` events.
  """
  @spec read_batch(t(), position(), pos_integer()) :: {[Events.event()], position()}
  def read_batch(%__MODULE__{} = buffer, start_position, count) do
    write_pos = :atomics.get(buffer.atomics_ref, @write_pos)
    available = max(0, write_pos - start_position)
    to_read = min(count, available)
    
    if to_read > 0 do
      events = for offset <- 0..(to_read - 1) do
        position = start_position + offset
        index = position &&& buffer.mask
        case :ets.lookup(buffer.buffer_table, index) do
          [{^index, event}] -> event
          [] -> nil
        end
      end
      
      # Filter out any nil values (shouldn't happen but defensive)
      valid_events = Enum.reject(events, &is_nil/1)
      
      :atomics.add(buffer.atomics_ref, @total_reads, length(valid_events))
      {valid_events, start_position + to_read}
    else
      {[], start_position}
    end
  end

  @doc """
  Gets current buffer statistics.
  """
  @spec stats(t()) :: %{
    size: pos_integer(),
    write_position: position(),
    read_position: position(),
    available_events: non_neg_integer(),
    total_writes: non_neg_integer(),
    total_reads: non_neg_integer(),
    dropped_events: non_neg_integer(),
    utilization: float()
  }
  def stats(%__MODULE__{} = buffer) do
    write_pos = :atomics.get(buffer.atomics_ref, @write_pos)
    read_pos = :atomics.get(buffer.atomics_ref, @read_pos)
    total_writes = :atomics.get(buffer.atomics_ref, @total_writes)
    total_reads = :atomics.get(buffer.atomics_ref, @total_reads)
    dropped = :atomics.get(buffer.atomics_ref, @dropped_events)
    
    available = max(0, write_pos - read_pos)
    utilization = if buffer.size > 0, do: available / buffer.size, else: 0.0
    
    %{
      size: buffer.size,
      write_position: write_pos,
      read_position: read_pos,
      available_events: available,
      total_writes: total_writes,
      total_reads: total_reads,
      dropped_events: dropped,
      utilization: utilization
    }
  end

  @doc """
  Returns the buffer size.
  """
  @spec size(t()) :: pos_integer()
  def size(%__MODULE__{size: size}), do: size

  @doc """
  Clears all events from the buffer and resets counters.
  """
  @spec clear(t()) :: :ok
  def clear(%__MODULE__{} = buffer) do
    # Reset all atomic counters
    :atomics.put(buffer.atomics_ref, @write_pos, 0)
    :atomics.put(buffer.atomics_ref, @read_pos, 0)
    :atomics.put(buffer.atomics_ref, @total_writes, 0)
    :atomics.put(buffer.atomics_ref, @total_reads, 0)
    :atomics.put(buffer.atomics_ref, @dropped_events, 0)
    
    # Clear ETS table
    :ets.delete_all_objects(buffer.buffer_table)
    
    :ok
  end

  @doc """
  Destroys the buffer and cleans up resources.
  """
  @spec destroy(t()) :: :ok
  def destroy(%__MODULE__{} = buffer) do
    :ets.delete(buffer.buffer_table)
    :ok
  end

  # Private functions

  defp claim_write_position(%__MODULE__{} = buffer) do
    write_pos = :atomics.get(buffer.atomics_ref, @write_pos)
    read_pos = :atomics.get(buffer.atomics_ref, @read_pos)
    
    # Check if buffer is full
    if write_pos - read_pos >= buffer.size do
      {:error, :buffer_full}
    else
      # Try to atomically increment write position
      case :atomics.compare_exchange(buffer.atomics_ref, @write_pos, write_pos, write_pos + 1) do
        :ok -> {:ok, write_pos}
        _ -> 
          # Another process claimed this position, retry
          claim_write_position(buffer)
      end
    end
  end

  defp handle_overflow(%__MODULE__{overflow_strategy: :drop_newest}, _event) do
    # Simply drop the new event
    {:error, :buffer_full}
  end

  defp handle_overflow(%__MODULE__{overflow_strategy: :drop_oldest} = buffer, event) do
    # Advance read position to make room
    :atomics.add(buffer.atomics_ref, @read_pos, 1)
    :atomics.add(buffer.atomics_ref, @dropped_events, 1)
    
    # Retry the write
    write(buffer, event)
  end

  defp handle_overflow(%__MODULE__{overflow_strategy: :block}, _event) do
    # For now, just return error. In future could implement backpressure
    {:error, :buffer_full}
  end

  defp validate_size(size) when is_integer(size) and size > 0 do
    # Must be power of 2 for efficient modulo operations
    if (size &&& (size - 1)) == 0 do
      :ok
    else
      {:error, :size_must_be_power_of_2}
    end
  end
  defp validate_size(_), do: {:error, :invalid_size}

  defp validate_overflow_strategy(strategy) when strategy in [:drop_oldest, :drop_newest, :block] do
    :ok
  end
  defp validate_overflow_strategy(_), do: {:error, :invalid_overflow_strategy}

  defp generate_buffer_name do
    :"buffer_#{System.unique_integer([:positive])}"
  end
end 