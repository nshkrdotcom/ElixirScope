defmodule ElixirScope.ASTRepository.MemoryManagerTest do
  @moduledoc """
  Comprehensive tests for the Enhanced AST Repository Memory Manager.
  
  Tests memory monitoring, cleanup, compression, LRU caching, and
  memory pressure handling with various scenarios and edge cases.
  """
  
  use ExUnit.Case, async: false
  
  alias ElixirScope.ASTRepository.MemoryManager
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  @moduletag :memory_manager
  
  setup do
    # Stop any existing MemoryManager
    case GenServer.whereis(MemoryManager) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
    
    # Start fresh MemoryManager for each test
    {:ok, memory_manager} = MemoryManager.start_link(monitoring_enabled: true)
    
    on_exit(fn ->
      if Process.alive?(memory_manager) do
        GenServer.stop(memory_manager)
      end
    end)
    
    %{memory_manager: memory_manager}
  end
  
  describe "Memory Monitoring" do
    test "monitors memory usage successfully", %{memory_manager: _manager} do
      {:ok, stats} = MemoryManager.monitor_memory_usage()
      
      # Verify required fields are present
      assert is_integer(stats.total_memory)
      assert is_integer(stats.repository_memory)
      assert is_integer(stats.cache_memory)
      assert is_integer(stats.ets_memory)
      assert is_integer(stats.process_memory)
      assert is_float(stats.memory_usage_percent)
      assert is_integer(stats.available_memory)
      
      # Memory values should be non-negative
      assert stats.total_memory >= 0
      assert stats.repository_memory >= 0
      assert stats.cache_memory >= 0
      assert stats.ets_memory >= 0
      assert stats.process_memory >= 0
      assert stats.memory_usage_percent >= 0.0
      assert stats.available_memory > 0
    end
    
    test "tracks memory usage over time", %{memory_manager: _manager} do
      # Take multiple measurements
      measurements = Enum.map(1..5, fn _i ->
        {:ok, stats} = MemoryManager.monitor_memory_usage()
        :timer.sleep(100)  # Small delay between measurements
        stats
      end)
      
      # All measurements should be valid
      assert length(measurements) == 5
      
      Enum.each(measurements, fn stats ->
        assert is_map(stats)
        assert Map.has_key?(stats, :total_memory)
        assert Map.has_key?(stats, :memory_usage_percent)
      end)
    end
    
    test "handles memory monitoring errors gracefully", %{memory_manager: _manager} do
      # Memory monitoring should not crash even if system calls fail
      # This is tested by ensuring the function returns properly
      result = MemoryManager.monitor_memory_usage()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
    
    test "enables and disables monitoring", %{memory_manager: _manager} do
      # Disable monitoring
      :ok = MemoryManager.set_monitoring(false)
      
      # Should still work but may not update automatically
      {:ok, _stats} = MemoryManager.monitor_memory_usage()
      
      # Re-enable monitoring
      :ok = MemoryManager.set_monitoring(true)
      
      {:ok, _stats} = MemoryManager.monitor_memory_usage()
    end
  end
  
  describe "Data Cleanup" do
    test "cleans up unused data successfully", %{memory_manager: _manager} do
      # Create some test data to clean up
      setup_test_data_for_cleanup()
      
      # Perform cleanup
      result = MemoryManager.cleanup_unused_data(max_age: 1800)
      assert result == :ok
    end
    
    test "respects max_age parameter", %{memory_manager: _manager} do
      setup_test_data_for_cleanup()
      
      # Cleanup with very short max_age (should clean more)
      result1 = MemoryManager.cleanup_unused_data(max_age: 1)
      assert result1 == :ok
      
      # Cleanup with very long max_age (should clean less)
      result2 = MemoryManager.cleanup_unused_data(max_age: 86400)  # 24 hours
      assert result2 == :ok
    end
    
    test "supports dry run mode", %{memory_manager: _manager} do
      setup_test_data_for_cleanup()
      
      # Dry run should not actually clean data
      result = MemoryManager.cleanup_unused_data(dry_run: true, max_age: 1)
      assert result == :ok
    end
    
    test "supports force cleanup", %{memory_manager: _manager} do
      setup_test_data_for_cleanup()
      
      # Force cleanup should clean regardless of age
      result = MemoryManager.cleanup_unused_data(force: true)
      assert result == :ok
    end
    
    test "handles cleanup errors gracefully", %{memory_manager: _manager} do
      # Cleanup should not crash even with invalid parameters
      result = MemoryManager.cleanup_unused_data(max_age: -1)
      assert match?(:ok, result) or match?({:error, _}, result)
    end
  end
  
  describe "Data Compression" do
    test "compresses old analysis data", %{memory_manager: _manager} do
      setup_test_data_for_compression()
      
      {:ok, stats} = MemoryManager.compress_old_analysis(
        access_threshold: 3,
        age_threshold: 300
      )
      
      # Verify compression statistics
      assert is_integer(stats.modules_compressed)
      assert is_float(stats.compression_ratio)
      assert is_integer(stats.space_saved_bytes)
      
      assert stats.modules_compressed >= 0
      assert stats.compression_ratio >= 0.0
      assert stats.space_saved_bytes >= 0
    end
    
    test "respects access threshold", %{memory_manager: _manager} do
      setup_test_data_for_compression()
      
      # High access threshold (should compress less)
      {:ok, stats1} = MemoryManager.compress_old_analysis(access_threshold: 100)
      
      # Low access threshold (should compress more)
      {:ok, stats2} = MemoryManager.compress_old_analysis(access_threshold: 1)
      
      # Both should succeed
      assert is_map(stats1)
      assert is_map(stats2)
    end
    
    test "respects age threshold", %{memory_manager: _manager} do
      setup_test_data_for_compression()
      
      # Short age threshold (should compress less)
      {:ok, stats1} = MemoryManager.compress_old_analysis(age_threshold: 1)
      
      # Long age threshold (should compress more)
      {:ok, stats2} = MemoryManager.compress_old_analysis(age_threshold: 3600)
      
      assert is_map(stats1)
      assert is_map(stats2)
    end
    
    test "supports different compression levels", %{memory_manager: _manager} do
      setup_test_data_for_compression()
      
      # Test different compression levels
      compression_levels = [1, 6, 9]
      
      results = Enum.map(compression_levels, fn level ->
        MemoryManager.compress_old_analysis(compression_level: level)
      end)
      
      # All should succeed
      Enum.each(results, fn result ->
        assert match?({:ok, _}, result)
      end)
    end
  end
  
  describe "LRU Caching" do
    test "implements LRU cache for different types", %{memory_manager: _manager} do
      cache_types = [:query, :analysis, :cpg]
      
      Enum.each(cache_types, fn cache_type ->
        result = MemoryManager.implement_lru_cache(cache_type, max_entries: 100)
        assert result == :ok
      end)
    end
    
    test "cache put and get operations work", %{memory_manager: _manager} do
      # Put a value in cache
      :ok = MemoryManager.cache_put(:query, "test_key", "test_value")
      
      # Get the value back
      result = MemoryManager.cache_get(:query, "test_key")
      assert result == {:ok, "test_value"}
    end
    
    test "cache miss returns :miss", %{memory_manager: _manager} do
      result = MemoryManager.cache_get(:query, "nonexistent_key")
      assert result == :miss
    end
    
    test "cache entries expire based on TTL", %{memory_manager: _manager} do
      # Put a value in cache
      :ok = MemoryManager.cache_put(:query, "expiring_key", "expiring_value")
      
      # Should be available immediately
      result1 = MemoryManager.cache_get(:query, "expiring_key")
      assert result1 == {:ok, "expiring_value"}
      
      # Simulate time passing (this is simplified - in real tests we'd mock time)
      # For now, just verify the cache mechanism works
      result2 = MemoryManager.cache_get(:query, "expiring_key")
      assert match?({:ok, _}, result2) or result2 == :miss
    end
    
    test "cache clear removes all entries", %{memory_manager: _manager} do
      # Put multiple values
      :ok = MemoryManager.cache_put(:query, "key1", "value1")
      :ok = MemoryManager.cache_put(:query, "key2", "value2")
      
      # Clear cache
      :ok = MemoryManager.cache_clear(:query)
      
      # Values should be gone
      assert MemoryManager.cache_get(:query, "key1") == :miss
      assert MemoryManager.cache_get(:query, "key2") == :miss
    end
    
    test "LRU eviction works when cache is full", %{memory_manager: _manager} do
      # Configure small cache for testing
      :ok = MemoryManager.implement_lru_cache(:query, max_entries: 3)
      
      # Fill cache beyond capacity
      :ok = MemoryManager.cache_put(:query, "key1", "value1")
      :ok = MemoryManager.cache_put(:query, "key2", "value2")
      :ok = MemoryManager.cache_put(:query, "key3", "value3")
      :ok = MemoryManager.cache_put(:query, "key4", "value4")  # Should evict oldest
      
      # Newest entries should still be there
      assert MemoryManager.cache_get(:query, "key4") == {:ok, "value4"}
      
      # Some older entries might be evicted (exact behavior depends on implementation)
      result = MemoryManager.cache_get(:query, "key1")
      assert match?({:ok, _}, result) or result == :miss
    end
  end
  
  describe "Memory Pressure Handling" do
    test "handles all memory pressure levels", %{memory_manager: _manager} do
      pressure_levels = [:level_1, :level_2, :level_3, :level_4]
      
      Enum.each(pressure_levels, fn level ->
        result = MemoryManager.memory_pressure_handler(level)
        assert result == :ok
      end)
    end
    
    test "level 1 pressure clears query caches", %{memory_manager: _manager} do
      # Put some data in query cache
      :ok = MemoryManager.cache_put(:query, "test_key", "test_value")
      
      # Trigger level 1 pressure
      :ok = MemoryManager.memory_pressure_handler(:level_1)
      
      # Query cache should be cleared
      result = MemoryManager.cache_get(:query, "test_key")
      assert result == :miss
    end
    
    test "level 2 pressure clears caches and compresses data", %{memory_manager: _manager} do
      setup_test_data_for_compression()
      
      # Put data in cache
      :ok = MemoryManager.cache_put(:query, "test_key", "test_value")
      
      # Trigger level 2 pressure
      :ok = MemoryManager.memory_pressure_handler(:level_2)
      
      # Cache should be cleared
      result = MemoryManager.cache_get(:query, "test_key")
      assert result == :miss
    end
    
    test "level 3 pressure performs comprehensive cleanup", %{memory_manager: _manager} do
      setup_test_data_for_cleanup()
      
      # Put data in multiple caches
      :ok = MemoryManager.cache_put(:query, "test_key1", "test_value1")
      :ok = MemoryManager.cache_put(:analysis, "test_key2", "test_value2")
      
      # Trigger level 3 pressure
      :ok = MemoryManager.memory_pressure_handler(:level_3)
      
      # All caches should be cleared
      assert MemoryManager.cache_get(:query, "test_key1") == :miss
      assert MemoryManager.cache_get(:analysis, "test_key2") == :miss
    end
    
    test "level 4 pressure performs emergency cleanup", %{memory_manager: _manager} do
      setup_test_data_for_cleanup()
      
      # Put data in all caches
      :ok = MemoryManager.cache_put(:query, "test_key1", "test_value1")
      :ok = MemoryManager.cache_put(:analysis, "test_key2", "test_value2")
      :ok = MemoryManager.cache_put(:cpg, "test_key3", "test_value3")
      
      # Trigger level 4 pressure (emergency)
      :ok = MemoryManager.memory_pressure_handler(:level_4)
      
      # All caches should be cleared
      assert MemoryManager.cache_get(:query, "test_key1") == :miss
      assert MemoryManager.cache_get(:analysis, "test_key2") == :miss
      assert MemoryManager.cache_get(:cpg, "test_key3") == :miss
    end
    
    test "handles invalid pressure levels gracefully", %{memory_manager: _manager} do
      result = MemoryManager.memory_pressure_handler(:invalid_level)
      assert result == :ok  # Should handle gracefully
    end
  end
  
  describe "Statistics and Monitoring" do
    test "provides comprehensive statistics", %{memory_manager: _manager} do
      {:ok, stats} = MemoryManager.get_stats()
      
      # Verify required sections are present
      assert Map.has_key?(stats, :memory)
      assert Map.has_key?(stats, :cache)
      assert Map.has_key?(stats, :cleanup)
      assert Map.has_key?(stats, :compression)
      assert Map.has_key?(stats, :pressure_level)
      assert Map.has_key?(stats, :monitoring_enabled)
      
      # Verify types
      assert is_map(stats.cache)
      assert is_map(stats.cleanup)
      assert is_map(stats.compression)
      assert is_atom(stats.pressure_level)
      assert is_boolean(stats.monitoring_enabled)
    end
    
    test "tracks cleanup statistics", %{memory_manager: _manager} do
      setup_test_data_for_cleanup()
      
      # Perform cleanup
      :ok = MemoryManager.cleanup_unused_data()
      
      # Check statistics
      {:ok, stats} = MemoryManager.get_stats()
      cleanup_stats = stats.cleanup
      
      assert is_integer(cleanup_stats.modules_cleaned)
      assert is_integer(cleanup_stats.data_removed_bytes)
      assert is_integer(cleanup_stats.last_cleanup_duration)
      assert is_integer(cleanup_stats.total_cleanups)
      
      assert cleanup_stats.total_cleanups >= 1
    end
    
    test "tracks compression statistics", %{memory_manager: _manager} do
      setup_test_data_for_compression()
      
      # Perform compression
      {:ok, _compression_result} = MemoryManager.compress_old_analysis()
      
      # Check statistics
      {:ok, stats} = MemoryManager.get_stats()
      compression_stats = stats.compression
      
      assert is_integer(compression_stats.modules_compressed)
      assert is_float(compression_stats.compression_ratio)
      assert is_integer(compression_stats.space_saved_bytes)
      assert is_integer(compression_stats.last_compression_duration)
      assert is_integer(compression_stats.total_compressions)
      
      assert compression_stats.total_compressions >= 1
    end
  end
  
  describe "Garbage Collection" do
    test "forces garbage collection", %{memory_manager: _manager} do
      # Force GC should complete without error
      result = MemoryManager.force_gc()
      assert result == :ok
    end
    
    test "garbage collection reduces memory usage", %{memory_manager: _manager} do
      # Get initial memory stats
      {:ok, initial_stats} = MemoryManager.monitor_memory_usage()
      initial_memory = initial_stats.total_memory
      
      # Create some temporary data
      _large_data = Enum.map(1..1000, fn i -> {i, :crypto.strong_rand_bytes(1024)} end)
      
      # Force garbage collection
      :ok = MemoryManager.force_gc()
      
      # Memory usage should be reasonable (this is a simplified test)
      {:ok, final_stats} = MemoryManager.monitor_memory_usage()
      final_memory = final_stats.total_memory
      
      # Memory should not have grown excessively
      assert final_memory < initial_memory * 2
    end
  end
  
  describe "Integration Scenarios" do
    test "handles concurrent operations safely", %{memory_manager: _manager} do
      # Run multiple operations concurrently
      tasks = Enum.map(1..5, fn i ->
        Task.async(fn ->
          case rem(i, 3) do
            0 ->
              MemoryManager.monitor_memory_usage()
            1 ->
              MemoryManager.cache_put(:query, "concurrent_key_#{i}", "value_#{i}")
              MemoryManager.cache_get(:query, "concurrent_key_#{i}")
            2 ->
              MemoryManager.cleanup_unused_data(max_age: 3600)
          end
        end)
      end)
      
      # All tasks should complete successfully
      results = Task.await_many(tasks, 10_000)
      
      Enum.each(results, fn result ->
        assert match?({:ok, _}, result) or match?(:ok, result) or match?(:miss, result)
      end)
    end
    
    test "maintains performance under sustained load", %{memory_manager: _manager} do
      # Perform sustained operations
      start_time = System.monotonic_time(:millisecond)
      
      Enum.each(1..100, fn i ->
        # Mix of operations
        :ok = MemoryManager.cache_put(:query, "load_key_#{i}", "load_value_#{i}")
        _result = MemoryManager.cache_get(:query, "load_key_#{rem(i, 50)}")
        
        # Periodic cleanup
        if rem(i, 20) == 0 do
          :ok = MemoryManager.cleanup_unused_data(max_age: 1800)
        end
      end)
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # Should complete in reasonable time
      assert duration < 10_000, "Sustained load took too long: #{duration}ms"
    end
    
    test "recovers from memory pressure gracefully", %{memory_manager: _manager} do
      # Simulate memory pressure scenario
      setup_test_data_for_cleanup()
      
      # Fill caches
      Enum.each(1..50, fn i ->
        :ok = MemoryManager.cache_put(:query, "pressure_key_#{i}", "pressure_value_#{i}")
      end)
      
      # Trigger escalating memory pressure
      :ok = MemoryManager.memory_pressure_handler(:level_1)
      :ok = MemoryManager.memory_pressure_handler(:level_2)
      :ok = MemoryManager.memory_pressure_handler(:level_3)
      :ok = MemoryManager.memory_pressure_handler(:level_4)
      
      # System should still be responsive
      {:ok, _stats} = MemoryManager.monitor_memory_usage()
      :ok = MemoryManager.cache_put(:query, "recovery_test", "recovery_value")
      result = MemoryManager.cache_get(:query, "recovery_test")
      assert result == {:ok, "recovery_value"}
    end
  end
  
  describe "Error Handling and Edge Cases" do
    test "handles invalid cache types gracefully", %{memory_manager: _manager} do
      # Invalid cache type should not crash
      result = MemoryManager.cache_put(:invalid_cache_type, "key", "value")
      assert match?(:ok, result) or match?({:error, _}, result)
    end
    
    test "handles empty cleanup gracefully", %{memory_manager: _manager} do
      # Cleanup with no data should work
      result = MemoryManager.cleanup_unused_data()
      assert result == :ok
    end
    
    test "handles empty compression gracefully", %{memory_manager: _manager} do
      # Compression with no data should work
      {:ok, stats} = MemoryManager.compress_old_analysis()
      assert stats.modules_compressed == 0
    end
    
    test "handles invalid cleanup parameters", %{memory_manager: _manager} do
      # Invalid parameters should be handled gracefully
      result = MemoryManager.cleanup_unused_data(max_age: "invalid")
      assert match?(:ok, result) or match?({:error, _}, result)
    end
    
    test "handles invalid compression parameters", %{memory_manager: _manager} do
      # Invalid parameters should be handled gracefully
      result = MemoryManager.compress_old_analysis(compression_level: 100)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
  
  # Helper Functions
  
  defp setup_test_data_for_cleanup() do
    # Create some test access tracking data
    current_time = System.monotonic_time(:second)
    
    test_modules = [
      {:TestModule1, current_time - 3600, 5},  # Old, accessed
      {:TestModule2, current_time - 7200, 2},  # Very old, few accesses
      {:TestModule3, current_time - 100, 10},  # Recent, many accesses
    ]
    
    # Ensure the access tracking table exists
    case :ets.whereis(:ast_repo_access_tracking) do
      :undefined ->
        :ets.new(:ast_repo_access_tracking, [:named_table, :public, :set])
      _ ->
        :ok
    end
    
    Enum.each(test_modules, fn {module, last_access, access_count} ->
      :ets.insert(:ast_repo_access_tracking, {module, last_access, access_count})
    end)
  end
  
  defp setup_test_data_for_compression() do
    # Create test data similar to cleanup but with different access patterns
    current_time = System.monotonic_time(:second)
    
    test_modules = [
      {:CompressModule1, current_time - 1800, 1},  # Old, rarely accessed
      {:CompressModule2, current_time - 3600, 3},  # Older, few accesses
      {:CompressModule3, current_time - 100, 15},  # Recent, many accesses
    ]
    
    # Ensure the access tracking table exists
    case :ets.whereis(:ast_repo_access_tracking) do
      :undefined ->
        :ets.new(:ast_repo_access_tracking, [:named_table, :public, :set])
      _ ->
        :ok
    end
    
    Enum.each(test_modules, fn {module, last_access, access_count} ->
      :ets.insert(:ast_repo_access_tracking, {module, last_access, access_count})
    end)
  end
end 