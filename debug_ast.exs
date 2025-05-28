#!/usr/bin/env elixir

# Debug script to check AST structure
alias ElixirScope.ASTRepository.Enhanced.CFGGenerator

# Test the AST that's failing
test_ast = quote(do: (def simple, do: :ok))
IO.puts("Test AST structure:")
IO.inspect(test_ast, pretty: true)

# Test validation
case ElixirScope.ASTRepository.Enhanced.CFGGenerator.Utils.validate_ast_structure(test_ast) do
  :ok -> IO.puts("✓ AST validation passed")
  {:error, reason} -> IO.puts("✗ AST validation failed: #{inspect(reason)}")
end

# Test CFG generation
case CFGGenerator.generate_cfg(test_ast) do
  {:ok, cfg} -> 
    IO.puts("✓ CFG generation succeeded")
    IO.puts("Complexity: #{cfg.complexity_metrics.cyclomatic}")
  {:error, reason} -> 
    IO.puts("✗ CFG generation failed: #{inspect(reason)}")
end 