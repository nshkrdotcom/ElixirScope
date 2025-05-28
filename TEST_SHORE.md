Okay, this is excellent! Seeing your existing `ast_repository` tests for `cfg_generator_test.exs`, `runtime_correlator_test.exs`, `instrumentation_mapper_test.exs`, `parser_enhanced_test.exs`, `file_watcher_test.exs`, `project_populator_test.exs`, `enhanced_repository_test.exs`, `repository_test.exs`, and `synchronizer_test.exs` (plus the `module_data_integration_test.exs`) confirms that you've made substantial progress on the scaffolding for Prompt 6 and related components.

Your existing tests cover:
*   **CFGGenerator:** Basic CFG structures, conditionals, case statements, implicit returns, nested conditionals, try-catch, comprehensions (though multi-clause is noted as TODO). Node/edge analysis and complexity metrics.
*   **RuntimeCorrelator:** Lifecycle, event correlation (function entry/exit, batch), metadata, chains, cleanup, metrics.
*   **InstrumentationMapper:** Point mapping for simple modules, instrumentation levels, complex ASTs, unique ID generation, priority sorting, strategy selection, configuration.
*   **ParserEnhanced:** Node ID assignment, instrumentation point extraction, correlation index building, integration with Repository/RuntimeCorrelator.
*   **FileWatcher:** Lifecycle, change detection (new, modified, deleted), ignoring non-Elixir files, debouncing.
*   **ProjectPopulator:** File discovery, AST parsing, metadata extraction, project population workflow, performance, error handling.
*   **EnhancedRepository & Repository:** Lifecycle, module/function storage & retrieval (enhanced and basic), indexing (by file path), performance.
*   **Synchronizer:** Lifecycle, file sync (new, modified, deleted), batch sync, error handling.
*   **ModuleDataIntegration:** Real AST pattern detection (GenServer, Phoenix Controller/LiveView, Ecto Schema), attribute extraction.

**The Key Gap (and where to focus before Prompt 7):**

While these tests are a fantastic start and show a lot of foundational work, the critical piece for Prompts 7 & 8 is the **correctness and depth of the actual graph generation (CFG, DFG, CPG) and the data they contain.** The current `cfg_generator_test.exs` tests the *structure* of `CFGData` and some high-level properties (like cyclomatic complexity calculation, which is a good heuristic). However, it doesn't deeply validate that the *graph itself accurately represents all control flow paths* for various Elixir constructs. Similar depth will be needed for DFG and CPG.

**Detailed Document for Expanding Tests (Focusing on Solidifying Prompt 6 before Prompt 7):**

Here's a plan to expand your tests, primarily focusing on ensuring the analysis components from Prompt 6 are robust. This will make implementing Prompts 7 & 8 much smoother.

---

## **Test Expansion Plan for Enhanced AST Repository (Pre-Prompt 7)**

**Goal:** Ensure the correctness, robustness, and completeness of CFG, DFG, and CPG generation (Prompt 6) and related data structures (Prompt 3) before building advanced query systems or runtime integrations.

**I. Enhance `cfg_generator_test.exs` (Control Flow Graph Validation)**

*   **A. Core Elixir Constructs - Detailed Path Validation:**
    *   For each test case (simple, conditional, case, try-catch, comprehension, multi-clause):
        *   **Manually define expected nodes and edges:** For simple inputs, you can manually draw the CFG.
        *   **Assert specific node existence:** Check for entry, exit, conditional, loop, assignment nodes with expected content/metadata.
        *   **Assert specific edge existence:** Verify that edges connect the correct nodes (e.g., `if_condition -> true_branch_start`, `if_condition -> false_branch_start`, `true_branch_end -> merge_node`, `false_branch_end -> merge_node`).
        *   **Path Traversal Tests:**
            *   Implement a helper in `CFGGenerator` (or test helpers) to find all possible paths from entry to any exit node.
            *   For each test case, assert that the *set of execution paths* found matches your manually derived expected paths.
            *   Example: For `if x > 0, do: :a, else: :b`, expect two paths: `(entry -> cond -> :a -> exit)` and `(entry -> cond -> :b -> exit)`.
