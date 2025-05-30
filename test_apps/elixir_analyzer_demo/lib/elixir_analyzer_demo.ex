defmodule ElixirAnalyzerDemo do
  @moduledoc """
  ElixirAnalyzerDemo showcases all the advanced features of the Enhanced AST Repository.

  This module provides convenient functions to run various demo scenarios and explore
  the capabilities of the Enhanced AST Repository including memory management,
  performance optimization, runtime correlation, and debugging features.

  ## Quick Start

      # Load sample projects for analysis
      ElixirAnalyzerDemo.load_sample_project()

      # Run basic repository demo
      ElixirAnalyzerDemo.demo_basic_operations()

      # Demonstrate memory management
      ElixirAnalyzerDemo.demo_memory_management()

      # Show performance optimization
      ElixirAnalyzerDemo.demo_performance_optimization()

      # Interactive debugging demo
      ElixirAnalyzerDemo.demo_debugging()

  """

  alias ElixirScope.ASTRepository.{EnhancedRepository, MemoryManager}
  alias ElixirAnalyzerDemo.{AnalysisEngine, SampleDataManager, PerformanceMonitor}

  @doc """
  Loads sample projects for analysis and demonstration.
  """
  def load_sample_project(project_type \\ :medium) do
    IO.puts("🚀 Loading sample project: #{project_type}")
    
    case SampleDataManager.load_project(project_type) do
      {:ok, modules_loaded} ->
        IO.puts("✅ Successfully loaded #{modules_loaded} modules")
        {:ok, modules_loaded}
      {:error, reason} ->
        IO.puts("❌ Failed to load sample project: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Demonstrates basic Enhanced Repository operations.
  """
  def demo_basic_operations do
    IO.puts("\n🔧 === Basic Repository Operations Demo ===")
    
    # Create a sample module
    sample_ast = quote do
      defmodule DemoModule do
        @moduledoc "A sample module for demonstration"
        
        def hello(name) when is_binary(name) do
          "Hello, #{name}!"
        end
        
        def complex_function(data) when is_list(data) do
          data
          |> Enum.filter(&is_integer/1)
          |> Enum.map(&(&1 * 2))
          |> Enum.reduce(0, &+/2)
        end
        
        def fibonacci(n) when n <= 1, do: n
        def fibonacci(n), do: fibonacci(n - 1) + fibonacci(n - 2)
      end
    end
    
    # Store the module
    IO.puts("📝 Storing module...")
    {:ok, _enhanced_data} = EnhancedRepository.store_enhanced_module(DemoModule, sample_ast)
    
    # Retrieve and display module data
    IO.puts("📖 Retrieving module data...")
    case EnhancedRepository.get_enhanced_module(DemoModule) do
      {:ok, module_data} ->
        IO.puts("✅ Module retrieved successfully!")
        IO.puts("   - Functions: #{map_size(module_data.functions)}")
        IO.puts("   - Complexity Score: #{module_data.complexity_metrics.combined_complexity}")
        IO.puts("   - Memory Usage: #{byte_size(:erlang.term_to_binary(module_data))} bytes")
        
        # Show function details
        Enum.each(module_data.functions, fn {{func_name, arity}, func_data} ->
          IO.puts("   - #{func_name}/#{arity} (complexity: #{func_data.complexity})")
        end)
        
      {:error, reason} ->
        IO.puts("❌ Failed to retrieve module: #{reason}")
    end
    
    # Demonstrate batch operations
    IO.puts("\n📦 Demonstrating batch operations...")
    demo_batch_operations()
    
    IO.puts("✅ Basic operations demo completed!")
  end

  @doc """
  Demonstrates memory management features.
  """
  def demo_memory_management do
    IO.puts("\n🧠 === Memory Management Demo ===")
    
    # Show initial memory stats
    {:ok, initial_stats} = MemoryManager.monitor_memory_usage()
    IO.puts("📊 Initial memory usage: #{format_bytes(initial_stats.repository_memory)}")
    
    # Load many modules to create memory pressure
    IO.puts("📈 Creating memory pressure...")
    create_memory_pressure()
    
    # Show memory stats after loading
    {:ok, loaded_stats} = MemoryManager.monitor_memory_usage()
    IO.puts("📊 Memory after loading: #{format_bytes(loaded_stats.repository_memory)}")
    
    # Demonstrate cleanup
    IO.puts("🧹 Performing cleanup...")
    {:ok, cleanup_result} = MemoryManager.cleanup_unused_data(max_age: 60)  # 1 minute
    IO.puts("   - Data removed: #{format_bytes(cleanup_result.data_removed_bytes)}")
    IO.puts("   - Modules cleaned: #{cleanup_result.modules_cleaned}")
    
    # Show memory stats after cleanup
    {:ok, cleanup_stats} = MemoryManager.monitor_memory_usage()
    IO.puts("📊 Memory after cleanup: #{format_bytes(cleanup_stats.repository_memory)}")
    
    # Demonstrate compression
    IO.puts("🗜️  Performing compression...")
    {:ok, compression_result} = MemoryManager.compress_old_analysis([])
    IO.puts("   - Modules compressed: #{compression_result.modules_compressed}")
    IO.puts("   - Space saved: #{format_bytes(compression_result.space_saved_bytes)}")
    IO.puts("   - Compression ratio: #{Float.round(compression_result.compression_ratio * 100, 1)}%")
    
    # Show final memory stats
    {:ok, final_stats} = MemoryManager.monitor_memory_usage()
    IO.puts("📊 Final memory usage: #{format_bytes(final_stats.repository_memory)}")
    
    # Get cache stats separately if available
    case MemoryManager.get_stats() do
      {:ok, all_stats} when is_map(all_stats.cache) ->
        IO.puts("📈 Cache hit ratio: #{Float.round(all_stats.cache.cache_hit_ratio * 100, 1)}%")
      _ ->
        IO.puts("📈 Cache statistics not available")
    end
    
    IO.puts("✅ Memory management demo completed!")
  end

  @doc """
  Demonstrates performance optimization features.
  """
  def demo_performance_optimization do
    IO.puts("\n⚡ === Performance Optimization Demo ===")
    
    # Benchmark basic operations
    IO.puts("🏃 Benchmarking basic operations...")
    benchmark_operations()
    
    # Demonstrate cache warming
    IO.puts("🔥 Demonstrating cache warming...")
    demo_cache_warming()
    
    # Show performance monitoring
    IO.puts("📊 Starting performance monitoring...")
    PerformanceMonitor.start_monitoring()
    
    # Run some operations to generate metrics
    run_performance_test_operations()
    
    # Get performance dashboard
    dashboard = PerformanceMonitor.get_performance_dashboard()
    display_performance_dashboard(dashboard)
    
    IO.puts("✅ Performance optimization demo completed!")
  end

  @doc """
  Demonstrates interactive debugging features.
  """
  def demo_debugging do
    IO.puts("\n🐛 === Interactive Debugging Demo ===")
    
    # Start debugging session
    case ElixirAnalyzerDemo.DebugInterface.start_debug_session(DemoModule) do
      {:ok, session_id} ->
        IO.puts("🎯 Debug session started: #{session_id}")
        
        # Set breakpoints
        IO.puts("🔴 Setting breakpoints...")
        {:ok, _bp1} = ElixirAnalyzerDemo.DebugInterface.set_breakpoint(session_id, :complex_function, 1)
        {:ok, _bp2} = ElixirAnalyzerDemo.DebugInterface.set_breakpoint(session_id, :fibonacci, 1)
        
        # Add watch expressions
        IO.puts("👁️  Adding watch expressions...")
        {:ok, _watch1} = ElixirAnalyzerDemo.DebugInterface.add_watch_expression(session_id, "data length")
        {:ok, _watch2} = ElixirAnalyzerDemo.DebugInterface.add_watch_expression(session_id, "recursion depth")
        
        # Analyze execution paths
        IO.puts("🛤️  Analyzing execution paths...")
        path_analysis = ElixirAnalyzerDemo.DebugInterface.analyze_execution_path(
          session_id, :complex_function, 1, [[1, 2, 3, "invalid", 4, 5]]
        )
        
        IO.puts("   - Function: #{path_analysis.function}")
        IO.puts("   - Path complexity: #{path_analysis.complexity_analysis.score}")
        IO.puts("   - Potential issues: #{length(path_analysis.potential_issues)}")
        
        IO.puts("✅ Debugging demo completed!")
        
      {:error, reason} ->
        IO.puts("❌ Failed to start debug session: #{reason}")
    end
  end

  @doc """
  Runs all demo scenarios in sequence.
  """
  def run_all_demos do
    IO.puts("🎬 === Running All Enhanced AST Repository Demos ===\n")
    
    # Load sample data first
    load_sample_project(:medium)
    
    # Run all demos
    demo_basic_operations()
    demo_memory_management()
    demo_performance_optimization()
    demo_debugging()
    
    IO.puts("\n🎉 All demos completed successfully!")
    IO.puts("💡 Try exploring individual features with the specific demo functions.")
  end

  # Private helper functions

  defp demo_batch_operations do
    modules = [
      {BatchModule1, create_sample_ast("BatchModule1")},
      {BatchModule2, create_sample_ast("BatchModule2")},
      {BatchModule3, create_sample_ast("BatchModule3")}
    ]
    
    {time_us, :ok} = :timer.tc(fn ->
      # Store modules individually since batch function doesn't exist
      Enum.each(modules, fn {module_name, ast} ->
        EnhancedRepository.store_enhanced_module(module_name, ast)
      end)
    end)
    
    IO.puts("   - Stored #{length(modules)} modules in #{time_us / 1000}ms")
    
    # Retrieve individually
    module_names = Enum.map(modules, fn {name, _ast} -> name end)
    {time_us, batch_data} = :timer.tc(fn ->
      Enum.reduce(module_names, %{}, fn module_name, acc ->
        case EnhancedRepository.get_enhanced_module(module_name) do
          {:ok, module_data} -> Map.put(acc, module_name, module_data)
          {:error, _} -> acc
        end
      end)
    end)
    
    IO.puts("   - Retrieved #{map_size(batch_data)} modules in #{time_us / 1000}ms")
  end

  defp create_memory_pressure do
    modules = Enum.map(1..50, fn i ->
      module_name = :"MemoryTestModule#{i}"
      ast = create_complex_ast(module_name, complexity: :high)
      {module_name, ast}
    end)
    
    # Store modules individually since batch function doesn't exist
    Enum.each(modules, fn {module_name, ast} ->
      EnhancedRepository.store_enhanced_module(module_name, ast)
    end)
  end

  defp benchmark_operations do
    # Module lookup benchmark
    {time_us, _result} = :timer.tc(fn ->
      EnhancedRepository.get_enhanced_module(DemoModule)
    end)
    IO.puts("   - Module lookup: #{time_us / 1000}ms")
    
    # Function search benchmark
    {time_us, _result} = :timer.tc(fn ->
      EnhancedRepository.get_enhanced_function(DemoModule, :complex_function, 1)
    end)
    IO.puts("   - Function search: #{time_us / 1000}ms")
    
    # Statistics benchmark (instead of list_modules which doesn't exist)
    {time_us, {:ok, stats}} = :timer.tc(fn ->
      EnhancedRepository.get_statistics()
    end)
    IO.puts("   - Get statistics (#{stats.modules} modules): #{time_us / 1000}ms")
  end

  defp demo_cache_warming do
    # Get frequently accessed modules
    hot_modules = [:DemoModule, :BatchModule1, :BatchModule2]
    
    # Warm cache
    {time_us, :ok} = :timer.tc(fn ->
      ElixirScope.ASTRepository.PerformanceOptimizer.warm_caches()
    end)
    
    IO.puts("   - Cache warmed for #{length(hot_modules)} modules in #{time_us / 1000}ms")
  end

  defp run_performance_test_operations do
    # Simulate various operations
    Enum.each(1..10, fn _i ->
      EnhancedRepository.get_enhanced_module(DemoModule)
      EnhancedRepository.get_statistics()
      :timer.sleep(100)
    end)
  end

  defp display_performance_dashboard(dashboard) do
    IO.puts("📊 Performance Dashboard:")
    IO.puts("   - System Status: #{dashboard.current_status}")
    
    if dashboard.metrics do
      metrics = dashboard.metrics
      IO.puts("   - Repository Memory: #{format_bytes(metrics.memory.repository_memory)}")
      IO.puts("   - Cache Hit Ratio: #{Float.round(metrics.memory.cache_hit_ratio * 100, 1)}%")
      IO.puts("   - Average Query Time: #{metrics.performance.average_query_time}ms")
    end
    
    if length(dashboard.alerts) > 0 do
      IO.puts("⚠️  Active Alerts: #{length(dashboard.alerts)}")
    end
  end

  defp create_sample_ast(module_name) do
    quote do
      defmodule unquote(module_name) do
        def sample_function(x) when is_integer(x) do
          x * 2
        end
        
        def another_function(list) when is_list(list) do
          Enum.sum(list)
        end
      end
    end
  end

  defp create_complex_ast(module_name, opts \\ []) do
    complexity = Keyword.get(opts, :complexity, :medium)
    
    case complexity do
      :high ->
        quote do
          defmodule unquote(module_name) do
            def complex_logic(data) do
              case data do
                %{type: :process, items: items} when is_list(items) ->
                  items
                  |> Enum.filter(&valid_item?/1)
                  |> Enum.group_by(&get_category/1)
                  |> Enum.map(fn {category, items} ->
                    {category, process_category(category, items)}
                  end)
                  |> Enum.into(%{})
                
                %{type: :aggregate, data: data} ->
                  aggregate_data(data)
                
                _ ->
                  {:error, :invalid_data}
              end
            end
            
            defp valid_item?(%{id: id, value: value}) when is_integer(id) and is_number(value) do
              value > 0
            end
            defp valid_item?(_), do: false
            
            defp get_category(%{category: cat}), do: cat
            defp get_category(_), do: :unknown
            
            defp process_category(:important, items) do
              items |> Enum.map(&enhance_item/1) |> Enum.sort_by(& &1.priority, :desc)
            end
            defp process_category(_, items), do: items
            
            defp enhance_item(item), do: Map.put(item, :priority, calculate_priority(item))
            defp calculate_priority(%{value: value}), do: value * 1.5
            
            defp aggregate_data(data) when is_list(data) do
              %{
                count: length(data),
                sum: Enum.sum(data),
                average: Enum.sum(data) / length(data)
              }
            end
          end
        end
      
      _ ->
        create_sample_ast(module_name)
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end
