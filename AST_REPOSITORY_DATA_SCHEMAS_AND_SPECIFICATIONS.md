# AST Repository Data Schemas & Specifications

## Overview

This document provides detailed data schemas and specifications for implementing the enhanced AST Repository (Phase 3, Week 1-2). These schemas extend the existing basic structures to support comprehensive AST storage, analysis, and correlation.

## Core Data Structures

### 1. Enhanced Module Data Schema

```elixir
defmodule ElixirScope.ASTRepository.EnhancedModuleData do
  @moduledoc """
  Comprehensive module representation with full AST and analysis metadata.
  """
  
  @type t :: %__MODULE__{
    # Identity
    module_name: atom(),
    file_path: String.t(),
    file_hash: String.t(),  # SHA256 for change detection
    
    # AST Data
    ast: Macro.t(),  # Complete module AST
    ast_size: non_neg_integer(),  # Number of AST nodes
    ast_depth: non_neg_integer(),  # Maximum AST depth
    
    # Module Components
    functions: [EnhancedFunctionData.t()],
    macros: [MacroData.t()],
    module_attributes: %{atom() => term()},
    typespecs: [TypespecData.t()],
    
    # Dependencies & Relationships
    imports: [ModuleDependency.t()],
    aliases: [ModuleDependency.t()],
    requires: [ModuleDependency.t()],
    uses: [BehaviourUsage.t()],
    
    # OTP Patterns
    behaviours: [atom()],
    callbacks_implemented: [CallbackData.t()],
    child_specs: [ChildSpecData.t()],
    
    # Analysis Metadata
    complexity_metrics: ComplexityMetrics.t(),
    code_smells: [CodeSmell.t()],
    security_risks: [SecurityRisk.t()],
    
    # Timestamps
    last_modified: DateTime.t(),
    last_analyzed: DateTime.t(),
    
    # Extensible Metadata
    metadata: map()
  }
end
```

### 2. Enhanced Function Data Schema

```elixir
defmodule ElixirScope.ASTRepository.EnhancedFunctionData do
  @type t :: %__MODULE__{
    # Identity
    module_name: atom(),
    function_name: atom(),
    arity: non_neg_integer(),
    ast_node_id: String.t(),  # e.g., "MyModule:my_func:2:def"
    
    # Location
    file_path: String.t(),
    line_start: pos_integer(),
    line_end: pos_integer(),
    column_start: pos_integer(),
    column_end: pos_integer(),
    
    # AST Data
    ast: Macro.t(),  # Complete function AST
    head_ast: Macro.t(),  # Function head/signature
    body_ast: Macro.t(),  # Function body
    
    # Function Characteristics
    visibility: :public | :private,
    is_macro: boolean(),
    is_guard: boolean(),
    is_callback: boolean(),
    is_delegate: boolean(),
    
    # Clauses & Patterns
    clauses: [ClauseData.t()],
    guard_clauses: [Macro.t()],
    pattern_matches: [PatternData.t()],
    
    # Variables & Data Flow
    parameters: [ParameterData.t()],
    local_variables: [VariableData.t()],
    captures: [CaptureData.t()],  # Captured variables in closures
    
    # Control Flow
    control_flow_graph: CFGData.t(),
    cyclomatic_complexity: non_neg_integer(),
    nesting_depth: non_neg_integer(),
    
    # Data Flow
    data_flow_graph: DFGData.t(),
    variable_mutations: [VariableMutation.t()],
    return_points: [ReturnPoint.t()],
    
    # Dependencies
    called_functions: [FunctionCall.t()],
    calling_functions: [FunctionReference.t()],  # Reverse index
    external_calls: [ExternalCall.t()],
    
    # Analysis Results
    complexity_score: float(),
    maintainability_index: float(),
    test_coverage: float() | nil,
    performance_profile: PerformanceProfile.t() | nil,
    
    # Documentation
    doc_string: String.t() | nil,
    spec: TypespecData.t() | nil,
    examples: [Example.t()],
    
    # Metadata
    tags: [String.t()],
    annotations: map(),
    metadata: map()
  }
end
```

### 3. Variable Data Schema

