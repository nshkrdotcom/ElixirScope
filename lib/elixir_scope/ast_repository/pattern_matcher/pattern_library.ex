defmodule ElixirScope.ASTRepository.PatternMatcher.PatternLibrary do
  @moduledoc """
  Pattern library management and default pattern definitions.
  """
  
  alias ElixirScope.ASTRepository.PatternMatcher.PatternRules
  
  @spec load_all_patterns(atom()) :: :ok
  def load_all_patterns(pattern_library_table) do
    load_behavioral_patterns(pattern_library_table)
    load_anti_patterns(pattern_library_table)
    load_ast_patterns(pattern_library_table)
    :ok
  end
  
  defp load_behavioral_patterns(table) do
    patterns = [
      {:genserver, %{
        description: "GenServer implementation pattern",
        severity: :info,
        suggestions: ["Consider using GenServer best practices"],
        metadata: %{category: :otp_pattern},
        rules: [
          &PatternRules.has_genserver_behavior/1,
          &PatternRules.has_init_callback/1,
          &PatternRules.has_handle_call_or_cast/1
        ]
      }},
      {:supervisor, %{
        description: "Supervisor implementation pattern",
        severity: :info,
        suggestions: ["Ensure proper supervision strategy"],
        metadata: %{category: :otp_pattern},
        rules: [
          &PatternRules.has_supervisor_behavior/1,
          &PatternRules.has_init_callback/1,
          &PatternRules.has_child_spec/1
        ]
      }},
      {:singleton, %{
        description: "Singleton pattern implementation",
        severity: :warning,
        suggestions: ["Consider if singleton is necessary", "Use GenServer for state management"],
        metadata: %{category: :design_pattern},
        rules: [
          &PatternRules.has_singleton_characteristics/1
        ]
      }}
    ]
    
    Enum.each(patterns, fn {pattern_type, pattern_def} ->
      :ets.insert(table, {{:behavioral, pattern_type}, pattern_def})
    end)
  end
  
  defp load_anti_patterns(table) do
    patterns = [
      {:n_plus_one_query, %{
        description: "N+1 query anti-pattern detected",
        severity: :error,
        suggestions: [
          "Use preloading or joins to reduce database queries",
          "Consider batching queries",
          "Use Ecto.Repo.preload/2"
        ],
        metadata: %{category: :performance},
        rules: [
          &PatternRules.has_loop_with_queries/1,
          &PatternRules.has_repeated_query_pattern/1
        ]
      }},
      {:god_function, %{
        description: "God function anti-pattern (function too complex)",
        severity: :warning,
        suggestions: [
          "Break function into smaller functions",
          "Extract common logic",
          "Consider using function composition"
        ],
        metadata: %{category: :complexity},
        rules: [
          &PatternRules.has_high_complexity/1,
          &PatternRules.has_many_responsibilities/1
        ]
      }},
      {:deep_nesting, %{
        description: "Deep nesting anti-pattern",
        severity: :warning,
        suggestions: [
          "Use early returns",
          "Extract nested logic into functions",
          "Consider using with statements"
        ],
        metadata: %{category: :readability},
        rules: [
          &PatternRules.has_deep_nesting/1
        ]
      }},
      {:sql_injection, %{
        description: "Potential SQL injection vulnerability",
        severity: :critical,
        suggestions: [
          "Use parameterized queries",
          "Validate and sanitize input",
          "Use Ecto query builders"
        ],
        metadata: %{category: :security},
        rules: [
          &PatternRules.has_string_interpolation_in_sql/1,
          &PatternRules.has_unsafe_query_construction/1
        ]
      }}
    ]
    
    Enum.each(patterns, fn {pattern_type, pattern_def} ->
      :ets.insert(table, {{:anti_pattern, pattern_type}, pattern_def})
    end)
  end
  
  defp load_ast_patterns(table) do
    patterns = [
      {:enum_map, quote(do: Enum.map(_, _))},
      {:enum_reduce, quote(do: Enum.reduce(_, _, _))},
      {:case_statement, quote(do: case _ do _ end)},
      {:with_statement, quote(do: with _ <- _ do _ end)},
      {:pipe_operator, quote(do: _ |> _)}
    ]
    
    Enum.each(patterns, fn {pattern_type, pattern_ast} ->
      :ets.insert(table, {{:ast, pattern_type}, pattern_ast})
    end)
  end
end
