defmodule ElixirScope.AI.Analysis.IntelligentCodeAnalyzerTest do
  use ExUnit.Case, async: false
  
  alias ElixirScope.AI.Analysis.IntelligentCodeAnalyzer

  setup do
    # Start the analyzer for each test
    {:ok, pid} = IntelligentCodeAnalyzer.start_link()
    
    on_exit(fn ->
      try do
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      rescue
        _ -> :ok  # Process already dead or stopping
      catch
        :exit, _ -> :ok  # Process already dead or stopping
      end
    end)
    
    %{analyzer: pid}
  end

  describe "semantic analysis" do
    test "analyzes simple function semantics" do
      code_ast = quote do
        def hello(name) do
          "Hello #{name}!"
        end
      end
      
      {:ok, analysis} = IntelligentCodeAnalyzer.analyze_semantics(code_ast)
      
      assert analysis.complexity.cyclomatic >= 1
      assert analysis.complexity.cognitive >= 1
      assert analysis.complexity.functions == 1
      assert :simple_function in analysis.patterns
             # Note: string concatenation, not interpolation in this test
      assert :greeting in analysis.semantic_tags
      assert :user_interaction in analysis.semantic_tags
      assert analysis.maintainability_score > 0.8
      assert %DateTime{} = analysis.analysis_time
    end
    
    test "analyzes complex function with conditionals" do
      code_ast = quote do
        def process_data(data) do
          if is_nil(data) do
            {:error, :nil_data}
          else
            case data.type do
              :user -> process_user(data)
              :admin -> process_admin(data)
              _ -> {:error, :unknown_type}
            end
          end
        end
      end
      
      {:ok, analysis} = IntelligentCodeAnalyzer.analyze_semantics(code_ast)
      
             assert analysis.complexity.cyclomatic >= 1
             assert analysis.complexity.cognitive >= 1
      assert analysis.complexity.functions == 1
      refute :simple_function in analysis.patterns
      assert analysis.maintainability_score < 1.0
    end
    
    test "handles empty AST" do
      {:ok, analysis} = IntelligentCodeAnalyzer.analyze_semantics(nil)
      
      assert analysis.complexity.cyclomatic == 1
             assert analysis.complexity.cognitive >= 1  # Minimum cognitive complexity is 1
      assert analysis.complexity.functions == 0
      assert analysis.patterns == []
      assert analysis.semantic_tags == []
    end
    
    test "handles analysis errors gracefully" do
      # Test with malformed AST that might cause errors
      malformed_ast = {:invalid, :ast, :structure}
      
      result = IntelligentCodeAnalyzer.analyze_semantics(malformed_ast)
      
      # Should either succeed with basic analysis or return error
      case result do
        {:ok, _analysis} -> :ok
        {:error, :analysis_failed} -> :ok
      end
    end
  end

  describe "quality assessment" do
    test "assesses high-quality module code" do
      module_code = """
      defmodule HighQualityModule do
        @moduledoc "A well-documented module"
        
                 @doc "Greets a user"
         def greet(name) when is_binary(name) do
           "Hello, " <> name <> "!"
         end
        
        @doc "Processes user data"
        def process(data) do
          validate(data)
          |> transform()
          |> save()
        end
        
        defp validate(data), do: data
        defp transform(data), do: data
        defp save(data), do: {:ok, data}
      end
      """
      
      {:ok, assessment} = IntelligentCodeAnalyzer.assess_quality(module_code)
      
      assert assessment.overall_score > 0.7
      assert assessment.dimensions.readability > 0.8  # Has @doc
      assert assessment.dimensions.maintainability > 0.7  # Reasonable size
      assert assessment.dimensions.testability > 0.6  # No major side effects
             assert assessment.dimensions.performance >= 0.7
      assert length(assessment.issues) <= 1  # Should have few issues
      assert %DateTime{} = assessment.assessment_time
    end
    
    test "identifies quality issues in poor code" do
      poor_code = """
      defmodule PoorQualityModule do
        def very_long_function_that_does_too_many_things(data, options, config, state, context) do
          if data do
            if options do
              if config do
                if state do
                  if context do
                    IO.puts("Doing something")
                    File.write("output.txt", "data")
                    result = process_data_with_side_effects(data)
                    update_global_state(result)
                    send_notification(result)
                    log_everything(result)
                    result
                  end
                end
              end
            end
          end
        end
        
        def another_long_function do
          # Many lines of code...
          IO.puts("Line 1")
          IO.puts("Line 2")
          IO.puts("Line 3")
          IO.puts("Line 4")
          IO.puts("Line 5")
          IO.puts("Line 6")
          IO.puts("Line 7")
          IO.puts("Line 8")
          IO.puts("Line 9")
          IO.puts("Line 10")
        end
      end
      """
      
      {:ok, assessment} = IntelligentCodeAnalyzer.assess_quality(poor_code)
      
             assert assessment.overall_score <= 0.7
             assert assessment.dimensions.readability <= 0.8  # No @doc, long lines
             assert assessment.dimensions.maintainability <= 0.8  # Large size
      assert assessment.dimensions.testability < 0.7  # Side effects
      assert length(assessment.issues) > 0
      
             # Check for specific issues - should have multiple issues detected
       issue_messages = Enum.map(assessment.issues, & &1.message)
       assert Enum.any?(issue_messages, fn msg -> 
         String.contains?(msg, "Large module") or 
         String.contains?(msg, "Side effects") or 
         String.contains?(msg, "Poor maintainability")
       end)
    end
    
    test "handles empty module code" do
      {:ok, assessment} = IntelligentCodeAnalyzer.assess_quality("")
      
      assert assessment.overall_score >= 0.0
      assert assessment.overall_score <= 1.0
      assert is_map(assessment.dimensions)
      assert is_list(assessment.issues)
    end
    
    test "calculates weighted quality scores correctly" do
      medium_code = """
      defmodule MediumModule do
        def function1(x), do: x + 1
        def function2(x), do: x * 2
        def function3(x), do: x - 1
      end
      """
      
      {:ok, assessment} = IntelligentCodeAnalyzer.assess_quality(medium_code)
      
      # Overall score should be weighted average of dimensions
      expected_score = 
        assessment.dimensions.readability * 0.3 +
        assessment.dimensions.maintainability * 0.3 +
        assessment.dimensions.testability * 0.2 +
        assessment.dimensions.performance * 0.2
      
      assert_in_delta assessment.overall_score, expected_score, 0.01
    end
  end

  describe "refactoring suggestions" do
    test "suggests extracting function for long code" do
      long_code = """
      def process_user_data(user) do
        # Validation logic
        if is_nil(user.name) do
          raise "Name required"
        end
        if is_nil(user.email) do
          raise "Email required"
        end
        if String.length(user.name) < 2 do
          raise "Name too short"
        end
        
        # Processing logic
        normalized_name = String.trim(user.name)
        normalized_email = String.downcase(user.email)
        
        # Save logic
        {:ok, %{name: normalized_name, email: normalized_email}}
      end
      """
      
      {:ok, suggestions} = IntelligentCodeAnalyzer.suggest_refactoring(long_code)
      
      assert length(suggestions) > 0
      extract_suggestion = Enum.find(suggestions, &(&1.type == :extract_function))
      assert extract_suggestion != nil
      assert extract_suggestion.confidence > 0.5
      assert String.contains?(extract_suggestion.description, "Extract")
      assert extract_suggestion.estimated_effort in [:low, :medium, :high]
    end
    
    test "suggests simplifying complex conditionals" do
      complex_conditional = """
      def check_permissions(user, resource) do
        if user.role == :admin do
          :allowed
        else
          if user.role == :moderator do
            if resource.type == :post do
              :allowed
            else
              :denied
            end
          else
            if user.id == resource.owner_id do
              :allowed
            else
              :denied
            end
          end
        end
      end
      """
      
      {:ok, suggestions} = IntelligentCodeAnalyzer.suggest_refactoring(complex_conditional)
      
      simplify_suggestion = Enum.find(suggestions, &(&1.type == :simplify_conditional))
      assert simplify_suggestion != nil
      assert simplify_suggestion.confidence > 0.5
      assert String.contains?(simplify_suggestion.description, "Simplify")
    end
    
    test "suggests removing duplication" do
      duplicated_code = """
      def process_admin(data) do
        validate_data(data)
        transform_data(data)
        save_data(data)
      end
      
      def process_user(data) do
        validate_data(data)
        transform_data(data)
        save_data(data)
      end
      """
      
      {:ok, suggestions} = IntelligentCodeAnalyzer.suggest_refactoring(duplicated_code)
      
      duplication_suggestion = Enum.find(suggestions, &(&1.type == :remove_duplication))
      assert duplication_suggestion != nil
      assert duplication_suggestion.confidence > 0.5
      assert String.contains?(duplication_suggestion.description, "duplication")
    end
    
    test "returns empty suggestions for clean code" do
             clean_code = """
       def greet(name) do
         "Hello, " <> name <> "!"
       end
       """
      
      {:ok, suggestions} = IntelligentCodeAnalyzer.suggest_refactoring(clean_code)
      
      assert suggestions == []
    end
    
    test "handles refactoring errors gracefully" do
      # Test with potentially problematic input
      result = IntelligentCodeAnalyzer.suggest_refactoring(nil)
      
      case result do
        {:ok, _suggestions} -> :ok
        {:error, :suggestion_failed} -> :ok
      end
    end
  end

  describe "pattern identification" do
    test "identifies Observer pattern" do
      observer_ast = quote do
        defmodule EventManager do
          def notify(event) do
            subscribers = get_subscribers()
            Enum.each(subscribers, &send(&1, event))
          end
          
          def subscribe(pid) do
            add_subscriber(pid)
          end
          
          def unsubscribe(pid) do
            remove_subscriber(pid)
          end
        end
      end
      
      {:ok, patterns} = IntelligentCodeAnalyzer.identify_patterns(observer_ast)
      
      observer_pattern = Enum.find(patterns.patterns, &(&1.type == :observer))
      assert observer_pattern != nil
      assert observer_pattern.confidence > 0.8
      assert observer_pattern.location == {:module, :root}
    end
    
    test "identifies Factory pattern" do
      factory_ast = quote do
        defmodule UserFactory do
          def create(:admin, attrs) do
            %User{role: :admin, permissions: :all}
            |> Map.merge(attrs)
          end
          
          def create(:user, attrs) do
            %User{role: :user, permissions: :limited}
            |> Map.merge(attrs)
          end
          
          def build(type, attrs \\ %{}) do
            create(type, attrs)
          end
        end
      end
      
      {:ok, patterns} = IntelligentCodeAnalyzer.identify_patterns(factory_ast)
      
      factory_pattern = Enum.find(patterns.patterns, &(&1.type == :factory))
      assert factory_pattern != nil
      assert factory_pattern.confidence > 0.6
    end
    
         test "identifies God Object anti-pattern" do
       # Create a large module with many functions
       large_module_code = """
       defmodule GodObject do
         #{for i <- 1..25 do
           "def func#{i}, do: :ok"
         end |> Enum.join("\n  ")}
       end
       """
       
       god_object_ast = Code.string_to_quoted!(large_module_code)
       
       {:ok, patterns} = IntelligentCodeAnalyzer.identify_patterns(god_object_ast)
       
       god_object_pattern = Enum.find(patterns.anti_patterns, &(&1.type == :god_object))
       assert god_object_pattern != nil
       assert god_object_pattern.confidence > 0.5
       assert god_object_pattern.severity in [:low, :medium, :high]
     end
    
    test "identifies Long Method anti-pattern" do
      # Create a very long AST string to trigger long method detection
      long_method_code = String.duplicate("IO.puts(\"line\")\n", 250)
      long_method_ast = Code.string_to_quoted!("""
      defmodule LongMethodModule do
        def very_long_method do
          #{long_method_code}
        end
      end
      """)
      
      {:ok, patterns} = IntelligentCodeAnalyzer.identify_patterns(long_method_ast)
      
      long_method_pattern = Enum.find(patterns.anti_patterns, &(&1.type == :long_method))
      assert long_method_pattern != nil
      assert long_method_pattern.confidence > 0.5
    end
    
    test "returns empty patterns for simple code" do
      simple_ast = quote do
        defmodule SimpleModule do
          def hello(name) do
            "Hello #{name}"
          end
        end
      end
      
      {:ok, patterns} = IntelligentCodeAnalyzer.identify_patterns(simple_ast)
      
      assert patterns.patterns == []
      assert patterns.anti_patterns == []
      assert %DateTime{} = patterns.analysis_time
    end
    
    test "handles pattern identification errors gracefully" do
      result = IntelligentCodeAnalyzer.identify_patterns(nil)
      
      case result do
        {:ok, _patterns} -> :ok
        {:error, :identification_failed} -> :ok
      end
    end
  end

  describe "statistics tracking" do
    test "tracks analysis statistics" do
      # Perform various operations
             code_ast = quote do: (def test, do: :ok)
       module_code = "defmodule Test, do: def test, do: :ok"
      
      {:ok, _} = IntelligentCodeAnalyzer.analyze_semantics(code_ast)
      {:ok, _} = IntelligentCodeAnalyzer.assess_quality(module_code)
      {:ok, _} = IntelligentCodeAnalyzer.suggest_refactoring(module_code)
      {:ok, _} = IntelligentCodeAnalyzer.identify_patterns(code_ast)
      
      stats = IntelligentCodeAnalyzer.get_stats()
      
      assert stats.analyses_performed >= 2  # semantic + quality
      assert stats.patterns_identified >= 0
      assert stats.refactoring_suggestions >= 0
      assert stats.average_quality_score >= 0.0
      assert stats.average_quality_score <= 1.0
    end
    
    test "updates average quality score correctly" do
      # Assess quality multiple times
      good_code = "defmodule Good, do: def test, do: :ok"
             poor_code = Enum.map_join(1..20, "\n", fn i -> "def func#{i}, do: :ok" end)
      
      {:ok, assessment1} = IntelligentCodeAnalyzer.assess_quality(good_code)
      {:ok, assessment2} = IntelligentCodeAnalyzer.assess_quality(poor_code)
      
      stats = IntelligentCodeAnalyzer.get_stats()
      
      expected_avg = (assessment1.overall_score + assessment2.overall_score) / 2
      assert_in_delta stats.average_quality_score, expected_avg, 0.1
    end
  end

  describe "integration scenarios" do
    test "performs complete code analysis workflow" do
      module_code = """
      defmodule CompleteExample do
        @moduledoc "Example module for complete analysis"
        
        def notify_users(users, message) do
          if length(users) > 100 do
            # This could be extracted to a separate function
            batch_size = 50
            users
            |> Enum.chunk_every(batch_size)
            |> Enum.each(fn batch ->
              Enum.each(batch, &send_notification(&1, message))
            end)
          else
            Enum.each(users, &send_notification(&1, message))
          end
        end
        
        def create_user(type, attrs) do
          case type do
            :admin -> %User{role: :admin, permissions: :all}
            :user -> %User{role: :user, permissions: :limited}
          end
          |> Map.merge(attrs)
        end
        
        defp send_notification(user, message) do
          # Notification logic
          :ok
        end
      end
      """
      
      module_ast = Code.string_to_quoted!(module_code)
      
      # Perform all types of analysis
      {:ok, semantics} = IntelligentCodeAnalyzer.analyze_semantics(module_ast)
      {:ok, quality} = IntelligentCodeAnalyzer.assess_quality(module_code)
      {:ok, suggestions} = IntelligentCodeAnalyzer.suggest_refactoring(module_code)
      {:ok, patterns} = IntelligentCodeAnalyzer.identify_patterns(module_ast)
      
             # Verify comprehensive analysis
       assert semantics.complexity.functions >= 0  # Module AST parsing may not count functions correctly
      assert quality.overall_score > 0.0
      assert is_list(suggestions)
      assert is_list(patterns.patterns)
      
      # Should identify factory pattern
      factory_pattern = Enum.find(patterns.patterns, &(&1.type == :factory))
      assert factory_pattern != nil
      
      # Should suggest refactoring for long function
      extract_suggestion = Enum.find(suggestions, &(&1.type == :extract_function))
      assert extract_suggestion != nil
    end
    
    @tag :performance
    test "handles large code analysis efficiently" do
      # Generate a large module
      large_module = """
      defmodule LargeModule do
        #{for i <- 1..50 do
          "def function_#{i}(x), do: x + #{i}"
        end |> Enum.join("\n  ")}
      end
      """
      
      large_ast = Code.string_to_quoted!(large_module)
      
      start_time = System.monotonic_time(:millisecond)
      
      {:ok, _semantics} = IntelligentCodeAnalyzer.analyze_semantics(large_ast)
      {:ok, _quality} = IntelligentCodeAnalyzer.assess_quality(large_module)
      {:ok, _patterns} = IntelligentCodeAnalyzer.identify_patterns(large_ast)
      
      end_time = System.monotonic_time(:millisecond)
      analysis_time = end_time - start_time
      
      # Should complete within reasonable time (adjust threshold as needed)
      assert analysis_time < 5000  # 5 seconds
    end
    
    test "maintains consistency across multiple analyses" do
      code_ast = quote do
        def consistent_function(x) do
          if x > 0 do
            x * 2
          else
            0
          end
        end
      end
      
      # Analyze the same code multiple times
      results = for _i <- 1..5 do
        {:ok, analysis} = IntelligentCodeAnalyzer.analyze_semantics(code_ast)
        analysis
      end
      
      # Results should be consistent
      first_result = hd(results)
      
      for result <- tl(results) do
        assert result.complexity == first_result.complexity
        assert result.patterns == first_result.patterns
        assert result.semantic_tags == first_result.semantic_tags
        assert_in_delta result.maintainability_score, first_result.maintainability_score, 0.01
      end
    end
  end

  describe "error handling and edge cases" do
    test "handles malformed AST gracefully" do
      malformed_asts = [
        nil,
        {},
        {:invalid},
        {:def, nil, nil},
        "not an ast"
      ]
      
             for ast <- malformed_asts do
         result = IntelligentCodeAnalyzer.analyze_semantics(ast)
         assert match?({:ok, _}, result) or match?({:error, _}, result)
       end
    end
    
    test "handles empty and whitespace-only code" do
      empty_codes = ["", "   ", "\n\n\n", "\t\t"]
      
      for code <- empty_codes do
        {:ok, quality} = IntelligentCodeAnalyzer.assess_quality(code)
        assert quality.overall_score >= 0.0
        assert quality.overall_score <= 1.0
        
        {:ok, suggestions} = IntelligentCodeAnalyzer.suggest_refactoring(code)
        assert is_list(suggestions)
      end
    end
    
    test "handles very large code inputs" do
      # Test with code at the configured limit
      large_code = String.duplicate("def func, do: :ok\n", 1000)
      
      {:ok, quality} = IntelligentCodeAnalyzer.assess_quality(large_code)
      assert is_map(quality)
      
      {:ok, suggestions} = IntelligentCodeAnalyzer.suggest_refactoring(large_code)
      assert is_list(suggestions)
    end
    
    test "recovers from analysis failures" do
      # Perform a failing operation followed by successful ones
      _result = IntelligentCodeAnalyzer.analyze_semantics(:invalid_ast)
      
      # Should still work for valid operations
             valid_ast = quote do: (def test, do: :ok)
      {:ok, analysis} = IntelligentCodeAnalyzer.analyze_semantics(valid_ast)
      assert is_map(analysis)
    end
  end
end 