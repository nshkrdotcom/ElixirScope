# AST Repository API Specification

## Overview

This document provides detailed API specifications for the enhanced AST Repository components. Each API includes function signatures, parameters, return values, error conditions, and usage examples.

## Repository Core API

### ElixirScope.ASTRepository.Repository

#### start_link/1
```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

**Purpose**: Starts the AST Repository GenServer and initializes all ETS tables.

**Options**:
- `:name` - GenServer name (default: `__MODULE__`)
- `:tables_config` - ETS table configuration overrides
- `:indexes` - List of indexes to create (default: all)
- `:memory_limit` - Maximum memory usage in MB (default: 500)

**Returns**: 
- `{:ok, pid}` on success
- `{:error, reason}` on failure

**Example**:
```elixir
{:ok, pid} = Repository.start_link(name: :ast_repo, memory_limit: 1000)
```

#### store_module/2
```elixir
@spec store_module(GenServer.server(), EnhancedModuleData.t()) :: 
  :ok | {:error, term()}
```

**Purpose**: Stores complete module data including AST, functions, and metadata.

**Parameters**:
- `server` - Repository GenServer reference
- `module_data` - Complete module data structure

**Returns**:
- `:ok` on success
- `{:error, :invalid_data}` if data validation fails
- `{:error, :memory_limit_exceeded}` if over memory limit

**Side Effects**:
- Updates all relevant ETS tables
- Updates indexes
- Triggers change notifications

#### get_module/2
```elixir
@spec get_module(GenServer.server(), atom()) :: 
  {:ok, EnhancedModuleData.t()} | {:error, :not_found}
```

**Purpose**: Retrieves complete module data by module name.

**Parameters**:
- `server` - Repository GenServer reference  
- `module_name` - Atom module name

**Returns**:
- `{:ok, module_data}` if found
- `{:error, :not_found}` if module not in repository

#### store_function/2
```elixir
@spec store_function(GenServer.server(), EnhancedFunctionData.t()) :: 
  :ok | {:error, term()}
```

**Purpose**: Stores or updates individual function data.

**Parameters**:
- `server` - Repository GenServer reference
- `function_data` - Complete function data structure

**Returns**:
- `:ok` on success
- `{:error, :module_not_found}` if parent module missing
- `{:error, :invalid_data}` if validation fails

#### get_function/4
```elixir
@spec get_function(GenServer.server(), atom(), atom(), non_neg_integer()) :: 
  {:ok, EnhancedFunctionData.t()} | {:error, :not_found}
```

**Purpose**: Retrieves function data by MFA.

**Parameters**:
- `server` - Repository GenServer reference
- `module` - Module name
- `function` - Function name  
- `arity` - Function arity

**Returns**:
- `{:ok, function_data}` if found
- `{:error, :not_found}` if function not in repository

#### query_functions/2
```elixir
@spec query_functions(GenServer.server(), function_query()) :: 
  {:ok, [EnhancedFunctionData.t()]} | {:error, term()}

@type function_query :: %{
  optional(:module) => atom() | [atom()],
  optional(:complexity) => {:gt | :lt | :eq, number()},
  optional(:visibility) => :public | :private,
  optional(:pattern) => String.t(),
  optional(:calls) => {atom(), atom(), non_neg_integer()},
  optional(:limit) => pos_integer(),
  optional(:sort) => {:asc | :desc, atom()}
}
```

**Purpose**: Queries functions based on multiple criteria.

**Parameters**:
- `server` - Repository GenServer reference
- `query` - Query specification map

**Returns**:
- `{:ok, functions}` matching functions
- `{:error, :invalid_query}` if query malformed

**Example**:
```elixir
{:ok, complex_functions} = Repository.query_functions(repo, %{
  complexity: {:gt, 10},
  visibility: :public,
  limit: 20,
  sort: {:desc, :complexity}
})
```

#### get_ast_node/2
```elixir
@spec get_ast_node(GenServer.server(), String.t()) :: 
  {:ok, {Macro.t(), map()}} | {:error, :not_found}
```

**Purpose**: Retrieves specific AST node by ID.

**Parameters**:
- `server` - Repository GenServer reference
- `ast_node_id` - Unique AST node identifier

**Returns**:
- `{:ok, {ast, metadata}}` if found
- `{:error, :not_found}` if node not in repository

#### find_references/4
```elixir
@spec find_references(GenServer.server(), atom(), atom(), non_neg_integer()) :: 
  {:ok, [reference()]} | {:error, term()}