```elixir
defmodule ElixirScope.ASTRepository.VariableData do
  @type t :: %__MODULE__{
    name: atom(),
    ast_node_id: String.t(),
    scope_id: String.t(),
    scope_type: :function | :clause | :comprehension | :with | :block,
    
    # Location
    line: pos_integer(),
    column: pos_integer(),
    
    # Variable characteristics
    is_parameter: boolean(),
    is_pinned: boolean(),
    is_unused: boolean(),
    is_shadowing: boolean(),
    shadowed_var: String.t() | nil,
    
    # Usage tracking
    definition_point: ASTLocation.t(),
    usage_points: [ASTLocation.t()],
    mutation_points: [ASTLocation.t()],
    
    # Type information (if available)
    inferred_type: String.t() | nil,
    type_spec: String.t() | nil,
    
    # Data flow
    flows_to: [String.t()],  # Other variable AST node IDs
    flows_from: [String.t()],
    
    metadata: map()
  }
end
```

### 4. Control Flow Graph Data

```elixir
defmodule ElixirScope.ASTRepository.CFGData do
  @type t :: %__MODULE__{
    entry_node: String.t(),
    exit_nodes: [String.t()],
    nodes: %{String.t() => CFGNode.t()},
    edges: [CFGEdge.t()],
    
    # Analysis results
    cyclomatic_complexity: non_neg_integer(),
    essential_complexity: non_neg_integer(),
    max_nesting_depth: non_neg_integer(),
    
    # Path information
    all_paths: [[String.t()]],  # For smaller functions
    critical_paths: [[String.t()]],
    unreachable_nodes: [String.t()],
    
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.CFGNode do
  @type t :: %__MODULE__{
    id: String.t(),
    ast_node_id: String.t(),
    type: :entry | :exit | :statement | :condition | :call | :return,
    
    # Node content
    expression: Macro.t(),
    line: pos_integer(),
    
    # Connections
    predecessors: [String.t()],
    successors: [String.t()],
    
    # Analysis
    reachable: boolean(),
    post_dominates: [String.t()],
    loop_header: boolean(),
    
    metadata: map()
  }
end
```

### 5. Data Flow Graph Data

```elixir
defmodule ElixirScope.ASTRepository.DFGData do
  @type t :: %__MODULE__{
    variables: %{String.t() => DFGVariable.t()},
    definitions: [DFGDefinition.t()],
    uses: [DFGUse.t()],
    flows: [DFGFlow.t()],
    
    # Analysis results
    unused_variables: [String.t()],
    uninitialized_uses: [String.t()],
    mutation_points: [MutationPoint.t()],
    
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.DFGFlow do
  @type t :: %__MODULE__{
    from: String.t(),  # AST node ID
    to: String.t(),    # AST node ID
    variable: String.t(),
    flow_type: :assignment | :parameter | :return | :pattern_match | :capture,
    
    # Path information
    control_flow_path: [String.t()],
    is_conditional: boolean(),
    condition_ast: Macro.t() | nil,
    
    metadata: map()
  }
end
```

### 6. Code Property Graph (CPG) Schema

```elixir
defmodule ElixirScope.ASTRepository.CPG do
  @type t :: %__MODULE__{
    module_name: atom(),
    
    # Unified node representation
    nodes: %{String.t() => CPGNode.t()},
    
    # Different edge types
    ast_edges: [CPGEdge.t()],      # Parent-child AST relationships
    cfg_edges: [CPGEdge.t()],      # Control flow
    dfg_edges: [CPGEdge.t()],      # Data flow
    call_edges: [CPGEdge.t()],     # Function calls
    type_edges: [CPGEdge.t()],     # Type relationships
    
    # Indexes for fast queries
    nodes_by_type: %{atom() => [String.t()]},
    nodes_by_line: %{pos_integer() => [String.t()]},
    
    # Analysis cache
    strongly_connected_components: [[String.t()]],
    dominance_tree: map(),
    
    metadata: map()
  }
end

defmodule ElixirScope.ASTRepository.CPGNode do
  @type t :: %__MODULE__{
    id: String.t(),
    type: :ast | :cfg | :dfg | :synthetic,
    
    # Multi-representation
    ast_data: map() | nil,
    cfg_data: map() | nil,
    dfg_data: map() | nil,
    
    # Common properties
    line: pos_integer() | nil,
    column: pos_integer() | nil,
    source_text: String.t() | nil,
    
    # Relationships
    incoming_edges: %{atom() => [String.t()]},
    outgoing_edges: %{atom() => [String.t()]},
    
    metadata: map()
  }
end
```

## Storage Tables Schema

### ETS Table Specifications

