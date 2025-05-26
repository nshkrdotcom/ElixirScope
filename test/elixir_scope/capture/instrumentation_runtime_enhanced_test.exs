defmodule ElixirScope.Capture.InstrumentationRuntimeEnhancedTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.Capture.InstrumentationRuntime
  alias ElixirScope.Capture.RingBuffer
  # TODO: Add Ingestor alias when implementing actual tests
  # alias ElixirScope.Capture.Ingestor
  
  @moduletag :capture

  setup do
    # Create a test buffer for instrumentation (size must be power of 2)
    {:ok, buffer} = RingBuffer.new(size: 1024)
    
    # Set up application environment for testing
    Application.put_env(:elixir_scope, :main_buffer, buffer)
    
    # Initialize instrumentation context
    InstrumentationRuntime.initialize_context()
    
    on_exit(fn ->
      InstrumentationRuntime.clear_context()
      Application.delete_env(:elixir_scope, :main_buffer)
    end)
    
    %{buffer: buffer}
  end

  describe "report_ast_function_entry_with_node_id/5" do
    test "should report function entry with AST node correlation", %{buffer: _buffer} do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      ast_node_id = "TestModule:test_function:10:function_def"
      
      result = InstrumentationRuntime.report_ast_function_entry_with_node_id(
        TestModule, 
        :test_function, 
        [:arg1, :arg2], 
        correlation_id, 
        ast_node_id
      )
      
      assert result == :ok
      
      # Verify call stack was updated
      assert InstrumentationRuntime.current_correlation_id() == correlation_id
    end
    
    test "should handle disabled context gracefully" do
      InstrumentationRuntime.clear_context()
      
      result = InstrumentationRuntime.report_ast_function_entry_with_node_id(
        TestModule, 
        :test_function, 
        [], 
        :test_correlation, 
        "test:node:id"
      )
      
      assert result == :ok
    end
  end

  describe "report_ast_function_exit_with_node_id/4" do
    test "should report function exit with AST node correlation" do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      ast_node_id = "TestModule:test_function:10:function_def"
      
      # First enter a function to set up call stack
      InstrumentationRuntime.report_ast_function_entry_with_node_id(
        TestModule, 
        :test_function, 
        [], 
        correlation_id, 
        ast_node_id
      )
      
      result = InstrumentationRuntime.report_ast_function_exit_with_node_id(
        correlation_id, 
        :return_value, 
        1000000, 
        ast_node_id
      )
      
      assert result == :ok
      
      # Verify call stack was popped
      assert InstrumentationRuntime.current_correlation_id() == nil
    end
    
    test "should handle disabled context gracefully" do
      InstrumentationRuntime.clear_context()
      
      result = InstrumentationRuntime.report_ast_function_exit_with_node_id(
        :test_correlation, 
        :return_value, 
        1000, 
        "test:node:id"
      )
      
      assert result == :ok
    end
  end

  describe "report_ast_variable_snapshot/4" do
    test "should capture variable snapshot with AST node correlation" do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      ast_node_id = "TestModule:test_function:15:variable_binding"
      variables = %{x: 42, y: "hello", z: [1, 2, 3]}
      
      result = InstrumentationRuntime.report_ast_variable_snapshot(
        correlation_id, 
        variables, 
        15, 
        ast_node_id
      )
      
      assert result == :ok
    end
    
    test "should handle large variable maps" do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      ast_node_id = "TestModule:test_function:20:variable_binding"
      
      # Create a large variable map
      large_variables = for i <- 1..100, into: %{} do
        {String.to_atom("var_#{i}"), i * 2}
      end
      
      result = InstrumentationRuntime.report_ast_variable_snapshot(
        correlation_id, 
        large_variables, 
        20, 
        ast_node_id
      )
      
      assert result == :ok
    end
    
    test "should handle disabled context gracefully" do
      InstrumentationRuntime.clear_context()
      
      result = InstrumentationRuntime.report_ast_variable_snapshot(
        :test_correlation, 
        %{x: 1}, 
        10, 
        "test:node:id"
      )
      
      assert result == :ok
    end
  end

  describe "validate_ast_node_id/1" do
    test "should accept valid format" do
      valid_id = "TestModule:test_function:10:function_def"
      assert {:ok, ^valid_id} = InstrumentationRuntime.validate_ast_node_id(valid_id)
    end
    
    test "should accept different node types" do
      test_cases = [
        "MyModule:my_function:15:variable_binding",
        "SomeModule:another_function:20:expression",
        "AnotherModule:func:25:pattern_match",
        "Module:function:30:if_branch"
      ]
      
      for test_id <- test_cases do
        assert {:ok, ^test_id} = InstrumentationRuntime.validate_ast_node_id(test_id)
      end
    end
    
    test "should reject invalid formats" do
      invalid_cases = [
        "missing:parts",
        "too:many:parts:here:extra",
        "no_separators",
        "wrong-separator:format:10:type",
        ""
      ]
      
      for invalid_id <- invalid_cases do
        assert {:error, :invalid_format} = InstrumentationRuntime.validate_ast_node_id(invalid_id)
      end
    end
    
    test "should reject non-string inputs" do
      non_string_cases = [
        123,
        :atom,
        %{},
        [],
        nil
      ]
      
      for invalid_input <- non_string_cases do
        assert {:error, :not_string} = InstrumentationRuntime.validate_ast_node_id(invalid_input)
      end
    end
  end

  describe "get_ast_correlation_metadata/0" do
    test "should return complete metadata structure" do
      metadata = InstrumentationRuntime.get_ast_correlation_metadata()
      
      assert is_map(metadata)
      assert Map.has_key?(metadata, :process_id)
      assert Map.has_key?(metadata, :correlation_id)
      assert Map.has_key?(metadata, :timestamp_mono)
      assert Map.has_key?(metadata, :timestamp_system)
      assert Map.has_key?(metadata, :enabled)
      
      assert metadata.process_id == self()
      assert is_boolean(metadata.enabled)
      assert is_integer(metadata.timestamp_mono)
      assert is_integer(metadata.timestamp_system)
    end
    
    test "should reflect current enabled state" do
      # Test when enabled
      metadata_enabled = InstrumentationRuntime.get_ast_correlation_metadata()
      assert metadata_enabled.enabled == true
      
      # Test when disabled
      InstrumentationRuntime.clear_context()
      metadata_disabled = InstrumentationRuntime.get_ast_correlation_metadata()
      assert metadata_disabled.enabled == false
    end
  end

  describe "enhanced existing functions - backward compatibility" do
    test "enhanced report_local_variable_snapshot/4 maintains compatibility" do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      variables = %{x: 42, y: "test"}
      
      # Test with original signature
      result = InstrumentationRuntime.report_local_variable_snapshot(
        correlation_id, 
        variables, 
        10
      )
      
      assert result == :ok
    end
    
    test "enhanced report_expression_value/5 maintains compatibility" do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      
      result = InstrumentationRuntime.report_expression_value(
        correlation_id, 
        "x + 1", 
        43, 
        15
      )
      
      assert result == :ok
    end
    
    test "enhanced report_line_execution/4 maintains compatibility" do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      context = %{scope: :function}
      
      result = InstrumentationRuntime.report_line_execution(
        correlation_id, 
        20, 
        context
      )
      
      assert result == :ok
    end
    
    test "enhanced report_ast_function_entry/4 maintains compatibility" do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      
      result = InstrumentationRuntime.report_ast_function_entry(
        TestModule, 
        :test_function, 
        [:arg1], 
        correlation_id
      )
      
      assert result == :ok
    end
    
    test "enhanced report_ast_function_exit/3 manages call stack properly" do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      
      # Enter function
      InstrumentationRuntime.report_ast_function_entry(
        TestModule, 
        :test_function, 
        [], 
        correlation_id
      )
      
      # Verify correlation ID is current
      assert InstrumentationRuntime.current_correlation_id() == correlation_id
      
      # Exit function
      InstrumentationRuntime.report_ast_function_exit(
        correlation_id, 
        :return_value, 
        1000000
      )
      
      # Verify call stack was popped
      assert InstrumentationRuntime.current_correlation_id() == nil
    end
  end

  describe "performance characteristics" do
    test "validate_ast_node_id should be fast" do
      valid_id = "TestModule:test_function:10:function_def"
      
      {time_us, _result} = :timer.tc(fn ->
        for _ <- 1..1000 do
          InstrumentationRuntime.validate_ast_node_id(valid_id)
        end
      end)
      
      # Should be well under 100ns per call (1000 calls in reasonable time)
      avg_time_us = time_us / 1000
      assert avg_time_us < 10  # 10 microseconds average should be very achievable
    end
    
    test "get_ast_correlation_metadata should be fast" do
      {time_us, _result} = :timer.tc(fn ->
        for _ <- 1..1000 do
          InstrumentationRuntime.get_ast_correlation_metadata()
        end
      end)
      
      # Should be very fast since it's just process dictionary lookups
      avg_time_us = time_us / 1000
      assert avg_time_us < 5  # 5 microseconds average
    end
    
    test "AST correlation functions should have minimal overhead when disabled" do
      InstrumentationRuntime.clear_context()
      
      {time_us, _result} = :timer.tc(fn ->
        for _ <- 1..1000 do
          InstrumentationRuntime.report_ast_variable_snapshot(
            :test_correlation, 
            %{x: 1}, 
            10, 
            "test:node:id"
          )
        end
      end)
      
      # Should be very fast when disabled (just context check)
      avg_time_us = time_us / 1000
      assert avg_time_us < 1  # 1 microsecond average when disabled
    end
  end

  describe "error handling and edge cases" do
    test "should handle nil correlation IDs gracefully" do
      result = InstrumentationRuntime.report_ast_variable_snapshot(
        nil, 
        %{x: 1}, 
        10, 
        "test:node:id"
      )
      
      assert result == :ok
    end
    
    test "should handle empty variable maps" do
      correlation_id = {System.monotonic_time(:nanosecond), self(), make_ref()}
      
      result = InstrumentationRuntime.report_ast_variable_snapshot(
        correlation_id, 
        %{}, 
        10, 
        "test:node:id"
      )
      
      assert result == :ok
    end
    
    test "should handle very long AST node IDs" do
      long_id = String.duplicate("VeryLongModuleName", 10) <> 
                ":very_long_function_name:" <> 
                "999999:" <> 
                "very_long_node_type_description"
      
      result = InstrumentationRuntime.validate_ast_node_id(long_id)
      assert {:ok, ^long_id} = result
    end
    
    test "should handle special characters in AST node IDs" do
      # Test with module names that might have special characters
      special_cases = [
        "Elixir.MyModule:function_name:10:type",
        "MyApp.SubModule:function_name:10:type",
        "Module123:function_with_numbers_123:10:type"
      ]
      
      for special_id <- special_cases do
        result = InstrumentationRuntime.validate_ast_node_id(special_id)
        assert {:ok, ^special_id} = result
      end
    end
  end
end 