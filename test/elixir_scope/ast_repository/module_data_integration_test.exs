defmodule ElixirScope.ASTRepository.ModuleDataIntegrationTest do
  use ExUnit.Case
  
  alias ElixirScope.ASTRepository.ModuleData
  
  describe "AST pattern detection with real AST" do
    test "detects GenServer modules correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule TestGenServer do
          use GenServer
          
          def init(_), do: {:ok, %{}}
          def handle_call(:get, _from, state), do: {:reply, state, state}
          def handle_cast(:reset, _state), do: {:noreply, %{}}
        end
      """)
      
      module_data = ModuleData.new(TestGenServer, ast)
      
      # Should detect as GenServer module type
      assert module_data.module_type == :genserver
      
      # Should extract callbacks
      assert length(module_data.callbacks) == 3
      callback_names = Enum.map(module_data.callbacks, & &1.name)
      assert :init in callback_names
      assert :handle_call in callback_names
      assert :handle_cast in callback_names
    end
    
    test "detects Phoenix Controller modules correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule TestController do
          use MyApp.Web, :controller
          
          def index(conn, _params), do: render(conn, "index.html")
          def show(conn, %{"id" => id}), do: render(conn, "show.html", id: id)
        end
      """)
      
      module_data = ModuleData.new(TestController, ast)
      
      # Should detect as Phoenix controller
      assert module_data.module_type == :phoenix_controller
    end
    
    test "detects Phoenix LiveView modules correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule TestLiveView do
          use Phoenix.LiveView
          
          def mount(_params, _session, socket), do: {:ok, socket}
          def handle_event("click", _params, socket), do: {:noreply, socket}
          def render(assigns), do: ~H"<div>Hello</div>"
        end
      """)
      
      module_data = ModuleData.new(TestLiveView, ast)
      
      # Should detect as LiveView
      assert module_data.module_type == :phoenix_live_view
      
      # Should extract LiveView callbacks
      assert length(module_data.callbacks) == 3
      callback_names = Enum.map(module_data.callbacks, & &1.name)
      assert :mount in callback_names
      assert :handle_event in callback_names
      assert :render in callback_names
    end
    
    test "detects Ecto Schema modules correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule TestSchema do
          use Ecto.Schema
          
          schema "users" do
            field :name, :string
            field :email, :string
            timestamps()
          end
        end
      """)
      
      module_data = ModuleData.new(TestSchema, ast)
      
      # Should detect as Ecto schema
      assert module_data.module_type == :ecto_schema
    end
    
    test "detects regular modules correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule TestModule do
          def hello, do: :world
          def goodbye, do: :farewell
        end
      """)
      
      module_data = ModuleData.new(TestModule, ast)
      
      # Should detect as regular module
      assert module_data.module_type == :module
    end
  end
  
  describe "AST attribute extraction with real AST" do
    test "extracts module attributes correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule TestModule do
          @moduledoc "Test module for attribute extraction"
          @behaviour GenServer
          @custom_attr "custom value"
          @version "1.0.0"
          
          def test, do: :ok
        end
      """)
      
      module_data = ModuleData.new(TestModule, ast)
      
      # Should extract attributes
      assert length(module_data.attributes) >= 4
      
      attribute_names = Enum.map(module_data.attributes, & &1.name)
      assert :moduledoc in attribute_names
      assert :behaviour in attribute_names
      assert :custom_attr in attribute_names
      assert :version in attribute_names
      
      # Check attribute types
      moduledoc_attr = Enum.find(module_data.attributes, &(&1.name == :moduledoc))
      assert moduledoc_attr.type == :documentation
      
      behaviour_attr = Enum.find(module_data.attributes, &(&1.name == :behaviour))
      assert behaviour_attr.type == :behaviour
      
      custom_attr = Enum.find(module_data.attributes, &(&1.name == :custom_attr))
      assert custom_attr.type == :custom
    end
  end
  
  describe "AST use directive detection with real AST" do
    test "detects use directives correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule TestModule do
          use GenServer
          use Agent
          
          def init(_), do: {:ok, %{}}
        end
      """)
      
      module_data = ModuleData.new(TestModule, ast)
      
      # Should detect GenServer (first use directive wins in detect_module_type)
      assert module_data.module_type == :genserver
    end
  end
  
  describe "error handling with invalid AST" do
    test "handles malformed AST gracefully" do
      invalid_ast = {:invalid, :ast, :structure}
      
      # Should not crash, but return a module with minimal data
      module_data = ModuleData.new(InvalidModule, invalid_ast)
      
      assert module_data.module_name == InvalidModule
      assert module_data.module_type == :module  # Default fallback
      assert module_data.callbacks == []
      assert module_data.attributes == []
    end
    
    test "handles empty module AST" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule EmptyModule do
        end
      """)
      
      module_data = ModuleData.new(EmptyModule, ast)
      
      assert module_data.module_name == EmptyModule
      assert module_data.module_type == :module
      assert module_data.callbacks == []
      assert module_data.attributes == []
    end
  end
  
  describe "architectural pattern detection" do
    test "detects factory pattern correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule UserFactory do
          def create(attrs), do: %User{name: attrs.name}
          def build(attrs), do: %User{name: attrs.name}
        end
      """)
      
      module_data = ModuleData.new(UserFactory, ast)
      
      # Should detect factory pattern
      assert :factory in module_data.patterns
    end
    
    test "detects singleton pattern correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule ConfigSingleton do
          def instance, do: GenServer.call(__MODULE__, :get)
          def get_instance, do: instance()
        end
      """)
      
      module_data = ModuleData.new(ConfigSingleton, ast)
      
      # Should detect singleton pattern
      assert :singleton in module_data.patterns
    end
    
    test "detects observer pattern correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule EventNotifier do
          def subscribe(pid), do: :ok
          def notify(event), do: :ok
          def unsubscribe(pid), do: :ok
        end
      """)
      
      module_data = ModuleData.new(EventNotifier, ast)
      
      # Should detect observer pattern
      assert :observer in module_data.patterns
    end
    
    test "detects state machine pattern correctly" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule OrderStateMachine do
          def transition(from, to), do: :ok
          def current_state(order), do: order.state
          def next_state(order), do: :shipped
        end
      """)
      
      module_data = ModuleData.new(OrderStateMachine, ast)
      
      # Should detect state machine pattern
      assert :state_machine in module_data.patterns
    end
  end
  
  describe "complex module analysis" do
    test "analyzes complex GenServer with multiple callbacks and attributes" do
      {:ok, ast} = Code.string_to_quoted("""
        defmodule ComplexGenServer do
          @moduledoc "A complex GenServer for testing"
          @behaviour GenServer
          @timeout 5000
          
          use GenServer
          
          def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
          
          def init(state), do: {:ok, state}
          def handle_call(:get, _from, state), do: {:reply, state, state}
          def handle_cast({:set, value}, _state), do: {:noreply, value}
          def handle_info(:timeout, state), do: {:noreply, state}
          def terminate(reason, _state), do: :ok
          def code_change(_old_vsn, state, _extra), do: {:ok, state}
          
          defp private_helper, do: :ok
        end
      """)
      
      module_data = ModuleData.new(ComplexGenServer, ast)
      
      # Module type detection
      assert module_data.module_type == :genserver
      
      # Callback extraction
      assert length(module_data.callbacks) == 6
      callback_names = Enum.map(module_data.callbacks, & &1.name)
      assert :init in callback_names
      assert :handle_call in callback_names
      assert :handle_cast in callback_names
      assert :handle_info in callback_names
      assert :terminate in callback_names
      assert :code_change in callback_names
      
      # Attribute extraction
      assert length(module_data.attributes) >= 3
      attribute_names = Enum.map(module_data.attributes, & &1.name)
      assert :moduledoc in attribute_names
      assert :behaviour in attribute_names
      assert :timeout in attribute_names
      
      # Verify callback types
      init_callback = Enum.find(module_data.callbacks, &(&1.name == :init))
      assert init_callback.type == :genserver
      assert init_callback.arity == 1
    end
  end
end 