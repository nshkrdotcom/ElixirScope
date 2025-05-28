defmodule ElixirAnalyzerDemo.SampleDataManager do
  @moduledoc """
  Manages sample data sets for demonstrating Enhanced AST Repository features.
  
  Provides various sample projects with different complexity levels:
  - Simple: Basic Elixir patterns (10 modules)
  - Medium: GenServer patterns, supervision trees (50 modules)
  - Complex: Phoenix application, complex business logic (200+ modules)
  - Legacy: Technical debt examples, code smells (100 modules)
  """
  
  use GenServer
  
  alias ElixirScope.ASTRepository.EnhancedRepository
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def load_project(project_type \\ :medium) do
    GenServer.call(__MODULE__, {:load_project, project_type})
  end
  
  def get_available_projects do
    GenServer.call(__MODULE__, :get_available_projects)
  end
  
  def clear_all_data do
    GenServer.call(__MODULE__, :clear_all_data)
  end
  
  def init(_opts) do
    {:ok, %{
      loaded_projects: [],
      project_stats: %{}
    }}
  end
  
  def handle_call({:load_project, project_type}, _from, state) do
    case load_project_data(project_type) do
      {:ok, modules_count} ->
        new_loaded = [project_type | state.loaded_projects]
        new_stats = Map.put(state.project_stats, project_type, %{
          modules_count: modules_count,
          loaded_at: DateTime.utc_now()
        })
        
        new_state = %{state | 
          loaded_projects: new_loaded,
          project_stats: new_stats
        }
        
        {:reply, {:ok, modules_count}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call(:get_available_projects, _from, state) do
    projects = %{
      simple: %{
        description: "Basic Elixir patterns",
        modules: 10,
        complexity: "Low",
        features: ["Basic functions", "Pattern matching", "Guards"]
      },
      medium: %{
        description: "GenServer patterns, supervision trees",
        modules: 50,
        complexity: "Medium",
        features: ["GenServers", "Supervision trees", "Database interactions"]
      },
      complex: %{
        description: "Phoenix application, complex business logic",
        modules: 200,
        complexity: "High",
        features: ["Phoenix controllers", "Complex business logic", "Multiple dependencies"]
      },
      legacy: %{
        description: "Technical debt examples, code smells",
        modules: 100,
        complexity: "High",
        features: ["Code smells", "Technical debt", "Refactoring opportunities"]
      }
    }
    
    {:reply, projects, state}
  end
  
  def handle_call(:clear_all_data, _from, state) do
    # Clear all loaded modules from repository
    # Since list_modules doesn't exist, we'll use clear_repository instead
    EnhancedRepository.clear_repository()
    
    new_state = %{state | 
      loaded_projects: [],
      project_stats: %{}
    }
    
    {:reply, :ok, new_state}
  end
  
  # Private functions
  
  defp load_project_data(:simple) do
    modules = generate_simple_project()
    store_modules_batch(modules)
  end
  
  defp load_project_data(:medium) do
    modules = generate_medium_project()
    store_modules_batch(modules)
  end
  
  defp load_project_data(:complex) do
    modules = generate_complex_project()
    store_modules_batch(modules)
  end
  
  defp load_project_data(:legacy) do
    modules = generate_legacy_project()
    store_modules_batch(modules)
  end
  
  defp load_project_data(_) do
    {:error, :unknown_project_type}
  end
  
  defp store_modules_batch(modules) do
    try do
      # Store modules individually since batch function doesn't exist in EnhancedRepository
      results = Enum.map(modules, fn {module_name, ast} ->
        case EnhancedRepository.store_enhanced_module(module_name, ast) do
          {:ok, _enhanced_data} -> :ok
          :ok -> :ok
          error -> error
        end
      end)
      
      # Check if all succeeded
      case Enum.find(results, fn result -> result != :ok end) do
        nil -> {:ok, length(modules)}
        error -> error
      end
    rescue
      e ->
        {:error, {:batch_storage_failed, Exception.message(e)}}
    end
  end
  
  # Simple project generators
  
  defp generate_simple_project do
    [
      {SimpleCalculator, simple_calculator_ast()},
      {SimpleList, simple_list_ast()},
      {SimpleString, simple_string_ast()},
      {SimpleMath, simple_math_ast()},
      {SimpleValidator, simple_validator_ast()},
      {SimpleConverter, simple_converter_ast()},
      {SimpleFormatter, simple_formatter_ast()},
      {SimpleParser, simple_parser_ast()},
      {SimpleHelper, simple_helper_ast()},
      {SimpleUtils, simple_utils_ast()}
    ]
  end
  
  defp simple_calculator_ast do
    quote do
      defmodule SimpleCalculator do
        @moduledoc "A simple calculator with basic operations"
        
        def add(a, b) when is_number(a) and is_number(b) do
          a + b
        end
        
        def subtract(a, b) when is_number(a) and is_number(b) do
          a - b
        end
        
        def multiply(a, b) when is_number(a) and is_number(b) do
          a * b
        end
        
        def divide(a, b) when is_number(a) and is_number(b) and b != 0 do
          a / b
        end
        
        def divide(_, 0), do: {:error, :division_by_zero}
      end
    end
  end
  
  defp simple_list_ast do
    quote do
      defmodule SimpleList do
        @moduledoc "Simple list operations"
        
        def sum(list) when is_list(list) do
          Enum.sum(list)
        end
        
        def average(list) when is_list(list) and length(list) > 0 do
          Enum.sum(list) / length(list)
        end
        
        def max(list) when is_list(list) and length(list) > 0 do
          Enum.max(list)
        end
        
        def min(list) when is_list(list) and length(list) > 0 do
          Enum.min(list)
        end
      end
    end
  end
  
  # Medium project generators
  
  defp generate_medium_project do
    base_modules = [
      {UserManager, user_manager_ast()},
      {UserSupervisor, user_supervisor_ast()},
      {DatabaseConnection, database_connection_ast()},
      {CacheManager, cache_manager_ast()},
      {NotificationService, notification_service_ast()},
      {EmailService, email_service_ast()},
      {AuthenticationService, authentication_service_ast()},
      {LoggingService, logging_service_ast()},
      {ConfigManager, config_manager_ast()},
      {HealthChecker, health_checker_ast()}
    ]
    
    # Generate additional modules to reach 50
    additional_modules = Enum.map(1..40, fn i ->
      {:"MediumModule#{i}", medium_module_ast(i)}
    end)
    
    base_modules ++ additional_modules
  end
  
  defp user_manager_ast do
    quote do
      defmodule UserManager do
        @moduledoc "Manages user operations"
        
        use GenServer
        
        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end
        
        def create_user(user_data) do
          GenServer.call(__MODULE__, {:create_user, user_data})
        end
        
        def get_user(user_id) do
          GenServer.call(__MODULE__, {:get_user, user_id})
        end
        
        def update_user(user_id, updates) do
          GenServer.call(__MODULE__, {:update_user, user_id, updates})
        end
        
        def delete_user(user_id) do
          GenServer.call(__MODULE__, {:delete_user, user_id})
        end
        
        def init(_opts) do
          {:ok, %{users: %{}, next_id: 1}}
        end
        
        def handle_call({:create_user, user_data}, _from, state) do
          user_id = state.next_id
          user = Map.put(user_data, :id, user_id)
          new_users = Map.put(state.users, user_id, user)
          new_state = %{state | users: new_users, next_id: user_id + 1}
          {:reply, {:ok, user}, new_state}
        end
        
        def handle_call({:get_user, user_id}, _from, state) do
          case Map.get(state.users, user_id) do
            nil -> {:reply, {:error, :not_found}, state}
            user -> {:reply, {:ok, user}, state}
          end
        end
        
        def handle_call({:update_user, user_id, updates}, _from, state) do
          case Map.get(state.users, user_id) do
            nil -> 
              {:reply, {:error, :not_found}, state}
            user -> 
              updated_user = Map.merge(user, updates)
              new_users = Map.put(state.users, user_id, updated_user)
              new_state = %{state | users: new_users}
              {:reply, {:ok, updated_user}, new_state}
          end
        end
        
        def handle_call({:delete_user, user_id}, _from, state) do
          new_users = Map.delete(state.users, user_id)
          new_state = %{state | users: new_users}
          {:reply, :ok, new_state}
        end
      end
    end
  end
  
  # Complex project generators
  
  defp generate_complex_project do
    base_modules = [
      {ComplexController, complex_controller_ast()},
      {ComplexService, complex_service_ast()},
      {ComplexRepository, complex_repository_ast()},
      {ComplexValidator, complex_validator_ast()},
      {ComplexTransformer, complex_transformer_ast()},
      {ComplexAggregator, complex_aggregator_ast()},
      {ComplexProcessor, complex_processor_ast()},
      {ComplexAnalyzer, complex_analyzer_ast()},
      {ComplexOptimizer, complex_optimizer_ast()},
      {ComplexScheduler, complex_scheduler_ast()}
    ]
    
    # Generate additional modules to reach 200+
    additional_modules = Enum.map(1..190, fn i ->
      {:"ComplexModule#{i}", complex_module_ast(i)}
    end)
    
    base_modules ++ additional_modules
  end
  
  defp complex_controller_ast do
    quote do
      defmodule ComplexController do
        @moduledoc "Complex Phoenix controller with multiple responsibilities"
        
        use Phoenix.Controller
        
        alias ComplexService
        alias ComplexValidator
        alias ComplexTransformer
        
        def index(conn, params) do
          with {:ok, validated_params} <- ComplexValidator.validate_index_params(params),
               {:ok, filters} <- extract_filters(validated_params),
               {:ok, pagination} <- extract_pagination(params),
               {:ok, sorting} <- extract_sorting(params),
               {:ok, raw_data} <- ComplexService.fetch_data(filters, pagination, sorting),
               {:ok, transformed_data} <- ComplexTransformer.transform_for_index(raw_data),
               {:ok, enriched_data} <- enrich_with_metadata(transformed_data) do
            
            render(conn, "index.json", %{
              data: enriched_data,
              pagination: pagination,
              total_count: ComplexService.count_data(filters)
            })
          else
            {:error, :validation_failed, errors} ->
              conn
              |> put_status(:bad_request)
              |> render("errors.json", %{errors: errors})
            
            {:error, :not_found} ->
              conn
              |> put_status(:not_found)
              |> render("error.json", %{message: "Resource not found"})
            
            {:error, reason} ->
              conn
              |> put_status(:internal_server_error)
              |> render("error.json", %{message: "Internal server error"})
          end
        end
        
        def show(conn, %{"id" => id} = params) do
          with {:ok, parsed_id} <- parse_id(id),
               {:ok, include_params} <- extract_include_params(params),
               {:ok, data} <- ComplexService.get_by_id(parsed_id),
               {:ok, enriched_data} <- enrich_single_item(data, include_params),
               {:ok, transformed_data} <- ComplexTransformer.transform_for_show(enriched_data) do
            
            render(conn, "show.json", %{data: transformed_data})
          else
            {:error, :invalid_id} ->
              conn
              |> put_status(:bad_request)
              |> render("error.json", %{message: "Invalid ID format"})
            
            {:error, :not_found} ->
              conn
              |> put_status(:not_found)
              |> render("error.json", %{message: "Resource not found"})
          end
        end
        
        defp extract_filters(params) do
          filters = %{}
          
          filters = if Map.has_key?(params, "status") do
            Map.put(filters, :status, params["status"])
          else
            filters
          end
          
          filters = if Map.has_key?(params, "category") do
            Map.put(filters, :category, params["category"])
          else
            filters
          end
          
          filters = if Map.has_key?(params, "date_from") do
            case Date.from_iso8601(params["date_from"]) do
              {:ok, date} -> Map.put(filters, :date_from, date)
              {:error, _} -> filters
            end
          else
            filters
          end
          
          {:ok, filters}
        end
        
        defp extract_pagination(params) do
          page = Map.get(params, "page", "1") |> String.to_integer()
          per_page = Map.get(params, "per_page", "20") |> String.to_integer()
          
          cond do
            page < 1 -> {:error, :invalid_page}
            per_page < 1 or per_page > 100 -> {:error, :invalid_per_page}
            true -> {:ok, %{page: page, per_page: per_page}}
          end
        end
        
        defp extract_sorting(params) do
          sort_by = Map.get(params, "sort_by", "created_at")
          sort_order = Map.get(params, "sort_order", "desc")
          
          if sort_order in ["asc", "desc"] do
            {:ok, %{sort_by: sort_by, sort_order: sort_order}}
          else
            {:error, :invalid_sort_order}
          end
        end
        
        defp enrich_with_metadata(data) when is_list(data) do
          enriched = Enum.map(data, fn item ->
            Map.merge(item, %{
              metadata: %{
                enriched_at: DateTime.utc_now(),
                version: "1.0"
              }
            })
          end)
          
          {:ok, enriched}
        end
        
        defp enrich_single_item(data, include_params) do
          enriched = Map.merge(data, %{
            metadata: %{
              enriched_at: DateTime.utc_now(),
              includes: include_params
            }
          })
          
          {:ok, enriched}
        end
        
        defp parse_id(id) when is_binary(id) do
          case Integer.parse(id) do
            {parsed_id, ""} when parsed_id > 0 -> {:ok, parsed_id}
            _ -> {:error, :invalid_id}
          end
        end
        
        defp extract_include_params(params) do
          includes = Map.get(params, "include", "")
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))
          
          {:ok, includes}
        end
      end
    end
  end
  
  # Legacy project generators
  
  defp generate_legacy_project do
    base_modules = [
      {LegacyGodObject, legacy_god_object_ast()},
      {LegacySpaghettiCode, legacy_spaghetti_ast()},
      {LegacyDuplicatedCode, legacy_duplicated_ast()},
      {LegacyLongMethod, legacy_long_method_ast()},
      {LegacyDeepNesting, legacy_deep_nesting_ast()},
      {LegacyMagicNumbers, legacy_magic_numbers_ast()},
      {LegacyPoorNaming, legacy_poor_naming_ast()},
      {LegacyTightCoupling, legacy_tight_coupling_ast()},
      {LegacyNoErrorHandling, legacy_no_error_handling_ast()},
      {LegacyHardcodedValues, legacy_hardcoded_values_ast()}
    ]
    
    # Generate additional modules to reach 100
    additional_modules = Enum.map(1..90, fn i ->
      {:"LegacyModule#{i}", legacy_module_ast(i)}
    end)
    
    base_modules ++ additional_modules
  end
  
  defp legacy_god_object_ast do
    quote do
      defmodule LegacyGodObject do
        @moduledoc "A god object that does everything - classic anti-pattern"
        
        # User management
        def create_user(name, email, password, role, department, manager_id, start_date, salary, benefits) do
          # Validation
          if String.length(name) < 2 or String.length(name) > 50 do
            {:error, "Invalid name"}
          else
            if not String.contains?(email, "@") do
              {:error, "Invalid email"}
            else
              if String.length(password) < 8 do
                {:error, "Password too short"}
              else
                # Hash password
                hashed_password = :crypto.hash(:sha256, password) |> Base.encode64()
                
                # Create user record
                user = %{
                  id: :rand.uniform(1000000),
                  name: name,
                  email: email,
                  password: hashed_password,
                  role: role,
                  department: department,
                  manager_id: manager_id,
                  start_date: start_date,
                  salary: salary,
                  benefits: benefits,
                  created_at: DateTime.utc_now()
                }
                
                # Save to database (simulated)
                save_user_to_database(user)
                
                # Send welcome email
                send_welcome_email(user)
                
                # Create audit log
                create_audit_log("user_created", user.id)
                
                # Update department statistics
                update_department_stats(department)
                
                {:ok, user}
              end
            end
          end
        end
        
        # Email functionality
        def send_welcome_email(user) do
          subject = "Welcome to the company!"
          body = "Dear #{user.name}, welcome to our company. Your role is #{user.role}."
          
          # Send email (simulated)
          send_email(user.email, subject, body)
        end
        
        def send_email(to, subject, body) do
          # Email sending logic
          IO.puts("Sending email to #{to}: #{subject}")
          :ok
        end
        
        # Database operations
        def save_user_to_database(user) do
          # Database save logic
          IO.puts("Saving user #{user.id} to database")
          :ok
        end
        
        def get_user_from_database(user_id) do
          # Database retrieval logic
          IO.puts("Getting user #{user_id} from database")
          %{id: user_id, name: "John Doe"}
        end
        
        # Audit logging
        def create_audit_log(action, user_id) do
          log_entry = %{
            action: action,
            user_id: user_id,
            timestamp: DateTime.utc_now(),
            ip_address: "127.0.0.1"
          }
          
          save_audit_log(log_entry)
        end
        
        def save_audit_log(log_entry) do
          IO.puts("Saving audit log: #{log_entry.action}")
          :ok
        end
        
        # Statistics
        def update_department_stats(department) do
          current_stats = get_department_stats(department)
          new_count = current_stats.employee_count + 1
          
          save_department_stats(department, %{employee_count: new_count})
        end
        
        def get_department_stats(department) do
          %{employee_count: 10}
        end
        
        def save_department_stats(department, stats) do
          IO.puts("Updating stats for #{department}: #{stats.employee_count} employees")
          :ok
        end
        
        # Report generation
        def generate_monthly_report(month, year) do
          users = get_all_users_for_month(month, year)
          departments = get_all_departments()
          
          report = %{
            month: month,
            year: year,
            total_users: length(users),
            departments: departments,
            generated_at: DateTime.utc_now()
          }
          
          save_report(report)
          send_report_email(report)
          
          report
        end
        
        def get_all_users_for_month(month, year) do
          # Simulated user retrieval
          []
        end
        
        def get_all_departments do
          ["Engineering", "Sales", "Marketing"]
        end
        
        def save_report(report) do
          IO.puts("Saving report for #{report.month}/#{report.year}")
          :ok
        end
        
        def send_report_email(report) do
          send_email("admin@company.com", "Monthly Report", "Report generated")
        end
      end
    end
  end
  
  # Helper functions for generating additional modules
  
  defp simple_string_ast, do: quote do: defmodule SimpleString, do: def upcase(str), do: String.upcase(str)
  defp simple_math_ast, do: quote do: defmodule SimpleMath, do: def square(x), do: x * x
  defp simple_validator_ast, do: quote do: defmodule SimpleValidator, do: def valid_email?(email), do: String.contains?(email, "@")
  defp simple_converter_ast, do: quote do: defmodule SimpleConverter, do: def to_string(value), do: "#{value}"
  defp simple_formatter_ast, do: quote do: defmodule SimpleFormatter, do: def format_currency(amount), do: "$#{amount}"
  defp simple_parser_ast, do: quote do: defmodule SimpleParser, do: def parse_int(str), do: Integer.parse(str)
  defp simple_helper_ast, do: quote do: defmodule SimpleHelper, do: def timestamp, do: DateTime.utc_now()
  defp simple_utils_ast, do: quote do: defmodule SimpleUtils, do: def random_id, do: :rand.uniform(1000)
  
  defp user_supervisor_ast, do: quote do: defmodule UserSupervisor, do: use Supervisor
  defp database_connection_ast, do: quote do: defmodule DatabaseConnection, do: use GenServer
  defp cache_manager_ast, do: quote do: defmodule CacheManager, do: use GenServer
  defp notification_service_ast, do: quote do: defmodule NotificationService, do: use GenServer
  defp email_service_ast, do: quote do: defmodule EmailService, do: use GenServer
  defp authentication_service_ast, do: quote do: defmodule AuthenticationService, do: use GenServer
  defp logging_service_ast, do: quote do: defmodule LoggingService, do: use GenServer
  defp config_manager_ast, do: quote do: defmodule ConfigManager, do: use GenServer
  defp health_checker_ast, do: quote do: defmodule HealthChecker, do: use GenServer
  
  defp medium_module_ast(i) do
    quote do
      defmodule unquote(:"MediumModule#{i}") do
        use GenServer
        
        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts)
        end
        
        def init(_opts) do
          {:ok, %{}}
        end
      end
    end
  end
  
  defp complex_service_ast, do: quote do: defmodule ComplexService, do: def fetch_data(_, _, _), do: {:ok, []}
  defp complex_repository_ast, do: quote do: defmodule ComplexRepository, do: def get_by_id(_), do: {:ok, %{}}
  defp complex_validator_ast, do: quote do: defmodule ComplexValidator, do: def validate_index_params(_), do: {:ok, %{}}
  defp complex_transformer_ast, do: quote do: defmodule ComplexTransformer, do: def transform_for_index(_), do: {:ok, []}
  defp complex_aggregator_ast, do: quote do: defmodule ComplexAggregator, do: def aggregate(_), do: {:ok, %{}}
  defp complex_processor_ast, do: quote do: defmodule ComplexProcessor, do: def process(_), do: {:ok, %{}}
  defp complex_analyzer_ast, do: quote do: defmodule ComplexAnalyzer, do: def analyze(_), do: {:ok, %{}}
  defp complex_optimizer_ast, do: quote do: defmodule ComplexOptimizer, do: def optimize(_), do: {:ok, %{}}
  defp complex_scheduler_ast, do: quote do: defmodule ComplexScheduler, do: def schedule(_), do: {:ok, %{}}
  
  defp complex_module_ast(i) do
    quote do
      defmodule unquote(:"ComplexModule#{i}") do
        def complex_function(data) do
          case data do
            %{type: :process} -> process_data(data)
            %{type: :transform} -> transform_data(data)
            _ -> {:error, :unknown_type}
          end
        end
        
        defp process_data(data), do: {:ok, data}
        defp transform_data(data), do: {:ok, data}
      end
    end
  end
  
  defp legacy_spaghetti_ast, do: quote do: defmodule LegacySpaghettiCode, do: def messy_function(_), do: :ok
  defp legacy_duplicated_ast, do: quote do: defmodule LegacyDuplicatedCode, do: def duplicate1(_), do: :ok
  defp legacy_long_method_ast, do: quote do: defmodule LegacyLongMethod, do: def very_long_method(_), do: :ok
  defp legacy_deep_nesting_ast, do: quote do: defmodule LegacyDeepNesting, do: def nested_function(_), do: :ok
  defp legacy_magic_numbers_ast, do: quote do: defmodule LegacyMagicNumbers, do: def calculate(_), do: 42
  defp legacy_poor_naming_ast, do: quote do: defmodule LegacyPoorNaming, do: def a(_), do: :ok
  defp legacy_tight_coupling_ast, do: quote do: defmodule LegacyTightCoupling, do: def coupled(_), do: :ok
  defp legacy_no_error_handling_ast, do: quote do: defmodule LegacyNoErrorHandling, do: def unsafe(_), do: :ok
  defp legacy_hardcoded_values_ast, do: quote do: defmodule LegacyHardcodedValues, do: def hardcoded, do: "localhost:3000"
  
  defp legacy_module_ast(i) do
    quote do
      defmodule unquote(:"LegacyModule#{i}") do
        def legacy_function(x) do
          if x > 0 do
            if x < 100 do
              if x > 50 do
                "high"
              else
                "medium"
              end
            else
              "very high"
            end
          else
            "low"
          end
        end
      end
    end
  end
end 