Okay, let's map out a detailed and robust Instrumentation Plan Schema. This schema will be the contract between your AI/Orchestrator (Producer) and the `Mix.Tasks.Compile.ElixirScope` / `AST.Transformer` (Consumer).

The goal is to create a schema that is:
*   **Expressive:** Can describe a wide range of instrumentation needs.
*   **Clear:** Easy for the AST transformer to interpret and act upon.
*   **Structured:** Logically organized for easy generation and consumption.
*   **Versioned:** Allows for future evolution without breaking existing consumers immediately.
*   **Extensible:** Can accommodate new types of instrumentation later.

We'll define this schema as if it were represented by Elixir structs and types for clarity. In practice, it would likely be serialized as JSON or another data interchange format when passed between processes or stored.

---

**Instrumentation Plan Schema (Version 1.0)**

```elixir
@typedoc """
The top-level structure for an instrumentation plan.
"""
@type instrumentation_plan_v1 :: %{
  schema_version: String.t(),            # E.g., "1.0"
  plan_id: String.t(),                   # Unique ID for this plan instance
  generated_at: DateTime.t(),            # Timestamp of plan generation
  metadata: map(),                       # Free-form metadata (e.g., AI model version, reason for plan)

  global_settings: global_settings_v1(), # Default settings applicable project-wide

  # Module-specific instrumentation plans, keyed by Module.name() (e.g., MyApp.MyModule)
  module_plans: %{optional(module()) => module_plan_v1()}
}

@typedoc """
Global default settings for instrumentation.
These can be overridden at module or function levels.
"""
@type global_settings_v1 :: %{
  default_instrumentation_level: :none | :boundaries | :detailed | :custom,
  # :none - No automatic instrumentation
  # :boundaries - Function entry/exit only
  # :detailed - Entry/exit, args, return values, execution time
  # :custom - Only apply specific probes defined in the plan

  default_capture_settings: capture_settings_v1(),

  # List of module name patterns (String or Regex) to always exclude.
  # Example: ["MyApp.Internals.*", ~r/.*Test$/]
  exclude_modules: [String.t() | Regex.t()],

  # If non-empty, only modules matching these patterns will be considered.
  # Overrides exclude_modules if a module matches both.
  include_modules: [String.t() | Regex.t()],

  # Maximum depth for capturing nested data structures (args, return values, locals).
  # nil means no limit (use with caution).
  max_data_capture_depth: non_neg_integer() | nil,

  # Maximum string length for captured string values. nil means no limit.
  max_string_capture_length: non_neg_integer() | nil,

  # Maximum number of elements for captured lists/maps. nil means no limit.
  max_collection_capture_size: non_neg_integer() | nil
}

@typedoc """
Settings defining what data to capture for instrumented functions/probes.
"""
@type capture_settings_v1 :: %{
  # Capture function arguments?
  # :brief - Capture type/arity or a very short summary
  # :full - Capture the full value (subject to global depth/size limits)
  args: :none | :brief | :full,

  # Capture function return value?
  return_value: :none | :brief | :full,

  # Capture execution time of functions/blocks?
  execution_time: boolean(),

  # Capture self() PID?
  pid: boolean(),

  # Capture timestamp for the event?
  timestamp: boolean(),

  # Capture a unique correlation ID for this specific call/probe instance?
  correlation_id: boolean(),

  # For GenServer callbacks, capture state before/after?
  genserver_state_before: :none | :brief | :full,
  genserver_state_after: :none | :brief | :full,

  # For Phoenix controller actions, capture conn assigns?
  phoenix_conn_assigns: :none | :brief | :full,
  phoenix_params: :none | :brief | :full,
  phoenix_response_body: :none | :brief | :full
}

@typedoc """
Instrumentation plan for a specific module.
"""
@type module_plan_v1 :: %{
  module_name: module(),
  enabled: boolean(), # True to instrument this module, false to skip (overrides global include/exclude for this specific module)
  instrumentation_level: :inherit | :none | :boundaries | :detailed | :custom, # Overrides global
  capture_settings: :inherit | capture_settings_v1(), # Overrides global

  # Function-specific plans, keyed by {function_name_atom, arity_integer}
  # Example: {{:my_func, 2} => function_plan_v1}
  function_plans: %{optional({atom(), non_neg_integer()}) => function_plan_v1()},

  # Probes to be applied at the module level (e.g., around attributes, before first def).
  # This is more advanced and might be limited initially.
  module_level_probes: [probe_v1()]
}

@typedoc """
Instrumentation plan for a specific function.
"""
@type function_plan_v1 :: %{
  function_signature: {module(), atom(), non_neg_integer()}, # {Module, :function, arity}
  enabled: boolean(),
  instrumentation_level: :inherit | :none | :boundaries | :detailed | :custom, # Overrides module/global
  capture_settings: :inherit | capture_settings_v1(), # Overrides module/global

  # Specific probes to apply within this function.
  # If instrumentation_level is :boundaries or :detailed, entry/exit probes are added automatically
  # unless explicitly disabled or overridden here.
  probes: [probe_v1()],

  # Hints about the function type for more specialized instrumentation by the transformer.
  # This helps the AST.Transformer apply framework-specific logic if available.
  function_type_hint: :generic | :genserver_callback | :phoenix_action | :phoenix_liveview_callback | :ecto_query_dsl | atom()
}

@typedoc """
Defines a specific instrumentation point (a "probe").
"""
@type probe_v1 :: %{
  probe_id: String.t(), # Unique ID for this probe, for traceability
  type: :function_entry | :function_exit | :line_execution |
        :local_variable_capture | :expression_value_capture | :custom_code_injection,

  # Location for the probe. The AST.Transformer will interpret this.
  location: probe_location_v1(),

  # Settings specific to this probe, overriding function/module/global settings.
  capture_settings: :inherit | capture_settings_v1(),

  # Payload specific to the probe type.
  payload: map(),
  # Examples for payload:
  # - type: :local_variable_capture, payload: %{variables: [:var1, :var2], capture_at: :scope_exit | {:line, integer()}}
  # - type: :expression_value_capture, payload: %{expression_string: "a + b", original_ast_node_id: term()} (node_id from AST prewalk metadata)
  # - type: :custom_code_injection, payload: %{code_ast: term()} (a quoted Elixir AST to inject)

  # Optional: A quoted Elixir AST representing a condition.
  # The probe is only active if this condition evaluates to true at runtime at the probe site.
  # Example: quote(do: some_var > 10 and AnotherModule.is_feature_enabled?(:advanced_tracing))
  condition_ast: term() | nil,

  metadata: map() # AI notes, reasons for this specific probe
}

@typedoc """
Specifies the location for a probe within the code.
The AST.Transformer needs to be ableto interpret these location types.
"""
@type probe_location_v1 ::
  # For function_entry/exit, location is implicit.
  :implicit_function_boundary |

  # Execute before/after a specific line number.
  %{type: :line, line_number: non_neg_integer(), position: :before | :after} |

  # Target specific local variables.
  %{type: :local_variables, variables: [atom()], on: :assignment | :scope_exit | :every_mention} |

  # Target a specific expression. Identifying expressions robustly can be complex.
  # Using a unique ID assigned during a pre-analysis AST walk is a robust way.
  %{type: :expression_by_id, ast_node_id: term(), wrap_mode: :capture_result | :before_eval | :after_eval} |
  # Simpler alternative for expressions, less robust:
  %{type: :expression_at_line, line_number: non_neg_integer(), expression_string_hint: String.t()} |

  # Before/after calls to specific functions.
  %{type: :around_call, target_mfa: {module(), atom(), arity()}, position: :before | :after} |

  # For custom code, can be more flexible.
  %{type: :custom_block_insertion, target_block_id: term(), position_in_block: :start | :end | non_neg_integer()}
```