@type reference :: %{
  caller_module: atom(),
  caller_function: atom(),
  caller_arity: non_neg_integer(),
  call_site_id: String.t(),
  line: pos_integer(),
  type: :direct | :indirect | :dynamic
}
```

**Purpose**: Finds all references to a function.

**Parameters**:
- `server` - Repository GenServer reference
- `module` - Target module
- `function` - Target function
- `arity` - Target arity

**Returns**:
- `{:ok, references}` list of all references
- `{:error, :not_found}` if target function not found

## Project Population API

### ElixirScope.ASTRepository.ProjectPopulator

#### populate_project/2
```elixir
@spec populate_project(String.t(), keyword()) :: 
  {:ok, population_result()} | {:error, term()}

@type population_result :: %{
  modules: non_neg_integer(),
  functions: non_neg_integer(),
  files: non_neg_integer(),
  errors: [parsing_error()],
  duration_ms: non_neg_integer(),
  memory_used_mb: float()
}
```

**Purpose**: Populates repository with entire project AST data.

**Options**:
- `:include_deps` - Include dependencies (default: false)
- `:include_test` - Include test files (default: true)
- `:parallel` - Number of parallel workers (default: System.schedulers_online())
- `:progress_callback` - Function called with progress updates
- `:error_handler` - Function called on errors

**Returns**:
- `{:ok, result}` with statistics
- `{:error, reason}` on fatal errors

**Example**:
```elixir
{:ok, result} = ProjectPopulator.populate_project("/path/to/project", 
  include_deps: false,
  progress_callback: &IO.inspect/1
)
```

#### populate_module/2
```elixir
@spec populate_module(String.t(), keyword()) :: 
  {:ok, EnhancedModuleData.t()} | {:error, term()}
```

**Purpose**: Populates repository with single module file.

**Parameters**:
- `file_path` - Path to .ex or .exs file
- `opts` - Population options

**Returns**:
- `{:ok, module_data}` on success
- `{:error, reason}` on failure

#### refresh_module/2
```elixir
@spec refresh_module(atom(), keyword()) :: 
  {:ok, :unchanged | :updated} | {:error, term()}
```

**Purpose**: Refreshes module data if source file changed.

**Parameters**:
- `module_name` - Module to refresh
- `opts` - Refresh options

**Returns**:
- `{:ok, :unchanged}` if no changes
- `{:ok, :updated}` if module updated
- `{:error, reason}` on failure

## File Watcher API

### ElixirScope.ASTRepository.FileWatcher

#### start_link/1
```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

**Purpose**: Starts file watcher for project.

**Options**:
- `:project_path` - Root project path to watch
- `:name` - GenServer name
- `:debounce_ms` - Milliseconds to debounce changes (default: 500)
- `:ignore_patterns` - List of patterns to ignore
- `:callback` - Function called on changes

#### watch_directory/2
```elixir
@spec watch_directory(GenServer.server(), String.t()) :: 
  :ok | {:error, term()}
```

**Purpose**: Adds directory to watch list.

**Parameters**:
- `server` - FileWatcher GenServer reference
- `directory_path` - Directory to watch

**Returns**:
- `:ok` on success
- `{:error, :invalid_path}` if path doesn't exist
- `{:error, :already_watching}` if already watched

#### unwatch_directory/2
```elixir
@spec unwatch_directory(GenServer.server(), String.t()) :: 
  :ok | {:error, term()}
```

**Purpose**: Removes directory from watch list.

**Parameters**:
- `server` - FileWatcher GenServer reference
- `directory_path` - Directory to stop watching

**Returns**:
- `:ok` on success
- `{:error, :not_watching}` if not currently watched

#### pause/1
```elixir
@spec pause(GenServer.server()) :: :ok
```

**Purpose**: Temporarily pauses file watching.

**Parameters**:
- `server` - FileWatcher GenServer reference

**Returns**: `:ok`

#### resume/1
```elixir
@spec resume(GenServer.server()) :: :ok
```

**Purpose**: Resumes file watching after pause.

**Parameters**:
- `server` - FileWatcher GenServer reference

**Returns**: `:ok`

## Synchronizer API

### ElixirScope.ASTRepository.Synchronizer

#### sync_file/2
```elixir
@spec sync_file(String.t(), keyword()) :: 
  {:ok, sync_result()} | {:error, term()}

@type sync_result :: %{
  status: :updated | :unchanged | :created | :deleted,
  modules_affected: [atom()],
  functions_changed: [{atom(), atom(), non_neg_integer()}],
  duration_ms: non_neg_integer()
}
```

**Purpose**: Synchronizes single file with repository.

**Parameters**:
- `file_path` - Path to file to sync
- `opts` - Sync options

