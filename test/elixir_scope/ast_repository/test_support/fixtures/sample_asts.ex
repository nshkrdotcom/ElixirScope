defmodule ElixirScope.ASTRepository.TestSupport.Fixtures.SampleASTs do
  @moduledoc """
  Curated AST samples for testing AST parser enhancement and correlation functionality.
  """

  @doc """
  Simple GenServer module with callbacks for testing instrumentation point extraction.
  """
  def simple_genserver_ast do
    quote do
      defmodule TestGenServer do
        use GenServer

        def start_link(opts \\ []) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(opts) do
          {:ok, %{counter: 0, opts: opts}}
        end

        def handle_call(:get_counter, _from, state) do
          {:reply, state.counter, state}
        end

        def handle_call({:increment, amount}, _from, state) do
          new_counter = state.counter + amount
          {:reply, new_counter, %{state | counter: new_counter}}
        end

        def handle_cast({:set_counter, value}, state) do
          {:noreply, %{state | counter: value}}
        end

        def handle_info(:reset, state) do
          {:noreply, %{state | counter: 0}}
        end
      end
    end
  end

  @doc """
  Phoenix Controller with multiple actions for testing instrumentation.
  """
  def phoenix_controller_ast do
    quote do
      defmodule TestController do
        use Phoenix.Controller

        def index(conn, _params) do
          users = get_all_users()
          render(conn, "index.html", users: users)
        end

        def show(conn, %{"id" => id}) do
          case get_user(id) do
            {:ok, user} -> render(conn, "show.html", user: user)
            {:error, :not_found} -> send_resp(conn, 404, "Not found")
          end
        end

        def create(conn, %{"user" => user_params}) do
          case create_user(user_params) do
            {:ok, user} -> 
              conn
              |> put_flash(:info, "User created successfully")
              |> redirect(to: "/users/#{user.id}")
            {:error, changeset} ->
              render(conn, "new.html", changeset: changeset)
          end
        end

        defp get_all_users, do: []
        defp get_user(_id), do: {:error, :not_found}
        defp create_user(_params), do: {:error, %{}}
      end
    end
  end

  @doc """
  Complex module with nested functions and pattern matching for testing.
  """
  def complex_module_ast do
    quote do
      defmodule ComplexModule do
        @moduledoc "Complex module for testing AST parsing"

        @default_timeout 5000

        def process_data(data) when is_list(data) do
          data
          |> validate_data()
          |> transform_data()
          |> save_results()
        end

        def process_data(data) when is_map(data) do
          data
          |> Map.to_list()
          |> process_data()
        end

        def process_data(_invalid_data) do
          {:error, :invalid_input}
        end

        defp validate_data(data) do
          case Enum.all?(data, &valid_item?/1) do
            true -> {:ok, data}
            false -> {:error, :validation_failed}
          end
        end

        defp transform_data({:ok, data}) do
          transformed = Enum.map(data, &transform_item/1)
          {:ok, transformed}
        end

        defp transform_data({:error, reason}), do: {:error, reason}

        defp save_results({:ok, data}) do
          case save_to_database(data) do
            :ok -> {:ok, length(data)}
            # Note: save_to_database always returns :ok in this test fixture
          end
        end

        defp save_results({:error, reason}), do: {:error, reason}

        defp valid_item?(%{id: id, name: name}) when is_integer(id) and is_binary(name) do
          String.length(name) > 0
        end

        defp valid_item?(_), do: false

        defp transform_item(%{id: id, name: name}) do
          %{id: id, name: String.upcase(name), processed_at: DateTime.utc_now()}
        end

        defp save_to_database(_data) do
          Process.sleep(@default_timeout)
          :ok
        end
      end
    end
  end

  @doc """
  Module with various function types for comprehensive instrumentation testing.
  """
  def mixed_function_types_ast do
    quote do
      defmodule MixedFunctionTypes do
        # Public functions
        def public_function(arg) do
          private_function(arg)
        end

        def public_with_guard(arg) when is_binary(arg) do
          String.length(arg)
        end

        def public_with_pattern_match({:ok, value}) do
          {:success, value}
        end

        def public_with_pattern_match({:error, reason}) do
          {:failure, reason}
        end

        # Private functions
        defp private_function(arg) do
          helper_function(arg)
        end

        defp helper_function(arg) do
          {:processed, arg}
        end

        # Function with multiple clauses
        def multi_clause_function([]), do: :empty
        def multi_clause_function([head | tail]) do
          [process_head(head) | multi_clause_function(tail)]
        end

        defp process_head(item) when is_atom(item), do: Atom.to_string(item)
        defp process_head(item) when is_binary(item), do: String.upcase(item)
        defp process_head(item), do: inspect(item)

        # Function with try-catch
        def risky_function(input) do
          try do
            dangerous_operation(input)
          catch
            :error, reason -> {:error, reason}
          rescue
            e in RuntimeError -> {:error, e.message}
          end
        end

        defp dangerous_operation(input) when input < 0 do
          raise "Negative input not allowed"
        end

        defp dangerous_operation(input) do
          {:ok, input * 2}
        end
      end
    end
  end

  @doc """
  Returns expected instrumentation points for the simple GenServer.
  """
  def simple_genserver_expected_points do
    [
      %{
        type: :function_entry,
        function: {:start_link, 1},
        line: 5
      },
      %{
        type: :function_entry,
        function: {:init, 1},
        line: 9
      },
      %{
        type: :function_entry,
        function: {:handle_call, 3},
        line: 13
      },
      %{
        type: :function_entry,
        function: {:handle_call, 3},
        line: 17
      },
      %{
        type: :function_entry,
        function: {:handle_cast, 2},
        line: 22
      },
      %{
        type: :function_entry,
        function: {:handle_info, 2},
        line: 26
      }
    ]
  end

  @doc """
  Returns expected instrumentation points for the Phoenix controller.
  """
  def phoenix_controller_expected_points do
    [
      %{
        type: :function_entry,
        function: {:index, 2},
        line: 5
      },
      %{
        type: :function_entry,
        function: {:show, 2},
        line: 10
      },
      %{
        type: :function_entry,
        function: {:create, 2},
        line: 17
      }
    ]
  end

  @doc """
  Returns a list of all sample ASTs with their metadata.
  """
  def all_sample_asts do
    [
      %{
        name: :simple_genserver,
        ast: simple_genserver_ast(),
        expected_points: simple_genserver_expected_points(),
        module_type: :genserver
      },
      %{
        name: :phoenix_controller,
        ast: phoenix_controller_ast(),
        expected_points: phoenix_controller_expected_points(),
        module_type: :phoenix_controller
      },
      %{
        name: :complex_module,
        ast: complex_module_ast(),
        expected_points: [],
        module_type: :unknown
      },
      %{
        name: :mixed_function_types,
        ast: mixed_function_types_ast(),
        expected_points: [],
        module_type: :unknown
      }
    ]
  end

  @doc """
  Returns a sample AST by name.
  """
  def get_sample_ast(name) do
    all_sample_asts()
    |> Enum.find(&(&1.name == name))
  end
end 