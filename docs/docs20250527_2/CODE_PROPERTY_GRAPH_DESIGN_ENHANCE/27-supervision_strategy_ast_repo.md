# ElixirScope AST Repository: Supervision Strategy

This document outlines the proposed supervision strategy for the components of the ElixirScope AST Repository within the main ElixirScope application. Proper supervision is critical for the stability and reliability of these background processes.

## 1. Core AST Repository Components to Supervise

The primary long-running processes introduced by the AST Repository are:

1.  **`ElixirScope.ASTRepository.Repository` (GenServer):**
    *   Manages ETS tables for all static analysis data.
    *   Crucial stateful component. Must be highly available.
    *   Restarting it means losing in-memory data unless persistence/recovery is implemented (currently ETS based, so data is lost on BEAM restart unless DETS or other persistence is used).

2.  **`ElixirScope.ASTRepository.FileWatcher` (GenServer):**
    *   Monitors the file system for changes.
    *   Relies on an underlying file system watching library/process (e.g., `FileSystem` or `:fs`).
    *   If it crashes, real-time updates to the repository will cease until restarted.

3.  **`ElixirScope.ASTRepository.Synchronizer` (Potentially a pool of workers or a GenServer):**
    *   While individual sync operations might be transient (e.g., triggered by `FileWatcher`), if it manages a queue of changes or has its own state, it might need supervision.
    *   For simplicity, we can assume `FileWatcher` directly calls `Synchronizer` functions, making `Synchronizer` itself stateless. If `Synchronizer` becomes a GenServer managing a queue, it needs supervision. *Let's assume stateless for now, invoked by FileWatcher or ProjectPopulator.*

4.  **`ElixirScope.ASTRepository.ProjectPopulator` (Task/Process during startup/request):**
    *   Typically run as a one-off task (e.g., `Task.Supervisor.async_nolink`) during application startup (if configured) or on demand.
    *   It doesn't usually need to be a continuously supervised GenServer unless it's designed to manage ongoing background population efforts.

## 2. Proposed Supervision Tree Integration

We propose integrating these components into the main ElixirScope application supervisor, likely under a dedicated supervisor for the AST Repository subsystem.

```elixir
# In ElixirScope.Application (lib/elixir_scope/application.ex)

def start(_type, _args) do
  children = [
    # ... other ElixirScope core services (e.g., EventStore, QueryEngine, TemporalBridge) ...

    # Supervisor for AST Repository Subsystem
    {Supervisor, strategy: :one_for_one, name: ElixirScope.ASTRepository.Supervisor},
  ]

  # ...
end

# Create: lib/elixir_scope/ast_repository/supervisor.ex
defmodule ElixirScope.ASTRepository.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # Fetch configurations using ASTRepository.Config
    repo_name = ElixirScope.ASTRepository.Config.repository_genserver_name()
    repo_opts = [name: repo_name] # Add other opts like memory_limit from config

    watcher_name = ElixirScope.ASTRepository.Config.watcher_genserver_name()
    watcher_opts = [
      name: watcher_name,
      project_path: Application.get_env(:elixir_scope, :project_root_path, File.cwd!()), # Needs project_path config
      callback: {ElixirScope.ASTRepository.Synchronizer, :sync_changes_batch, [[repo_pid: repo_name]]}, # Pass repo_name to Synchronizer
      # other watcher configs from ASTRepository.Config
      debounce_ms: ElixirScope.ASTRepository.Config.watcher_debounce_ms(),
      ignore_patterns: ElixirScope.ASTRepository.Config.watcher_ignore_patterns(),
      file_patterns: ElixirScope.ASTRepository.Config.watcher_file_patterns()
    ]

    children = [
      # 1. ASTRepository.Repository - Critical, stateful
      {ElixirScope.ASTRepository.Repository, repo_opts},

      # 2. FileWatcher - Monitors file system
      #    Starts after Repository so Synchronizer can use a live repo_pid.
      #    Alternatively, FileWatcher could resolve the repo_pid lazily or be passed it.
      {ElixirScope.ASTRepository.FileWatcher, watcher_opts},

      # 3. (Optional) ProjectPopulator Task Supervisor if initial population is always backgrounded
      # Supervisor.child_spec({Task.Supervisor, name: ElixirScope.ASTRepository.PopulatorTasks}, id: :populator_tasks)
    ]

    # Define supervision strategy for these children.
    # :one_for_one is common if children are largely independent.
    # :rest_for_one if Repository crashing means FileWatcher is pointless.
    # Let's start with :one_for_one.
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 5, max_seconds: 60)
  end
end
```

## 3. Startup Sequence and Dependencies

