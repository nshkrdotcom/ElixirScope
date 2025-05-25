defmodule ElixirScope.Compiler.MixTaskTest do
  use ExUnit.Case, async: false
  
  alias Mix.Tasks.Compile.ElixirScope, as: MixTask

  @temp_project_dir "tmp/test_project"

  setup do
    # Ensure ElixirScope is running for tests
    {:ok, _} = Application.ensure_all_started(:elixir_scope)
    
    # Create temp project structure
    File.mkdir_p!(@temp_project_dir <> "/lib")
    File.mkdir_p!(@temp_project_dir <> "/_build/test")
    
    # Clean up after test
    on_exit(fn ->
      File.rm_rf(@temp_project_dir)
      # Clean up persistent term storage
      try do
        :persistent_term.erase(:elixir_scope_default_storage)
      rescue
        _ -> :ok
      end
    end)
    
    %{temp_dir: @temp_project_dir}
  end

  describe "run/1" do
    test "runs successfully with basic configuration", %{temp_dir: temp_dir} do
      # Create a simple test file
      test_file = Path.join([temp_dir, "lib", "simple_module.ex"])
      File.write!(test_file, """
      defmodule SimpleModule do
        def hello(name) do
          "Hello, \#{name}!"
        end
      end
      """)
      
      # Create mock instrumentation plan
      plan = %{
        modules: %{
          SimpleModule => %{
            functions: %{
              {:hello, 1} => %{capture_args: true, capture_return: true}
            }
          }
        }
      }
      
      # Store plan for orchestrator to return
      ElixirScope.Storage.DataAccess.store_instrumentation_plan(plan)
      
      # Change to temp directory for compilation
      original_cwd = File.cwd!()
      File.cd!(temp_dir)
      
      try do
        # Run the compiler
        result = MixTask.run([])
        
        assert {:ok, []} = result
        
        # Verify output file was created
        output_file = Path.join(["_build", "test", "elixir_scope", "lib", "simple_module.ex"])
        assert File.exists?(output_file)
        
        # Verify file contains instrumentation
        content = File.read!(output_file)
        assert String.contains?(content, "ElixirScope.Capture.InstrumentationRuntime")
        assert String.contains?(content, "# This file was automatically instrumented by ElixirScope")
      after
        File.cd!(original_cwd)
      end
    end
    
    test "handles parse errors gracefully", %{temp_dir: temp_dir} do
      # Create a file with syntax errors
      test_file = Path.join([temp_dir, "lib", "broken_module.ex"])
      File.write!(test_file, """
      defmodule BrokenModule do
        def hello(name
          "Hello, \#{name}!"
        end
      end
      """)
      
      # Create basic plan
      plan = %{modules: %{}}
      ElixirScope.Storage.DataAccess.store_instrumentation_plan(plan)
      
      original_cwd = File.cwd!()
      File.cd!(temp_dir)
      
      try do
        result = MixTask.run([])
        
        # Should return error with details
        assert {:error, [reason]} = result
        assert is_tuple(reason)
        {:transformation_failed, _failed_files} = reason
      after
        File.cd!(original_cwd)
      end
    end
    
    test "skips files that should not be instrumented", %{temp_dir: temp_dir} do
      # Create test file and regular file
      test_file = Path.join([temp_dir, "lib", "regular_module.ex"])
      File.write!(test_file, """
      defmodule RegularModule do
        def process do
          :ok
        end
      end
      """)
      
      test_test_file = Path.join([temp_dir, "test", "regular_module_test.exs"])
      File.mkdir_p!(Path.dirname(test_test_file))
      File.write!(test_test_file, """
      defmodule RegularModuleTest do
        use ExUnit.Case
        
        test "works" do
          assert RegularModule.process() == :ok
        end
      end
      """)
      
      # Plan excludes test files
      plan = %{
        modules: %{RegularModule => %{}},
        instrument_tests: false
      }
      ElixirScope.Storage.DataAccess.store_instrumentation_plan(plan)
      
      original_cwd = File.cwd!()
      File.cd!(temp_dir)
      
      try do
        result = MixTask.run([])
        assert {:ok, []} = result
        
        # Regular module should be transformed
        output_file = Path.join(["_build", "test", "elixir_scope", "lib", "regular_module.ex"])
        assert File.exists?(output_file)
        
        # Test file should NOT be transformed (no output created)
        test_output_file = Path.join(["_build", "test", "elixir_scope", "test", "regular_module_test.exs"])
        refute File.exists?(test_output_file)
      after
        File.cd!(original_cwd)
      end
    end
    
    test "respects module exclusion patterns", %{temp_dir: temp_dir} do
      # Create modules that should be excluded
      excluded_file = Path.join([temp_dir, "lib", "excluded_module.ex"])
      File.write!(excluded_file, """
      defmodule MyApp.ExcludedModule do
        def do_work do
          :work_done
        end
      end
      """)
      
      included_file = Path.join([temp_dir, "lib", "included_module.ex"])
      File.write!(included_file, """
      defmodule MyApp.IncludedModule do
        def do_work do
          :work_done
        end
      end
      """)
      
      # Plan excludes specific module
      plan = %{
        modules: %{},
        excluded_modules: [MyApp.ExcludedModule, "Excluded"]
      }
      ElixirScope.Storage.DataAccess.store_instrumentation_plan(plan)
      
      original_cwd = File.cwd!()
      File.cd!(temp_dir)
      
      try do
        result = MixTask.run([])
        assert {:ok, []} = result
        
        # Excluded module should NOT be transformed
        excluded_output = Path.join(["_build", "test", "elixir_scope", "lib", "excluded_module.ex"])
        refute File.exists?(excluded_output)
        
        # Included module should be transformed  
        included_output = Path.join(["_build", "test", "elixir_scope", "lib", "included_module.ex"])
        assert File.exists?(included_output)
      after
        File.cd!(original_cwd)
      end
    end
    
    test "handles command line options", %{temp_dir: temp_dir} do
      # Create simple file
      test_file = Path.join([temp_dir, "lib", "option_test.ex"])
      File.write!(test_file, """
      defmodule OptionTest do
        def test do
          :ok
        end
      end
      """)
      
      plan = %{modules: %{}}
      ElixirScope.Storage.DataAccess.store_instrumentation_plan(plan)
      
      original_cwd = File.cwd!()
      File.cd!(temp_dir)
      
      try do
        # Test with debug option
        result = MixTask.run(["--debug"])
        assert {:ok, []} = result
        
        # Test with force option
        result = MixTask.run(["--force"])
        assert {:ok, []} = result
        
        # Test with strategy options
        result = MixTask.run(["--minimal"])
        assert {:ok, []} = result
        
        result = MixTask.run(["--full-trace"])
        assert {:ok, []} = result
      after
        File.cd!(original_cwd)
      end
    end
  end

  describe "transform_ast/2" do
    test "transforms AST directly with given plan" do
      # Test with a single function AST
      ast = quote do
        def greet(name) do
          "Hello #{name}"
        end
      end
      
      plan = %{
        functions: %{
          {:greet, 1} => %{capture_args: true, capture_return: true}
        }
      }
      
      result = MixTask.transform_ast(ast, plan)
      
      # Should return transformed AST
      assert is_tuple(result)
      
      # Convert to string to verify instrumentation was added
      code = Macro.to_string(result)
      assert String.contains?(code, "ElixirScope.Capture.InstrumentationRuntime")
    end
  end

  describe "parse_argv/1" do
    test "parses command line arguments correctly" do
      # Test in MixTask module since parse_argv is private
      # This tests the integration through run/1
      
      # Basic test to ensure argv parsing works
      assert {:ok, []} = MixTask.run([])
    end
  end

  describe "error handling" do
    test "handles missing source directories" do
      original_cwd = File.cwd!()
      File.cd!(@temp_project_dir)
      
      try do
        # Remove lib directory
        File.rm_rf!("lib")
        
        plan = %{modules: %{}}
        ElixirScope.Storage.DataAccess.store_instrumentation_plan(plan)
        
        result = MixTask.run([])
        
        # Should succeed with no files to process
        assert {:ok, []} = result
      after
        File.cd!(original_cwd)
      end
    end
    
    test "handles orchestrator failures" do
      original_cwd = File.cwd!()
      File.cd!(@temp_project_dir)
      
      try do
        # Clear any existing plan to force orchestrator call
        :persistent_term.erase(:elixir_scope_default_storage)
        
        # Create a simple file
        lib_dir = Path.join([@temp_project_dir, "lib"])
        File.mkdir_p!(lib_dir)
        test_file = Path.join(lib_dir, "test_module.ex")
        File.write!(test_file, """
        defmodule TestModule do
          def test do
            :ok
          end
        end
        """)
        
        result = MixTask.run([])
        
        # Should handle error gracefully or succeed if orchestrator works
        case result do
          {:ok, []} -> :ok  # Orchestrator succeeded
          {:error, [_reason]} -> :ok  # Expected error case
        end
      after
        File.cd!(original_cwd)
      end
    end
  end
end
