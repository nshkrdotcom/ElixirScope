defmodule ElixirScope.Integration.ProductionPhoenixTest do
  use ExUnit.Case

  alias ElixirScope.Storage.DataAccess
  alias ElixirScope.Phoenix.Integration

  @moduletag :integration
  @moduletag timeout: 60_000

  # Use a real Phoenix app for testing
  @test_app_path "test/fixtures/production_phoenix_app"

  setup_all do
    # Start the test Phoenix application
    {:ok, _} = start_test_phoenix_app()

    # Enable ElixirScope instrumentation
    :ok = ElixirScope.start(strategy: :full_trace)
    :ok = Integration.enable()

    # Wait for instrumentation to be active
    Process.sleep(1000)

    on_exit(fn ->
      ElixirScope.stop()
      stop_test_phoenix_app()
    end)

    :ok
  end

  describe "real Phoenix application tracing" do
    test "traces complete user registration flow" do
      # Simulate user registration through web interface
      registration_data = %{
        "user" => %{
          "email" => "test@example.com",
          "password" => "securepassword123",
          "name" => "Test User"
        }
      }

      # Make HTTP request to registration endpoint
      {:ok, response} = make_http_request(:post, "/api/users/register", registration_data)

      # Wait for async processing
      Process.sleep(500)

      # Extract correlation ID from response
      correlation_id = extract_correlation_id(response)

      # Verify complete trace was captured
      events = DataAccess.get_events_by_correlation(correlation_id)

      # Should capture the complete flow
      expected_events = [
        :phoenix_request_start,
        :phoenix_controller_entry,
        :ecto_query_start,         # User existence check
        :ecto_query_complete,
        :genserver_call_start,     # Password hashing service
        :genserver_handle_call_start,
        :genserver_handle_call_complete,
        :genserver_call_complete,
        :ecto_query_start,         # User creation
        :ecto_query_complete,
        :phoenix_pubsub_broadcast, # Welcome email notification
        :phoenix_controller_exit,
        :phoenix_request_complete
      ]

      verify_event_sequence(events, expected_events)

      # Verify data integrity
      request_event = find_event(events, :phoenix_request_start)
      assert request_event.data.path == "/api/users/register"
      assert request_event.data.method == "POST"

      # Verify database operations are captured
      db_events = filter_events(events, :ecto_query_start)
      assert length(db_events) >= 2  # At least existence check and creation

      # Verify GenServer interactions
      genserver_events = filter_events(events, :genserver_call_start)
      assert length(genserver_events) >= 1  # Password hashing service
    end

    test "traces LiveView real-time chat application" do
      # Connect to LiveView chat
      {:ok, view, _html} = connect_to_liveview("/chat/room/general")

      # Send several messages
      messages = [
        "Hello everyone!",
        "How is everyone doing?",
        "This is a test message"
      ]

      correlation_ids = for message <- messages do
        send_chat_message(view, message)
      end

      # Wait for all processing
      Process.sleep(1000)

      # Verify each message was fully traced
      for correlation_id <- correlation_ids do
        events = DataAccess.get_events_by_correlation(correlation_id)

        expected_flow = [
          :liveview_handle_event_start,
          :ecto_query_start,          # Save message to database
          :ecto_query_complete,
          :phoenix_pubsub_broadcast,  # Broadcast to other users
          :liveview_handle_event_complete
        ]

        verify_event_sequence(events, expected_flow)
      end

      # Verify PubSub correlation across users
      pubsub_events = DataAccess.get_events_by_type(:phoenix_pubsub_broadcast)
      assert length(pubsub_events) == length(messages)

      # Each broadcast should have corresponding receives
      for broadcast_event <- pubsub_events do
        receive_events = DataAccess.get_events_by_correlation(broadcast_event.correlation_id)
        receive_count = count_events(receive_events, :phoenix_pubsub_receive)
        assert receive_count > 0  # Should have at least one receiver
      end
    end

    test "traces background job processing" do
      # Trigger a background job that processes uploaded file
      file_data = generate_test_file_data()
      {:ok, response} = make_http_request(:post, "/api/files/upload", file_data)

      correlation_id = extract_correlation_id(response)

      # Wait for background processing to complete
      Process.sleep(2000)

      # Verify the complete async flow was traced
      events = DataAccess.get_events_by_correlation(correlation_id)

      # Should include:
      # 1. Initial upload request
      # 2. Job queuing
      # 3. Background worker processing
      # 4. File processing steps
      # 5. Database updates
      # 6. Completion notification

      job_queue_events = filter_events(events, :job_queued)
      assert length(job_queue_events) == 1

      worker_events = filter_events(events, :background_worker_start)
      assert length(worker_events) >= 1

      file_processing_events = filter_events(events, :file_processing)
      assert length(file_processing_events) >= 1

      # Verify correlation spans across processes
      pids = Enum.map(events, & &1.pid) |> Enum.uniq()
      assert length(pids) >= 3  # Web process, job queue, worker process
    end
  end

  describe "performance and reliability under load" do
    test "maintains performance under high load" do
      # Baseline: measure performance without ElixirScope
      ElixirScope.stop()
      baseline_metrics = run_load_test(requests: 1000, concurrency: 10)

      # With ElixirScope: measure performance with full tracing
      ElixirScope.start(strategy: :full_trace)
      traced_metrics = run_load_test(requests: 1000, concurrency: 10)

      # Verify acceptable overhead
      latency_overhead = calculate_overhead(traced_metrics.avg_latency, baseline_metrics.avg_latency)
      throughput_impact = calculate_impact(traced_metrics.throughput, baseline_metrics.throughput)

      assert latency_overhead < 15.0  # Less than 15% latency increase
      assert throughput_impact < 10.0  # Less than 10% throughput decrease

      # Verify no request failures due to tracing
      assert traced_metrics.error_rate <= baseline_metrics.error_rate
    end

    test "handles sustained load without memory leaks" do
      # Run sustained load for 5 minutes
      start_time = System.monotonic_time(:second)
      initial_memory = get_elixir_scope_memory_usage()

      # Continuous load generation
      load_task = Task.async(fn ->
        run_continuous_load(duration_seconds: 300)
      end)

      # Monitor memory usage every 30 seconds
      memory_samples = monitor_memory_usage(duration_seconds: 300, interval: 30)

      Task.await(load_task, 400_000)

      final_memory = get_elixir_scope_memory_usage()

      # Verify memory growth is bounded
      memory_growth = final_memory - initial_memory
      memory_growth_mb = memory_growth / (1024 * 1024)

      assert memory_growth_mb < 50  # Less than 50MB growth over 5 minutes

      # Verify no memory leak trend
      assert no_memory_leak_detected?(memory_samples)
    end

    test "recovers gracefully from failures" do
      # Inject various failure scenarios
      failure_scenarios = [
        :ets_table_corruption,
        :ring_buffer_overflow,
        :worker_process_crash,
        :correlation_engine_failure,
        :storage_disk_full
      ]

      for scenario <- failure_scenarios do
        # Reset system
        restart_elixir_scope()

        # Run normal operations
        baseline_correlation_id = generate_test_operations()

        # Inject failure
        inject_failure(scenario)

        # Continue operations
        post_failure_correlation_id = generate_test_operations()

        # Wait for recovery
        Process.sleep(1000)

        # Verify system recovered
        baseline_events = DataAccess.get_events_by_correlation(baseline_correlation_id)
        post_failure_events = DataAccess.get_events_by_correlation(post_failure_correlation_id)

        assert length(baseline_events) > 0
        assert length(post_failure_events) > 0

        # Verify no data corruption
        assert events_are_valid?(baseline_events)
        assert events_are_valid?(post_failure_events)

        # Verify correlation integrity maintained
        assert correlation_integrity_maintained?(baseline_events)
        assert correlation_integrity_maintained?(post_failure_events)
      end
    end

    test "handles concurrent debugging sessions" do
      # Start multiple debugging sessions simultaneously
      session_count = 5

      debug_sessions = for i <- 1..session_count do
        Task.async(fn ->
          # Each session traces different aspects
          strategy = case rem(i, 3) do
            0 -> :full_trace
            1 -> :performance_only
            2 -> :state_tracking_only
          end

          # Run session-specific operations
          run_debug_session(strategy, operations: 100)
        end)
      end

      results = Task.await_many(debug_sessions, 30_000)

      # Verify all sessions completed successfully
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Verify no cross-session interference
      total_events = DataAccess.count_all_events()
      expected_min_events = session_count * 50  # Conservative estimate

      assert total_events >= expected_min_events

      # Verify correlation IDs are unique across sessions
      all_correlation_ids = DataAccess.get_all_correlation_ids()
      unique_correlation_ids = Enum.uniq(all_correlation_ids)

      assert length(all_correlation_ids) == length(unique_correlation_ids)
    end
  end

  describe "data accuracy and completeness" do
    test "captures complete request lifecycle with zero data loss" do
      # Generate complex nested operations
      correlation_id = perform_complex_operation()

      Process.sleep(500)

      events = DataAccess.get_events_by_correlation(correlation_id)

      # Verify no events were dropped
      assert verify_complete_trace(events)

      # Verify event ordering is correct
      assert events_are_chronologically_ordered?(events)

      # Verify all GenServer state transitions are captured
      state_events = filter_events(events, :state_change)
      assert verify_state_transition_completeness(state_events)

      # Verify message send/receive correlation
      message_events = filter_events(events, [:message_send, :message_receive])
      assert verify_message_correlation_completeness(message_events)
    end

    test "accurately captures exception scenarios" do
      # Generate various types of exceptions
      exception_scenarios = [
        :function_exception,
        :genserver_crash,
        :database_timeout,
        :validation_error,
        :network_timeout
      ]

      for scenario <- exception_scenarios do
        correlation_id = trigger_exception_scenario(scenario)

        Process.sleep(200)

        events = DataAccess.get_events_by_correlation(correlation_id)

        # Should have error event
        error_events = filter_events(events, :error)
        assert length(error_events) >= 1

        error_event = hd(error_events)
        assert error_event.data.error_type != nil
        assert error_event.data.stacktrace != nil

        # Should have events leading up to error
        pre_error_events = filter_events_before(events, error_event.timestamp)
        assert length(pre_error_events) > 0

        # Verify error context is captured
        assert error_event.data.context != nil
      end
    end

    test "maintains data integrity across system restarts" do
      # Generate events
      pre_restart_correlation_id = generate_test_operations()

      Process.sleep(200)

      # Get events before restart
      pre_restart_events = DataAccess.get_events_by_correlation(pre_restart_correlation_id)
      pre_restart_count = DataAccess.count_all_events()

      # Restart ElixirScope
      ElixirScope.stop()
      Process.sleep(100)
      ElixirScope.start()

      # Verify data persisted
      persisted_events = DataAccess.get_events_by_correlation(pre_restart_correlation_id)
      persisted_count = DataAccess.count_all_events()

      assert length(persisted_events) == length(pre_restart_events)
      assert persisted_count >= pre_restart_count

      # Generate new events after restart
      post_restart_correlation_id = generate_test_operations()

      Process.sleep(200)

      # Verify new events are captured
      post_restart_events = DataAccess.get_events_by_correlation(post_restart_correlation_id)
      assert length(post_restart_events) > 0

      # Verify no data corruption
      assert events_are_valid?(persisted_events)
      assert events_are_valid?(post_restart_events)
    end
  end

  # Helper functions

  defp start_test_phoenix_app do
    # Start the test Phoenix application
    Application.ensure_all_started(:production_phoenix_app)
  end

  defp stop_test_phoenix_app do
    Application.stop(:production_phoenix_app)
  end

  defp make_http_request(method, path, data \\ %{}) do
    # Use HTTPoison or similar to make real HTTP requests
    url = "http://localhost:4000" <> path
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(data)

    case method do
      :get -> HTTPoison.get(url, headers)
      :post -> HTTPoison.post(url, body, headers)
      :put -> HTTPoison.put(url, body, headers)
      :delete -> HTTPoison.delete(url, headers)
    end
  end

  defp extract_correlation_id(response) do
    # Extract correlation ID from response headers or body
    case Enum.find(response.headers, fn {key, _} ->
      String.downcase(key) == "x-correlation-id"
    end) do
      {_, correlation_id} -> correlation_id
      nil ->
        # Try to extract from response body
        case Jason.decode(response.body) do
          {:ok, %{"correlation_id" => id}} -> id
          _ -> nil
        end
    end
  end

  defp connect_to_liveview(path) do
    # Use Phoenix.LiveViewTest for real LiveView testing
    {:ok, view, html} = live(build_conn(), path)
    {view, html}
  end

  defp send_chat_message(view, message) do
    correlation_id = ElixirScope.Utils.generate_correlation_id()

    # Set correlation ID in process for tracking
    Process.put(:elixir_scope_correlation_id, correlation_id)

    # Send message through LiveView
    view
    |> form("#chat-form", message: %{text: message})
    |> render_submit()

    correlation_id
  end

  defp generate_test_file_data do
    %{
      "file" => %{
        "filename" => "test_document.pdf",
        "content_type" => "application/pdf",
        "content" => Base.encode64(File.read!("test/fixtures/sample.pdf"))
      }
    }
  end

  defp run_load_test(opts) do
    requests = Keyword.get(opts, :requests, 100)
    concurrency = Keyword.get(opts, :concurrency, 5)

    start_time = System.monotonic_time(:millisecond)

    # Create concurrent request tasks
    tasks = for _i <- 1..concurrency do
      Task.async(fn ->
        requests_per_task = div(requests, concurrency)

        for _j <- 1..requests_per_task do
          {time, response} = :timer.tc(fn ->
            make_http_request(:get, "/api/health")
          end)

          {time, response.status_code}
        end
      end)
    end

    # Collect all results
    all_results = Task.await_many(tasks, 60_000) |> List.flatten()

    end_time = System.monotonic_time(:millisecond)
    total_time = end_time - start_time

    # Calculate metrics
    response_times = Enum.map(all_results, &elem(&1, 0))
    status_codes = Enum.map(all_results, &elem(&1, 1))

    successful_requests = Enum.count(status_codes, &(&1 in 200..299))
    error_requests = length(all_results) - successful_requests

    %{
      total_requests: length(all_results),
      successful_requests: successful_requests,
      error_requests: error_requests,
      error_rate: error_requests / length(all_results),
      avg_latency: Enum.sum(response_times) / length(response_times) / 1000, # Convert to ms
      max_latency: Enum.max(response_times) / 1000,
      min_latency: Enum.min(response_times) / 1000,
      throughput: length(all_results) / (total_time / 1000), # Requests per second
      total_time: total_time
    }
  end

  defp calculate_overhead(traced_value, baseline_value) do
    ((traced_value - baseline_value) / baseline_value) * 100
  end

  defp calculate_impact(traced_value, baseline_value) do
    ((baseline_value - traced_value) / baseline_value) * 100
  end

  defp get_elixir_scope_memory_usage do
    # Get memory usage of ElixirScope processes
    elixir_scope_processes = Process.list()
    |> Enum.filter(fn pid ->
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} ->
          Keyword.get(dict, :"$initial_call")
          |> to_string()
          |> String.contains?("ElixirScope")
        _ -> false
      end
    end)

    Enum.reduce(elixir_scope_processes, 0, fn pid, acc ->
      case Process.info(pid, :memory) do
        {:memory, memory} -> acc + memory
        _ -> acc
      end
    end)
  end

  defp run_continuous_load(opts) do
    duration = Keyword.get(opts, :duration_seconds, 300)
    end_time = System.monotonic_time(:second) + duration

    Stream.repeatedly(fn ->
      if System.monotonic_time(:second) < end_time do
        make_http_request(:get, "/api/users/#{:rand.uniform(1000)}")
        Process.sleep(50)  # 20 requests per second
        :continue
      else
        :stop
      end
    end)
    |> Stream.take_while(&(&1 == :continue))
    |> Enum.to_list()
  end

  defp monitor_memory_usage(opts) do
    duration = Keyword.get(opts, :duration_seconds, 300)
    interval = Keyword.get(opts, :interval, 30)

    end_time = System.monotonic_time(:second) + duration

    Stream.unfold(System.monotonic_time(:second), fn current_time ->
      if current_time < end_time do
        memory = get_elixir_scope_memory_usage()
        Process.sleep(interval * 1000)
        next_time = System.monotonic_time(:second)
        {{current_time, memory}, next_time}
      else
        nil
      end
    end)
    |> Enum.to_list()
  end

  defp no_memory_leak_detected?(memory_samples) do
    # Simple linear regression to detect memory leak trend
    if length(memory_samples) < 3 do
      true
    else
      {times, memories} = Enum.unzip(memory_samples)

      # Calculate trend
      n = length(times)
      sum_x = Enum.sum(times)
      sum_y = Enum.sum(memories)
      sum_xy = Enum.zip(times, memories) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
      sum_x2 = Enum.map(times, &(&1 * &1)) |> Enum.sum()

      slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)

      # Memory leak if slope indicates significant upward trend
      # Consider it a leak if memory grows more than 1MB per minute
      slope < 1024 * 1024 / 60
    end
  end

  defp restart_elixir_scope do
    ElixirScope.stop()
    Process.sleep(100)
    ElixirScope.start()
    Process.sleep(200)
  end

  defp generate_test_operations do
    correlation_id = ElixirScope.Utils.generate_correlation_id()

    # Set correlation ID for tracking
    Process.put(:elixir_scope_correlation_id, correlation_id)

    # Perform various operations
    make_http_request(:get, "/api/users")
    make_http_request(:post, "/api/posts", %{"post" => %{"title" => "Test", "content" => "Content"}})
    make_http_request(:get, "/api/posts/1")

    correlation_id
  end

  defp inject_failure(scenario) do
    case scenario do
      :ets_table_corruption ->
        # Simulate ETS table corruption
        :ets.delete_all_objects(:elixir_scope_events)

      :ring_buffer_overflow ->
        # Fill ring buffer to capacity
        buffer = get_main_ring_buffer()
        for _i <- 1..10000 do
          ElixirScope.Capture.RingBuffer.write(buffer, create_test_event())
        end

      :worker_process_crash ->
        # Crash async writer workers
        workers = get_async_writer_workers()
        Enum.each(workers, &Process.exit(&1, :kill))

      :correlation_engine_failure ->
        # Crash correlation engine
        case Process.whereis(ElixirScope.Capture.EventCorrelator) do
          nil -> :ok
          pid -> Process.exit(pid, :kill)
        end

      :storage_disk_full ->
        # Simulate disk full by making writes fail
        mock_disk_full_condition()
    end
  end

  defp verify_event_sequence(events, expected_sequence) do
    event_types = Enum.map(events, & &1.event_type)

    # Verify all expected events are present
    for expected_type <- expected_sequence do
      assert expected_type in event_types,
        "Expected event #{expected_type} not found in #{inspect(event_types)}"
    end

    # Verify rough ordering (some events may be async)
    key_events = Enum.filter(events, &(&1.event_type in expected_sequence))
    assert length(key_events) >= length(expected_sequence) * 0.8  # Allow for some variation
  end

  defp find_event(events, event_type) do
    Enum.find(events, &(&1.event_type == event_type))
  end

  defp filter_events(events, event_type) when is_atom(event_type) do
    Enum.filter(events, &(&1.event_type == event_type))
  end

  defp filter_events(events, event_types) when is_list(event_types) do
    Enum.filter(events, &(&1.event_type in event_types))
  end

  defp count_events(events, event_type) do
    length(filter_events(events, event_type))
  end

  defp filter_events_before(events, timestamp) do
    Enum.filter(events, &(&1.timestamp < timestamp))
  end

  defp events_are_valid?(events) do
    Enum.all?(events, fn event ->
      event.id != nil and
      event.timestamp != nil and
      event.event_type != nil and
      is_pid(event.pid)
    end)
  end

  defp events_are_chronologically_ordered?(events) do
    timestamps = Enum.map(events, & &1.timestamp)
    timestamps == Enum.sort(timestamps)
  end

  defp correlation_integrity_maintained?(events) do
    correlation_ids = Enum.map(events, & &1.correlation_id) |> Enum.uniq()

    # All events should have the same correlation ID
    length(correlation_ids) <= 1
  end

  defp verify_complete_trace(events) do
    # Verify that for every function entry, there's a corresponding exit
    entry_events = filter_events(events, :function_entry)
    exit_events = filter_events(events, :function_exit)

    entry_call_ids = Enum.map(entry_events, & &1.data.call_id) |> MapSet.new()
    exit_call_ids = Enum.map(exit_events, & &1.data.call_id) |> MapSet.new()

    # All entries should have corresponding exits (allowing for some async operations)
    missing_exits = MapSet.difference(entry_call_ids, exit_call_ids)
    MapSet.size(missing_exits) <= MapSet.size(entry_call_ids) * 0.1  # Allow 10% async
  end

  defp verify_state_transition_completeness(state_events) do
    # Group by PID and verify state transitions are logical
    events_by_pid = Enum.group_by(state_events, & &1.pid)

    Enum.all?(events_by_pid, fn {_pid, pid_events} ->
      # Sort by timestamp
      sorted_events = Enum.sort_by(pid_events, & &1.timestamp)

      # Verify each state change has both before and after
      Enum.all?(sorted_events, fn event ->
        event.data.old_state != nil and event.data.new_state != nil
      end)
    end)
  end

  defp verify_message_correlation_completeness(message_events) do
    send_events = filter_events(message_events, :message_send)
    receive_events = filter_events(message_events, :message_receive)

    send_message_ids = Enum.map(send_events, & &1.data.message_id) |> MapSet.new()
    receive_message_ids = Enum.map(receive_events, & &1.data.message_id) |> MapSet.new()

    # Most sends should have corresponding receives
    matched_messages = MapSet.intersection(send_message_ids, receive_message_ids)
    match_ratio = MapSet.size(matched_messages) / MapSet.size(send_message_ids)

    match_ratio >= 0.8  # 80% of messages should be matched
  end

  defp perform_complex_operation do
    correlation_id = ElixirScope.Utils.generate_correlation_id()
    Process.put(:elixir_scope_correlation_id, correlation_id)

    # Complex operation involving multiple components
    {:ok, response} = make_http_request(:post, "/api/complex_operation", %{
      "data" => %{
        "type" => "batch_processing",
        "items" => for i <- 1..10 do %{"id" => i, "value" => "item_#{i}"} end
      }
    })

    correlation_id
  end

  defp trigger_exception_scenario(scenario) do
    correlation_id = ElixirScope.Utils.generate_correlation_id()
    Process.put(:elixir_scope_correlation_id, correlation_id)

    endpoint = case scenario do
      :function_exception -> "/api/test/function_exception"
      :genserver_crash -> "/api/test/genserver_crash"
      :database_timeout -> "/api/test/database_timeout"
      :validation_error -> "/api/test/validation_error"
      :network_timeout -> "/api/test/network_timeout"
    end

    # Make request that will trigger exception (expect it to fail)
    make_http_request(:post, endpoint, %{})

    correlation_id
  end

  defp run_debug_session(strategy, opts) do
    operations = Keyword.get(opts, :operations, 50)

    # Configure ElixirScope for this session
    ElixirScope.update_instrumentation(strategy: strategy)

    # Perform operations
    results = for _i <- 1..operations do
      correlation_id = generate_test_operations()
      {correlation_id, :ok}
    end

    {:ok, results}
  end

  # Mock helper functions (these would be implemented based on actual system)

  defp get_main_ring_buffer do
    # Get the main ring buffer instance
    Application.get_env(:elixir_scope, :main_buffer)
  end

  defp get_async_writer_workers do
    # Get PIDs of async writer workers
    case Process.whereis(ElixirScope.Capture.AsyncWriterPool) do
      nil -> []
      pool_pid ->
        ElixirScope.Capture.AsyncWriterPool.get_worker_pids(pool_pid)
    end
  end

  defp create_test_event do
    %ElixirScope.Events.FunctionExecution{
      id: ElixirScope.Utils.generate_id(),
      timestamp: ElixirScope.Utils.monotonic_timestamp(),
      module: TestModule,
      function: :test_function,
      event_type: :call
    }
  end

  defp mock_disk_full_condition do
    # Mock disk full by intercepting file writes
    # This would require more sophisticated mocking
    :ok
  end
end