**Returns**:
- `{:ok, result}` with sync details
- `{:error, reason}` on failure

#### sync_changes/2
```elixir
@spec sync_changes([FileChangeEvent.t()], keyword()) :: 
  {:ok, batch_sync_result()} | {:error, term()}

@type batch_sync_result :: %{
  total_changes: non_neg_integer(),
  successful: non_neg_integer(),
  failed: non_neg_integer(),
  errors: [{String.t(), term()}],
  duration_ms: non_neg_integer()
}
```

**Purpose**: Synchronizes batch of file changes.

**Parameters**:
- `changes` - List of file change events
- `opts` - Sync options

**Returns**:
- `{:ok, result}` with batch results
- `{:error, reason}` on complete failure

#### get_sync_state/1
```elixir
@spec get_sync_state(GenServer.server()) :: 
  {:ok, SyncState.t()}
```

**Purpose**: Gets current synchronization state.

**Parameters**:
- `server` - Synchronizer GenServer reference

**Returns**:
- `{:ok, state}` current sync state

## AST Analysis API

### ElixirScope.ASTRepository.ASTAnalyzer

#### analyze_module/2
```elixir
@spec analyze_module(Macro.t(), keyword()) :: 
  {:ok, module_analysis()} | {:error, term()}

@type module_analysis :: %{
  functions: [function_analysis()],
  dependencies: [dependency()],
  attributes: %{atom() => term()},
  behaviours: [atom()],
  protocols: [atom()],
  complexity: complexity_metrics(),
  patterns: [detected_pattern()],
  risks: [risk()]
}
```

**Purpose**: Performs comprehensive module analysis.

**Parameters**:
- `module_ast` - Module AST to analyze
- `opts` - Analysis options

**Options**:
- `:include_metrics` - Calculate complexity metrics (default: true)
- `:include_patterns` - Detect code patterns (default: true)
- `:include_risks` - Identify security/quality risks (default: true)

**Returns**:
- `{:ok, analysis}` with complete analysis
- `{:error, reason}` on failure

#### analyze_function/2
```elixir
@spec analyze_function(Macro.t(), keyword()) :: 
  {:ok, function_analysis()} | {:error, term()}

@type function_analysis :: %{
  complexity: complexity_metrics(),
  variables: [variable_analysis()],
  calls: [function_call()],
  patterns: [pattern_match()],
  control_flow: cfg_analysis(),
  data_flow: dfg_analysis()
}
```

**Purpose**: Performs deep function analysis.

**Parameters**:
- `function_ast` - Function AST to analyze
- `opts` - Analysis options

**Returns**:
- `{:ok, analysis}` with complete analysis
- `{:error, reason}` on failure

#### extract_dependencies/1
```elixir
@spec extract_dependencies(Macro.t()) :: 
  {:ok, dependencies()} | {:error, term()}

@type dependencies :: %{
  imports: [module_ref()],
  aliases: [module_ref()],
  requires: [module_ref()],
  uses: [behaviour_ref()]
}
```

**Purpose**: Extracts all module dependencies.

**Parameters**:
- `module_ast` - Module AST

**Returns**:
- `{:ok, dependencies}` extracted dependencies
- `{:error, reason}` on failure

## Control Flow Analysis API

### ElixirScope.ASTRepository.CFGGenerator

#### generate_cfg/2
```elixir
@spec generate_cfg(Macro.t(), keyword()) :: 
  {:ok, CFGData.t()} | {:error, term()}
```

**Purpose**: Generates control flow graph for function.

**Parameters**:
- `function_ast` - Function AST
- `opts` - Generation options

**Options**:
- `:include_all_paths` - Generate all possible paths (default: false)
- `:max_path_length` - Maximum path length to analyze (default: 100)
- `:detect_unreachable` - Detect unreachable code (default: true)

**Returns**:
- `{:ok, cfg}` control flow graph
- `{:error, reason}` on failure

#### find_paths/3
```elixir
@spec find_paths(CFGData.t(), String.t(), String.t()) :: 
  {:ok, [[String.t()]]} | {:error, term()}
```

**Purpose**: Finds all paths between CFG nodes.

**Parameters**:
- `cfg` - Control flow graph
- `from_node_id` - Starting node ID
- `to_node_id` - Target node ID

**Returns**:
- `{:ok, paths}` list of paths
- `{:error, :no_path}` if no path exists

#### calculate_complexity/1
```elixir
@spec calculate_complexity(CFGData.t()) :: 
  {:ok, complexity_metrics()} | {:error, term()}

@type complexity_metrics :: %{
  cyclomatic: non_neg_integer(),
  essential: non_neg_integer(),
  cognitive: non_neg_integer(),
  nesting: non_neg_integer()
}
```

