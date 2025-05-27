# ElixirScope Instrumentation: Use Guide

This guide explains how ElixirScope instruments your Elixir code, what gets instrumented by default, how you can influence this process, and what the injected instrumentation looks like.

## Table of Contents

1.  [Overview](#overview)
2.  [Automatic Instrumentation (Default Behavior)](#automatic-instrumentation-default-behavior)
    *   [Mechanism: The Mix Compiler](#mechanism-the-mix-compiler)
    *   [What Gets Instrumented by Default?](#what-gets-instrumented-by-default)
3.  [Influencing Instrumentation](#influencing-instrumentation)
    *   [Configuration in `mix.exs`](#configuration-in-mixexs)
    *   [Configuration in `config/*.exs` (Future)](#configuration-in-configexs-future)
4.  [Granular Instrumentation (Enhanced Capabilities)](#granular-instrumentation-enhanced-capabilities)
    *   [Local Variable Capture](#local-variable-capture)
    *   [Expression Value Tracing](#expression-value-tracing)
    *   [Custom Debugging Logic Injection](#custom-debugging-logic-injection)
5.  [Programmatic Instrumentation API (Advanced)](#programmatic-instrumentation-api-advanced)
    *   [Steps for Programmatic Instrumentation](#steps-for-programmatic-instrumentation)
    *   [Conceptual Example](#conceptual-example)
6.  [What Injected Instrumentation Looks Like](#what-injected-instrumentation-looks-like)
    *   [Function Boundary Instrumentation](#function-boundary-instrumentation)
    *   [Local Variable Capture](#local-variable-capture-1)
7.  [Key Modules Involved](#key-modules-involved)
8.  [Important Considerations](#important-considerations)
9.  [The Future: AI-Driven Instrumentation](#the-future-ai-driven-instrumentation)

## 1. Overview

ElixirScope achieves its "Execution Cinema Debugger" capabilities by performing **compile-time AST (Abstract Syntax Tree) transformations**. This means it modifies your code's structure before it's compiled into BEAM bytecode to insert calls to its own runtime for capturing execution data.

The goal is to link runtime events (like function calls, variable changes, errors) back to the specific lines and constructs in your original source code.

## 2. Automatic Instrumentation (Default Behavior)

When you include ElixirScope in your project (like in `cinema_demo`), it provides a baseline level of instrumentation automatically.

### Mechanism: The Mix Compiler

*   **Hooking into Compilation:** ElixirScope integrates into the Mix compilation process. By adding `:elixir_scope` to the `compilers` list in your `mix.exs` file, you tell Mix to run ElixirScope's custom compiler task *before* the standard Elixir compiler.
    ```elixir
    # In your project's mix.exs
    def project do
      [
        # ... other options ...
        compilers: [:elixir_scope] ++ Mix.compilers()
      ]
    end
    ```
*   **AST Transformation:**
    1.  The `Mix.Tasks.Compile.ElixirScope` task (`lib/elixir_scope/compiler/mix_task.ex`) is executed.
    2.  It reads your `.ex` source files.
    3.  It parses them into Elixir ASTs.
    4.  It applies transformations to these ASTs, injecting calls to `ElixirScope.Capture.InstrumentationRuntime`.
    5.  The transformed (instrumented) ASTs are then written to *new files* within your project's `_build` directory (e.g., `_build/dev/elixir_scope/lib/your_module.ex`). **Your original source files are never modified.**
    6.  The standard Elixir compiler then compiles these instrumented files from the `_build` directory.

### What Gets Instrumented by Default?

Even without a fully implemented AI planner, ElixirScope uses a rule-based system to decide what to instrument:

*   **Pattern Recognition (`ElixirScope.AI.PatternRecognizer`):** This module identifies common Elixir/OTP and Phoenix patterns:
    *   GenServer modules (based on `use GenServer`).
    *   Supervisor modules.
    *   Phoenix Controllers, LiveViews, Channels.
    *   Ecto Schemas.
*   **Complexity Analysis (`ElixirScope.AI.ComplexityAnalyzer`):** This module uses heuristics to assess code complexity (e.g., nesting depth, cyclomatic complexity for functions within recognized patterns).
*   **Code Analysis & Planning (`ElixirScope.AI.CodeAnalyzer`):** Based on the recognized patterns and complexity, this module generates a basic instrumentation plan.
    *   **Function Boundaries:** For recognized patterns like GenServer callbacks (`init/1`, `handle_call/3`, etc.), Phoenix controller actions, and LiveView callbacks (`mount/3`, `handle_event/3`, etc.), ElixirScope will typically instrument the entry and exit points of these functions. This involves injecting calls to `InstrumentationRuntime.report_function_entry` and `InstrumentationRuntime.report_function_exit`.
    *   **Regular Modules/Functions:** For standard modules and functions not matching specific OTP/Phoenix patterns, the default instrumentation might be less comprehensive. The `ElixirScope.AST.Transformer` will process any `def` or `defp` it finds. The extent of instrumentation depends on the "plan" it receives from the `CodeAnalyzer`. If a function isn't explicitly targeted by the current rule-based planner, it might receive minimal or no boundary instrumentation by default unless a global setting (see `mix.exs` configuration) implies broader coverage.

## 3. Influencing Instrumentation

While the full AI-driven dynamic planning is under development, you can influence instrumentation through configuration.

### Configuration in `mix.exs`

The `elixir_scope` key in your project's `mix.exs` file allows some high-level control. For `cinema_demo/mix.exs`:

```elixir
elixir_scope: [
  enabled: true, // Master switch for ElixirScope instrumentation
  instrumentation: [
    functions: true,          // Enables function boundary tracing for recognized patterns
    variables: true,          // Enables CAPABILITY for local variable capture
    expressions: true,        // Enables CAPABILITY for expression tracing
    temporal_correlation: true // Enables features for time-travel debugging
  ],
  cinema_debugger: [ /* ... */ ]
]
```

*   `enabled: true`: Activates ElixirScope's compiler task.
*   `instrumentation: [functions: true]`: This is the main driver for the default function boundary instrumentation described above (for OTP/Phoenix patterns primarily).
*   `instrumentation: [variables: true, expressions: true]`: These flags enable the *potential* for more granular instrumentation. However, they don't automatically instrument every variable or expression. They enable the `ElixirScope.AST.EnhancedTransformer` to act if it's given a specific plan that targets certain variables or expressions (see [Granular Instrumentation](#granular-instrumentation-enhanced-capabilities) and [Programmatic Instrumentation API](#programmatic-instrumentation-api-advanced)). The project-wide compilation in `cinema_demo` primarily relies on the `functions: true` behavior.

### Configuration in `config/*.exs` (Future)

The `config/config.exs` file for ElixirScope itself defines a structure for more fine-grained control:

```elixir
config :elixir_scope,
  instrumentation: [
    default_level: :function_boundaries,
    module_overrides: %{ /* Example: MyApp.ImportantModule => :full_trace */ },
    function_overrides: %{ /* Example: {MyApp.FastModule, :critical_function, 2} => :minimal */ },
    exclude_modules: [ElixirScope, :logger]
  ]
```

*   **Current Status:** The rule-based `ElixirScope.AI.CodeAnalyzer` does not yet seem to deeply leverage `module_overrides` or `function_overrides` from this application config to precisely tailor the compile-time plan for the entire project.
*   **Future Use:** This section is designed for a more advanced AI planner or for users to manually specify detailed instrumentation strategies for specific modules or functions, which would then feed into the plan generation.
*   `exclude_modules`: This is respected by the `Mix.Tasks.Compile.ElixirScope` to skip instrumentation for ElixirScope's own code and other specified modules.

## 4. Granular Instrumentation (Enhanced Capabilities)

For more detailed debugging beyond function boundaries, ElixirScope has an `ElixirScope.AST.EnhancedTransformer`. This is typically used when a specific, granular instrumentation plan is generated, often programmatically (see next section) or in the future, by a sophisticated AI planner.

These features are enabled by flags like `variables: true` and `expressions: true` in `mix.exs` but require a plan that specifies *where* to apply them.

### Local Variable Capture

*   **What:** Captures the values of specified local variables at certain points in your code.
*   **How:** Injects calls to `ElixirScope.Capture.InstrumentationRuntime.report_local_variable_snapshot/4` or `report_ast_variable_snapshot/4` (which includes an `ast_node_id` for precise mapping).
*   **Control:** A plan would specify which variables to capture and potentially at which line number (e.g., `after_line: 42`) or after which expressions.

### Expression Value Tracing

*   **What:** (Conceptually) Captures the resulting value of specific expressions or function calls.
*   **How:** (Current `EnhancedTransformer` uses `IO.puts` for this, but conceptually) It would inject calls to `ElixirScope.Capture.InstrumentationRuntime.report_expression_value/5` or `report_ast_expression_value/5`.
*   **Control:** A plan would list the expressions (often function call names) to trace.

### Custom Debugging Logic Injection

*   **What:** Allows injecting arbitrary Elixir code (as AST) into your functions at specific points.
*   **How:** The `EnhancedTransformer` can take a plan detailing the line number, position (`:before`, `:after`, `:replace`), and the quoted Elixir logic to inject.
*   **Use Cases:** Adding `IO.puts`, custom logging, or `ElixirScope.Debug.checkpoint/2` calls.

## 5. Programmatic Instrumentation API (Advanced)

For users needing very fine-grained control over compile-time instrumentation (e.g., for testing specific instrumentation scenarios or building custom tooling), ElixirScope provides modules that can be used programmatically.

### Steps for Programmatic Instrumentation

1.  **Generate a Plan:** Use `ElixirScope.CompileTime.Orchestrator.generate_plan(target, opts)`.
    *   `target`: The module (e.g., `MyModule`) or a specific function MFA (`{MyModule, :my_func, 1}`).
    *   `opts`: A map specifying the desired instrumentation, for example:
        ```elixir
        opts = %{
          functions: [:my_func_to_trace_boundaries], // Target specific functions for boundary tracing
          capture_locals: [:var1, :result],           // Variables to capture
          after_line: 25,                             // Line after which to capture locals
          trace_expressions: [:some_api_call],        // Expressions/function calls whose values to trace
          custom_injections: [                        // Inject custom code
            {10, :before, quote do: IO.puts("Starting complex part")},
            {30, :after, quote do: ElixirScope.Debug.checkpoint(:step_done, %{value: important_var})}
          ]
        }
        plan = ElixirScope.CompileTime.Orchestrator.generate_plan(MyModule, opts)
        ```

2.  **Get the AST:** Read your source file and parse it:
    ```elixir
    {:ok, source_code} = File.read("lib/my_module.ex")
    {:ok, original_ast} = Code.string_to_quoted(source_code)
    ```

3.  **Transform the AST:** Apply the generated plan using the appropriate transformer. For granular features, use `EnhancedTransformer`:
    ```elixir
    {:ok, plan} = ElixirScope.CompileTime.Orchestrator.generate_plan(MyModule, opts) // from step 1
    transformed_ast = ElixirScope.AST.EnhancedTransformer.transform_with_granular_instrumentation(original_ast, plan)
    ```
    For standard function boundary instrumentation based on a plan, you might use `ElixirScope.AST.Transformer` directly (though this is usually handled by the Mix task).

4.  **Use the Transformed AST:**
    *   Convert back to string: `instrumented_code_string = Macro.to_string(transformed_ast)`
    *   Compile it: `Code.compile_quoted(transformed_ast)`
    *   Or write it to a file for Mix to pick up.

### Conceptual Example

```elixir
# --- Assume you have MyModule with this function ---
# defmodule MyModule do
#   def calculate(x) do
#     intermediate = x * 2 # line 2
#     result = intermediate + 5 # line 3
#     result
#   end
# end

# --- Programmatic Instrumentation ---
opts = %{
  functions: [:calculate],
  capture_locals: [:intermediate, :result],
  custom_injections: [
    {2, :after, quote do: IO.puts("Intermediate calculated: #{intermediate}")}
  ]
}
{:ok, plan} = ElixirScope.CompileTime.Orchestrator.generate_plan(MyModule, opts)

source_code = """
defmodule MyModule do
  def calculate(x) do
    intermediate = x * 2 # line 2
    result = intermediate + 5 # line 3
    result
  end
end
"""
{:ok, original_ast} = Code.string_to_quoted(source_code)

transformed_ast = ElixirScope.AST.EnhancedTransformer.transform_with_granular_instrumentation(original_ast, plan)
IO.puts(Macro.to_string(transformed_ast))
```

This would produce code where `report_ast_variable_snapshot` is called to capture `intermediate` and `result`, and the `IO.puts` is injected.

## 6. What Injected Instrumentation Looks Like

Here are conceptual examples of how your code is transformed. The actual injected AST is more complex.

### Function Boundary Instrumentation

**Original:**
```elixir
defmodule MyService do
  def process(data) do
    # ... logic ...
    {:ok, processed_data}
  end
end
```

**Conceptually Instrumented (by `AST.Transformer`):**
```elixir
defmodule MyService do
  def process(data) do
    __elixir_scope_correlation_id__ = ElixirScope.Capture.InstrumentationRuntime.report_function_entry(MyService, :process, [data], __elixir_scope_parent_correlation_id__ )
    __elixir_scope_start_time__ = System.monotonic_time()
    try do
      # --- Original logic ---
      # ... logic ...
      __elixir_scope_original_result__ = {:ok, processed_data}
      # --- End Original logic ---

      ElixirScope.Capture.InstrumentationRuntime.report_function_exit(__elixir_scope_correlation_id__, __elixir_scope_original_result__, System.monotonic_time() - __elixir_scope_start_time__)
      __elixir_scope_original_result__
    catch
      __elixir_scope_kind__, __elixir_scope_reason__ ->
        ElixirScope.Capture.InstrumentationRuntime.report_function_exit(__elixir_scope_correlation_id__, __elixir_scope_reason__, System.monotonic_time() - __elixir_scope_start_time__, __elixir_scope_kind__)
        :erlang.raise(__elixir_scope_kind__, __elixir_scope_reason__, __STACKTRACE__)
    end
  end
end
```

### Local Variable Capture

**Original:**
```elixir
def my_calculation(input) do
  step1 = input * 10
  step2 = step1 + 5 // Line 3
  step2
end
```

**Conceptually Instrumented (by `AST.EnhancedTransformer` if plan targets `step1` after line 3):**
```elixir
def my_calculation(input) do
  # ... (entry instrumentation) ...
  try do
    step1 = input * 10
    step2 = step1 + 5 // Line 3
    ElixirScope.Capture.InstrumentationRuntime.report_ast_variable_snapshot(
      __elixir_scope_correlation_id__,
      %{step1: step1, step2: step2}, // Or just %{step1: step1} depending on plan
      3, // line_number
      "MyModule:my_calculation:3:assignment_step2" // ast_node_id
    )
    # ... (exit instrumentation for my_calculation) ...
    step2
  catch
    # ...
  end
end
```

## 7. Key Modules Involved

*   **`Mix.Tasks.Compile.ElixirScope`**: The custom Mix compiler task.
*   **`ElixirScope.AI.Orchestrator`**: (Intended for) Coordinating AI components for plan generation.
*   **`ElixirScope.AI.CodeAnalyzer`**: Analyzes code and generates instrumentation plans (currently rule-based).
*   **`ElixirScope.AI.PatternRecognizer`**: Identifies OTP, Phoenix, and other patterns.
*   **`ElixirScope.AI.ComplexityAnalyzer`**: Assesses code complexity.
*   **`ElixirScope.AST.Transformer`**: Core engine for AST transformation (function boundaries).
*   **`ElixirScope.AST.InjectorHelpers`**: Utilities for generating AST for instrumentation calls.
*   **`ElixirScope.AST.EnhancedTransformer`**: For granular instrumentation (locals, expressions, custom logic).
*   **`ElixirScope.CompileTime.Orchestrator`**: API for programmatically generating detailed instrumentation plans.
*   **`ElixirScope.Capture.InstrumentationRuntime`**: The module whose functions are called by instrumented code at runtime.
*   **`ElixirScope.Capture.Ingestor`**: Receives raw trace data from `InstrumentationRuntime` and puts it into ring buffers.
*   **`ElixirScope.ASTRepository.Parser`**: Assigns unique IDs to AST nodes for correlation.
*   **`ElixirScope.Capture.TemporalBridge` & `ElixirScope.Capture.TemporalStorage`**: Handle events with AST correlation for the "Cinema Debugger."

## 8. Important Considerations

*   **Build Output:** Instrumented files are placed in your project's `_build` directory. Your original source files are *not* modified.
*   **Performance:** Compile-time instrumentation adds calls to your code. While ElixirScope aims for minimal overhead (<1% in production with smart sampling, as per docs), full tracing can have a noticeable impact, especially in development.
*   **Debugging Instrumented Code:** When debugging, remember that the code running is the transformed version. Stack traces might include calls to `ElixirScope.Capture.InstrumentationRuntime`.
*   **Plan Generation:** The sophistication of *what* gets instrumented automatically depends heavily on the plan generation logic (currently rule-based, evolving towards AI-driven).

## 9. The Future: AI-Driven Instrumentation

While the current system uses rule-based analysis, the architecture is designed for more advanced AI-driven instrumentation planning. Future versions aim to use AI/LLMs to:

*   Intelligently identify critical code paths and hotspots.
*   Suggest optimal instrumentation points based on code semantics and risk.
*   Dynamically adjust instrumentation levels based on runtime feedback and performance targets.

This guide reflects the current state based on the provided code. As ElixirScope evolves, especially its AI capabilities, the methods for determining *what* to instrument and how to *manually control* it will become more sophisticated.