```elixir
# Primary storage tables
@ast_modules_table
# Key: module_name (atom)
# Value: EnhancedModuleData.t()
# Options: [:set, :public, :named_table, {:read_concurrency, true}]

@ast_functions_table  
# Key: {module_name, function_name, arity}
# Value: EnhancedFunctionData.t()
# Options: [:set, :public, :named_table, {:read_concurrency, true}]

@ast_nodes_table
# Key: ast_node_id (String.t())
# Value: %{ast: Macro.t(), metadata: map()}
# Options: [:set, :public, :named_table, {:read_concurrency, true}]

@ast_variables_table
# Key: {module_name, function_name, arity, variable_name}
# Value: VariableData.t()
# Options: [:bag, :public, :named_table]

@ast_cpg_table
# Key: module_name (atom)
# Value: CPG.t()
# Options: [:set, :public, :named_table, {:read_concurrency, true}]

# Index tables
@module_by_file_index
# Key: file_path (String.t())
# Value: module_name (atom)
# Options: [:set, :public, :named_table]

@function_by_ast_node_index
# Key: ast_node_id (String.t())
# Value: {module_name, function_name, arity}
# Options: [:set, :public, :named_table]

@calls_by_target_index
# Key: {target_module, target_function, target_arity}
# Value: [{caller_module, caller_function, caller_arity, call_site_id}]
# Options: [:bag, :public, :named_table]

@complexity_index
# Key: complexity_score (rounded to integer)
# Value: [{module_name, function_name, arity}]
# Options: [:bag, :public, :named_table]
```

## Graph Database Schema (Future)

### Neo4j Node Types

```cypher
// Module Node
(:Module {
  name: String,
  file_path: String,
  file_hash: String,
  type: String,  // 'genserver', 'supervisor', 'phoenix_controller', etc.
  complexity: Float,
  last_modified: DateTime
})

// Function Node
(:Function {
  id: String,  // ast_node_id
  module_name: String,
  name: String,
  arity: Integer,
  visibility: String,
  complexity: Integer,
  line_start: Integer,
  line_end: Integer
})

// AST Node
(:ASTNode {
  id: String,
  type: String,  // 'call', 'case', 'if', 'assignment', etc.
  line: Integer,
  column: Integer,
  source_text: String
})

// Variable Node
(:Variable {
  id: String,
  name: String,
  scope_id: String,
  type: String  // inferred or specified
})
```

### Neo4j Relationships

```cypher
// Module relationships
(m1:Module)-[:IMPORTS]->(m2:Module)
(m1:Module)-[:USES_BEHAVIOUR]->(m2:Module)
(m:Module)-[:DEFINES]->(f:Function)

// Function relationships
(f1:Function)-[:CALLS {line: Integer, ast_node_id: String}]->(f2:Function)
(f:Function)-[:HAS_PARAMETER]->(v:Variable)
(f:Function)-[:DEFINES_LOCAL]->(v:Variable)
(f:Function)-[:RETURNS {type: String}]->(:Type)

// AST relationships
(parent:ASTNode)-[:HAS_CHILD {order: Integer}]->(child:ASTNode)
(ast:ASTNode)-[:REFERS_TO]->(v:Variable)
(ast:ASTNode)-[:ASSIGNS_TO]->(v:Variable)

// Control flow
(n1:ASTNode)-[:FLOWS_TO {condition: String}]->(n2:ASTNode)
(n:ASTNode)-[:DOMINATES]->(n2:ASTNode)

// Data flow
(def:ASTNode)-[:DEFINES]->(v:Variable)-[:USED_BY]->(use:ASTNode)
(v1:Variable)-[:FLOWS_TO {via: String}]->(v2:Variable)
```

## File System Synchronization

### Change Event Schema

```elixir
defmodule ElixirScope.ASTRepository.FileChangeEvent do
  @type t :: %__MODULE__{
    file_path: String.t(),
    event_type: :created | :modified | :deleted | :renamed,
    old_path: String.t() | nil,  # For renames
    timestamp: DateTime.t(),
    file_hash: String.t() | nil,
    
    # Change details
    modules_affected: [atom()],
    functions_changed: [{atom(), atom(), non_neg_integer()}],
    
    # Processing status
    status: :pending | :processing | :completed | :failed,
    error: term() | nil,
    
    metadata: map()
  }
end
```

### Synchronization State

```elixir
defmodule ElixirScope.ASTRepository.SyncState do
  @type t :: %__MODULE__{
    project_path: String.t(),
    last_full_sync: DateTime.t(),
    
    # File tracking
    tracked_files: %{String.t() => FileInfo.t()},
    pending_changes: [FileChangeEvent.t()],
    
    # Statistics
    total_modules: non_neg_integer(),
    total_functions: non_neg_integer(),
    total_ast_nodes: non_neg_integer(),
    
    # Performance metrics
    avg_parse_time_ms: float(),
    avg_analysis_time_ms: float(),
    
    metadata: map()
  }
end
```