**Purpose**: Calculates various complexity metrics.

**Parameters**:
- `cfg` - Control flow graph

**Returns**:
- `{:ok, metrics}` complexity metrics
- `{:error, reason}` on failure

## Data Flow Analysis API

### ElixirScope.ASTRepository.DFGGenerator

#### generate_dfg/2
```elixir
@spec generate_dfg(Macro.t(), keyword()) :: 
  {:ok, DFGData.t()} | {:error, term()}
```

**Purpose**: Generates data flow graph for function.

**Parameters**:
- `function_ast` - Function AST
- `opts` - Generation options

**Options**:
- `:track_mutations` - Track variable mutations (default: true)
- `:track_captures` - Track captured variables (default: true)
- `:include_guards` - Include guard expressions (default: true)

**Returns**:
- `{:ok, dfg}` data flow graph
- `{:error, reason}` on failure

#### trace_variable/2
```elixir
@spec trace_variable(DFGData.t(), String.t()) :: 
  {:ok, variable_trace()} | {:error, term()}

@type variable_trace :: %{
  definition: ast_location(),
  uses: [ast_location()],
  mutations: [ast_location()],
  flows_to: [String.t()],
  flows_from: [String.t()]
}
```

**Purpose**: Traces variable through data flow.

**Parameters**:
- `dfg` - Data flow graph
- `variable_name` - Variable to trace

**Returns**:
- `{:ok, trace}` variable trace information
- `{:error, :not_found}` if variable not in graph

#### find_uninitialized_uses/1
```elixir
@spec find_uninitialized_uses(DFGData.t()) :: 
  {:ok, [uninitialized_use()]} | {:error, term()}

@type uninitialized_use :: %{
  variable: String.t(),
  use_location: ast_location(),
  possible_paths: [[String.t()]]
}
```

**Purpose**: Finds potentially uninitialized variable uses.

**Parameters**:
- `dfg` - Data flow graph

**Returns**:
- `{:ok, uses}` list of uninitialized uses
- `{:error, reason}` on failure

## Code Property Graph API

### ElixirScope.ASTRepository.CPGBuilder

#### build_cpg/2
```elixir
@spec build_cpg(EnhancedModuleData.t(), keyword()) :: 
  {:ok, CPG.t()} | {:error, term()}
```

**Purpose**: Builds unified code property graph.

**Parameters**:
- `module_data` - Enhanced module data
- `opts` - Build options

**Options**:
- `:include_ast` - Include AST edges (default: true)
- `:include_cfg` - Include control flow (default: true)
- `:include_dfg` - Include data flow (default: true)
- `:include_types` - Include type information (default: true)

**Returns**:
- `{:ok, cpg}` code property graph
- `{:error, reason}` on failure

#### query_cpg/2
```elixir
@spec query_cpg(CPG.t(), cpg_query()) :: 
  {:ok, [CPGNode.t()]} | {:error, term()}

@type cpg_query :: %{
  node_type: atom(),
  properties: map(),
  connected_to: [{atom(), String.t()}],
  within_distance: pos_integer()
}
```

**Purpose**: Queries CPG for matching nodes.

**Parameters**:
- `cpg` - Code property graph
- `query` - Query specification

**Returns**:
- `{:ok, nodes}` matching nodes
- `{:error, reason}` on failure

#### find_pattern/2
```elixir
@spec find_pattern(CPG.t(), pattern_spec()) :: 
  {:ok, [pattern_match()]} | {:error, term()}

@type pattern_spec :: %{
  pattern_type: atom(),
  constraints: [constraint()],
  min_matches: pos_integer()
}

@type pattern_match :: %{
  nodes: [String.t()],
  edges: [String.t()],
  confidence: float(),
  location: ast_location()
}
```

**Purpose**: Finds specific patterns in CPG.

**Parameters**:
- `cpg` - Code property graph
- `pattern` - Pattern specification

**Returns**:
- `{:ok, matches}` pattern matches
- `{:error, reason}` on failure

## Query Builder API

### ElixirScope.ASTRepository.QueryBuilder

#### build_query/1
```elixir
@spec build_query(keyword()) :: 
  {:ok, query()} | {:error, term()}
```

**Purpose**: Builds query from keyword options.

**Options**:
- `:select` - Fields to select
- `:from` - Table/collection to query
- `:where` - Filter conditions
- `:join` - Join specifications
- `:order_by` - Sort order
- `:limit` - Result limit

**Returns**:
- `{:ok, query}` built query
- `{:error, reason}` on invalid options