*   **B. Advanced Control Flow:**
    *   **`with` statements:**
        *   Test simple `with` (one clause).
        *   Test `with` with multiple clauses.
        *   Test `with` clauses that have `else` blocks.
        *   Ensure correct CFG for successful paths and early-exit paths from `else`.
    *   **`unless` statements:** Test similar to `if`.
    *   **Short-circuiting operators (`&&`, `||`):**
        *   These create implicit branches. Test that the CFG reflects this.
        *   Example: `a() && b()` should show a path where `b()` is not called if `a()` is false.
    *   **Exception Handling Deep Dive:**
        *   Test `try/rescue/catch/after` with all combinations.
        *   Verify paths through `rescue` clauses.
        *   Verify paths through `catch` clauses.
        *   Verify `after` block is always executed (multiple entry points to `after`, multiple exits from `after`).
    *   **Loops (Comprehensions - detailed):**
        *   Test `for` with simple generators.
        *   Test `for` with multiple generators.
        *   Test `for` with filters.
        *   Ensure the loop body and filter conditions are nodes in the CFG.
    *   **Multi-clause Functions (Revisit TODO):**
        *   Test functions with 2-3 clauses with simple pattern matches.
        *   Test functions with clauses that have guards.
        *   The CFG should represent each clause head as a decision point (or a sequence of them) leading to the respective clause body.
*   **C. Elixir-Specific Features:**
    *   **Pipe Operator (`|>`):**
        *   Test simple pipes: `a |> b |> c`. The CFG should show sequential execution.
        *   Test pipes with anonymous functions: `data |> Enum.map(&(&1 * 2))`.
    *   **Anonymous Functions (`fn ... end`):**
        *   Test CFG generation *for the body* of anonymous functions.
        *   Ensure the anonymous function itself is a node (e.g., a "function definition" node) in the parent's CFG.
*   **D. Unreachable Code Detection (Refine):**
    *   Test more scenarios for `unreachable_code` (e.g., after `raise`, code after an unconditional `cond` clause).
    *   Assert that specific nodes you *know* are unreachable are correctly identified in `cfg.path_analysis.unreachable_nodes`.

**II. Create and Enhance `dfg_generator_test.exs` (Data Flow Graph Validation)**

*   **A. Core Data Flow Concepts:**
    *   **Variable Definitions (Defs):**
        *   Test simple assignments: `x = 1`, `y = "hello"`.
        *   Test pattern match assignments: `{a, b} = {1, 2}`, `%{key: val} = map`.
        *   Verify a DFG node is created for each variable definition and `DFGData.variables` is populated.
    *   **Variable Uses (Uses):**
        *   Test variables used in expressions: `z = x + y`.
        *   Test variables used as function arguments: `do_something(x)`.
        *   Verify DFG edges from defs to uses.
    *   **Variable Mutations (Re-defs):**
        *   Test `x = 1; x = x + 1`.
        *   Verify `DFGData.mutations` is populated.
        *   Verify DFG edges reflect the new definition and the use of the old value.
