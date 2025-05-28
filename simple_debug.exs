#!/usr/bin/env elixir

IO.puts("=== Module Name Debug ===")

# Test what Module.concat returns for different inputs
test_cases = [
  ["DebugModule"],
  ["NewModule"]
]

Enum.each(test_cases, fn parts ->
  result = Module.concat(parts)
  IO.puts("Module.concat(#{inspect(parts)}) = #{inspect(result)}")
  IO.puts("  String representation: #{inspect(to_string(result))}")
  IO.puts("  == :DebugModule: #{inspect(result == :DebugModule)}")
  IO.puts("  == DebugModule: #{inspect(result == DebugModule)}")
  IO.puts("  == Elixir.DebugModule: #{inspect(result == Elixir.DebugModule)}")
  IO.puts("")
end)

# Test atom comparisons
IO.puts("=== Atom Comparison Tests ===")
IO.puts(":DebugModule == DebugModule: #{inspect(:DebugModule == DebugModule)}")
IO.puts(":NewModule == NewModule: #{inspect(:NewModule == NewModule)}")
IO.puts("Elixir.DebugModule == DebugModule: #{inspect(Elixir.DebugModule == DebugModule)}")
IO.puts("Elixir.NewModule == NewModule: #{inspect(Elixir.NewModule == NewModule)}")

# Test what the extract_module_name function would return
IO.puts("\n=== AST Extraction Test ===")
test_ast = {:defmodule, [], [{:__aliases__, [], [:NewModule]}, []]}
IO.puts("Test AST: #{inspect(test_ast)}")

case test_ast do
  {:defmodule, _, [module_alias, _body]} ->
    case module_alias do
      {:__aliases__, _, parts} -> 
        result = Module.concat(parts)
        IO.puts("Extracted module name: #{inspect(result)}")
        IO.puts("Parts: #{inspect(parts)}")
        IO.puts("Result == :NewModule: #{inspect(result == :NewModule)}")
        IO.puts("Result == NewModule: #{inspect(result == NewModule)}")
      atom when is_atom(atom) -> 
        IO.puts("Direct atom: #{inspect(atom)}")
      _ -> 
        IO.puts("Unknown format: #{inspect(module_alias)}")
    end
  _ -> 
    IO.puts("Not a defmodule")
end 