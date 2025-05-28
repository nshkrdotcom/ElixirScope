#!/usr/bin/env elixir

# Debug script to isolate synchronizer/repository issues
Mix.install([])

# Set up logging
Logger.configure(level: :debug)

# Load the application modules
Code.require_file("lib/elixir_scope/ast_repository/enhanced/enhanced_module_data.ex")
Code.require_file("lib/elixir_scope/ast_repository/enhanced/enhanced_function_data.ex")
Code.require_file("lib/elixir_scope/ast_repository/enhanced/repository.ex")
Code.require_file("lib/elixir_scope/ast_repository/enhanced/project_populator.ex")
Code.require_file("lib/elixir_scope/ast_repository/enhanced/synchronizer.ex")

alias ElixirScope.ASTRepository.Enhanced.{Repository, Synchronizer, ProjectPopulator}

IO.puts("=== Debug Synchronizer Test ===")

# Create test file
test_dir = "debug_test_tmp"
File.mkdir_p!(Path.join(test_dir, "lib"))

test_file = Path.join([test_dir, "lib", "debug_module.ex"])
File.write!(test_file, """
defmodule DebugModule do
  def test_function, do: :ok
end
""")

IO.puts("Created test file: #{test_file}")

# Start repository
IO.puts("Starting repository...")
{:ok, repo_pid} = Repository.start_link(name: :debug_repo)
IO.puts("Repository started: #{inspect(repo_pid)}")

# Start synchronizer
IO.puts("Starting synchronizer...")
{:ok, sync_pid} = Synchronizer.start_link(repository: repo_pid)
IO.puts("Synchronizer started: #{inspect(sync_pid)}")

# Test direct parsing
IO.puts("\n=== Testing direct parsing ===")
case ProjectPopulator.parse_and_analyze_file(test_file) do
  {:ok, module_data} ->
    IO.puts("Parse successful!")
    IO.puts("Module name: #{inspect(module_data.module_name)}")
    IO.puts("Function count: #{map_size(module_data.functions)}")
    
    # Test direct repository storage
    IO.puts("\n=== Testing direct repository storage ===")
    case Repository.store_module(repo_pid, module_data) do
      :ok ->
        IO.puts("Direct storage successful!")
        
        # Test direct retrieval
        IO.puts("\n=== Testing direct repository retrieval ===")
        case Repository.get_module(repo_pid, module_data.module_name) do
          {:ok, retrieved_data} ->
            IO.puts("Direct retrieval successful!")
            IO.puts("Retrieved module: #{inspect(retrieved_data.module_name)}")
          {:error, reason} ->
            IO.puts("Direct retrieval failed: #{inspect(reason)}")
        end
      error ->
        IO.puts("Direct storage failed: #{inspect(error)}")
    end
  {:error, reason} ->
    IO.puts("Parse failed: #{inspect(reason)}")
end

# Test synchronizer
IO.puts("\n=== Testing synchronizer ===")
case Synchronizer.sync_file(sync_pid, test_file) do
  :ok ->
    IO.puts("Synchronizer sync successful!")
    
    # Test retrieval after sync with different atom representations
    IO.puts("\n=== Testing retrieval after sync with different representations ===")
    
    # Test 1: Plain atom
    IO.puts("Testing with DebugModule (plain atom):")
    case Repository.get_module(repo_pid, DebugModule) do
      {:ok, module_data} ->
        IO.puts("✓ Success with plain atom: #{inspect(module_data.module_name)}")
      {:error, reason} ->
        IO.puts("✗ Failed with plain atom: #{inspect(reason)}")
    end
    
    # Test 2: Atom with colon prefix (same as plain atom)
    IO.puts("Testing with :DebugModule (colon atom):")
    case Repository.get_module(repo_pid, :DebugModule) do
      {:ok, module_data} ->
        IO.puts("✓ Success with colon atom: #{inspect(module_data.module_name)}")
      {:error, reason} ->
        IO.puts("✗ Failed with colon atom: #{inspect(reason)}")
    end
    
    # Test 3: String representation
    IO.puts("Testing with \"DebugModule\" (string):")
    case Repository.get_module(repo_pid, "DebugModule") do
      {:ok, module_data} ->
        IO.puts("✓ Success with string: #{inspect(module_data.module_name)}")
      {:error, reason} ->
        IO.puts("✗ Failed with string: #{inspect(reason)}")
    end
    
    # Test 4: Full module name
    IO.puts("Testing with Elixir.DebugModule (full name):")
    case Repository.get_module(repo_pid, Elixir.DebugModule) do
      {:ok, module_data} ->
        IO.puts("✓ Success with full name: #{inspect(module_data.module_name)}")
      {:error, reason} ->
        IO.puts("✗ Failed with full name: #{inspect(reason)}")
    end
    
    # Debug: Show what's actually in the table
    IO.puts("\n=== Table contents debug ===")
    all_entries = :ets.tab2list(:ast_modules_enhanced)
    IO.puts("All table entries:")
    Enum.each(all_entries, fn {key, data} ->
      IO.puts("  Key: #{inspect(key)} (type: #{inspect(key.__struct__ || :atom)})")
      IO.puts("  Module name: #{inspect(data.module_name)} (type: #{inspect(data.module_name.__struct__ || :atom)})")
      IO.puts("  Key == :DebugModule: #{inspect(key == :DebugModule)}")
      IO.puts("  Key == DebugModule: #{inspect(key == DebugModule)}")
      IO.puts("  ---")
    end)
    
  error ->
    IO.puts("Synchronizer sync failed: #{inspect(error)}")
end

# Cleanup
Synchronizer.stop(sync_pid)
GenServer.stop(repo_pid)
File.rm_rf!(test_dir)

IO.puts("\n=== Debug test completed ===")

# Debug module name processing
IO.puts("\n=== Module name processing debug ===")

# Test what Module.concat returns for different inputs
test_cases = [
  ["DebugModule"],
  ["NewModule"],
  [:DebugModule],
  [:NewModule]
]

Enum.each(test_cases, fn parts ->
  try do
    result = Module.concat(parts)
    IO.puts("Module.concat(#{inspect(parts)}) = #{inspect(result)}")
    IO.puts("  Type: #{inspect(result.__struct__ || :atom)}")
    IO.puts("  String representation: #{inspect(to_string(result))}")
    IO.puts("  == :DebugModule: #{inspect(result == :DebugModule)}")
    IO.puts("  == DebugModule: #{inspect(result == DebugModule)}")
    IO.puts("  == Elixir.DebugModule: #{inspect(result == Elixir.DebugModule)}")
  rescue
    e -> IO.puts("Module.concat(#{inspect(parts)}) failed: #{Exception.message(e)}")
  end
  IO.puts("")
end)

# Test AST parsing
IO.puts("=== AST parsing debug ===")
test_ast = {:defmodule, [], [{:__aliases__, [], [:DebugModule]}, []]}
IO.puts("Test AST: #{inspect(test_ast)}")

case test_ast do
  {:defmodule, _, [module_alias, _body]} ->
    case module_alias do
      {:__aliases__, _, parts} -> 
        result = Module.concat(parts)
        IO.puts("Extracted module name: #{inspect(result)}")
        IO.puts("Parts: #{inspect(parts)}")
        IO.puts("Result type: #{inspect(result.__struct__ || :atom)}")
      atom when is_atom(atom) -> 
        IO.puts("Direct atom: #{inspect(atom)}")
      _ -> 
        IO.puts("Unknown format: #{inspect(module_alias)}")
    end
  _ -> 
    IO.puts("Not a defmodule")
end 