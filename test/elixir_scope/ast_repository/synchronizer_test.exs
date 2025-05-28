defmodule ElixirScope.ASTRepository.SynchronizerTest do
  use ExUnit.Case, async: false  # async: false due to shared state
  
  alias ElixirScope.ASTRepository.Enhanced.{Synchronizer, Repository, FileWatcher}
  alias ElixirScope.TestHelpers
  
  @test_sync_dir "test/tmp/sync_test"

  describe "Synchronizer lifecycle" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      {:ok, repo_pid} = Repository.start_link(name: :test_sync_repo)
      
      on_exit(fn -> cleanup_repository(repo_pid) end)
      
      %{repository: repo_pid}
    end
    
    test "starts and stops synchronizer successfully", %{repository: repo} do
      {:ok, pid} = Synchronizer.start_link(repository: repo)
      
      assert Process.alive?(pid)
      assert {:ok, %{status: :ready}} = Synchronizer.get_status(pid)
      
      :ok = Synchronizer.stop(pid)
      refute Process.alive?(pid)
    end
    
    test "handles repository connection", %{repository: repo} do
      {:ok, sync_pid} = Synchronizer.start_link(repository: repo)
      
      {:ok, status} = Synchronizer.get_status(sync_pid)
      assert status.repository_pid == repo
      assert status.status == :ready
      
      Synchronizer.stop(sync_pid)
    end
  end

  describe "File synchronization" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      File.mkdir_p!(Path.join(@test_sync_dir, "lib"))
      
      {:ok, repo_pid} = Repository.start_link(name: :test_file_sync_repo)
      {:ok, sync_pid} = Synchronizer.start_link(repository: repo_pid)
      
      on_exit(fn -> 
        cleanup_synchronizer(sync_pid)
        cleanup_repository(repo_pid)
        cleanup_test_directory()
      end)
      
      %{repository: repo_pid, synchronizer: sync_pid, sync_dir: @test_sync_dir}
    end
    
    test "synchronizes new file creation", %{repository: repo, synchronizer: sync, sync_dir: sync_dir} do
      # Create new Elixir file
      new_file = Path.join([sync_dir, "lib", "new_module.ex"])
      File.write!(new_file, """
      defmodule NewModule do
        def test_function, do: :ok
      end
      """)
      
      # Trigger synchronization
      :ok = Synchronizer.sync_file(sync, new_file)
      
      # Verify module is in repository - use NewModule instead of :NewModule
      {:ok, module_data} = Repository.get_module(repo, NewModule)
      assert module_data.module_name == NewModule
      assert module_data.file_path == new_file
    end
    
    test "synchronizes file modifications", %{repository: repo, synchronizer: sync, sync_dir: sync_dir} do
      # Create initial file
      test_file = Path.join([sync_dir, "lib", "modified_module.ex"])
      File.write!(test_file, """
      defmodule ModifiedModule do
        def original_function, do: :original
      end
      """)
      
      # Initial sync
      :ok = Synchronizer.sync_file(sync, test_file)
      {:ok, original_data} = Repository.get_module(repo, ModifiedModule)
      original_timestamp = original_data.updated_at
      
      # Wait a moment to ensure timestamp difference
      Process.sleep(10)
      
      # Modify file
      File.write!(test_file, """
      defmodule ModifiedModule do
        def original_function, do: :original
        def new_function, do: :new
      end
      """)
      
      # Sync modification
      :ok = Synchronizer.sync_file(sync, test_file)
      
      # Verify update
      {:ok, updated_data} = Repository.get_module(repo, ModifiedModule)
      assert DateTime.compare(updated_data.updated_at, original_timestamp) == :gt
      assert map_size(updated_data.functions) > map_size(original_data.functions)
    end
    
    test "handles file deletion", %{repository: repo, synchronizer: sync, sync_dir: sync_dir} do
      # Create file to delete
      delete_file = Path.join([sync_dir, "lib", "delete_module.ex"])
      File.write!(delete_file, """
      defmodule DeleteModule do
        def goodbye, do: :farewell
      end
      """)
      
      # Initial sync
      :ok = Synchronizer.sync_file(sync, delete_file)
      {:ok, _module_data} = Repository.get_module(repo, DeleteModule)
      
      # Delete file and sync deletion
      File.rm!(delete_file)
      :ok = Synchronizer.sync_file_deletion(sync, delete_file)
      
      # Verify removal
      assert {:error, :not_found} = Repository.get_module(repo, DeleteModule)
    end
    
    test "handles parse errors gracefully", %{synchronizer: sync, sync_dir: sync_dir} do
      # Create file with syntax error
      error_file = Path.join([sync_dir, "lib", "error_module.ex"])
      File.write!(error_file, """
      defmodule ErrorModule do
        def broken_function(
      """)
      
      # Should handle parse error without crashing
      assert {:error, :parse_error} = Synchronizer.sync_file(sync, error_file)
    end
  end

  describe "Batch synchronization" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      File.mkdir_p!(Path.join(@test_sync_dir, "lib"))
      
      {:ok, repo_pid} = Repository.start_link(name: :test_batch_sync_repo)
      {:ok, sync_pid} = Synchronizer.start_link(repository: repo_pid, batch_size: 5)
      
      on_exit(fn -> 
        cleanup_synchronizer(sync_pid)
        cleanup_repository(repo_pid)
        cleanup_test_directory()
      end)
      
      %{repository: repo_pid, synchronizer: sync_pid, sync_dir: @test_sync_dir}
    end
    
    test "synchronizes multiple files efficiently", %{repository: repo, synchronizer: sync, sync_dir: sync_dir} do
      # Create multiple files
      files = 1..10
      |> Enum.map(fn i ->
        file_path = Path.join([sync_dir, "lib", "batch_module_#{i}.ex"])
        File.write!(file_path, """
        defmodule BatchModule#{i} do
          def function_#{i}, do: #{i}
        end
        """)
        file_path
      end)
      
      # Batch synchronization
      {time_us, {:ok, _results}} = :timer.tc(fn ->
        Synchronizer.sync_files(sync, files)
      end)
      
      # Should complete efficiently
      assert time_us < 1_000_000  # Less than 1 second
      
      # Verify all modules are synchronized
      1..10
      |> Enum.each(fn i ->
        module_name = Module.concat([:"BatchModule#{i}"])
        {:ok, _module_data} = Repository.get_module(repo, module_name)
      end)
    end
    
    test "handles mixed valid and invalid files in batch", %{repository: repo, synchronizer: sync, sync_dir: sync_dir} do
      # Create mix of valid and invalid files
      valid_file = Path.join([sync_dir, "lib", "valid_batch.ex"])
      File.write!(valid_file, """
      defmodule ValidBatch do
        def valid_function, do: :ok
      end
      """)
      
      invalid_file = Path.join([sync_dir, "lib", "invalid_batch.ex"])
      File.write!(invalid_file, "defmodule InvalidBatch do\n  def broken(")
      
      # Batch sync should handle both
      {:ok, results} = Synchronizer.sync_files(sync, [valid_file, invalid_file])
      
      # Should have one success and one error
      assert length(results) == 2
      assert Enum.any?(results, &match?({:ok, _}, &1))
      assert Enum.any?(results, &match?({:error, _}, &1))
      
      # Valid module should be in repository
      {:ok, _module_data} = Repository.get_module(repo, ValidBatch)
    end
  end

  describe "Integration with FileWatcher" do
    @tag :skip
    setup do
      :ok = TestHelpers.ensure_config_available()
      File.mkdir_p!(Path.join(@test_sync_dir, "lib"))
      
      {:ok, repo_pid} = Repository.start_link(name: :test_watcher_sync_repo)
      {:ok, sync_pid} = Synchronizer.start_link(repository: repo_pid)
      
      {:ok, watcher_pid} = FileWatcher.start_link(
        watch_dirs: [@test_sync_dir],
        synchronizer: sync_pid,
        debounce_ms: 50
      )
      
      on_exit(fn -> 
        FileWatcher.stop(watcher_pid)
        cleanup_synchronizer(sync_pid)
        cleanup_repository(repo_pid)
        cleanup_test_directory()
      end)
      
      %{repository: repo_pid, synchronizer: sync_pid, watcher: watcher_pid, sync_dir: @test_sync_dir}
    end
    
    @tag :skip
    test "automatically syncs watched file changes", %{repository: repo, sync_dir: sync_dir} do
      # Create file in watched directory
      watched_file = Path.join([sync_dir, "lib", "watched_sync.ex"])
      File.write!(watched_file, """
      defmodule WatchedSync do
        def watched_function, do: :watched
      end
      """)
      
      # Wait for automatic synchronization
      Process.sleep(500)
      
      # Should be automatically synchronized
      {:ok, module_data} = Repository.get_module(repo, WatchedSync)
      assert module_data.module_name == WatchedSync
    end
    
    @tag :skip
    test "handles rapid file changes with debouncing", %{repository: repo, sync_dir: sync_dir} do
      rapid_file = Path.join([sync_dir, "lib", "rapid_sync.ex"])
      
      # Make rapid changes
      1..5
      |> Enum.each(fn i ->
        File.write!(rapid_file, """
        defmodule RapidSync do
          def version_#{i}, do: #{i}
        end
        """)
        Process.sleep(10)
      end)
      
      # Wait for debounced synchronization
      Process.sleep(300)
      
      # Should have final version
      {:ok, module_data} = Repository.get_module(repo, RapidSync)
      assert map_size(module_data.functions) >= 1
    end
  end

  describe "Performance and reliability" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      File.mkdir_p!(Path.join(@test_sync_dir, "lib"))
      
      {:ok, repo_pid} = Repository.start_link(name: :test_perf_sync_repo)
      {:ok, sync_pid} = Synchronizer.start_link(repository: repo_pid)
      
      on_exit(fn -> 
        cleanup_synchronizer(sync_pid)
        cleanup_repository(repo_pid)
        cleanup_test_directory()
      end)
      
      %{repository: repo_pid, synchronizer: sync_pid, sync_dir: @test_sync_dir}
    end
    
    test "meets performance targets for large projects", %{synchronizer: sync, sync_dir: sync_dir} do
      # Create 50 files
      files = 1..50
      |> Enum.map(fn i ->
        file_path = Path.join([sync_dir, "lib", "perf_module_#{i}.ex"])
        File.write!(file_path, """
        defmodule PerfModule#{i} do
          def function_1, do: #{i}
          def function_2(x), do: x + #{i}
          def function_3(x, y), do: x + y + #{i}
        end
        """)
        file_path
      end)
      
      # Should sync all files efficiently
      {time_us, {:ok, _results}} = :timer.tc(fn ->
        Synchronizer.sync_files(sync, files)
      end)
      
      # Should complete in <5 seconds for 50 files
      assert time_us < 5_000_000
    end
    
    test "handles synchronizer restart gracefully", %{repository: repo, sync_dir: sync_dir} do
      {:ok, sync_pid} = Synchronizer.start_link(repository: repo)
      
      # Create and sync file
      test_file = Path.join([sync_dir, "lib", "restart_test.ex"])
      File.write!(test_file, """
      defmodule RestartTest do
        def test_function, do: :ok
      end
      """)
      
      :ok = Synchronizer.sync_file(sync_pid, test_file)
      
      # Stop and restart synchronizer
      Synchronizer.stop(sync_pid)
      {:ok, new_sync_pid} = Synchronizer.start_link(repository: repo)
      
      # Should work with new synchronizer
      File.write!(test_file, """
      defmodule RestartTest do
        def test_function, do: :ok
        def new_function, do: :new
      end
      """)
      
      :ok = Synchronizer.sync_file(new_sync_pid, test_file)
      
      # Verify update
      {:ok, module_data} = Repository.get_module(repo, RestartTest)
      assert map_size(module_data.functions) >= 2
      
      Synchronizer.stop(new_sync_pid)
    end
    
    test "memory usage remains stable during long operation", %{synchronizer: sync, sync_dir: sync_dir} do
      initial_memory = get_process_memory(sync)
      
      # Sync many files
      1..100
      |> Enum.each(fn i ->
        file_path = Path.join([sync_dir, "lib", "memory_test_#{i}.ex"])
        File.write!(file_path, """
        defmodule MemoryTest#{i} do
          def test_function, do: #{i}
        end
        """)
        
        Synchronizer.sync_file(sync, file_path)
      end)
      
      final_memory = get_process_memory(sync)
      memory_growth = final_memory - initial_memory
      
      # Memory growth should be reasonable (less than 50MB)
      assert memory_growth < 50_000_000
    end
  end

  describe "Error handling and edge cases" do
    setup do
      :ok = TestHelpers.ensure_config_available()
      {:ok, repo_pid} = Repository.start_link(name: :test_error_sync_repo)
      
      on_exit(fn -> cleanup_repository(repo_pid) end)
      
      %{repository: repo_pid}
    end
    
    test "handles repository failures gracefully", %{repository: repo} do
      {:ok, sync_pid} = Synchronizer.start_link(repository: repo)
      
      # Stop repository to simulate failure
      GenServer.stop(repo)
      
      # Synchronizer should handle repository failure
      File.mkdir_p!(Path.join(@test_sync_dir, "lib"))
      test_file = Path.join([@test_sync_dir, "lib", "repo_failure_test.ex"])
      File.write!(test_file, """
      defmodule RepoFailureTest do
        def test_function, do: :ok
      end
      """)
      
      assert {:error, :repository_unavailable} = Synchronizer.sync_file(sync_pid, test_file)
      
      Synchronizer.stop(sync_pid)
      cleanup_test_directory()
    end
    
    test "handles non-existent files gracefully" do
      {:ok, repo_pid} = Repository.start_link(name: :test_nonexistent_repo)
      {:ok, sync_pid} = Synchronizer.start_link(repository: repo_pid)
      
      non_existent_file = "/non/existent/file.ex"
      
      assert {:error, :file_not_found} = Synchronizer.sync_file(sync_pid, non_existent_file)
      
      Synchronizer.stop(sync_pid)
      cleanup_repository(repo_pid)
    end
    
    test "handles concurrent synchronization requests" do
      {:ok, repo_pid} = Repository.start_link(name: :test_concurrent_repo)
      {:ok, sync_pid} = Synchronizer.start_link(repository: repo_pid)
      
      File.mkdir_p!(Path.join(@test_sync_dir, "lib"))
      
      # Create multiple files
      files = 1..10
      |> Enum.map(fn i ->
        file_path = Path.join([@test_sync_dir, "lib", "concurrent_#{i}.ex"])
        File.write!(file_path, """
        defmodule Concurrent#{i} do
          def function_#{i}, do: #{i}
        end
        """)
        file_path
      end)
      
      # Start concurrent synchronization tasks
      tasks = Enum.map(files, fn file ->
        Task.async(fn -> Synchronizer.sync_file(sync_pid, file) end)
      end)
      
      # All should complete successfully
      results = Task.await_many(tasks, 5000)
      assert Enum.all?(results, &(&1 == :ok))
      
      Synchronizer.stop(sync_pid)
      cleanup_repository(repo_pid)
      cleanup_test_directory()
    end
  end

  # Helper functions
  defp get_process_memory(pid) do
    case Process.info(pid, :memory) do
      {:memory, memory} -> memory
      nil -> 0
    end
  end

  defp cleanup_test_directory do
    if File.exists?(@test_sync_dir) do
      File.rm_rf!(@test_sync_dir)
    end
  end

  defp cleanup_synchronizer(pid) do
    try do
      if Process.alive?(pid) do
        Synchronizer.stop(pid)
      end
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end

  defp cleanup_repository(pid) do
    try do
      if Process.alive?(pid) do
        GenServer.stop(pid, :normal, 5000)
      end
    rescue
      _ -> :ok
    catch
      :exit, _ -> :ok
    end
  end
end 