1.  **`ElixirScope.ASTRepository.Config`:** Should be available as application environment is loaded.
2.  **`ElixirScope.ASTRepository.Repository`:** Starts first under `ASTRepository.Supervisor`. Initializes its ETS tables.
3.  **`ElixirScope.ASTRepository.FileWatcher`:** Starts after the `Repository`. Its callback will target the (now started) `Repository` (e.g., via its registered name).
4.  **Initial Project Population (`ProjectPopulator`):**
    *   **Option A (Synchronous Startup):** The `ElixirScope.Application.start/2` or `ASTRepository.Supervisor.init/1` could block and run `ProjectPopulator.populate_project/2` if the repository is detected as empty and configuration dictates an initial population on boot. This can significantly increase application startup time.
    *   **Option B (Asynchronous Startup Task):** After `Repository` is started, `ASTRepository.Supervisor` (or `Application`) can spawn an unlinked, supervised task to run `ProjectPopulator.populate_project/2` in the background.
        ```elixir
        # In ASTRepository.Supervisor.init/1, after children list:
        # if ElixirScope.ASTRepository.Config.populate_on_startup?() do
        #   Task.Supervisor.start_child(ElixirScope.ASTRepository.PopulatorTasks, fn ->
        #     project_path = Application.get_env(:elixir_scope, :project_root_path, File.cwd!())
        #     pop_opts = [...] # from config
        #     ElixirScope.ASTRepository.ProjectPopulator.populate_project(project_path, pop_opts)
        #   end)
        # end
        ```
    *   **Option C (On-Demand / Mix Task):** No automatic population on application start. Population is triggered manually via a Mix task (e.g., `mix elixir_scope.ast.populate`) or an API call. This is often preferable for developer tools.

**Recommended Approach for Population:** Option C (On-Demand via Mix Task) is generally best for a developer tool, with Option B as a configurable alternative for applications that want the AST repo "warm" on startup.

## 4. Restart Strategies and State

*   **`ASTRepository.Repository`:**
    *   **Strategy:** `:one_for_one`.
    *   **Restart Intensity:** If this crashes frequently, it's a major issue. `max_restarts` and `max_seconds` should be configured to avoid rapid crash loops.
    *   **State:** ETS tables are in-memory. A crash and restart of this GenServer (if it's just the process, not the BEAM) *could* preserve ETS tables if they are `named_table` and the table owner wasn't the crashing process itself (ETS tables are owned by the process that creates them. If the supervisor owns/creates them or they are `:heir` based, this is more complex).
        *   If `ASTRepository.Repository` itself creates its named ETS tables in `init/1`, then a restart of this process will mean the tables are re-initialized (emptied).
        *   **Consideration for Robustness:** For production-like use, the `Repository` might need to manage table ownership carefully or use a separate, more stable process for table creation/ownership, or implement disk-backed persistence (e.g., DETS, Mnesia, or external DB). The current design with `:named_table` created in `init/1` implies data loss on process restart.

*   **`FileWatcher`:**
    *   **Strategy:** `:one_for_one`.
    *   **Restart Intensity:** Can be restarted if its underlying FS library process crashes.
    *   **State:** Its primary state is its subscriptions and pending debounced changes. A restart would lose pending debounced changes, but it would re-subscribe and pick up new events. This is generally acceptable.

## 5. Configuration Dependencies

*   The `ASTRepository.Supervisor` needs access to configuration to correctly start its children. This can be done by reading from `Application.get_env` or by passing configuration through `init_arg`.
*   A crucial piece of configuration needed at startup is the `project_root_path` to tell `FileWatcher` and `ProjectPopulator` what to operate on. This should be a top-level ElixirScope application configuration.

    ```elixir
    # config/config.exs
    config :elixir_scope,
      project_root_path: File.cwd!(), # Or specify an explicit path
      # ... other elixir_scope configs ...
      ast_repository: [
        # ... specific ast_repository configs from ASTRepository.Config ...
        populate_on_startup: false # Default to false
      ]
    ```

## 6. Health Checks and Monitoring

*   The `ASTRepository.Repository` could expose a health check function (e.g., `Repository.health_check/1`) that verifies ETS table presence and basic responsiveness.
*   The `FileWatcher` status function (`FileWatcher.status/1`) can be used for monitoring.
*   Telemetry events should be emitted by these components for operational insights (e.g., files processed, queue lengths, ETS table sizes).

## 7. Shutdown Sequence

*   When `ElixirScope.Application` stops, the `ASTRepository.Supervisor` will terminate its children.
*   `FileWatcher` should ideally stop its underlying file system subscription cleanly in its `terminate/2`.
*   `ASTRepository.Repository` `terminate/2` could perform cleanup if needed (e.g., flushing any buffered writes if it had them, though current design is synchronous for writes).

This supervision strategy provides a robust way to manage the lifecycle of the AST Repository components, ensuring they are started in the correct order and restarted according to defined policies if they encounter issues.
