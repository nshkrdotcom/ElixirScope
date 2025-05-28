# ElixirScope Enhanced AST Repository - Design Analysis & Unknowns

## Executive Summary

This document analyzes the current state of the CFG, DFG, and CPG components in ElixirScope's Enhanced AST Repository, with a specific focus on **unknowns, unclear requirements, and areas requiring deeper investigation**.

## Component Status Overview

| Component | Lines of Code | Test Status | Core Issue |
|-----------|---------------|-------------|------------|
| CFGGenerator | 705 | 24 tests, 18 failures | Logic errors in complexity calculation |
| DFGGenerator | 962 | 21 tests, 19 failures | Fundamental state management architecture flaw |
| CPGBuilder | 678 | 19 tests, 18 failures | Depends on broken DFG + CFG issues |

## Critical Unknowns & Design Questions

### 1. CFG Generator - Complexity Calculation Mysteries

**What We Don't Know:**
- **Elixir-specific complexity semantics**: How should cyclomatic complexity be calculated for Elixir's unique constructs?
  - Pattern matching in function heads: Does `def foo([]), do: :empty; def foo([h|t]), do: process(h)` count as 1 or 2 complexity points?
  - Guard clauses: Does `def foo(x) when x > 0, do: :pos; def foo(x), do: :neg` add complexity?
  - With statements: How do `with` clauses contribute to complexity vs traditional if/case?
  - Pipe operators: Do pipes affect control flow complexity or just data flow?

**Current Implementation Gap:**
```elixir
# Current logic counts decision edges, but should it count decision POINTS?
decision_points = edges
|> Enum.filter(fn edge -> edge.type in [:true_branch, :false_branch, :case_branch] end)
|> Enum.group_by(fn edge -> edge.from_node_id end)  # Groups by source node
|> Map.keys()
|> length()
```

**Unknown:** Is this the correct interpretation of McCabe's complexity for functional languages?

### 2. DFG Generator - Fundamental Architecture Questions

**What We Don't Know:**
- **State threading semantics**: Should DFG analysis be:
  - Purely functional (immutable state passing)?
  - Stateful with mutation tracking?
  - Hybrid approach with scoped mutations?

**Critical Unknown - Variable Scoping:**
```elixir
def complex_scoping do
  x = 1                    # Scope 1
  case input do
    :a -> 
      x = 2                # Scope 2 - shadows or new binding?
      y = x + 1            # Which x? How to track?
    :b -> 
      z = x + 1            # Original x or error?
  end
  x                        # Which x is returned?
end
```

**Questions:**
1. How should variable shadowing be represented in the DFG?
2. Should we create phi nodes (SSA form) or track binding contexts?
3. How do we handle Elixir's immutable variable semantics vs traditional mutable DFG models?

**Unknown Implementation Pattern:**
- Current code tries to track variables by `{var_name, scope}` tuples, but scope management is broken
- No clear strategy for handling variable rebinding vs shadowing
- Unclear how to represent data flow across scope boundaries

### 3. CPG Builder - Integration Mysteries

**What We Don't Know:**
- **Unified representation**: How should CFG and DFG nodes be merged?
  - Should there be separate node types or unified nodes with multiple properties?
  - How do we handle conflicts when CFG says "sequential" but DFG says "data dependency"?

**Critical Unknown - Node Correlation:**
```elixir
# CFG might create: entry -> assignment -> variable_ref -> exit
# DFG might create: var_def -> var_use
# How do we correlate these? Are they the same nodes or different views?
```

**Questions:**
1. Should CPG nodes be:
   - Union of CFG + DFG nodes?
   - Intersection with cross-references?
   - Completely new unified representation?

2. How do we handle timing? CFG is about execution order, DFG is about data dependencies - these can conflict.

### 4. Elixir-Specific Semantic Unknowns

**Pattern Matching Semantics:**
```elixir
case {x, y} do
  {a, b} when a > b -> a - b    # How many nodes? How to represent guard?
  {a, b} -> a + b               # Same variable names, different scope?
end
```

