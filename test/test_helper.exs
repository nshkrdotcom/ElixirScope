ExUnit.start()

# Configure Mox for dependency injection testing
Mox.defmock(ElixirScope.MockStateManager,
  for: ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManagerBehaviour)

Mox.defmock(ElixirScope.MockASTUtilities,
  for: ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilitiesBehaviour)

Mox.defmock(ElixirScope.MockASTProcessor,
  for: ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessorBehaviour)

# Set default dependency injection configuration for tests
Application.put_env(:elixir_scope, :state_manager,
  ElixirScope.ASTRepository.Enhanced.CFGGenerator.StateManager)
Application.put_env(:elixir_scope, :ast_utilities,
  ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTUtilities)
Application.put_env(:elixir_scope, :ast_processor,
  ElixirScope.ASTRepository.Enhanced.CFGGenerator.ASTProcessor)

# Configure test environment
Application.put_env(:elixir_scope, :test_mode, true)

# Ensure clean state for each test and exclude live API tests by default
ExUnit.configure(exclude: [:skip, :live_api])

# Compile test support modules
Code.compile_file("test/support/test_phoenix_app.ex")
Code.compile_file("test/support/ai_test_helpers.ex")

# Compile AST repository test support modules
Code.compile_file("test/elixir_scope/ast_repository/test_support/fixtures/sample_asts.ex")
Code.compile_file("test/elixir_scope/ast_repository/test_support/helpers.ex")
Code.compile_file("test/elixir_scope/ast_repository/test_support/cfg_validation_helpers.ex")
Code.compile_file("test/elixir_scope/ast_repository/test_support/dfg_validation_helpers.ex")

# Helper functions for tests
defmodule ElixirScope.TestHelpers do
  @moduledoc """
  Helper functions for ElixirScope tests.
  """

  @doc """
  Creates a test configuration with minimal settings.
  """
  def test_config do
    %ElixirScope.Config{
      ai: %{
        provider: :mock,
        api_key: nil,
        model: "test-model",
        analysis: %{
          max_file_size: 100_000,
          timeout: 5_000,
          cache_ttl: 60
        },
        planning: %{
          default_strategy: :minimal,
          performance_target: 0.1,
          sampling_rate: 0.1
        }
      },
      capture: %{
        ring_buffer: %{
          size: 1024,
          max_events: 100,
          overflow_strategy: :drop_oldest,
          num_buffers: 1
        },
        processing: %{
          batch_size: 10,
          flush_interval: 10,
          max_queue_size: 100
        },
        vm_tracing: %{
          enable_spawn_trace: false,
          enable_exit_trace: false,
          enable_message_trace: false,
          trace_children: false
        }
      },
      storage: %{
        hot: %{
          max_events: 1000,
          max_age_seconds: 60,
          prune_interval: 1000
        },
        warm: %{
          enable: false,
          path: "./test_data",
          max_size_mb: 10,
          compression: :zstd
        },
        cold: %{
          enable: false
        }
      },
      interface: %{
        iex_helpers: false,
        query_timeout: 1000,
        web: %{
          enable: false,
          port: 4001
        }
      },
      instrumentation: %{
        default_level: :none,
        module_overrides: %{},
        function_overrides: %{},
        exclude_modules: [ElixirScope, :logger, :gen_server, :supervisor]
      }
    }
  end

  @doc """
  Ensures ElixirScope.Config GenServer is available for tests that depend on it.

  This function uses a more robust approach with proper synchronization
  and longer timeouts to handle race conditions in async tests.
  """
  def ensure_config_available do
    # Use a global lock to prevent race conditions between async tests
    :global.trans({:config_setup, self()}, fn ->
      do_ensure_config_available()
    end, [node()], 5000)
  end

  defp do_ensure_config_available do
    case GenServer.whereis(ElixirScope.Config) do
      nil ->
        # Config not running, start it with retry logic
        start_config_with_retry(3)

      pid when is_pid(pid) ->
        # Config is running, verify it's responsive with longer timeout
        case test_config_responsiveness(pid) do
          :ok -> :ok
          :unresponsive -> restart_config_with_retry(pid, 3)
        end
    end
  end

  defp start_config_with_retry(0), do: {:error, :max_retries_exceeded}
  defp start_config_with_retry(retries) do
    case ElixirScope.Config.start_link([]) do
      {:ok, pid} ->
        case wait_for_config_ready(pid, 100) do
          :ok -> :ok
          :timeout ->
            GenServer.stop(pid, :kill, 1000)
            start_config_with_retry(retries - 1)
        end

      {:error, {:already_started, pid}} ->
        # Race condition - another process started it
        case wait_for_config_ready(pid, 100) do
          :ok -> :ok
          :timeout -> start_config_with_retry(retries - 1)
        end

      {:error, _reason} ->
        Process.sleep(50)  # Brief pause before retry
        start_config_with_retry(retries - 1)
    end
  end

  defp restart_config_with_retry(_pid, 0), do: {:error, :max_retries_exceeded}
  defp restart_config_with_retry(pid, retries) do
    # Safely stop the GenServer, handling the case where it might already be dead
    try do
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 2000)
      end
    rescue
      _ -> :ok  # Process already dead or stopping
    catch
      :exit, _ -> :ok  # Process already dead or stopping
    end

    Process.sleep(50)  # Allow cleanup
    start_config_with_retry(retries)
  end

  defp test_config_responsiveness(pid) do
    try do
      # Test with a longer timeout
      case GenServer.call(pid, :get_config, 2000) do
        %ElixirScope.Config{} -> :ok
        _ -> :unresponsive
      end
    rescue
      _ -> :unresponsive
    catch
      :exit, _ -> :unresponsive
    end
  end

  @doc """
  Waits for Config GenServer to become ready and responsive with configurable timeout.
  """
  def wait_for_config_ready(pid, max_attempts \\ 50) do
    wait_for_config_ready_loop(pid, max_attempts, 0)
  end

  defp wait_for_config_ready_loop(_pid, max_attempts, attempts) when attempts >= max_attempts do
    :timeout
  end

  defp wait_for_config_ready_loop(pid, max_attempts, attempts) do
    case test_config_responsiveness(pid) do
      :ok -> :ok
      :unresponsive ->
        # Exponential backoff: start with 10ms, max 100ms
        sleep_time = min(10 * :math.pow(1.2, attempts), 100) |> round()
        Process.sleep(sleep_time)
        wait_for_config_ready_loop(pid, max_attempts, attempts + 1)
    end
  end

  @doc """
  Creates a test event with minimal required fields.
  """
  def test_event(type \\ :function_entry, data \\ %{}) do
    ElixirScope.Events.new_event(type, data)
  end

  @doc """
  Waits for a condition to be true with timeout.
  """
  def wait_until(fun, timeout \\ 1000) do
    wait_until(fun, timeout, 10)
  end

  defp wait_until(fun, timeout, interval) when timeout > 0 do
    if fun.() do
      :ok
    else
      Process.sleep(interval)
      wait_until(fun, timeout - interval, interval)
    end
  end

  defp wait_until(_fun, _timeout, _interval) do
    {:error, :timeout}
  end
end
