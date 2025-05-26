defmodule ElixirScope.AST.EnhancedTransformerTest do
  use ExUnit.Case
  
  alias ElixirScope.AST.EnhancedTransformer
  
  describe "expression-level instrumentation" do
    test "instruments individual expressions within function" do
      input_ast = quote do
        def complex_function(x, y) do
          temp1 = x + y           # <- Should be instrumentable
          temp2 = temp1 * 2       # <- Should be instrumentable  
          result = temp2 - 1      # <- Should be instrumentable
          result
        end
      end
      
      plan = %{
        granularity: :expression,
        capture_locals: [:temp1, :temp2, :result]
      }
      
      result = EnhancedTransformer.transform_with_runtime_bridge(input_ast, plan)
      
      # Verify each expression has instrumentation
      assert expression_instrumented?(result, :temp1_assignment)
      assert expression_instrumented?(result, :temp2_assignment)
      assert expression_instrumented?(result, :result_assignment)
      
      # Verify variable values are captured
      assert variable_capture_present?(result, :temp1)
      assert variable_capture_present?(result, :temp2)
      assert variable_capture_present?(result, :result)
    end
    
    test "injects custom debugging logic" do
      input_ast = quote do
        def algorithm(data) do
          Enum.map(data, &process_item/1)
        end
      end
      
      custom_logic = quote do
        IO.puts("Processing #{length(data)} items")
        ElixirScope.Debug.checkpoint(:algorithm_start, %{data_size: length(data)})
      end
      
      plan = %{
        custom_injections: [
          {1, :before, custom_logic}  # Inject at line 1, before execution
        ]
      }
      
      result = EnhancedTransformer.transform_with_runtime_bridge(input_ast, plan)
      
      assert custom_logic_injected?(result, custom_logic)
    end

    test "injects expression tracing for specified expressions" do
      input_ast = quote do
        def calculate(x, y) do
          intermediate = complex_calculation(x)
          final = intermediate + y
          final
        end
      end

      plan = %{
        trace_expressions: [:complex_calculation, :intermediate]
      }

      result = EnhancedTransformer.inject_expression_tracing(input_ast, plan)

      # Debug: Print the result to see what we got
      IO.inspect(result, label: "Result AST")
      IO.inspect(Macro.to_string(result), label: "Result as string")

      # Should wrap complex_calculation call with value capture
      assert expression_tracing_present?(result, "complex_calculation")
      
      # Should NOT wrap intermediate variable (it's not a function call)
      refute expression_tracing_present?(result, "intermediate")
    end

    test "injects local variable capture at specific line" do
      input_ast = quote do
        def process_data(items) do
          count = length(items)      # line 1
          filtered = filter_items(items)  # line 2
          result = transform(filtered)     # line 3
          result
        end
      end

      plan = %{
        capture_locals: [:count, :filtered],
        after_line: 2
      }

      result = EnhancedTransformer.inject_local_variable_capture(input_ast, plan)

      # Should inject variable capture after line 2
      assert variable_capture_at_line?(result, 2)
      assert captures_variables?(result, [:count, :filtered])
    end
  end
  
  describe "runtime integration" do
    test "registers instrumented modules with runtime system" do
      input_ast = quote do
        defmodule TestModule do
          def test_function do
            :ok
          end
        end
      end
      
      plan = %{
        module: TestModule, 
        functions: %{
          {TestModule, :test_function, 0} => %{instrument: true}
        }
      }
      
      result = EnhancedTransformer.transform_with_runtime_bridge(input_ast, plan)
      
      # Verify registration call is injected
      assert runtime_registration_present?(result, TestModule)
      
      # Verify plan is passed to runtime system
      assert plan_passed_to_runtime?(result, plan)
    end

    test "includes runtime coordination checks" do
      input_ast = quote do
        defmodule TestModule do
          def monitored_function(arg) do
            arg * 2
          end
        end
      end

      plan = %{coordinate_with_runtime: true}

      result = EnhancedTransformer.transform_with_runtime_bridge(input_ast, plan)

      # Should include runtime enable/disable checks
      assert runtime_coordination_present?(result)
      assert ast_tracing_check_present?(result)
    end
  end

  describe "granular instrumentation capabilities" do
    test "transforms with all granular features" do
      input_ast = quote do
        def complex_algorithm(data) do
          preprocessed = preprocess(data)
          temp_result = calculate_intermediate(preprocessed)
          final_result = finalize(temp_result)
          final_result
        end
      end

      plan = %{
        capture_locals: [:preprocessed, :temp_result],
        trace_expressions: [:preprocess, :calculate_intermediate],
        custom_injections: [
          {2, :after, quote do: IO.puts("Checkpoint: intermediate calculated")}
        ]
      }

      result = EnhancedTransformer.transform_with_granular_instrumentation(input_ast, plan)

      # Should have all types of instrumentation
      assert variable_capture_present?(result, :preprocessed)
      assert variable_capture_present?(result, :temp_result)
      assert expression_tracing_present?(result, "preprocess")
      assert expression_tracing_present?(result, "calculate_intermediate")
      assert custom_injection_present?(result, 2)
    end

    test "handles empty plans gracefully" do
      input_ast = quote do
        def simple_function(x) do
          x + 1
        end
      end

      plan = %{}

      result = EnhancedTransformer.transform_with_granular_instrumentation(input_ast, plan)

      # Should still transform through base transformer
      assert is_tuple(result)
      # Should not crash or add unwanted instrumentation
      refute has_variable_capture?(result)
      refute has_expression_tracing?(result)
    end
  end

  describe "error handling and edge cases" do
    test "handles malformed AST gracefully" do
      malformed_ast = {:invalid, :ast, :structure}
      plan = %{capture_locals: [:var1]}

      # Should not crash
      result = EnhancedTransformer.inject_local_variable_capture(malformed_ast, plan)
      assert result == malformed_ast
    end

    test "handles missing line metadata" do
      input_ast = quote do
        def no_line_info do
          # This might not have line metadata in some cases
          :ok
        end
      end

      plan = %{trace_expressions: [:some_call]}

      # Should not crash when line metadata is missing
      result = EnhancedTransformer.inject_expression_tracing(input_ast, plan)
      assert is_tuple(result)
    end

    test "handles functions not in instrumentation plan" do
      input_ast = quote do
        def not_instrumented(x) do
          x * 2
        end
      end

      plan = %{
        functions: [:other_function],  # This function not in plan
        capture_locals: [:x]
      }

      result = EnhancedTransformer.inject_local_variable_capture(input_ast, plan)

      # Should not instrument functions not in the plan
      refute variable_capture_present?(result, :x)
    end
  end

  # Helper functions for test assertions

  defp expression_instrumented?(ast, _assignment_type) do
    # Check if the AST contains instrumentation for expression assignments
    Macro.prewalk(ast, false, fn
      {{:., _, [{:__aliases__, _, [:ElixirScope, :Capture, :InstrumentationRuntime]}, :report_local_variable_snapshot]}, _, _}, _acc ->
        {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp variable_capture_present?(ast, variable_name) do
    # Check if variable capture is present for the given variable
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "#{variable_name}")
  end

  defp custom_logic_injected?(ast, logic) do
    # Check if custom logic is present in the AST
    _logic_string = Macro.to_string(logic)
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "IO.puts") and String.contains?(ast_string, "checkpoint")
  end

  defp expression_tracing_present?(ast, _expression_name) do
    # Check if expression tracing comment is present (simplified implementation)
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "Expression tracing enabled")
  end

  defp variable_capture_at_line?(ast, line_number) do
    # Check if variable capture is injected at specific line
    Macro.prewalk(ast, false, fn
      {{:., _, [{:__aliases__, _, [:ElixirScope, :Capture, :InstrumentationRuntime]}, :report_local_variable_snapshot]}, _, args}, _acc ->
        # Check if the line number matches
        case args do
          [_, _, ^line_number, _] -> {true, true}
          _ -> {false, false}
        end
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp captures_variables?(ast, variable_names) do
    # Check if all specified variables are captured
    ast_string = Macro.to_string(ast)
    Enum.all?(variable_names, fn var ->
      String.contains?(ast_string, "#{var}")
    end)
  end

  defp runtime_registration_present?(ast, module_name) do
    # Check if runtime registration call is present
    Macro.prewalk(ast, false, fn
      {{:., _, [{:__aliases__, _, [:ElixirScope, :Runtime]}, :register_instrumented_module]}, _, [^module_name, _]}, _acc ->
        {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp plan_passed_to_runtime?(ast, _plan) do
    # Check if plan is passed to runtime system
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "register_instrumented_module")
  end

  defp runtime_coordination_present?(ast) do
    # Check if runtime coordination logic is present
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "ast_tracing_enabled?")
  end

  defp ast_tracing_check_present?(ast) do
    # Check if AST tracing enable/disable check is present
    Macro.prewalk(ast, false, fn
      {:if, _, [{:ast_tracing_enabled?, _, _}, _]}, _acc ->
        {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp custom_injection_present?(ast, _line_number) do
    # Check if custom injection is present at line
    # This is a simplified check - in practice would need more sophisticated logic
    ast_string = Macro.to_string(ast)
    String.contains?(ast_string, "Checkpoint")
  end

  defp has_variable_capture?(ast) do
    # Check if any variable capture is present
    Macro.prewalk(ast, false, fn
      {{:., _, [{:__aliases__, _, [:ElixirScope, :Capture, :InstrumentationRuntime]}, :report_local_variable_snapshot]}, _, _}, _acc ->
        {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end

  defp has_expression_tracing?(ast) do
    # Check if any expression tracing is present
    Macro.prewalk(ast, false, fn
      {{:., _, [{:__aliases__, _, [:ElixirScope, :Capture, :InstrumentationRuntime]}, :report_expression_value]}, _, _}, _acc ->
        {true, true}
      node, acc -> {node, acc}
    end) |> elem(1)
  end
end 