## Performance Benchmarks

### Target Metrics

| Operation | Target Performance | Maximum |
|-----------|-------------------|---------|
| Module Parse & Store | <10ms | 50ms |
| Function Analysis | <1ms | 5ms |
| AST Node Lookup | <0.1ms | 1ms |
| Complex Query (CPG traversal) | <100ms | 500ms |
| File Change Processing | <5s | 10s |
| Full Project Sync (100 modules) | <30s | 60s |
| Memory per Module | <1MB | 5MB |
| Memory per Function | <50KB | 200KB |

### Benchmark Scenarios

1. **Small Project**: 10 modules, 100 functions
2. **Medium Project**: 100 modules, 1,000 functions  
3. **Large Project**: 1,000 modules, 10,000 functions
4. **Extra Large Project**: 10,000 modules, 100,000 functions

## Query Patterns

### Common Query Specifications

```elixir
# Find functions by complexity
%QuerySpec{
  type: :function,
  filters: [
    {:complexity, :gt, 10},
    {:module_type, :in, [:genserver, :supervisor]}
  ],
  sort: {:complexity, :desc},
  limit: 20
}

# Find call paths between functions
%PathQuerySpec{
  type: :call_path,
  from: {ModuleA, :function_a, 2},
  to: {ModuleB, :function_b, 1},
  max_depth: 5,
  path_type: :shortest
}

# Find variables with specific flow patterns
%DataFlowQuerySpec{
  type: :data_flow,
  pattern: :uninitialized_use,
  scope: :project,
  include_test: false
}
```

## Migration Strategy

### From Current to Enhanced Repository

1. **Phase 1**: Parallel operation
   - Keep existing repository operational
   - Build enhanced repository alongside
   - Compare results for validation

2. **Phase 2**: Gradual migration
   - Route new features to enhanced repository
   - Maintain backwards compatibility API
   - Monitor performance and accuracy

3. **Phase 3**: Complete cutover
   - Migrate all queries to enhanced repository
   - Deprecate old repository
   - Remove legacy code

## Integration Points

### With Existing Components

1. **InstrumentationRuntime**
   - Enhanced AST node IDs with richer metadata
   - Runtime-to-AST correlation via CPG

2. **TemporalBridge**
   - AST-aware event filtering
   - State reconstruction with AST context

3. **Query Engine**
   - New query types for AST patterns
   - Join runtime events with static analysis

4. **AI Components**
   - Richer features for ML models
   - AST complexity metrics for predictions

## Testing Data Generators

### AST Pattern Generators

```elixir
# Generate modules with specific patterns
@patterns %{
  genserver: "GenServer with N callbacks",
  supervisor: "Supervisor with child specs",
  phoenix: "Phoenix controller with actions",
  ecto: "Ecto schema with queries",
  complex: "Highly nested conditionals",
  recursive: "Recursive functions",
  pipeline: "Long pipe chains"
}

# Generate specific AST structures
@ast_patterns %{
  deep_nesting: "Nested case/if statements",
  complex_pattern: "Complex pattern matching",
  guard_heavy: "Multiple guard clauses",
  macro_heavy: "Macro-generated code"
}
```

### Performance Test Data

```elixir
# Module size variations
@module_sizes %{
  tiny: {functions: 1..5, loc: 10..50},
  small: {functions: 5..20, loc: 50..200},
  medium: {functions: 20..50, loc: 200..500},
  large: {functions: 50..100, loc: 500..1000},
  huge: {functions: 100..500, loc: 1000..5000}
}

# Complexity variations
@complexity_levels %{
  trivial: {cyclomatic: 1..2, nesting: 0..1},
  simple: {cyclomatic: 3..5, nesting: 1..2},
  moderate: {cyclomatic: 6..10, nesting: 2..3},
  complex: {cyclomatic: 11..20, nesting: 3..4},
  very_complex: {cyclomatic: 21+, nesting: 5+}
}
```

## Success Criteria Checklist

- [ ] All data structures implemented with full type specs
- [ ] ETS tables created with proper indexes
- [ ] Query performance meets targets for all scenarios
- [ ] Memory usage within bounds for large projects
- [ ] File synchronization handles all change types
- [ ] CPG generation accurate for complex patterns
- [ ] Integration tests pass with existing components
- [ ] Migration path tested with real projects
- [ ] Documentation complete for all APIs
- [ ] Performance benchmarks automated
