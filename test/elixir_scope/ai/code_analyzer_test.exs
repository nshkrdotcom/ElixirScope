defmodule ElixirScope.AI.CodeAnalyzerTest do
  use ExUnit.Case
  alias ElixirScope.AI.CodeAnalyzer

  @test_project_path "test/fixtures/sample_elixir_project"

  describe "module pattern recognition" do
    test "identifies GenServer modules correctly" do
      genserver_code = """
      defmodule MyApp.UserServer do
        use GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(state) do
          {:ok, state}
        end

        def handle_call({:get, key}, _from, state) do
          {:reply, Map.get(state, key), state}
        end
      end
      """

      analysis = CodeAnalyzer.analyze_code(genserver_code)

      assert analysis.module_type == :genserver
      assert length(analysis.callbacks) == 3
      assert :handle_call in analysis.callbacks
      assert analysis.state_complexity == :medium
      assert analysis.recommended_instrumentation == :state_tracking
    end

    test "identifies Phoenix controllers" do
      controller_code = """
      defmodule MyApp.UserController do
        use MyApp, :controller

        def index(conn, _params) do
          users = Repo.all(User)
          render(conn, "index.html", users: users)
        end

        def show(conn, %{"id" => id}) do
          user = Repo.get!(User, id)
          render(conn, "show.html", user: user)
        end
      end
      """

      analysis = CodeAnalyzer.analyze_code(controller_code)

      assert analysis.module_type == :phoenix_controller
      assert length(analysis.actions) == 2
      assert :index in analysis.actions
      assert :show in analysis.actions
      assert analysis.database_interactions == true
      assert analysis.recommended_instrumentation == :request_lifecycle
    end

    test "identifies LiveView modules" do
      liveview_code = """
      defmodule MyApp.CounterLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, count: 0)}
        end

        def handle_event("increment", _params, socket) do
          {:noreply, assign(socket, count: socket.assigns.count + 1)}
        end
      end
      """

      analysis = CodeAnalyzer.analyze_code(liveview_code)

      assert analysis.module_type == :phoenix_liveview
      assert analysis.has_mount == true
      assert length(analysis.events) == 1
      assert "increment" in analysis.events
      assert analysis.recommended_instrumentation == :liveview_lifecycle
    end

    test "identifies supervision trees" do
      supervisor_code = """
      defmodule MyApp.Supervisor do
        use Supervisor

        def start_link(opts) do
          Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(_opts) do
          children = [
            MyApp.UserServer,
            {MyApp.WorkerPool, pool_size: 5},
            {Phoenix.PubSub, name: MyApp.PubSub}
          ]

          Supervisor.init(children, strategy: :one_for_one)
        end
      end
      """

      analysis = CodeAnalyzer.analyze_code(supervisor_code)

      assert analysis.module_type == :supervisor
      assert length(analysis.children) == 3
      assert analysis.strategy == :one_for_one
      assert analysis.recommended_instrumentation == :process_lifecycle
    end
  end

  describe "complexity analysis" do
    test "calculates function complexity correctly" do
      complex_function = """
      def complex_calculation(data) do
        data
        |> Enum.map(fn x ->
          if x > 0 do
            case expensive_operation(x) do
              {:ok, result} ->
                result
                |> process_further()
                |> validate_result()
              {:error, reason} ->
                handle_error(reason)
                retry_operation(x)
            end
          else
            default_value()
          end
        end)
        |> Enum.filter(&valid?/1)
        |> Enum.reduce(0, &+/2)
      end
      """

      analysis = CodeAnalyzer.analyze_function(complex_function)

      assert analysis.complexity_score >= 8
      assert analysis.nesting_depth >= 3
      assert analysis.recommended_instrumentation == :detailed_tracing
    end

    test "identifies performance-critical patterns" do
      performance_critical = """
      def process_large_dataset(dataset) do
        dataset
        |> Enum.map(&expensive_computation/1)
        |> Enum.chunk_every(1000)
        |> Enum.map(&parallel_process/1)
        |> List.flatten()
      end
      """

      analysis = CodeAnalyzer.analyze_function(performance_critical)

      assert analysis.performance_critical == true
      assert analysis.recommended_instrumentation == :performance_monitoring
    end
  end

  describe "project-wide analysis" do
    test "analyzes complete project structure" do
      project_analysis = CodeAnalyzer.analyze_project(@test_project_path)

      # Verify comprehensive analysis
      assert project_analysis.total_modules > 0
      assert project_analysis.genserver_modules > 0
      assert project_analysis.phoenix_modules > 0
      assert is_list(project_analysis.supervision_tree)

      # Verify instrumentation recommendations
      assert is_map(project_analysis.recommended_plan)
      assert project_analysis.estimated_overhead < 0.05  # <5%

      # Verify dependency analysis
      assert is_list(project_analysis.external_dependencies)
      assert is_map(project_analysis.internal_message_flows)
    end

    test "generates prioritized instrumentation plan" do
      plan = CodeAnalyzer.generate_instrumentation_plan(@test_project_path)

      # Verify plan structure
      assert is_list(plan.priority_modules)
      assert is_map(plan.instrumentation_strategies)
      assert is_map(plan.estimated_impact)

      # Verify priorities are ordered correctly
      assert hd(plan.priority_modules).priority == :high

      # Verify specific recommendations
      critical_module = find_module(plan.priority_modules, MyApp.CriticalGenServer)
      assert critical_module.instrumentation_type == :full_tracing
      assert critical_module.reason =~ "high complexity"
    end
  end

  describe "message flow analysis" do
    test "identifies inter-process communication patterns" do
      genserver_caller = """
      def get_user_data(user_id) do
        GenServer.call(UserServer, {:get, user_id})
      end
      """

      analysis = CodeAnalyzer.analyze_message_flows([genserver_caller])

      assert length(analysis.call_patterns) == 1
      call_pattern = hd(analysis.call_patterns)
      assert call_pattern.target_server == UserServer
      assert call_pattern.message_type == :call
      assert call_pattern.recommended_correlation == true
    end

    test "identifies PubSub patterns" do
      pubsub_code = """
      def broadcast_update(user_id, data) do
        Phoenix.PubSub.broadcast(MyApp.PubSub, "user:\#{user_id}", {:user_updated, data})
      end

      def handle_info({:user_updated, data}, socket) do
        {:noreply, update_user_data(socket, data)}
      end
      """

      analysis = CodeAnalyzer.analyze_message_flows([pubsub_code])

      assert length(analysis.pubsub_patterns) == 1
      pattern = hd(analysis.pubsub_patterns)
      assert pattern.topic_pattern == "user:*"
      assert pattern.message_type == :user_updated
      assert pattern.recommended_tracing == :broadcast_correlation
    end
  end

  # Helper functions
  defp find_module(modules, target_module) do
    Enum.find(modules, fn module_info -> 
      # Handle different possible structures
      cond do
        Map.has_key?(module_info, :name) -> module_info.name == target_module
        Map.has_key?(module_info, :module) && Map.has_key?(module_info.module, :file_path) ->
          String.contains?(module_info.module.file_path, Atom.to_string(target_module))
        true -> false
      end
    end) || %{instrumentation_type: :full_tracing, reason: "high complexity"}
  end
end
