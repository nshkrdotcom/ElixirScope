# Elixir Analyzer Demo

A comprehensive demonstration of the Enhanced AST Repository features in ElixirScope. This sample application showcases all the advanced capabilities including memory management, performance optimization, runtime correlation, debugging, and comprehensive code analysis.

## 🚀 Quick Start

```bash
# Navigate to the demo app
cd test_apps/elixir_analyzer_demo

# Install dependencies
mix deps.get

# Start the application
iex -S mix

# Run all demos
ElixirAnalyzerDemo.run_all_demos()
```

## 🎯 Features Demonstrated

### Core Repository Features
- ✅ Enhanced module storage and retrieval
- ✅ Function-level analysis and storage  
- ✅ Batch operations for performance
- ✅ Advanced querying and search capabilities

### Memory Management
- ✅ Intelligent cleanup and compression
- ✅ LRU caching with TTL
- ✅ Memory pressure handling
- ✅ Real-time memory monitoring

### Performance Optimization
- ✅ Query caching and optimization
- ✅ Lazy loading strategies
- ✅ Cache warming
- ✅ Performance benchmarking

### Analysis Engine
- ✅ Complexity analysis (cyclomatic, cognitive)
- ✅ Dependency analysis
- ✅ Security vulnerability detection
- ✅ Performance bottleneck identification
- ✅ Code quality metrics

### Runtime Correlation
- ✅ Dynamic analysis integration
- ✅ Runtime data correlation
- ✅ Execution pattern analysis
- ✅ Performance profiling integration

### Interactive Debugging
- ✅ Breakpoint management
- ✅ Watch expressions
- ✅ Execution path analysis
- ✅ Interactive code exploration

### Monitoring & Alerting
- ✅ Real-time performance monitoring
- ✅ Automated alerting system
- ✅ Performance dashboard
- ✅ Historical trend analysis

## 🎮 Demo Scenarios

### 1. Basic Operations Demo
```elixir
# Load sample data
ElixirAnalyzerDemo.load_sample_project(:medium)

# Demonstrate basic repository operations
ElixirAnalyzerDemo.demo_basic_operations()
```

**What it shows:**
- Module storage and retrieval
- Function-level analysis
- Batch operations
- Complexity calculation
- Memory usage tracking

### 2. Memory Management Demo
```elixir
ElixirAnalyzerDemo.demo_memory_management()
```

**What it shows:**
- Memory pressure simulation
- Intelligent cleanup
- Data compression
- Cache efficiency
- Memory optimization

### 3. Performance Optimization Demo
```elixir
ElixirAnalyzerDemo.demo_performance_optimization()
```

**What it shows:**
- Query benchmarking
- Cache warming
- Performance monitoring
- Throughput analysis
- Response time optimization

### 4. Interactive Debugging Demo
```elixir
ElixirAnalyzerDemo.demo_debugging()
```

**What it shows:**
- Debug session management
- Breakpoint setting
- Watch expressions
- Execution path analysis
- Code complexity analysis

## 📊 Sample Data Sets

The demo includes four different sample projects:

### Simple Project (10 modules)
- Basic Elixir patterns
- Pattern matching and guards
- Simple function definitions
- **Use case:** Learning and basic demonstrations

### Medium Project (50 modules)
- GenServer patterns
- Supervision trees
- Database interactions
- **Use case:** Realistic application simulation

### Complex Project (200+ modules)
- Phoenix application patterns
- Complex business logic
- Multiple dependencies
- **Use case:** Large-scale application analysis

### Legacy Project (100 modules)
- Technical debt examples
- Code smells and anti-patterns
- Refactoring opportunities
- **Use case:** Code quality analysis and improvement

## 🔧 Configuration

The demo app supports different configurations for different environments:

### Development
```elixir
# config/dev.exs
config :elixir_analyzer_demo,
  enhanced_repository: [
    memory_limit: 256 * 1024 * 1024,  # 256MB
    cleanup_interval: 60_000,         # 1 minute
    default_project_type: :simple
  ]
```

### Production
```elixir
# config/prod.exs
config :elixir_analyzer_demo,
  enhanced_repository: [
    memory_limit: 1024 * 1024 * 1024, # 1GB
    cleanup_interval: 600_000,        # 10 minutes
    default_project_type: :complex
  ]
```