**Unknown:** How should this be represented in CFG/DFG?
- Are `a` and `b` the same variables across clauses?
- How do guards affect control flow vs data flow?
- Should pattern matching create special node types?

**Pipe Operator Semantics:**
```elixir
input
|> transform()
|> filter(fn x -> x > 0 end)
|> Enum.map(&process/1)
```

**Unknowns:**
1. CFG perspective: Is this sequential execution or does the anonymous function create branching?
2. DFG perspective: How do we track data flow through the pipe chain?
3. Should pipes create special edge types or be treated as function calls?

**Comprehension Semantics:**
```elixir
for x <- list, x > 0, y = process(x), do: y * 2
```

**Unknowns:**
1. How many CFG nodes should this create?
2. How do we represent the filter condition in DFG?
3. Is the variable `y` in a different scope?

### 5. Performance & Scalability Unknowns

**Memory Usage:**
- Current target: <1MB per function CFG, <2MB per function DFG
- **Unknown:** Are these realistic for complex Elixir functions with heavy pattern matching?
- **Unknown:** How do we handle GenServer state machines with hundreds of clauses?

**Time Complexity:**
- Current target: CFG <100ms, DFG <200ms, CPG <500ms
- **Unknown:** What's the algorithmic complexity of our current approach?
- **Unknown:** Do we need incremental updates or full regeneration?

### 6. Integration with Existing ElixirScope Unknowns

**EventStore Integration:**
- Current implementation stores events, but **unknown:** what granularity?
- Should every node creation be an event?
- How do we correlate AST analysis events with runtime execution events?

**Query Engine Integration:**
- **Unknown:** What query patterns will be most common?
- Should we optimize for:
  - "Find all variables that depend on X"?
  - "Show control flow path from A to B"?
  - "Detect potential race conditions"?

### 7. Testing & Validation Unknowns

**Correctness Validation:**
- **Unknown:** How do we validate that our CFG/DFG is "correct"?
- Should we compare against other tools (like Dialyzer's analysis)?
- How do we test edge cases in pattern matching?

**Test Coverage:**
- Current tests focus on basic cases
- **Unknown:** What are the most important edge cases for Elixir?
- How do we test OTP behaviors, GenServers, Supervisors?

## Immediate Research Priorities

### Priority 1: Elixir Semantics Research
1. **Study Dialyzer's approach** to control flow and data flow analysis
2. **Research SSA form** for functional languages
3. **Investigate existing CFG/DFG tools** for Erlang/Elixir

### Priority 2: Architecture Decisions
1. **Define variable scoping semantics** clearly
2. **Choose state management pattern** (functional vs stateful)
3. **Design unified node representation** for CPG

### Priority 3: Implementation Strategy
1. **Fix CFG complexity calculation** with proper Elixir semantics
2. **Rewrite DFG state management** from scratch
3. **Design CPG integration** based on fixed CFG/DFG

## Questions for Further Investigation

1. **Should we follow academic literature** on CFG/DFG for functional languages, or adapt imperative approaches?

2. **How does Elixir's actor model** (processes, message passing) affect traditional CFG/DFG analysis?

3. **Should we create Elixir-specific node types** (like `:pattern_match`, `:guard_clause`, `:pipe_operation`) or stick to traditional types?

4. **How do we handle macros** in AST analysis? Should macro expansion happen before or during analysis?

5. **What's the relationship** between our static analysis and ElixirScope's runtime execution cinema?

## Conclusion

The current implementation has fundamental gaps in understanding Elixir's unique semantics. Before continuing implementation, we need to:

1. **Research existing approaches** to functional language analysis
2. **Define clear semantics** for Elixir-specific constructs
3. **Choose architectural patterns** that fit Elixir's immutable, pattern-matching nature
4. **Validate our approach** against real-world Elixir codebases

The goal is not just to make tests pass, but to create analysis tools that provide meaningful insights into Elixir code behavior. 