#### execute_query/2
```elixir
@spec execute_query(GenServer.server(), query()) :: 
  {:ok, query_result()} | {:error, term()}

@type query_result :: %{
  data: [map()],
  count: non_neg_integer(),
  execution_time_ms: non_neg_integer(),
  query_plan: String.t()
}
```

**Purpose**: Executes query against repository.

**Parameters**:
- `server` - Repository GenServer reference
- `query` - Query to execute

**Returns**:
- `{:ok, result}` query results
- `{:error, reason}` on failure

## Error Handling

### Common Error Types

```elixir
@type error_reason ::
  :not_found |
  :invalid_data |
  :memory_limit_exceeded |
  :invalid_query |
  :parsing_error |
  :analysis_error |
  :sync_error |
  {:timeout, term()} |
  {:exception, Exception.t()}
```

### Error Recovery Strategies

1. **Partial Results**: Return successful results with error list
2. **Retry Logic**: Automatic retry for transient failures
3. **Graceful Degradation**: Fallback to simpler analysis
4. **Error Aggregation**: Collect all errors for batch operations

## Performance Considerations

### Caching Strategy

```elixir
# Query cache
@query_cache_ttl 60_000  # 1 minute
@max_cache_size 1000     # entries

# Analysis cache  
@analysis_cache_ttl 300_000  # 5 minutes
@max_analysis_cache_size 500

# CPG cache
@cpg_cache_ttl 600_000  # 10 minutes
@max_cpg_cache_size 100
```

### Batch Operations

```elixir
# Batch size recommendations
@default_batch_size 100
@max_batch_size 1000
@parallel_workers System.schedulers_online()
```

### Memory Management

```elixir
# Memory limits
@max_ast_size 10_000  # nodes
@max_function_size 1_000  # nodes
@max_query_result_size 10_000  # records
```

## Usage Examples

### Complete Project Analysis

```elixir
# Initialize repository
{:ok, repo} = Repository.start_link()

# Populate project
{:ok, stats} = ProjectPopulator.populate_project("/my/project", 
  progress_callback: fn progress ->
    IO.puts("Progress: #{progress.percent}%")
  end
)

# Start file watcher
{:ok, watcher} = FileWatcher.start_link(
  project_path: "/my/project",
  callback: fn changes ->
    Synchronizer.sync_changes(changes)
  end
)

# Query complex functions
{:ok, complex_fns} = Repository.query_functions(repo, %{
  complexity: {:gt, 10},
  limit: 20
})

# Analyze module
{:ok, module_data} = Repository.get_module(repo, MyModule)
{:ok, cpg} = CPGBuilder.build_cpg(module_data)

# Find patterns
{:ok, patterns} = CPGBuilder.find_pattern(cpg, %{
  pattern_type: :n_plus_one_query,
  min_matches: 1
})
```

### Real-time Synchronization

```elixir
# Handle file change
def handle_file_change(file_path) do
  case Synchronizer.sync_file(file_path) do
    {:ok, %{status: :updated, modules_affected: modules}} ->
      # Trigger re-analysis for affected modules
      Enum.each(modules, &analyze_module/1)
      
    {:ok, %{status: :unchanged}} ->
      # No action needed
      :ok
      
    {:error, reason} ->
      Logger.error("Sync failed: #{inspect(reason)}")
  end
end
```

### Advanced Querying

```elixir
# Build complex query
{:ok, query} = QueryBuilder.build_query(
  select: [:module, :function, :complexity],
  from: :functions,
  where: [
    {:and, [
      {:module_type, :in, [:genserver, :supervisor]},
      {:complexity, :gt, 15},
      {:visibility, :eq, :public}
    ]}
  ],
  join: [
    {:modules, :module_name, :module_name}
  ],
  order_by: {:desc, :complexity},
  limit: 50
)

# Execute query
{:ok, result} = QueryBuilder.execute_query(repo, query)
```

## Testing Support

### Mock Repository

```elixir
# Create mock repository for testing
{:ok, mock_repo} = Repository.start_link(name: :test_repo)

# Load test fixtures
TestFixtures.load_sample_modules(mock_repo)

# Test analysis
{:ok, analysis} = ASTAnalyzer.analyze_module(
  TestFixtures.complex_module_ast()
)
```

### Performance Testing

```elixir
# Benchmark query performance
Benchee.run(%{
  "simple_query" => fn ->
    Repository.query_functions(repo, %{module: MyModule})
  end,
  "complex_query" => fn ->
    Repository.query_functions(repo, %{
      complexity: {:gt, 10},
      calls: {Enum, :map, 2}
    })
  end
})
```