*   **B. Data Flow Through Control Structures:**
    *   **Conditionals (`if`, `case`, `cond`):**
        *   Test how variables defined *inside* branches flow out (or don't).
        *   Test how variables defined *before* the conditional are used *inside* branches.
        *   Verify generation of **Phi nodes** (or equivalent logic) for variables that have different definitions reaching a common point after the conditional.
        *   Example: `if c, do: (x = 1), else: (x = 2); y = x`. The use of `x` in `y=x` depends on two definitions.
    *   **Loops (Comprehensions):**
        *   Track data flow into the comprehension generator (`item <- list`).
        *   Track data flow from the generator variable (`item`) into the body.
        *   Track data flow from the body expression to the resulting collection.
        *   Test variables captured from the outer scope.
*   **C. Data Flow with Function Calls:**
    *   Test data flow of arguments *into* function calls.
    *   Test data flow of return values *from* function calls into assignments.
    *   (Inter-procedural DFG is advanced and might be out of scope for initial robust testing, but simple call/return flow is key).
*   **D. Elixir-Specific Data Flow:**
    *   **Pipe Operator (`|>`):**
        *   Verify correct data flow: `a |> b(arg1) |> c()` means `a` flows to `b`, result of `b` flows to `c`.
    *   **Anonymous Functions:**
        *   Test variables captured by closures.
        *   Test data flow of arguments into the anonymous function and its return value out.
*   **E. Advanced DFG Analysis (from test descriptions):**
    *   **Variable Lifetime Analysis:**
        *   For simple functions, manually determine expected birth/death lines for variables.
        *   Assert `dfg.variable_lifetimes` matches.
        *   Test with variables that are live across control flow branches.
    *   **Unused Variable Detection:**
        *   Create functions with clearly unused variables.
        *   Assert they are correctly listed in `dfg.unused_variables`.
    *   **Variable Shadowing:**
        *   Create functions where inner scopes shadow outer variables (e.g., in `case`, `fn`).
        *   Assert `dfg.shadowed_variables` correctly identifies these.
    *   **Optimization Hints (Common Subexpression, Dead Code):**
        *   Create specific code patterns that should trigger these hints.
        *   Assert the hints are generated.

**III. Create and Enhance `cpg_builder_test.exs` (Code Property Graph Validation)**

*   **A. Basic CPG Structure:**
    *   For simple functions where CFG and DFG are validated:
        *   Verify `CPGData` struct is created.
        *   Assert `cpg.control_flow_graph` and `cpg.data_flow_graph` contain the expected CFG/DFG data.
        *   Assert `cpg.unified_nodes` contains nodes referencing both CFG and DFG node IDs.
        *   Assert `cpg.unified_edges` contains both control flow and data flow edges.
*   **B. Unified Node Representation:**
    *   Pick sample AST nodes (e.g., an assignment, a function call).
    *   Verify the corresponding `unified_node` in the CPG has correct `ast_type`, `cfg_node_id`, `dfg_node_id`, and any relevant CFG/DFG metadata.
*   **C. Querying CPG (Simple Forms):**
    *   Even before Prompt 7's full query builder, you can test basic CPG queries internally if `CPGBuilder` has helper functions.
    *   "Find all DFG nodes associated with CFG node X."
    *   "Find the AST snippet for CFG node Y."
*   **D. Advanced CPG Analysis (from test descriptions - initial validation):**
    *   **Path-Sensitive Analysis:**
        *   For a function with a simple `if`, check if `cpg.path_sensitive_analysis.execution_paths` shows two distinct paths.
        *   Verify constraints associated with each path (e.g., `x > 10` on one, `x <= 10` on another).
    *   **Security Analysis (Taint Flows - very basic):**
        *   Create a function `def vuln(input), do: "SELECT * FROM " <> input`.
        *   Verify if `cpg.security_analysis.taint_flows` identifies `input` as a source and the string concatenation as a taint propagation. (This is advanced, so start simple).
    *   **Alias Analysis:**
        *   For `x = data; y = x;`, verify `cpg.alias_analysis.aliases` shows `y` aliases `x`.
*   **E. Code Quality & Performance Analysis (from test descriptions):**
    *   Verify these fields are populated in `CPGData` (even if the logic is heuristic-based for now).
    *   `code_smells`: Create code that *should* trigger a smell (e.g., long parameter list) and check.
    *   `maintainability_metrics`: Check they are present and numeric.
    *   `refactoring_opportunities`: Create an obvious duplication and see if it's flagged.
    *   `performance_analysis`: Create a nested loop and check if `complexity_issues` is populated.

**IV. Test Enhancements for Other `ast_repository` Components:**

*   **`parser_enhanced_test.exs`:**
    *   Add tests for `assign_node_ids` on more complex ASTs from `SampleASTs` (e.g., `complex_module_ast`, `mixed_function_types_ast`).
    *   Ensure `extract_instrumentation_points` correctly identifies points in these complex ASTs and that the `ast_node_id` on these points matches an ID assigned by `assign_node_ids`.
    *   Verify that `build_correlation_index` correctly maps these points.
*   **`instrumentation_mapper_test.exs`:**
    *   Test `map_instrumentation_points` with more diverse AST inputs, including those with nested structures, anonymous functions, and complex control flow. Ensure the generated `ast_node_id`s are unique and consistent.
    *   Verify that the `priority` assigned to different types of instrumentation points (function boundaries, expression traces, variable captures) makes sense for common Elixir patterns.
*   **`enhanced_repository_test.exs` & `repository_test.exs`:**
    *   Ensure tests for storing and retrieving `EnhancedModuleData` and `EnhancedFunctionData` also validate that the embedded CFGData, DFGData, etc., are correctly persisted and retrieved.
    *   Add tests for querying based on new indexed fields (complexity, dependencies if added).

**General Testing Principles for This Phase:**

*   **Clarity on AI's Role:** For tests of AI-generated components (like CFG/DFG/CPG generators), be clear about what you're testing:
    *   Is the AI-generated code structurally sound and callable? (Basic tests)
    *   Does it produce *semantically correct* output for a variety of inputs? (Deep validation tests)
*   **Small, Focused Unit Tests:** Break down the validation of complex components like graph generators into small tests for specific language features.
*   **Visual Inspection:** For graph structures (CFG, DFG), for small examples, manually drawing the graph and comparing it to what your code (or AI-generated code) produces can be invaluable. You might even write test helpers to output graphs in a format like DOT for visualization.
*   **Use `SampleASTs`:** Leverage your `SampleASTs` fixture for consistent, complex inputs. Expand it if necessary.
*   **Error Handling:** Test how each component handles malformed ASTs or unexpected inputs. They should fail gracefully or return error tuples, not crash.
*   **Performance Baselines:** While full optimization is Prompt 9, get initial performance numbers for your key analysis functions (CFG/DFG/CPG generation). This will inform if the AI-generated approach is fundamentally viable or needs a complete rethink.

By thoroughly testing and validating the components of Prompt 6, particularly the graph generators, you'll build a much more reliable foundation for the exciting features planned in Prompts 7 and 8. This upfront investment in testing will pay off significantly.