---

**Explanation and Rationale:**

1.  **`instrumentation_plan_v1` (Top Level):**
    *   `schema_version`: Essential for evolving the plan format.
    *   `plan_id`, `generated_at`, `metadata`: For tracking and debugging the plan itself.
    *   `global_settings`: Provides sensible defaults, reducing verbosity for common cases.
    *   `module_plans`: The core of the plan, allowing targeted instrumentation. Using `module()` as key (e.g., `MyApp.MyModule`) is idiomatic.

2.  **`global_settings_v1`:**
    *   `default_instrumentation_level`: A high-level directive. `:custom` means the AI has very specific instructions and default boundary/detailed instrumentation should not be automatically applied unless probes for them exist.
    *   `default_capture_settings`: Fine-grained control over what data is captured by default.
    *   `exclude_modules`, `include_modules`: Powerful filtering. `include_modules` acts as a whitelist if present.
    *   `max_data_capture_depth`, `max_string_capture_length`, `max_collection_capture_size`: Crucial for preventing excessive data capture that could serialize large terms and impact performance or data volume.

3.  **`capture_settings_v1`:**
    *   Provides granular control over what aspects of an event are captured. `:brief` vs `:full` allows the AI to make trade-offs (e.g., for args, `:brief` might just be `length(args)` or types, while `:full` captures actual values).
    *   Includes framework-specific hints like `genserver_state_before/after` and Phoenix-specifics. The AST transformer would use these in conjunction with `function_type_hint`.

