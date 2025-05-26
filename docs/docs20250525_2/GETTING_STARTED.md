# Getting Started with ElixirScope

Welcome to ElixirScope! This guide will walk you through installing, configuring, and understanding how to use ElixirScope to gain deep insights into your Elixir applications. ElixirScope aims to provide "Execution Cinema" – a comprehensive, AI-guided view of your application's runtime behavior, enabling powerful time-travel debugging.

## Prerequisites

Before you begin, ensure you have the following installed:

*   Elixir 1.15+
*   Erlang/OTP 25+
*   Mix (Elixir's build tool)

## 1. Installation

Integrating ElixirScope into your project involves two key steps: adding it as a dependency and registering its custom compiler.

### Step 1.1: Add ElixirScope as a Dependency

Open your project's `mix.exs` file and add `elixir_scope` to your list of dependencies:

```elixir
def deps do
  [
    {:elixir_scope, "~> 0.1.0"}
    # ... other dependencies
  ]
end
```

### Step 1.2: Register the ElixirScope Compiler

This is a **critical step** for enabling ElixirScope's automatic instrumentation. ElixirScope works by transforming your code's Abstract Syntax Tree (AST) at compile time. To do this, its custom compiler task must run *before* the standard Elixir compiler.

Modify the `project/0` function in your `mix.exs` to include `:elixir_scope` in the `:compilers` list, placing it **before** `Mix.compilers()` or specifically before `:elixir`:

```elixir
def project do
  [
    app: :my_app,
    version: "0.1.0",
    elixir: "~> 1.15",
    elixirc_paths: elixirc_paths(Mix.env()),
    # Add ElixirScope compiler BEFORE the default Elixir compiler
    compilers: [:elixir_scope | Mix.compilers()],
    start_permanent: Mix.env() == :prod,
    deps: deps()
  ]
end
```

**Why is the order important?**
ElixirScope's compiler (`Mix.Tasks.Compile.ElixirScope`) needs to analyze your original source code and inject instrumentation calls. If the standard `:elixir` compiler runs first, ElixirScope won't have a chance to perform its transformations.

### Step 1.3: Fetch Dependencies and Compile

After updating `mix.exs`, run the following commands in your project's root directory:

```bash
mix deps.get
mix compile
```

Running `mix compile` for the first time will:
1.  Download and compile ElixirScope and its dependencies.
2.  Allow ElixirScope's custom compiler to perform an initial analysis of your project (if configured to do so on first compile, or when instrumentation is enabled).

## 2. How ElixirScope Works: The Magic of Compile-Time Instrumentation

Understanding this core mechanism is key to effectively using ElixirScope. Unlike typical libraries that only provide runtime functions, ElixirScope actively modifies your code during the compilation process to enable its deep tracing capabilities.

Here's a simplified flow of what happens when you `mix compile` with ElixirScope:

1.  **ElixirScope Compiler Runs First:** Due to the `compilers: [:elixir_scope | Mix.compilers()]` setting in your `mix.exs`, ElixirScope's custom compiler task (`Mix.Tasks.Compile.ElixirScope`) is invoked by Mix before the standard Elixir compiler.
2.  **AI-Driven Analysis & Planning (Layer 4):**
    *   The ElixirScope compiler task ensures the `ElixirScope.Application` is running, which includes the `ElixirScope.AI.Orchestrator`.
    *   The `AI.Orchestrator` leverages other AI components (`CodeAnalyzer`, `PatternRecognizer`, `ComplexityAnalyzer`) to:
        *   Parse your project's source files into Abstract Syntax Trees (ASTs).
        *   Analyze these ASTs to understand code structure, identify OTP patterns (GenServers, Supervisors), Phoenix components (Controllers, LiveViews), Ecto usage, and assess code complexity.
    *   Based on this analysis and your ElixirScope configuration (see "Configuration" section below), the `Orchestrator` generates an **instrumentation plan**. This plan details precisely which modules, functions, and callbacks should be instrumented and what data to capture (e.g., arguments, return values, state changes).
3.  **AST Transformation (Layer 3):**
    *   The `ElixirScope.AST.Transformer` takes the original AST of your code and the instrumentation plan.
    *   It traverses the AST and, where specified by the plan, uses `ElixirScope.AST.InjectorHelpers` to "weave in" new AST nodes. These injected nodes are calls to `ElixirScope.Capture.InstrumentationRuntime` functions.
    *   For example, a function body might be wrapped in a `try/catch/after` block to report entry, normal exit, or exceptions.
4.  **Instrumented Code Generation:**
    *   The `AST.Transformer` produces a *modified AST* containing the original logic plus the injected instrumentation calls.
    *   The ElixirScope compiler task converts this modified AST back into Elixir source code strings.
    *   **Crucially, these instrumented source files are written to a temporary location within your project's `_build` directory.** Your original source files in `lib/`, `test/`, etc., remain **unmodified**.
5.  **Standard Elixir Compilation:**
    *   The standard `:elixir` compiler runs next. It takes the instrumented Elixir source files from the `_build` directory (generated by ElixirScope) as its input.
    *   It compiles these instrumented files into the final `.beam` bytecode files. These `.beam` files now contain the ElixirScope tracing calls.
6.  **Runtime Event Capture (Layer 2):**
    *   When you run your application, the BEAM loads these instrumented `.beam` files.
    *   As your code executes, the injected calls to `ElixirScope.Capture.InstrumentationRuntime` are triggered.
    *   These runtime functions are highly optimized for performance. They manage per-process tracing context (like correlation IDs and call stacks) and forward event data to the `ElixirScope.Capture.Ingestor`.
    *   The `Ingestor` writes events to an ultra-fast, lock-free `ElixirScope.Capture.RingBuffer`.
7.  **Asynchronous Processing & Storage (Layers 2 & part of 6):**
    *   `AsyncWriter` workers (managed by `AsyncWriterPool` and `PipelineManager`) read event batches from the `RingBuffer`.
    *   These events are passed to the `ElixirScope.Capture.EventCorrelator`, which establishes causal links and relationships between them.
    *   The correlated events are then stored in `ElixirScope.Storage.DataAccess` (an ETS-based hot storage).
8.  **Analysis & Visualization (Future Layers 6 & 7):**
    *   The "Execution Cinema" UI will query this rich, correlated data to provide time-travel debugging and multi-dimensional analysis.

This compile-time weaving allows ElixirScope to achieve "Total Behavioral Recall" intelligently and automatically, without requiring you to manually litter your codebase with tracing calls.

## 3. Basic Usage

### Starting ElixirScope

To begin capturing data, you need to start ElixirScope, typically in your `application.ex` or when your application boots up:

```elixir
# In your application.ex's start/2 function, or an IEx session:
{:ok, _pid} = ElixirScope.start()
```

You can pass options to `start/1` to influence its behavior, often by overriding parts of the configuration:

```elixir
# Start with a specific instrumentation strategy for more detail
ElixirScope.start(strategy: :full_trace)

# Start with a specific sampling rate
ElixirScope.start(sampling_rate: 0.5) # Capture 50% of eligible events
```

### Stopping ElixirScope

To stop ElixirScope and its data capture:

```elixir
ElixirScope.stop()
```

### Checking Status

To see if ElixirScope is running and get basic statistics:

```elixir
status = ElixirScope.status()
IO.inspect(status)
```

## 4. Configuration

ElixirScope is highly configurable via your project's `config/config.exs` file (or environment-specific config files like `config/dev.exs`).

```elixir
# Example: In config/dev.exs
import Config

config :elixir_scope,
  ai: [
    planning: [
      # :minimal, :balanced, :full_trace
      default_strategy: :balanced,
      # Target performance overhead (e.g., 0.01 = 1%)
      performance_target: 0.01,
      # Global event sampling rate (0.0 to 1.0)
      sampling_rate: 1.0
    ]
  ],
  capture: [
    ring_buffer: [
      size: 1_048_576,         # Number of slots in the ring buffer
      max_events: 100_000,    # Soft limit, triggers pruning if exceeded via other mechanisms
      overflow_strategy: :drop_oldest # or :drop_newest, :block
    ],
    processing: [
      batch_size: 1000,       # Events processed by AsyncWriter in one go
      flush_interval: 100    # Milliseconds for AsyncWriter polling
    ]
  ],
  instrumentation: [
    default_level: :function_boundaries,
    # Override AI plan for specific modules
    module_overrides: %{
      # MyApp.CriticalModule => %{instrumentation_level: :full_trace, sampling_rate: 1.0}
    },
    # Exclude modules entirely from instrumentation
    exclude_modules: [
      MyAppDataLoader,
      SomeThirdParty.NoisyLogger
    ]
  ]

# Remember to recompile after changing configurations that affect instrumentation
# $ mix compile
```

Key configuration areas:

*   **`ai.planning`**: Controls the AI's strategy for deciding what to instrument.
    *   `default_strategy`: `:minimal` (low overhead, essential tracing), `:balanced` (good detail vs. overhead), `:full_trace` (maximum detail, higher overhead).
    *   `sampling_rate`: A global rate (0.0 to 1.0) to sample eligible events.
*   **`capture.ring_buffer`**: Settings for the high-performance event buffer.
*   **`instrumentation`**: Allows manual overrides for specific modules or functions, and lists modules to exclude from any instrumentation.

**Important:** Changes to configuration options that affect the *instrumentation plan* (like `default_strategy`, `exclude_modules`, or sampling rates that influence planning) generally require a **recompile (`mix compile`)** for ElixirScope to regenerate the plan and re-transform your code.

## 5. Developer Workflow for Debugging

Here’s a typical workflow when using ElixirScope to debug an issue:

1.  **Configure for Detailed Tracing:**
    *   For development or debugging specific issues, you might want maximum detail. Update your `config/dev.exs` (or similar):
        ```elixir
        config :elixir_scope, ai: [planning: [default_strategy: :full_trace, sampling_rate: 1.0]]
        ```
    *   Alternatively, use `ElixirScope.start(strategy: :full_trace, sampling_rate: 1.0)` if starting manually.

2.  **Compile Your Project:**
    *   After any configuration change that affects instrumentation, or if you've changed code you want to trace, **you must recompile**:
        ```bash
        mix compile
        ```
    *   This ensures ElixirScope's custom compiler re-analyzes your code and applies the new instrumentation plan, generating updated instrumented `.beam` files.

3.  **Run Your Application:**
    *   Start your application as you normally would for testing or development:
        ```bash
        iex -S mix
        # or
        mix test
        # or
        mix phx.server
        ```
    *   Ensure `ElixirScope.start()` is called if it's not part of your application's automatic startup.

4.  **Trigger the Behavior:**
    *   Interact with your application to reproduce the bug or exercise the code paths you want to observe.
    *   ElixirScope's instrumented code will now be capturing a rich stream of events (function calls, state changes, messages, etc.) and storing them.

5.  **Analyze Captured Data (Future "Execution Cinema" UI):**
    *   *(The UI is part of the future roadmap)* Once the UI is available, you would open it to:
        *   View the timeline of captured events.
        *   "Time-travel" by selecting an event and inspecting the application state at that point.
        *   Follow causal chains (e.g., see which function call led to a specific message being sent).
        *   Filter and search events.
    *   **Current State (Manual Querying):** As per the `README.md`, you can currently query events programmatically for basic analysis:
        ```elixir
        # In an IEx session after ElixirScope has captured events:
        events = ElixirScope.Storage.DataAccess.query_events(%{
          module: MyApp.MyProblemModule,
          limit: 100
        })
        IO.inspect(events)
        ```
        Note: `ElixirScope.get_events/1` is the planned public API for this, currently a placeholder.

6.  **Revert Configuration (If Necessary):**
    *   Once you've finished your detailed debugging session, you might want to revert ElixirScope's configuration to a less verbose strategy (e.g., `:balanced` or `:minimal`) for general development or testing to reduce overhead.
        ```elixir
        config :elixir_scope, ai: [planning: [default_strategy: :balanced, sampling_rate: 0.8]]
        ```
    *   **Recompile again** (`mix compile`) after changing the configuration.

## 6. Understanding the Output (What to Expect)

ElixirScope captures a variety of events, including:

*   Function entries and exits (with arguments and return values, if configured).
*   State changes in GenServers.
*   Messages sent and received between processes.
*   Phoenix request lifecycles, controller actions, LiveView events.
*   Ecto queries.
*   Exceptions and errors.

These events are correlated by the `EventCorrelator` to build a causal graph of your application's execution. The future UI will be the primary way to explore this rich, interconnected data.

## 7. Advanced Topics (Brief Overview)

*   **Manual Event Ingestion:** For very specific tracing needs or integrating with non-Elixir parts, you can manually ingest events using `ElixirScope.Capture.Ingestor` functions (see `README.md`). This bypasses the automatic AST instrumentation.
*   **Distributed Tracing:** ElixirScope has foundational support for coordinating tracing across multiple BEAM nodes, providing a unified view of distributed systems.
*   **Customizing AI Planning:** Advanced users might delve into `ElixirScope.Config` to fine-tune `module_overrides` or `function_overrides` in the `instrumentation` section to precisely control the AI's planning decisions.

## 8. Troubleshooting Common Issues

*   **"ElixirScope doesn't seem to be capturing any events."**
    *   **Compiler Order:** Double-check that `:elixir_scope` is listed *before* `Mix.compilers()` in your `mix.exs` `project/0` function.
    *   **ElixirScope Started?**: Ensure `ElixirScope.start()` has been called in your running application.
    *   **Configuration:**
        *   Verify your `config :elixir_scope` settings. Is the `ai.planning.default_strategy` set to something other than `:minimal` if you expect more detail?
        *   Is `ai.planning.sampling_rate` very low or zero?
        *   Are the modules/functions you expect to be traced listed in `instrumentation.exclude_modules`?
    *   **Recompile:** Did you run `mix compile` *after* making changes to your ElixirScope configuration or the code you want to trace? This is essential.
    *   **Logs:** Check your application logs for any error messages from ElixirScope during startup or compilation.

*   **"Compilation is significantly slower."**
    *   ElixirScope's analysis and AST transformation do add some overhead to compilation.
    *   If it's too slow for rapid development cycles, consider:
        *   Setting `default_strategy: :minimal` in `config/dev.exs`.
        *   Using `exclude_modules` more aggressively for parts of your application you aren't actively debugging.
        *   Ensure ElixirScope's plan caching is effective (it should be, by default).

*   **"Runtime performance is impacted."**
    *   While ElixirScope aims for minimal overhead, `:full_trace` will naturally be more impactful than `:minimal`.
    *   Adjust `default_strategy` and `sampling_rate` in your configuration for the appropriate environment (e.g., less detail for production, more for focused debugging).
    *   Check the `performance_target` in the AI planning configuration.

## Next Steps & Further Reading

*   **`README.md`**: For the project vision, high-level architecture, and latest status.
*   **`docs/` directory (Technical Architecture documents)**: For deep dives into specific components like the RingBuffer, AST Transformer, Event Correlator, etc.
*   **API Documentation** (`mix hex.docs` or online): For detailed information on public modules and functions.

Happy "Execution Cinema" debugging with ElixirScope!
