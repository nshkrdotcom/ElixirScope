defmodule ElixirScope.ASTRepository.DFGGeneratorTest do
  use ExUnit.Case, async: true
  
  alias ElixirScope.ASTRepository.Enhanced.{DFGGenerator, DFGData, DFGNode, DFGEdge}
  alias ElixirScope.TestHelpers

  describe "Basic DFG generation" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "generates DFG for simple variable assignment" do
      function_ast = quote do
        def simple_assignment do
          x = 42
          x
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      assert %DFGData{} = dfg
      assert length(dfg.nodes) >= 2  # Variable definition and use
      assert length(dfg.edges) >= 1   # Data flow from definition to use
      assert length(dfg.variables) >= 1  # Variable 'x'
    end
    
    test "generates DFG for variable dependencies" do
      function_ast = quote do
        def variable_dependencies do
          x = 10
          y = x + 5
          z = x + y
          z
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should have nodes for each variable
      assert length(dfg.variables) >= 3  # x, y, z
      
      # Should have data flow edges
      data_edges = Enum.filter(dfg.edges, &(&1.type == :data_flow))
      assert length(data_edges) >= 3  # x->y, x->z, y->z
      
      # Should detect variable mutations
      assert length(dfg.mutations) == 0  # No mutations in this example
    end
    
    test "detects variable mutations" do
      function_ast = quote do
        def variable_mutations do
          x = 1
          x = x + 1  # Mutation
          x = x * 2  # Another mutation
          x
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should detect mutations
      assert length(dfg.mutations) >= 2
      
      # Should have mutation edges
      mutation_edges = Enum.filter(dfg.edges, &(&1.type == :mutation))
      assert length(mutation_edges) >= 2
    end
  end

  describe "Complex data flow patterns" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "generates DFG for conditional data flow" do
      function_ast = quote do
        def conditional_flow(input) do
          if input > 0 do
            x = input * 2
            y = x + 1
          else
            x = input * -1
            y = x - 1
          end
          
          z = y + 10
          z
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should have conditional data flow
      conditional_edges = Enum.filter(dfg.edges, &(&1.type == :conditional_flow))
      assert length(conditional_edges) >= 2
      
      # Should track variable definitions in different branches
      assert length(dfg.variables) >= 4  # input, x, y, z
      
      # Should have phi nodes for variables defined in both branches
      phi_nodes = Enum.filter(dfg.nodes, &(&1.type == :phi))
      assert length(phi_nodes) >= 2  # For x and y
    end
    
    test "generates DFG for function calls with data flow" do
      function_ast = quote do
        def function_calls do
          x = get_value()
          y = process(x)
          z = transform(x, y)
          save(z)
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should have call nodes
      call_nodes = Enum.filter(dfg.nodes, &(&1.type == :call))
      assert length(call_nodes) >= 4
      
      # Should have data flow through function calls
      call_edges = Enum.filter(dfg.edges, &(&1.type == :call_flow))
      assert length(call_edges) >= 3
    end
    
    test "handles pattern matching data flow" do
      function_ast = quote do
        def pattern_matching(tuple) do
          {x, y} = tuple
          case {x, y} do
            {a, b} when a > b -> a - b
            {a, b} -> a + b
          end
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should have pattern match nodes
      pattern_nodes = Enum.filter(dfg.nodes, &(&1.type == :pattern_match))
      assert length(pattern_nodes) >= 2
      
      # Should track variable bindings
      assert length(dfg.variables) >= 4  # tuple, x, y, a, b
    end
  end

  describe "Data dependency analysis" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "identifies data dependencies correctly" do
      function_ast = quote do
        def dependencies do
          a = input()
          b = process(a)
          c = transform(a)
          d = combine(b, c)
          output(d)
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should identify dependency chains
      deps = DFGGenerator.get_dependencies(dfg, "d")
      assert "a" in deps  # d depends on a (through b and c)
      assert "b" in deps  # d depends on b
      assert "c" in deps  # d depends on c
    end
    
    test "detects circular dependencies" do
      # This test will fail initially (TDD red phase)
      function_ast = quote do
        def circular_deps do
          x = y + 1
          y = x + 1  # Circular dependency
          x
        end
      end
      
      # Should detect circular dependency
      assert {:error, :circular_dependency} = DFGGenerator.generate_dfg(function_ast)
    end
    
    test "calculates data flow metrics" do
      function_ast = quote do
        def complex_flow do
          a = input1()
          b = input2()
          c = process(a)
          d = process(b)
          e = combine(c, d)
          f = transform(e)
          output(f)
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should calculate metrics
      assert dfg.fan_in >= 1    # Variables with multiple inputs
      assert dfg.fan_out >= 1   # Variables with multiple outputs
      assert dfg.depth >= 3     # Dependency chain depth
      assert dfg.width >= 2     # Parallel data flows
    end
  end

  describe "Variable lifetime analysis" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "tracks variable lifetimes" do
      function_ast = quote do
        def variable_lifetimes do
          x = 1        # x born
          y = x + 2    # y born, x used
          z = y * 3    # z born, y used
          # x dies here (last use was line 2)
          w = z + 4    # w born, z used
          # y dies here (last use was line 3)
          w            # z dies here, w used and dies
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should track lifetimes
      lifetimes = dfg.variable_lifetimes
      assert Map.has_key?(lifetimes, "x")
      assert Map.has_key?(lifetimes, "y")
      assert Map.has_key?(lifetimes, "z")
      assert Map.has_key?(lifetimes, "w")
      
      # Should have birth and death points
      x_lifetime = lifetimes["x"]
      assert x_lifetime.birth_line >= 1
      assert x_lifetime.death_line >= x_lifetime.birth_line
    end
    
    test "detects unused variables" do
      function_ast = quote do
        def unused_variables do
          x = 1
          y = 2    # y is unused
          z = 3    # z is unused
          x + 1
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should detect unused variables
      assert length(dfg.unused_variables) >= 2
      assert "y" in dfg.unused_variables
      assert "z" in dfg.unused_variables
      refute "x" in dfg.unused_variables
    end
    
    test "identifies variable shadowing" do
      function_ast = quote do
        def variable_shadowing do
          x = 1
          case input() do
            {:ok, x} -> x + 1  # x shadows outer x
            _ -> x
          end
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should detect shadowing
      assert length(dfg.shadowed_variables) >= 1
      
      shadowing = hd(dfg.shadowed_variables)
      assert shadowing.variable_name == "x"
      assert shadowing.outer_scope != nil
      assert shadowing.inner_scope != nil
    end
  end

  describe "Performance and optimization analysis" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "identifies optimization opportunities" do
      function_ast = quote do
        def optimization_opportunities do
          x = expensive_computation()
          y = x + 1
          z = x + 2  # Could reuse x
          w = expensive_computation()  # Duplicate computation
          {y, z, w}
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should identify optimization opportunities
      optimizations = dfg.optimization_hints
      
      # Should detect common subexpressions
      cse_hints = Enum.filter(optimizations, &(&1.type == :common_subexpression))
      assert length(cse_hints) >= 1
      
      # Should detect dead code
      dead_code_hints = Enum.filter(optimizations, &(&1.type == :dead_code))
      assert length(dead_code_hints) >= 0
    end
    
    test "calculates data flow complexity" do
      function_ast = quote do
        def complex_data_flow do
          a = input()
          b = process(a)
          c = process(a)
          d = combine(b, c)
          e = transform(d)
          f = validate(e)
          g = finalize(f)
          output(g)
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should calculate complexity metrics
      assert dfg.complexity_score > 1.0
      assert dfg.data_flow_complexity >= 3
      assert dfg.variable_complexity >= 2
    end
  end

  describe "Integration and error handling" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "handles malformed AST gracefully" do
      malformed_ast = {:invalid, :ast, :structure}
      
      assert {:error, :invalid_ast} = DFGGenerator.generate_dfg(malformed_ast)
    end
    
    test "handles empty function body" do
      empty_ast = quote do
        def empty_function do
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(empty_ast)
      
      assert length(dfg.nodes) >= 0
      assert length(dfg.edges) >= 0
      assert length(dfg.variables) == 0
    end
    
    test "handles very complex data flows efficiently" do
      # Generate function with many variables and dependencies
      complex_ast = generate_complex_data_flow_ast(50)
      
      {time_us, {:ok, dfg}} = :timer.tc(fn ->
        DFGGenerator.generate_dfg(complex_ast)
      end)
      
      # Should complete in reasonable time (<200ms)
      assert time_us < 200_000
      assert length(dfg.variables) >= 50
    end
    
    test "memory usage is reasonable for large DFGs" do
      large_ast = generate_complex_data_flow_ast(100)
      
      initial_memory = :erlang.memory(:total)
      {:ok, dfg} = DFGGenerator.generate_dfg(large_ast)
      final_memory = :erlang.memory(:total)
      
      memory_used = final_memory - initial_memory
      
      # Should use reasonable memory (less than 20MB for large DFG)
      assert memory_used < 20_000_000
      assert length(dfg.variables) >= 100
    end
  end

  describe "Advanced data flow patterns" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      :ok
    end
    
    test "handles closure variable capture" do
      function_ast = quote do
        def closure_capture do
          x = 10
          y = 20
          
          fn z ->
            x + y + z  # Captures x and y
          end
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should detect captured variables
      captured_vars = dfg.captured_variables
      assert "x" in captured_vars
      assert "y" in captured_vars
      refute "z" in captured_vars  # z is a parameter, not captured
      
      # Should have capture edges
      capture_edges = Enum.filter(dfg.edges, &(&1.type == :capture))
      assert length(capture_edges) >= 2
    end
    
    test "tracks data flow through comprehensions" do
      function_ast = quote do
        def comprehension_flow do
          list = [1, 2, 3]
          multiplier = 2
          
          for item <- list do
            item * multiplier  # multiplier is captured
          end
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should track comprehension data flow
      comp_nodes = Enum.filter(dfg.nodes, &(&1.type == :comprehension))
      assert length(comp_nodes) >= 1
      
      # Should detect variable usage in comprehension
      assert "multiplier" in dfg.captured_variables
    end
    
    test "analyzes pipe operator data flow" do
      function_ast = quote do
        def pipe_flow do
          input()
          |> process()
          |> transform()
          |> validate()
          |> output()
        end
      end
      
      {:ok, dfg} = DFGGenerator.generate_dfg(function_ast)
      
      # Should create pipe flow chain
      pipe_edges = Enum.filter(dfg.edges, &(&1.type == :pipe_flow))
      assert length(pipe_edges) >= 4
      
      # Should have linear data flow
      assert dfg.data_flow_complexity >= 4
    end
  end

  # Helper functions
  defp generate_complex_data_flow_ast(var_count) do
    # Generate function with many variables and dependencies
    assignments = 1..var_count
    |> Enum.map(fn i ->
      if i == 1 do
        quote do: unquote(Macro.var(:"var#{i}", nil)) = input()
      else
        prev_var = Macro.var(:"var#{i-1}", nil)
        quote do: unquote(Macro.var(:"var#{i}", nil)) = process(unquote(prev_var))
      end
    end)
    
    final_var = Macro.var(:"var#{var_count}", nil)
    
    body = assignments ++ [quote(do: output(unquote(final_var)))]
    
    quote do
      def complex_data_flow do
        unquote_splicing(body)
      end
    end
  end
end 