4.  **`module_plan_v1`:**
    *   `enabled`: Allows turning instrumentation on/off for an entire module.
    *   `instrumentation_level`, `capture_settings`: Module-specific overrides. `:inherit` means use parent (global) setting.
    *   `function_plans`: Drills down to individual functions.
    *   `module_level_probes`: For advanced use cases, like instrumenting module attribute declarations or code executed at module load time (less common for debugging typical application logic).

5.  **`function_plan_v1`:**
    *   `function_signature`: Uniquely identifies the target function.
    *   `probes`: The list of specific instrumentation actions to take *within* this function. If `instrumentation_level` is `:boundaries` or `:detailed`, the AST transformer can automatically add entry/exit probes based on the function's `capture_settings` unless specific `:function_entry` / `:function_exit` probes in this list override that behavior.
    *   `function_type_hint`: This is a critical hint for the AST Transformer. If it's `:genserver_callback`, the transformer might look for state variables or common GenServer return patterns. If `:phoenix_action`, it knows `conn` and `params` are likely available.

6.  **`probe_v1` (The Core Unit of Instrumentation):**
    *   `probe_id`: For tracing back to AI's reasoning or for uniquely identifying a probe's output.
    *   `type`: The fundamental action (log entry, capture variable, etc.).
    *   `location`: How the AST Transformer finds *where* to inject. This is one of the hardest parts to make robust.
        *   `:implicit_function_boundary`: Easy for entry/exit.
        *   `:line`: Simple, but can be brittle if code changes. Requires `position: :before | :after`.
        *   `:local_variables`: Specifies which variables, and `on:` clarifies when (e.g., after any assignment to them, or just before scope exits).
        *   `:expression_by_id`: The most robust way to target an expression is if a pre-analysis pass (perhaps by the AI or a preparatory step) walks the AST and assigns unique IDs to interesting expression nodes. The plan then refers to these IDs.
        *   `:expression_at_line`: A simpler but less robust alternative. `expression_string_hint` helps disambiguate if multiple expressions are on one line.
        *   `:around_call`: Useful for instrumenting before/after specific function calls *within* the current function's body.
        *   `:custom_block_insertion`: For injecting code at the start/end of known blocks (e.g., `do...end` of an `if` or `case`). Requires block identification.
    *   `capture_settings`: Probe-specific overrides for data capture.
    *   `payload`: Contains the data needed for the specific probe type.
        *   For `:local_variable_capture`: `%{variables: [:a, :b]}`. The AST transformer needs to ensure these variables are in scope at the probe location and construct the map for `InstrumentationRuntime.report_local_variable_snapshot/4`.
        *   For `:expression_value_capture`: The AI could provide `%{expression_string: "a + b"}` for logging, and if using `ast_node_id`, the transformer wraps that node to capture its result.
        *   For `:custom_code_injection`: `%{code_ast: quote(do: IO.inspect(my_var, label: "Debug"))}`. The transformer splices this AST.
    *   `condition_ast`: Powerful feature for conditional instrumentation. The transformer wraps the probe injection in an `if unquote(condition_ast) do ... end`.
    *   `metadata`: Allows the AI to "explain itself" for each probe.

