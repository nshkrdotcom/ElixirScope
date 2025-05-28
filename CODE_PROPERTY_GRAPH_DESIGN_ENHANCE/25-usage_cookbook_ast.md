# ElixirScope AST Repository: Usage Cookbook & Examples

This document provides practical examples and use cases for querying the ElixirScope AST Repository. It demonstrates how to leverage the `QueryBuilder`, `QueryExecutor` (or the main `Query.Engine` via `ASTExtensions`) to extract valuable static analysis information and insights from your codebase.

## Table of Contents

1.  [Prerequisites](#prerequisites)
2.  [Basic Queries](#basic-queries)
    *   [Finding All Modules](#finding-all-modules)
    *   [Getting Data for a Specific Module](#getting-data-for-a-specific-module)
    *   [Listing Functions in a Module](#listing-functions-in-a-module)
    *   [Getting Data for a Specific Function](#getting-data-for-a-specific-function)
3.  [Complexity Analysis Queries](#complexity-analysis-queries)
    *   [Finding Most Complex Functions (Cyclomatic)](#finding-most-complex-functions-cyclomatic)
    *   [Finding Functions with High Nesting Depth](#finding-functions-with-high-nesting-depth)
4.  [Dependency and Call Graph Queries](#dependency-and-call-graph-queries)
    *   [Finding Functions Calling a Specific MFA](#finding-functions-calling-a-specific-mfa)
    *   [Finding All Callers of a Specific MFA](#finding-all-callers-of-a-specific-mfa)
    *   [Listing Module Dependencies (Imports, Aliases)](#listing-module-dependencies-imports-aliases)
5.  [CPG (Code Property Graph) Queries](#cpg-code-property-graph-queries)
    *   [Retrieving the CPG for a Function](#retrieving-the-cpg-for-a-function)
    *   [Finding Specific AST Node Types within a Function's CPG](#finding-specific-ast-node-types-within-a-functions-cpg)
    *   [Conceptual: Finding Data Flow Paths (requires DFG integration in CPG query)](#conceptual-finding-data-flow-paths)
6.  [Correlated Static & Dynamic Queries](#correlated-static--dynamic-queries)
    *   [Finding Complex Functions with High Runtime Error Rates](#finding-complex-functions-with-high-runtime-error-rates)
    *   [Identifying Hot (Frequently Called) Functions that Use a Deprecated API](#identifying-hot-frequently-called-functions-that-use-a-deprecated-api)
7.  [Advanced Use Cases & Tips](#advanced-use-cases--tips)

---

## 1. Prerequisites

Before running these queries, ensure that:
1.  The `ElixirScope.ASTRepository.Repository` GenServer is running.
2.  The project you want to analyze has been populated into the repository using `ElixirScope.ASTRepository.ProjectPopulator.populate_project/2`.
3.  You have access to the `ElixirScope.ASTRepository.QueryBuilder` and `ElixirScope.ASTRepository.QueryExecutor` modules (or the main `ElixirScope.Query.Engine` that uses them).

```elixir
# Assuming the Repository is running under its default name
alias ElixirScope.ASTRepository.Repository
alias ElixirScope.ASTRepository.QueryBuilder, as: QB
alias ElixirScope.ASTRepository.QueryExecutor, as: QX
alias ElixirScope.QueryEngine.ASTExtensions # Or directly use QX

# Example: Get the repository PID
# repo_pid = Process.whereis(Repository) || Repository
```

---

## 2. Basic Queries

### Finding All Modules

```elixir
# Build the query
query = QB.find_modules()
        |> QB.select([:module_name, :file_path, :ast_size]) # Select specific fields
        |> QB.order_by(:module_name, :asc)

# Execute the query
case QX.execute_query(query) do
  {:ok, modules} ->
    IO.inspect(modules, label: "All Modules (Name, Path, AST Size)")
  {:error, reason} ->
    IO.puts("Error finding modules: #{inspect(reason)}")
end

# Expected output (example):
# All Modules (Name, Path, AST Size): [
#   %{module_name: MyApp.Application, file_path: "lib/my_app/application.ex", ast_size: 150},
#   %{module_name: MyApp.User, file_path: "lib/my_app/user.ex", ast_size: 300},
#   ...
# ]
```

### Getting Data for a Specific Module

```elixir
module_to_find = MyApp.User

query = QB.find_modules()
        |> QB.where(:module_name, :eq, module_to_find)
        # QB.select(:all) is default if not specified

case QX.execute_query(query) do
  {:ok, [%EnhancedModuleData{} = module_data | _]} -> # Expecting a list with one item
    IO.inspect(module_data, label: "Data for #{inspect(module_to_find)}")
    IO.puts("Functions in #{inspect(module_to_find)}: #{length(module_data.functions)}")
  {:ok, []} ->
    IO.puts("Module #{inspect(module_to_find)} not found.")
  {:error, reason} ->
    IO.puts("Error getting module: #{inspect(reason)}")
end
```

### Listing Functions in a Module

```elixir
target_module = MyApp.User

query = QB.find_functions()
        |> QB.where(:module_name, :eq, target_module)
        |> QB.select([:function_name, :arity, :visibility, :cyclomatic_complexity])
        |> QB.order_by(:function_name, :asc)
        |> QB.order_by(:arity, :asc) # For stable sort if names are same

case QX.execute_query(query) do
  {:ok, functions} ->
    IO.inspect(functions, label: "Functions in #{inspect(target_module)}")
  {:error, reason} ->
    IO.puts("Error listing functions: #{inspect(reason)}")
end
```

### Getting Data for a Specific Function

```elixir
target_mfa = {MyApp.User, :create_user, 2}

query = QB.find_functions()
        |> QB.where(:module_name, :eq, elem(target_mfa, 0))
        |> QB.where(:function_name, :eq, elem(target_mfa, 1))
        |> QB.where(:arity, :eq, elem(target_mfa, 2))

case QX.execute_query(query) do
  {:ok, [%EnhancedFunctionData{} = function_data | _]} ->
    IO.inspect(function_data, label: "Data for #{inspect(target_mfa)}")
    IO.puts("AST Node ID (def): #{function_data.ast_node_id}")
    IO.puts("Called functions: #{inspect(Enum.map(function_data.called_functions, fn cf -> {cf.module, cf.function, cf.arity} end))}")
  {:ok, []} ->
    IO.puts("Function #{inspect(target_mfa)} not found.")
  {:error, reason} ->
    IO.puts("Error getting function: #{inspect(reason)}")
end
```

---

## 3. Complexity Analysis Queries

### Finding Most Complex Functions (Cyclomatic)

```elixir
min_complexity_threshold = 10

query = QB.find_functions()
        |> QB.by_complexity(:cyclomatic_complexity, :gte, min_complexity_threshold) # Use :gte for >=
        |> QB.order_by(:cyclomatic_complexity, :desc)
        |> QB.limit(10) # Top 10
        |> QB.select([:module_name, :function_name, :arity, :cyclomatic_complexity, :file_path, :line_start])

case QX.execute_query(query) do
  {:ok, complex_functions} ->
    IO.inspect(complex_functions, label: "Top 10 Most Complex Functions (Cyclomatic >= #{min_complexity_threshold})")
  {:error, reason} ->
    IO.puts("Error finding complex functions: #{inspect(reason)}")
end
```

### Finding Functions with High Nesting Depth

```elixir
min_nesting_depth = 4

query = QB.find_functions()
        |> QB.by_complexity(:nesting_depth, :gte, min_nesting_depth) # Using by_complexity helper for field access
        # Or directly: |> QB.where(:nesting_depth, :gte, min_nesting_depth)
        |> QB.order_by(:nesting_depth, :desc)
        |> QB.select([:module_name, :function_name, :arity, :nesting_depth, :file_path, :line_start])

case QX.execute_query(query) do
  {:ok, deeply_nested_functions} ->
    IO.inspect(deeply_nested_functions, label: "Deeply Nested Functions (Depth >= #{min_nesting_depth})")
  {:error, reason} ->
    IO.puts("Error finding deeply nested functions: #{inspect(reason)}")
end
```

---

## 4. Dependency and Call Graph Queries

### Finding Functions Calling a Specific MFA

```elixir
target_mfa_called = {MyApp.ExternalService, :fetch_data, 1}

query = QB.find_functions()
        |> QB.calls_mfa(target_mfa_called) # Uses the specialized builder
        |> QB.select([:module_name, :function_name, :arity, :file_path, :line_start])

# This query might be executed by ASTRepository.Repository.query_functions internally
# based on the :calls_mfa filter or a specific index.
case QX.execute_query(query) do
  {:ok, functions} ->
    IO.inspect(functions, label: "Functions calling #{inspect(target_mfa_called)}")
  {:error, reason} ->
    IO.puts("Error finding functions calling MFA: #{inspect(reason)}")
end
```

### Finding All Callers of a Specific MFA

```elixir
target_mfa_for_callers = {MyApp.User, :_private_helper, 1}

query = QB.find_functions() # Or a new target like :call_sites
        |> QB.callers_of_mfa(target_mfa_for_callers) # This changes query.from to :call_references
        |> QB.select([:caller_module, :caller_function, :caller_arity, :call_site_id, :line]) # Fields from the reference data

case QX.execute_query(query) do
  {:ok, references} ->
    IO.inspect(references, label: "Callers of #{inspect(target_mfa_for_callers)}")
  {:error, reason} ->
    IO.puts("Error finding callers: #{inspect(reason)}")
end
```

### Listing Module Dependencies (Imports, Aliases)

```elixir
target_module_for_deps = MyApp.OrderProcessor

query = QB.find_modules()
        |> QB.where(:module_name, :eq, target_module_for_deps)
        |> QB.select([:module_name, :imports, :aliases, :uses]) # Assuming these are fields in EnhancedModuleData

case QX.execute_query(query) do
  {:ok, [%{imports: imports, aliases: aliases, uses: uses} | _]} ->
    IO.puts("Dependencies for #{inspect(target_module_for_deps)}:")
    IO.inspect(imports, label: "Imports")
    IO.inspect(aliases, label: "Aliases")
    IO.inspect(uses, label: "Uses (Behaviours/Modules)")
  {:ok, []} -> IO.puts "Module not found."
  {:error, reason} -> IO.puts("Error getting module dependencies: #{inspect(reason)}")
end
```

---

## 5. CPG (Code Property Graph) Queries

### Retrieving the CPG for a Function

```elixir
cpg_target_mfa = {MyApp.Order, :calculate_total, 1}

# Using ASTExtensions directly as it wraps the CPG fetch
case ASTExtensions.execute_ast_query(%{type: :get_cpg_for_function, params: %{function_key: cpg_target_mfa}}) do
  {:ok, %CPGData{} = cpg_data} ->
    IO.inspect(cpg_data, label: "CPG for #{inspect(cpg_target_mfa)}", limit: 5) # Inspect limited output
    IO.puts("CPG has #{map_size(cpg_data.nodes)} nodes and #{length(cpg_data.edges)} edges.")
  {:error, reason} ->
    IO.puts("Error getting CPG: #{inspect(reason)}")
end
```

### Finding Specific AST Node Types within a Function's CPG

This example assumes you first fetch the CPG, then query its nodes. A more advanced `QueryExecutor` might support direct CPG node querying with filters.

```elixir
cpg_target_mfa = {MyApp.PaymentGateway, :process_payment, 3}

with {:ok, %CPGData{} = cpg_data} <- ASTExtensions.execute_ast_query(%{type: :get_cpg_for_function, params: %{function_key: cpg_target_mfa}}),
     # Now filter nodes within this CPGData
     # This local filtering is an example. A dedicated CPG query language would be more powerful.
     call_nodes <- Enum.filter(Map.values(cpg_data.nodes), &(&1.type == :ast && (&1.label == "call" || String.starts_with?(&1.label, "fun_call:"))))
do
  IO.inspect(call_nodes, label: "Function Call CPG Nodes in #{inspect(cpg_target_mfa)}")
else
  {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
  _ -> IO.puts("Could not process CPG or find nodes.")
end

# Using QueryBuilder for CPG nodes (conceptual, if executor supports it well)
cpg_node_query = QB.find_cpg_nodes()
                 |> QB.where("cpg_data.function_key", :eq, cpg_target_mfa) # To scope to the function's CPG
                 |> QB.where(:type, :eq, :ast) # CPG nodes primarily derived from AST
                 |> QB.where(:label, :starts_with, "call:") # Assuming a convention for call node labels

# case QX.execute_query(cpg_node_query) do ... end
```

### Conceptual: Finding Data Flow Paths

This requires significant DFG integration within the CPG and a powerful CPG query capability.

```elixir
# Conceptual - not directly supported by simple QueryBuilder/Executor yet
# Would require a CPG pattern or specialized DFG trace query on CPG
target_mfa = {MyApp.DataProcessor, :transform, 1}
variable_to_trace = "input_data_0" # SSA variable name

# cpg_pattern_for_dfg = %{
#   start_node: %{dfg_data: %{variable_version: %{ssa_name: variable_to_trace}}},
#   path_query: [{edge_type: :dfg_reaches, max_depth: 5}]
# }
# query = QB.find_cpg_nodes()
#           |> QB.where("cpg_data.function_key", :eq, target_mfa)
#           |> QB.match_cpg_pattern(cpg_pattern_for_dfg)
#
# case QX.execute_query(query) do ... end
IO.puts("Conceptual: Finding data flow for #{variable_to_trace} in #{inspect(target_mfa)} - requires advanced CPG query.")
```

---

## 6. Correlated Static & Dynamic Queries

These examples use the `build_correlated_query` from `QueryBuilder` and would be executed by the main `ElixirScope.Query.Engine`.

### Finding Complex Functions with High Runtime Error Rates

```elixir
# 1. Define the static part of the query
static_query = QB.find_functions()
               |> QB.by_complexity(:cognitive_complexity, :gte, 8) # Example cognitive complexity
               |> QB.select([:module_name, :function_name, :arity, :cognitive_complexity, :file_path, :line_start])

# 2. Define the runtime event query template
runtime_template = %{
  event_type: :error, # Assuming your runtime events have a type field
  time_range: {:last_hours, 24} # Query events from the last 24 hours
}

# 3. Build the correlated query specification
# We join on function_key (module, function, arity)
correlated_query_spec = QB.build_correlated_query(
  static_query,
  runtime_template,
  join_on: {:function_key, :function_key} # Assumes static results have :function_key and events too
)

# 4. Execute with the main Query Engine (conceptual)
# case ElixirScope.Query.Engine.execute(correlated_query_spec) do
#   {:ok, results} ->
#     IO.inspect(results, label: "Complex Functions with Recent Runtime Errors")
#     # Each result would be the static function data merged with a list of its runtime errors
#   {:error, reason} ->
#     IO.puts("Error executing correlated query: #{inspect(reason)}")
# end
IO.puts("Conceptual: Correlated query for complex functions + runtime errors - needs main Query.Engine.")
```

### Identifying Hot (Frequently Called) Functions that Use a Deprecated API

```elixir
deprecated_mfa = {MyApp.OldUtils, :do_stuff, 1}

# Static: Find functions calling the deprecated MFA
static_query = QB.find_functions()
               |> QB.calls_mfa(deprecated_mfa)
               |> QB.select([:module_name, :function_name, :arity, :file_path, :line_start])

# Runtime: Template for high execution counts
runtime_template = %{
  event_type: :function_entry,
  time_range: {:last_days, 7},
  # QueryEngine needs to support aggregation for this to work well,
  # e.g., return only if execution_count > N
  min_execution_count: 1000 # Conceptual filter for aggregation result
}

correlated_query_spec = QB.build_correlated_query(
  static_query,
  runtime_template,
  join_on: {:function_key, :function_key}
)

# Execute with main Query Engine...
IO.puts("Conceptual: Correlated query for hot functions using deprecated API - needs main Query.Engine.")
```

---

## 7. Advanced Use Cases & Tips

*   **Combining Filters:** Use multiple `QB.where/4` calls to narrow down results. They are typically ANDed.
*   **Path-Based Fields:** For fields nested in maps/structs (e.g., `complexity_metrics.cognitive_complexity`), the `QueryExecutor`'s `get_field_value` needs to support dot-notation strings if you use them in `QB.where/4`.
*   **Performance:** For very large repositories:
    *   Use specific indexed fields in `where` clauses first (e.g., `:module_name`, `:function_name`).
    *   Apply `limit` early if you only need a few results.
    *   Be mindful of `select(:all)` as it retrieves full data structures.
*   **Extensibility:** The query system can be extended with custom filter operations or new query targets if the `QueryExecutor` and `Repository` are designed to support them.
*   **AST Node ID Queries:** If you have an `ast_node_id` from a runtime event, you can query for the specific CPG node or AST snippet:
    ```elixir
    # ast_node_id_from_event = "..."
    # query = QB.find_cpg_nodes() |> QB.where(:id, :eq, ast_node_id_from_event) # If CPG node ID is the AST Node ID
    # Or query = QB.find_cpg_nodes() |> QB.where(:original_ast_node_id, :eq, ast_node_id_from_event)
    ```

This cookbook provides a starting point. The power of the AST Repository and its query capabilities will grow as more specific indexes, CPG query features, and sophisticated static analyses are implemented.
