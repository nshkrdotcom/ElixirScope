ExUnit.start()

# Configure test environment
Application.put_env(:elixir_scope, :test_mode, true)

# Ensure clean state for each test
ExUnit.configure(exclude: [:skip])

# Compile test support modules
Code.compile_file("test/support/test_phoenix_app.ex")
Code.compile_file("test/support/ai_test_helpers.ex")

# Compile AST repository test support modules
Code.compile_file("test/elixir_scope/ast_repository/test_support/fixtures/sample_asts.ex")
Code.compile_file("test/elixir_scope/ast_repository/test_support/helpers.ex")

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