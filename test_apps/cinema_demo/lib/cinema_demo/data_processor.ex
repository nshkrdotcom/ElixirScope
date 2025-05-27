defmodule CinemaDemo.DataProcessor do
  @moduledoc """
  A data processing worker that demonstrates complex data transformations
  and function call patterns for ElixirScope temporal debugging.
  
  This module showcases:
  - Data transformation pipelines
  - Pattern matching complexity
  - Recursive operations
  - Error recovery patterns
  - Performance optimization scenarios
  """
  
  use GenServer
  require Logger
  
  defstruct [
    :processing_queue,
    :results_cache,
    :stats,
    :config
  ]
  
  @type data_item :: %{
    id: binary(),
    type: atom(),
    payload: term(),
    metadata: map(),
    created_at: integer()
  }
  
  @type processing_result :: %{
    original_id: binary(),
    processed_data: term(),
    processing_time: integer(),
    transformations_applied: [atom()],
    success: boolean(),
    error: term() | nil
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def process_data(data_item) do
    GenServer.call(__MODULE__, {:process_data, data_item})
  end
  
  def process_batch(data_items) when is_list(data_items) do
    GenServer.call(__MODULE__, {:process_batch, data_items}, 30_000)
  end
  
  def get_result(data_id) do
    GenServer.call(__MODULE__, {:get_result, data_id})
  end
  
  def get_stats() do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  def clear_cache() do
    GenServer.cast(__MODULE__, :clear_cache)
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    state = %__MODULE__{
      processing_queue: :queue.new(),
      results_cache: %{},
      stats: initialize_processing_stats(),
      config: %{
        max_cache_size: 1000,
        batch_size: 50,
        timeout_ms: 5000
      }
    }
    
    Logger.info("DataProcessor started")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:process_data, data_item}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    
    try do
      # Validate input data
      validated_data = validate_data_item(data_item)
      
      # Apply transformation pipeline
      result = apply_transformation_pipeline(validated_data)
      
      # Calculate processing time
      processing_time = System.monotonic_time(:microsecond) - start_time
      
      # Create result record
      processing_result = %{
        original_id: data_item.id,
        processed_data: result.data,
        processing_time: processing_time,
        transformations_applied: result.transformations,
        success: true,
        error: nil
      }
      
      # Cache result
      new_cache = cache_result(state.results_cache, data_item.id, processing_result, state.config)
      
      # Update stats
      new_stats = update_processing_stats(state.stats, :success, processing_time)
      
      new_state = %{state | results_cache: new_cache, stats: new_stats}
      
      Logger.debug("Processed data item #{data_item.id} in #{processing_time}μs")
      {:reply, {:ok, processing_result}, new_state}
      
    rescue
      error ->
        processing_time = System.monotonic_time(:microsecond) - start_time
        
        error_result = %{
          original_id: data_item.id,
          processed_data: nil,
          processing_time: processing_time,
          transformations_applied: [],
          success: false,
          error: error
        }
        
        new_stats = update_processing_stats(state.stats, :error, processing_time)
        new_state = %{state | stats: new_stats}
        
        Logger.warning("Failed to process data item #{data_item.id}: #{inspect(error)}")
        {:reply, {:error, error_result}, new_state}
    end
  end
  
  @impl true
  def handle_call({:process_batch, data_items}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    
    # Process items in parallel using Task.async_stream
    results = data_items
    |> Task.async_stream(
      fn item -> process_single_item_in_batch(item) end,
      max_concurrency: System.schedulers_online(),
      timeout: state.config.timeout_ms
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, reason}
    end)
    
    processing_time = System.monotonic_time(:microsecond) - start_time
    
    # Separate successful and failed results
    {successful, failed} = Enum.split_with(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    # Update cache with successful results
    new_cache = Enum.reduce(successful, state.results_cache, fn {:ok, result}, cache ->
      cache_result(cache, result.original_id, result, state.config)
    end)
    
    # Update stats
    new_stats = state.stats
    |> update_processing_stats(:batch_success, length(successful))
    |> update_processing_stats(:batch_error, length(failed))
    |> Map.put(:last_batch_time, processing_time)
    
    new_state = %{state | results_cache: new_cache, stats: new_stats}
    
    batch_result = %{
      total_items: length(data_items),
      successful: length(successful),
      failed: length(failed),
      processing_time: processing_time,
      results: results
    }
    
    Logger.info("Processed batch of #{length(data_items)} items: #{length(successful)} successful, #{length(failed)} failed")
    {:reply, {:ok, batch_result}, new_state}
  end
  
  @impl true
  def handle_call({:get_result, data_id}, _from, state) do
    result = Map.get(state.results_cache, data_id)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    current_stats = calculate_current_stats(state)
    {:reply, current_stats, state}
  end
  
  @impl true
  def handle_cast(:clear_cache, state) do
    new_state = %{state | results_cache: %{}}
    Logger.info("Cleared results cache")
    {:noreply, new_state}
  end
  
  # Private Functions - Data Validation
  
  defp validate_data_item(%{id: id, type: type, payload: payload} = item) 
       when is_binary(id) and is_atom(type) do
    # Perform type-specific validation
    case validate_payload_by_type(type, payload) do
      :ok -> item
      {:error, reason} -> raise ArgumentError, "Invalid payload for type #{type}: #{reason}"
    end
  end
  
  defp validate_data_item(_item) do
    raise ArgumentError, "Data item must have id (binary), type (atom), and payload fields"
  end
  
  defp validate_payload_by_type(:json, payload) when is_map(payload), do: :ok
  defp validate_payload_by_type(:text, payload) when is_binary(payload), do: :ok
  defp validate_payload_by_type(:numeric, payload) when is_number(payload), do: :ok
  defp validate_payload_by_type(:list, payload) when is_list(payload), do: :ok
  defp validate_payload_by_type(type, _payload), do: {:error, "unsupported type: #{type}"}
  
  # Private Functions - Transformation Pipeline
  
  defp apply_transformation_pipeline(data_item) do
    transformations = determine_transformations(data_item.type)
    
    result = Enum.reduce(transformations, %{data: data_item.payload, transformations: []}, 
      fn transformation, acc ->
        transformed_data = apply_single_transformation(transformation, acc.data, data_item)
        %{
          data: transformed_data,
          transformations: [transformation | acc.transformations]
        }
      end)
    
    %{result | transformations: Enum.reverse(result.transformations)}
  end
  
  defp determine_transformations(:json) do
    [:normalize_keys, :validate_schema, :enrich_metadata, :compress_if_large]
  end
  
  defp determine_transformations(:text) do
    [:trim_whitespace, :normalize_encoding, :extract_keywords, :calculate_metrics]
  end
  
  defp determine_transformations(:numeric) do
    [:validate_range, :apply_scaling, :calculate_statistics]
  end
  
  defp determine_transformations(:list) do
    [:deduplicate, :sort_elements, :chunk_if_large, :calculate_aggregates]
  end
  
  defp determine_transformations(_type) do
    [:basic_validation, :add_timestamp]
  end
  
  defp apply_single_transformation(:normalize_keys, data, _item) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> {normalize_key(k), v} end)
    |> Map.new()
  end
  
  defp apply_single_transformation(:validate_schema, data, _item) when is_map(data) do
    # Simulate schema validation
    required_fields = [:id, :timestamp]
    
    Enum.reduce(required_fields, data, fn field, acc ->
      if Map.has_key?(acc, field) do
        acc
      else
        Map.put(acc, field, generate_default_value(field))
      end
    end)
  end
  
  defp apply_single_transformation(:enrich_metadata, data, item) when is_map(data) do
    metadata = %{
      processed_at: System.system_time(:millisecond),
      original_type: item.type,
      size_bytes: estimate_size(data),
      complexity_score: calculate_complexity(data)
    }
    
    Map.put(data, :_metadata, metadata)
  end
  
  defp apply_single_transformation(:compress_if_large, data, _item) do
    estimated_size = estimate_size(data)
    
    if estimated_size > 1024 do
      # Simulate compression by removing some fields
      compress_large_data(data)
    else
      data
    end
  end
  
  defp apply_single_transformation(:trim_whitespace, data, _item) when is_binary(data) do
    String.trim(data)
  end
  
  defp apply_single_transformation(:normalize_encoding, data, _item) when is_binary(data) do
    # Simulate encoding normalization
    data
    |> String.normalize(:nfc)
    |> String.downcase()
  end
  
  defp apply_single_transformation(:extract_keywords, data, _item) when is_binary(data) do
    words = String.split(data, ~r/\W+/, trim: true)
    keywords = words |> Enum.frequencies() |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(10)
    
    %{
      original_text: data,
      word_count: length(words),
      keywords: keywords,
      character_count: String.length(data)
    }
  end
  
  defp apply_single_transformation(:calculate_metrics, data, _item) when is_map(data) do
    metrics = %{
      complexity: calculate_text_complexity(data.original_text),
      readability: calculate_readability_score(data.original_text),
      sentiment: analyze_sentiment(data.original_text)
    }
    
    Map.put(data, :metrics, metrics)
  end
  
  defp apply_single_transformation(:validate_range, data, _item) when is_number(data) do
    cond do
      data < -1_000_000 -> -1_000_000
      data > 1_000_000 -> 1_000_000
      true -> data
    end
  end
  
  defp apply_single_transformation(:apply_scaling, data, _item) when is_number(data) do
    # Apply logarithmic scaling for large numbers
    if abs(data) > 1000 do
      sign = if data >= 0, do: 1, else: -1
      sign * :math.log10(abs(data) + 1) * 100
    else
      data
    end
  end
  
  defp apply_single_transformation(:calculate_statistics, data, _item) when is_number(data) do
    %{
      value: data,
      absolute: abs(data),
      squared: data * data,
      is_prime: is_prime?(round(abs(data))),
      digit_sum: calculate_digit_sum(round(abs(data)))
    }
  end
  
  defp apply_single_transformation(:deduplicate, data, _item) when is_list(data) do
    Enum.uniq(data)
  end
  
  defp apply_single_transformation(:sort_elements, data, _item) when is_list(data) do
    Enum.sort(data)
  end
  
  defp apply_single_transformation(:chunk_if_large, data, _item) when is_list(data) do
    if length(data) > 100 do
      Enum.chunk_every(data, 50)
    else
      data
    end
  end
  
  defp apply_single_transformation(:calculate_aggregates, data, _item) when is_list(data) do
    numeric_items = Enum.filter(data, &is_number/1)
    
    %{
      original_list: data,
      count: length(data),
      numeric_count: length(numeric_items),
      sum: if(length(numeric_items) > 0, do: Enum.sum(numeric_items), else: 0),
      average: if(length(numeric_items) > 0, do: Enum.sum(numeric_items) / length(numeric_items), else: 0),
      unique_count: length(Enum.uniq(data))
    }
  end
  
  defp apply_single_transformation(:basic_validation, data, _item) do
    %{
      original: data,
      validated_at: System.system_time(:millisecond),
      type: determine_data_type(data)
    }
  end
  
  defp apply_single_transformation(:add_timestamp, data, _item) do
    if is_map(data) do
      Map.put(data, :processed_timestamp, System.system_time(:millisecond))
    else
      %{data: data, processed_timestamp: System.system_time(:millisecond)}
    end
  end
  
  defp apply_single_transformation(_transformation, data, _item) do
    # Fallback for unknown transformations
    data
  end
  
  # Helper Functions
  
  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key) do
    key
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]/, "_")
    |> String.to_atom()
  end
  defp normalize_key(key), do: key
  
  defp generate_default_value(:id), do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  defp generate_default_value(:timestamp), do: System.system_time(:millisecond)
  defp generate_default_value(_field), do: nil
  
  defp estimate_size(data) do
    data |> :erlang.term_to_binary() |> byte_size()
  end
  
  defp calculate_complexity(data) when is_map(data) do
    map_size(data) + Enum.sum(Enum.map(data, fn {_k, v} -> calculate_complexity(v) end))
  end
  defp calculate_complexity(data) when is_list(data) do
    length(data) + Enum.sum(Enum.map(data, &calculate_complexity/1))
  end
  defp calculate_complexity(_data), do: 1
  
  defp compress_large_data(data) when is_map(data) do
    # Remove metadata and keep only essential fields
    essential_fields = [:id, :timestamp, :value, :name, :type]
    Map.take(data, essential_fields)
  end
  
  defp calculate_text_complexity(text) when is_binary(text) do
    words = String.split(text, ~r/\W+/, trim: true)
    avg_word_length = if length(words) > 0 do
      Enum.sum(Enum.map(words, &String.length/1)) / length(words)
    else
      0
    end
    
    sentence_count = length(String.split(text, ~r/[.!?]+/, trim: true))
    
    %{
      word_count: length(words),
      sentence_count: sentence_count,
      avg_word_length: avg_word_length,
      words_per_sentence: if(sentence_count > 0, do: length(words) / sentence_count, else: 0)
    }
  end
  
  defp calculate_readability_score(text) when is_binary(text) do
    # Simplified readability score
    complexity = calculate_text_complexity(text)
    
    cond do
      complexity.avg_word_length < 4 and complexity.words_per_sentence < 10 -> :easy
      complexity.avg_word_length < 6 and complexity.words_per_sentence < 15 -> :medium
      true -> :hard
    end
  end
  
  defp analyze_sentiment(text) when is_binary(text) do
    # Very basic sentiment analysis
    positive_words = ["good", "great", "excellent", "amazing", "wonderful", "fantastic"]
    negative_words = ["bad", "terrible", "awful", "horrible", "disappointing", "poor"]
    
    words = String.split(String.downcase(text), ~r/\W+/, trim: true)
    
    positive_count = Enum.count(words, &(&1 in positive_words))
    negative_count = Enum.count(words, &(&1 in negative_words))
    
    cond do
      positive_count > negative_count -> :positive
      negative_count > positive_count -> :negative
      true -> :neutral
    end
  end
  
  defp is_prime?(n) when n < 2, do: false
  defp is_prime?(2), do: true
  defp is_prime?(n) when rem(n, 2) == 0, do: false
  defp is_prime?(n) do
    limit = round(:math.sqrt(n))
    not Enum.any?(3..limit//2, &(rem(n, &1) == 0))
  end
  
  defp calculate_digit_sum(n) when n < 10, do: n
  defp calculate_digit_sum(n) do
    rem(n, 10) + calculate_digit_sum(div(n, 10))
  end
  
  defp determine_data_type(data) when is_map(data), do: :map
  defp determine_data_type(data) when is_list(data), do: :list
  defp determine_data_type(data) when is_binary(data), do: :string
  defp determine_data_type(data) when is_number(data), do: :number
  defp determine_data_type(data) when is_atom(data), do: :atom
  defp determine_data_type(_data), do: :unknown
  
  defp process_single_item_in_batch(item) do
    # Simplified processing for batch operations
    start_time = System.monotonic_time(:microsecond)
    
    try do
      validated_data = validate_data_item(item)
      result = apply_transformation_pipeline(validated_data)
      processing_time = System.monotonic_time(:microsecond) - start_time
      
      {:ok, %{
        original_id: item.id,
        processed_data: result.data,
        processing_time: processing_time,
        transformations_applied: result.transformations,
        success: true,
        error: nil
      }}
    rescue
      error ->
        processing_time = System.monotonic_time(:microsecond) - start_time
        
        {:error, %{
          original_id: item.id,
          processed_data: nil,
          processing_time: processing_time,
          transformations_applied: [],
          success: false,
          error: error
        }}
    end
  end
  
  defp cache_result(cache, id, result, config) do
    new_cache = Map.put(cache, id, result)
    
    # Limit cache size
    if map_size(new_cache) > config.max_cache_size do
      # Remove oldest entries (simplified LRU)
      new_cache
      |> Enum.take(config.max_cache_size)
      |> Map.new()
    else
      new_cache
    end
  end
  
  defp initialize_processing_stats do
    %{
      items_processed: 0,
      items_failed: 0,
      total_processing_time: 0,
      average_processing_time: 0.0,
      batches_processed: 0,
      cache_hits: 0,
      cache_misses: 0,
      last_batch_time: 0
    }
  end
  
  defp update_processing_stats(stats, event, value) when is_integer(value) do
    case event do
      :success ->
        new_count = stats.items_processed + 1
        new_total_time = stats.total_processing_time + value
        %{stats | 
          items_processed: new_count,
          total_processing_time: new_total_time,
          average_processing_time: new_total_time / new_count
        }
      
      :error ->
        %{stats | items_failed: stats.items_failed + 1}
      
      :batch_success ->
        %{stats | 
          items_processed: stats.items_processed + value,
          batches_processed: stats.batches_processed + 1
        }
      
      :batch_error ->
        %{stats | items_failed: stats.items_failed + value}
      
      :cache_hit ->
        %{stats | cache_hits: stats.cache_hits + 1}
      
      :cache_miss ->
        %{stats | cache_misses: stats.cache_misses + 1}
    end
  end
  
  defp calculate_current_stats(state) do
    cache_size = map_size(state.results_cache)
    queue_size = :queue.len(state.processing_queue)
    
    Map.merge(state.stats, %{
      cache_size: cache_size,
      queue_size: queue_size,
      cache_hit_rate: if(state.stats.cache_hits + state.stats.cache_misses > 0,
                        do: state.stats.cache_hits / (state.stats.cache_hits + state.stats.cache_misses),
                        else: 0.0)
    })
  end
end 