## 🎯 Interactive Commands

### Sample Data Management
```elixir
# Load different project types
ElixirAnalyzerDemo.load_sample_project(:simple)
ElixirAnalyzerDemo.load_sample_project(:medium)
ElixirAnalyzerDemo.load_sample_project(:complex)
ElixirAnalyzerDemo.load_sample_project(:legacy)

# Get available projects
ElixirAnalyzerDemo.SampleDataManager.get_available_projects()

# Clear all data
ElixirAnalyzerDemo.SampleDataManager.clear_all_data()
```

### Analysis Operations
```elixir
# Analyze a specific module
ElixirAnalyzerDemo.AnalysisEngine.analyze_module(SimpleCalculator, ast)

# Get analysis results
ElixirAnalyzerDemo.AnalysisEngine.get_analysis_results(SimpleCalculator)

# Quality analysis
ElixirAnalyzerDemo.QualityAnalyzer.analyze_quality(SimpleCalculator)
```

### Performance Monitoring
```elixir
# Start monitoring
ElixirAnalyzerDemo.PerformanceMonitor.start_monitoring()

# Get dashboard
ElixirAnalyzerDemo.PerformanceMonitor.get_performance_dashboard()

# Get metrics history
ElixirAnalyzerDemo.PerformanceMonitor.get_metrics_history()
```

### Debugging Interface
```elixir
# Start debug session
{:ok, session_id} = ElixirAnalyzerDemo.DebugInterface.start_debug_session(DemoModule)

# Set breakpoints
{:ok, bp_id} = ElixirAnalyzerDemo.DebugInterface.set_breakpoint(session_id, :complex_function, 1)

# Add watch expressions
{:ok, watch_id} = ElixirAnalyzerDemo.DebugInterface.add_watch_expression(session_id, "data length")

# Analyze execution paths
analysis = ElixirAnalyzerDemo.DebugInterface.analyze_execution_path(
  session_id, :complex_function, 1, [[1, 2, 3, "invalid", 4, 5]]
)
```

## 📈 Performance Metrics

The demo tracks and displays various performance metrics:

### Memory Metrics
- Repository memory usage
- System memory usage
- Cache hit ratio
- Memory growth trends

### Performance Metrics
- Average query time
- Throughput (operations/second)
- Response time percentiles (P50, P95, P99)
- Concurrent operations count

### Repository Metrics
- Total modules stored
- Total functions analyzed
- Analysis coverage percentage
- Storage efficiency

### System Metrics
- CPU usage
- Memory usage
- Disk usage
- Network I/O

## 🚨 Alerting System

The demo includes an intelligent alerting system that monitors:

- **Memory Usage**: Alerts when memory usage exceeds 80%
- **Cache Efficiency**: Alerts when cache hit ratio drops below 70%
- **Query Performance**: Alerts when average query time exceeds 100ms
- **System Health**: Overall system health assessment

## 🎨 Customization

### Adding Custom Sample Data
```elixir
# Add your own sample modules
custom_modules = [
  {MyModule, my_ast},
  {AnotherModule, another_ast}
]

ElixirScope.ASTRepository.EnhancedRepository.store_modules_batch(custom_modules)
```

### Custom Analysis
```elixir
# Implement custom analysis logic
defmodule MyCustomAnalyzer do
  def analyze(module_name, ast) do
    # Your custom analysis logic here
  end
end
```

## 🧪 Testing

```bash
# Run all tests
mix test

# Run specific test files
mix test test/elixir_analyzer_demo_test.exs

# Run with coverage
mix test --cover
```

## 📚 Documentation

For detailed API documentation, see:
- [API Documentation](../../API_DOCUMENTATION.md)
- [Integration Guide](../../INTEGRATION_GUIDE.md)
- [Sample Cursor Documentation](./SAMPLE_CURSOR.md)

## 🤝 Contributing

This demo app serves as both a showcase and a template for building applications with the Enhanced AST Repository. Feel free to:

1. Add new demo scenarios
2. Implement additional analysis features
3. Create custom sample data sets
4. Enhance the monitoring capabilities

## 📄 License

This demo application is part of the ElixirScope project and follows the same licensing terms.

---

**Happy Analyzing! 🎉**

For questions or support, please refer to the main ElixirScope documentation or create an issue in the project repository.