**How the `MixTask` and `AST.Transformer` Would Use This Plan:**

1.  **`MixTask`:**
    *   Loads the `instrumentation_plan_v1`.
    *   Iterates through files in `elixirc_paths`.
    *   For each file:
        *   Parses to AST.
        *   Determines the module name(s) defined in the file.
        *   Looks up the `module_plan_v1` for that module. If no plan, or `enabled: false`, or matches `exclude_modules` (and not `include_modules`), it might skip or apply minimal global defaults.
        *   Passes the module AST and the relevant `module_plan_v1` (and `global_settings`) to `AST.Transformer.transform_module/3`.
        *   Writes the transformed AST back to a file in the `_build` directory.

2.  **`AST.Transformer` (`transform_module/3`):**
    *   Receives module AST, `module_plan_v1`, and inherited `global_settings`.
    *   Walks the module AST.
    *   When it encounters `def`, `defp`, etc.:
        *   Extracts function name and arity.
        *   Looks up the `function_plan_v1` from `module_plan.function_plans`.
        *   Merges/resolves `capture_settings` (probe -> function -> module -> global).
        *   If `instrumentation_level` is `:boundaries` or `:detailed`, it *automatically* prepares to inject entry/exit logging using the resolved `capture_settings`, unless specific `:function_entry`/`:function_exit` probes exist to override this.
        *   Calls a hypothetical `AST.Transformer.transform_function_body/4` with the function body AST, resolved settings, `function_plan.probes`, and `function_type_hint`.

3.  **`AST.Transformer` (`transform_function_body/4` - Simplified):**
    *   Iterates through `probes` in `function_plan.probes`.
    *   For each `probe_v1`:
        *   Uses `probe.location` to find the AST node(s) to modify. This is complex and requires careful AST traversal and pattern matching.
            *   Example: For `{type: :line, line_number: 42, position: :before}`, it finds the statement starting on line 42 and injects before it.
            *   Example: For `{type: :local_variables, variables: [:foo], on: :assignment}`, it finds all `foo = ...` and injects capture code after.
        *   Constructs the AST for the instrumentation call (e.g., `quote(do: ElixirScope.Capture.InstrumentationRuntime.report_local_variable_snapshot(...))`) using data from `probe.payload` and resolved `capture_settings`.
        *   If `probe.condition_ast` exists, wraps the injection in an `if`.
        *   Modifies the function body AST to include the new instrumentation AST.
    *   Handles automatic entry/exit instrumentation based on `instrumentation_level` and `capture_settings` if not overridden by specific probes.

**Key Considerations for Robustness:**

*   **AST Node Identification:** The `ast_node_id` in `probe_location_v1` for expression targeting is the most robust way. This implies the AI's `CodeAnalyzer` performs an initial pass, annotates the AST with unique IDs (perhaps using `Macro.prewalk_with_level` and storing IDs in metadata), and then the plan refers to these stable IDs. Line numbers are simpler but more brittle.
*   **Scope and Variable Availability:** The `AST.Transformer` must be careful when injecting code that captures local variables, ensuring they are in scope. This usually means injecting at the end of the current block or immediately after assignments.
*   **Preserving Semantics:** Injections must not alter the original code's behavior (e.g., return values, exception propagation). Wrapping expressions or injecting logging often involves creating temporary variables and ensuring the original result is returned.
*   **Macro Handling:** This plan instruments code *as written*. Macros are expanded by the Elixir compiler *after* this custom compilation step. If instrumentation of macro-generated code is needed, a different approach (Elixir macros that hook into `before_compile` or `after_compile`) would be required, or the AI would need to be aware of common macros and plan instrumentation for their expected expansion.
*   **Error Reporting:** The `MixTask` and `AST.Transformer` should provide detailed error messages if they cannot apply a part of the plan (e.g., "Cannot find line X for probe Y," "Variable Z not in scope for probe W").
*   **Plan Validation:** The `Orchestrator` or `MixTask` could include a step to validate the generated plan against this schema before attempting transformation.

This schema provides a solid foundation. As you implement, you might discover needs for additional location specifiers, probe types, or settings, which can be incorporated into future schema versions.
