defmodule ElixirScope.AI.LLM.Providers.VertexLiveTest do
  @moduledoc """
  Live API tests for the Vertex AI provider.
  
  These tests make actual API calls to Google Cloud's Vertex AI service.
  Run with: mix test.vertex
  
  Prerequisites:
  - VERTEX_JSON_FILE environment variable must be set to service account key path
  - Google Cloud project with Vertex AI enabled
  - Internet connection required
  """
  
  use ExUnit.Case, async: false
  
  alias ElixirScope.AI.LLM.Response
  alias ElixirScope.AI.LLM.Providers.Vertex
  
  @moduletag :live_api
  
  setup_all do
    unless Vertex.configured?() do
      IO.puts("\n⚠️  Skipping Vertex tests - VERTEX_JSON_FILE not configured")
      :skip
    else
      IO.puts("\n🚀 Running Vertex AI live API tests...")
      :ok
    end
  end
  
  describe "Vertex AI Provider - Live API Tests" do
    test "provider_name/0 returns :vertex" do
      assert Vertex.provider_name() == :vertex
    end
    
    test "configured?/0 returns true when service account is set" do
      assert Vertex.configured?() == true
    end
    
    test "test_connection/0 successfully connects to Vertex AI" do
      response = Vertex.test_connection()
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 0
      assert response.error == nil
      
      IO.puts("✅ Connection test: #{String.slice(response.text, 0, 100)}...")
    end
    
    test "analyze_code/2 analyzes Elixir code with Vertex AI" do
      code = """
      defmodule DataProcessor do
        def process(data) when is_list(data) do
          data
          |> Enum.filter(&is_integer/1)
          |> Enum.map(&(&1 * 2))
          |> Enum.sum()
        end
        
        def process(_), do: {:error, :invalid_input}
      end
      """
      
      context = %{
        file: "data_processor.ex",
        purpose: "data transformation pipeline",
        complexity: 3
      }
      
      response = Vertex.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 50
      assert response.error == nil
      
      # Should mention something about the code
      text_lower = String.downcase(response.text)
      assert text_lower =~ ~r/(function|module|process|data|pipeline|enum)/
      
      IO.puts("✅ Code analysis: #{String.slice(response.text, 0, 150)}...")
    end
    
    test "explain_error/2 explains Elixir runtime error" do
      error_message = """
      ** (FunctionClauseError) no function clause matching in DataProcessor.process/1
          
          The following arguments were given to DataProcessor.process/1:
          
              # 1
              "not a list"
          
          Attempted function clauses (showing 2 out of 2):
          
              def process(data) when is_list(data)
              def process(_)
          
          lib/data_processor.ex:2: DataProcessor.process/1
      """
      
      context = %{
        file: "data_processor.ex",
        line: 2,
        function: "process/1",
        error_type: "FunctionClauseError"
      }
      
      response = Vertex.explain_error(error_message, context)
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 30
      assert response.error == nil
      
      # Should mention something about function clause or pattern matching
      text_lower = String.downcase(response.text)
      assert text_lower =~ ~r/(function.*clause|pattern.*match|guard|when|clause)/
      
      IO.puts("✅ Error explanation: #{String.slice(response.text, 0, 150)}...")
    end
    
    test "suggest_fix/2 provides refactoring suggestions" do
      problem = """
      This GenServer has too many responsibilities and violates single responsibility principle:
      
      defmodule UserManager do
        use GenServer
        
        def start_link(_) do
          GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
        end
        
        def init(state) do
          {:ok, state}
        end
        
        def handle_call({:create_user, data}, _from, state) do
          # Validates user data
          # Saves to database
          # Sends welcome email
          # Updates analytics
          # Logs activity
          {:reply, :ok, state}
        end
        
        def handle_call({:delete_user, id}, _from, state) do
          # Validates permissions
          # Removes from database
          # Sends goodbye email
          # Updates analytics
          # Logs activity
          {:reply, :ok, state}
        end
      end
      """
      
      context = %{
        file: "user_manager.ex",
        pattern: "GenServer",
        issue: "single responsibility principle violation",
        complexity: 9
      }
      
      response = Vertex.suggest_fix(problem, context)
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert response.success == true
      assert is_binary(response.text)
      assert String.length(response.text) > 50
      assert response.error == nil
      
      # Should mention refactoring or separation of concerns
      text_lower = String.downcase(response.text)
      assert text_lower =~ ~r/(separate|extract|responsibility|module|refactor|concern)/
      
      IO.puts("✅ Fix suggestion: #{String.slice(response.text, 0, 150)}...")
    end
    
    test "handles OTP-specific code analysis" do
      code = """
      defmodule MyApp.Supervisor do
        use Supervisor
        
        def start_link(init_arg) do
          Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
        end
        
        @impl true
        def init(_init_arg) do
          children = [
            {MyApp.Worker, []},
            {MyApp.Cache, []},
            {MyApp.Server, []}
          ]
          
          Supervisor.init(children, strategy: :one_for_one)
        end
      end
      """
      
      context = %{
        file: "supervisor.ex",
        pattern: "OTP",
        framework: "supervisor"
      }
      
      response = Vertex.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
      
      # Should understand OTP concepts
      text_lower = String.downcase(response.text)
      assert text_lower =~ ~r/(supervisor|otp|children|strategy|worker|process)/
      
      IO.puts("✅ OTP analysis: #{String.slice(response.text, 0, 150)}...")
    end
    
    test "handles Phoenix-specific code" do
      code = """
      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller
        
        def index(conn, _params) do
          users = MyApp.Accounts.list_users()
          render(conn, "index.html", users: users)
        end
        
        def show(conn, %{"id" => id}) do
          user = MyApp.Accounts.get_user!(id)
          render(conn, "show.html", user: user)
        end
        
        def create(conn, %{"user" => user_params}) do
          case MyApp.Accounts.create_user(user_params) do
            {:ok, user} ->
              conn
              |> put_flash(:info, "User created successfully.")
              |> redirect(to: Routes.user_path(conn, :show, user))
            
            {:error, %Ecto.Changeset{} = changeset} ->
              render(conn, "new.html", changeset: changeset)
          end
        end
      end
      """
      
      context = %{
        file: "user_controller.ex",
        framework: "Phoenix",
        pattern: "MVC controller"
      }
      
      response = Vertex.analyze_code(code, context)
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
      
      # Should understand Phoenix/web concepts
      text_lower = String.downcase(response.text)
      assert text_lower =~ ~r/(controller|phoenix|web|route|render|conn|request)/
      
      IO.puts("✅ Phoenix analysis: #{String.slice(response.text, 0, 150)}...")
    end
    
    test "handles empty context gracefully" do
      code = "def simple_function, do: :ok"
      
      response = Vertex.analyze_code(code, %{})
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert response.success == true
      assert is_binary(response.text)
      assert response.error == nil
      
      IO.puts("✅ Empty context: #{String.slice(response.text, 0, 100)}...")
    end
    
    test "response includes proper metadata and timing" do
      response = Vertex.test_connection()
      
      assert %Response{} = response
      assert is_map(response.metadata)
      assert %DateTime{} = response.timestamp
      
      # Check that timestamp is recent (within last minute)
      now = DateTime.utc_now()
      diff = DateTime.diff(now, response.timestamp, :second)
      assert diff >= 0 and diff < 60
      
      # Vertex responses should include model information
      if response.success do
        assert is_map(response.metadata)
      end
      
      IO.puts("✅ Metadata check: timestamp=#{response.timestamp}")
    end
  end
  
  describe "Vertex AI Error Handling" do
    test "handles malformed Elixir syntax gracefully" do
      malformed_code = """
      defmodule BrokenSyntax do
        def function_with_syntax_error do
          case some_value
            :ok -> "missing do keyword"
            :error -> "this won't compile"
        end
      end
      """
      
      response = Vertex.analyze_code(malformed_code, %{})
      
      assert %Response{} = response
      assert response.provider == :vertex
      # Should either succeed with analysis or fail gracefully
      assert is_boolean(response.success)
      
      if response.success do
        assert is_binary(response.text)
        assert response.error == nil
      else
        assert is_binary(response.error)
      end
      
      IO.puts("✅ Malformed syntax handling: success=#{response.success}")
    end
    
    test "handles very large code blocks" do
      # Create a large but valid Elixir module
      functions = Enum.map_join(1..100, "\n\n", fn i -> 
        "  def function_#{i}(param) do\n" <>
        "    # Function #{i} implementation\n" <>
        "    case param do\n" <>
        "      :option_a -> {:ok, \"Result A for function #{i}\"}\n" <>
        "      :option_b -> {:ok, \"Result B for function #{i}\"}\n" <>
        "      _ -> {:error, \"Invalid option for function #{i}\"}\n" <>
        "    end\n" <>
        "  end"
      end)
      
      large_code = """
      defmodule LargeModule do
        @moduledoc "A module with many functions to test large input handling"
        
      #{functions}
      end
      """
      
      response = Vertex.analyze_code(large_code, %{})
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert is_boolean(response.success)
      
      IO.puts("✅ Large input handling: success=#{response.success}, length=#{String.length(large_code)}")
    end
    
    test "handles international characters and emojis" do
      unicode_code = """
      defmodule InternationalModule do
        @moduledoc "模块文档 - Documentación del módulo - Документация модуля"
        
        def greet_multilingual(name) do
          messages = [
            "Hello " <> name <> "! 👋",
            "¡Hola " <> name <> "! 🇪🇸",
            "你好 " <> name <> "! 🇨🇳",
            "Привет " <> name <> "! 🇷🇺",
            "こんにちは " <> name <> "! 🇯🇵",
            "مرحبا " <> name <> "! 🇸🇦"
          ]
          
          Enum.random(messages)
        end
        
        def emoji_status do
          %{
            success: "✅ 成功",
            warning: "⚠️ 警告", 
            error: "❌ エラー",
            info: "ℹ️ معلومات"
          }
        end
      end
      """
      
      response = Vertex.analyze_code(unicode_code, %{})
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert is_boolean(response.success)
      
      IO.puts("✅ Unicode handling: success=#{response.success}")
    end
    
    test "handles complex nested data structures" do
      complex_code = """
      defmodule ComplexDataProcessor do
        def process_nested_data(data) do
          data
          |> Map.get(:users, [])
          |> Enum.map(fn user ->
            %{
              id: user.id,
              profile: %{
                name: user.profile.name,
                settings: %{
                  notifications: %{
                    email: user.profile.settings.notifications.email,
                    push: user.profile.settings.notifications.push,
                    sms: Map.get(user.profile.settings.notifications, :sms, false)
                  },
                  privacy: %{
                    public_profile: user.profile.settings.privacy.public_profile,
                    show_email: Map.get(user.profile.settings.privacy, :show_email, false)
                  }
                }
              },
              metadata: %{
                created_at: user.metadata.created_at,
                updated_at: user.metadata.updated_at,
                tags: user.metadata.tags || [],
                custom_fields: Map.get(user.metadata, :custom_fields, %{})
              }
            }
          end)
        end
      end
      """
      
      response = Vertex.analyze_code(complex_code, %{})
      
      assert %Response{} = response
      assert response.provider == :vertex
      assert is_boolean(response.success)
      
      IO.puts("✅ Complex data handling: success=#{response.success}")
    end
  end
  
  describe "Vertex AI Performance" do
    test "response time is reasonable for simple requests" do
      start_time = System.monotonic_time(:millisecond)
      
      response = Vertex.analyze_code("def simple, do: :ok", %{})
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      assert %Response{} = response
      assert response.provider == :vertex
      
      # Vertex AI should respond within reasonable time (allow up to 15 seconds for API calls)
      assert duration < 15_000
      
      IO.puts("✅ Performance test: #{duration}ms")
    end
  end
end 