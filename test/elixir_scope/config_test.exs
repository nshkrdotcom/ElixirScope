defmodule ElixirScope.ConfigTest do
  use ExUnit.Case, async: false  # Config tests must be synchronous due to shared GenServer

  alias ElixirScope.Config
  alias ElixirScope.TestHelpers

  describe "config validation" do
    test "validates default configuration structure" do
      config = %Config{}
      assert {:ok, ^config} = Config.validate(config)
    end

    test "validates AI configuration" do
      # Valid configuration
      config = %Config{
        ai: %{
          provider: :mock,
          api_key: nil,
          model: "gpt-4",
          analysis: %{
            max_file_size: 1_000_000,
            timeout: 30_000,
            cache_ttl: 3600
          },
          planning: %{
            default_strategy: :balanced,
            performance_target: 0.01,
            sampling_rate: 1.0
          }
        }
      }
      
      assert {:ok, ^config} = Config.validate(config)
    end

    test "rejects invalid AI provider" do
      config = %Config{
        ai: %{provider: :invalid_provider}
      }
      
      assert {:error, _} = Config.validate(config)
    end

    test "rejects invalid sampling rate" do
      config = %Config{
        ai: %{
          provider: :mock,
          analysis: %{max_file_size: 1000, timeout: 1000, cache_ttl: 1000},
          planning: %{
            default_strategy: :balanced,
            performance_target: 0.01,
            sampling_rate: 1.5  # Invalid: > 1.0
          }
        }
      }
      
      assert {:error, _} = Config.validate(config)
    end

    test "rejects negative performance target" do
      config = %Config{
        ai: %{
          provider: :mock,
          analysis: %{max_file_size: 1000, timeout: 1000, cache_ttl: 1000},
          planning: %{
            default_strategy: :balanced,
            performance_target: -0.1,  # Invalid: negative
            sampling_rate: 1.0
          }
        }
      }
      
      assert {:error, _} = Config.validate(config)
    end

    test "validates capture configuration" do
      config = %Config{
        capture: %{
          ring_buffer: %{
            size: 1024,
            max_events: 1000,
            overflow_strategy: :drop_oldest,
            num_buffers: :schedulers
          },
          processing: %{
            batch_size: 100,
            flush_interval: 50,
            max_queue_size: 1000
          },
          vm_tracing: %{
            enable_spawn_trace: true,
            enable_exit_trace: true,
            enable_message_trace: false,
            trace_children: true
          }
        }
      }
      
      assert {:ok, ^config} = Config.validate(config)
    end

    test "rejects invalid overflow strategy" do
      config = %Config{
        capture: %{
          ring_buffer: %{
            size: 1024,
            max_events: 1000,
            overflow_strategy: :invalid_strategy,
            num_buffers: :schedulers
          },
          processing: %{batch_size: 1, flush_interval: 1, max_queue_size: 1},
          vm_tracing: %{
            enable_spawn_trace: true,
            enable_exit_trace: true,
            enable_message_trace: false,
            trace_children: true
          }
        }
      }
      
      assert {:error, _} = Config.validate(config)
    end

    test "validates storage configuration" do
      config = %Config{
        storage: %{
          hot: %{
            max_events: 100_000,
            max_age_seconds: 3600,
            prune_interval: 60_000
          },
          warm: %{
            enable: false,
            path: "./test_data",
            max_size_mb: 100,
            compression: :zstd
          },
          cold: %{enable: false}
        }
      }
      
      assert {:ok, ^config} = Config.validate(config)
    end

    test "rejects zero or negative values for required positive integers" do
      config = %Config{
        storage: %{
          hot: %{
            max_events: 0,  # Invalid: must be positive
            max_age_seconds: 3600,
            prune_interval: 60_000
          },
          warm: %{enable: false, path: "./test", max_size_mb: 100, compression: :zstd},
          cold: %{enable: false}
        }
      }
      
      assert {:error, _} = Config.validate(config)
    end
  end

  describe "configuration merging" do
    test "merges application environment configuration" do
      # This test would need to set up application environment
      # For now, we'll test the internal merge functions
      _base_config = %{
        ai: %{
          provider: :mock,
          planning: %{
            default_strategy: :balanced,
            sampling_rate: 1.0
          }
        }
      }
      
      _app_config = [
        ai: [
          planning: [
            sampling_rate: 0.5
          ]
        ]
      ]
      
      # Test internal merge function (we'd need to expose it or test integration)
      # This is a placeholder for the actual merge functionality
      assert true
    end
  end

  describe "configuration server" do
    setup do
      # Ensure Config GenServer is available with better error handling
      case ElixirScope.TestHelpers.ensure_config_available() do
        :ok -> :ok
        {:error, reason} -> 
          flunk("Failed to ensure Config GenServer availability: #{inspect(reason)}")
      end
      
      # Use the already running Config GenServer from the application
      # Store the current state to restore later with timeout
      current_config = try do
        Config.get()
      catch
        :exit, reason ->
          flunk("Failed to get current config in setup: #{inspect(reason)}")
      end
      
      on_exit(fn -> 
        # Restore original sampling rate if it was changed and Config is still running
        # Use try/catch to handle cases where GenServer stops between check and call
        try do
          if GenServer.whereis(ElixirScope.Config) do
            original_rate = current_config.ai.planning.sampling_rate
            Config.update([:ai, :planning, :sampling_rate], original_rate)
          end
        rescue
          _ ->
            # Any other error during cleanup - this is acceptable
            :ok
        catch
          :exit, _reason ->
            # GenServer stopped during cleanup - this is acceptable
            :ok
        end
      end)
      
      %{original_config: current_config}
    end

    test "gets configuration", %{original_config: _config} do
      config = Config.get()
      assert %Config{} = config
      assert config.ai.provider == :mock
    end

    test "gets configuration by path", %{original_config: _config} do
      provider = Config.get([:ai, :provider])
      assert provider == :mock
      
      sampling_rate = Config.get([:ai, :planning, :sampling_rate])
      assert is_number(sampling_rate)
    end

    test "gets nil for invalid path", %{original_config: _config} do
      result = Config.get([:invalid, :path])
      assert result == nil
    end

    test "updates allowed configuration paths", %{original_config: _config} do
      # Test updating sampling rate (should be allowed)
      assert :ok = Config.update([:ai, :planning, :sampling_rate], 0.8)
      
      updated_rate = Config.get([:ai, :planning, :sampling_rate])
      assert updated_rate == 0.8
    end

    test "rejects updates to non-updatable paths", %{original_config: _config} do
      # Test updating provider (should be rejected)
      result = Config.update([:ai, :provider], :openai)
      assert {:error, :not_updatable} = result
      
      # Verify the original value is unchanged
      provider = Config.get([:ai, :provider])
      assert provider == :mock
    end

    test "validates updates before applying", %{original_config: _config} do
      # Test updating sampling rate to invalid value
      result = Config.update([:ai, :planning, :sampling_rate], 1.5)
      assert {:error, _} = result
      
      # Verify the original value is unchanged
      sampling_rate = Config.get([:ai, :planning, :sampling_rate])
      assert sampling_rate != 1.5
    end

    test "updates batch size (allowed path)", %{original_config: _config} do
      assert :ok = Config.update([:capture, :processing, :batch_size], 2000)
      
      batch_size = Config.get([:capture, :processing, :batch_size])
      assert batch_size == 2000
    end

    test "updates flush interval (allowed path)", %{original_config: _config} do
      assert :ok = Config.update([:capture, :processing, :flush_interval], 200)
      
      flush_interval = Config.get([:capture, :processing, :flush_interval])
      assert flush_interval == 200
    end

    test "updates query timeout (allowed path)", %{original_config: _config} do
      assert :ok = Config.update([:interface, :query_timeout], 15_000)
      
      query_timeout = Config.get([:interface, :query_timeout])
      assert query_timeout == 15_000
    end
  end

  describe "edge cases and error handling" do
    test "handles missing required keys" do
      incomplete_config = %{
        ai: %{
          # Missing provider
          analysis: %{max_file_size: 1000, timeout: 1000, cache_ttl: 1000},
          planning: %{
            default_strategy: :balanced,
            performance_target: 0.01,
            sampling_rate: 1.0
          }
        }
      }
      
      # Convert to struct format for validation
      config = struct(Config, incomplete_config)
      assert {:error, _} = Config.validate(config)
    end

    test "handles non-integer values for integer fields" do
      config = %Config{
        capture: %{
          ring_buffer: %{
            size: "not_an_integer",  # Invalid type
            max_events: 1000,
            overflow_strategy: :drop_oldest,
            num_buffers: :schedulers
          },
          processing: %{batch_size: 1, flush_interval: 1, max_queue_size: 1},
          vm_tracing: %{
            enable_spawn_trace: true,
            enable_exit_trace: true,
            enable_message_trace: false,
            trace_children: true
          }
        }
      }
      
      assert {:error, _} = Config.validate(config)
    end

    test "handles non-numeric values for percentage fields" do
      config = %Config{
        ai: %{
          provider: :mock,
          analysis: %{max_file_size: 1000, timeout: 1000, cache_ttl: 1000},
          planning: %{
            default_strategy: :balanced,
            performance_target: "not_a_number",  # Invalid type
            sampling_rate: 1.0
          }
        }
      }
      
      assert {:error, _} = Config.validate(config)
    end
  end

  describe "environment variable support" do
    test "reads environment variables when present" do
      # Test would need to set environment variables
      # This is a placeholder for environment variable integration
      assert true
    end
  end

  describe "performance" do
    setup do
      # Ensure Config GenServer is available for performance tests
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "configuration validation is functional" do
      config = %Config{}
      
      {duration, result} = :timer.tc(fn ->
        Config.validate(config)
      end)
      
      # Validation should complete successfully and in reasonable time (< 500ms)
      assert {:ok, _} = result
      assert duration < 500_000
    end

    test "configuration access is functional" do
      {duration, result} = :timer.tc(fn ->
        Config.get()
      end)
      
      # Configuration access should work and complete in reasonable time (< 100ms)
      assert %Config{} = result
      assert duration < 100_000
    end
  end
end 