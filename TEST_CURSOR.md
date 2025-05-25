# ElixirScope Testing Guide

**Date**: December 2024  
**Purpose**: Comprehensive testing strategy for ElixirScope LLM Integration  
**Status**: 🟢 **ACTIVE** - Updated for Layer 10 LLM Integration  

---

## 📋 **Testing Overview**

ElixirScope uses a multi-tiered testing approach to ensure reliability across different environments and use cases:

1. **Unit Tests** - Fast, isolated tests for individual components
2. **Integration Tests** - Tests for component interactions
3. **Live API Tests** - Real API calls to external services (separate from main test suite)
4. **Compliance Tests** - Ensure all providers implement required interfaces

---

## 🚀 **Running Tests**

### **Standard Test Suite (Default)**
```bash
# Run all tests except live API tests
mix test

# Run with coverage report
mix test --cover

# Run specific test file
mix test test/elixir_scope/ai/llm/client_test.exs

# Run tests matching a pattern
mix test --only llm
```

### **Live API Tests (Separate)**
```bash
# Run ONLY live Gemini API tests (requires GEMINI_API_KEY)
mix test test/elixir_scope/ai/llm/providers/gemini_live_test.exs

# Run all live API tests with tag
mix test --only live_api

# Include live tests in full test run
mix test --include live_api

# Run live tests with verbose output
mix test --only live_api --trace
```

### **Provider Compliance Tests**
```bash
# Test that all providers implement the required behaviour
mix test test/elixir_scope/ai/llm/provider_compliance_test.exs

# Run compliance tests for specific provider
mix test test/elixir_scope/ai/llm/provider_compliance_test.exs -k "Mock"
```

---

## 🔧 **Environment Setup for Testing**

### **Standard Tests (No API Keys Required)**
```bash
# Standard tests use mock providers by default
export LLM_PROVIDER=mock
mix test
```

### **Live API Tests (Requires API Keys)**
```bash
# Set up Gemini API key for live testing
export GEMINI_API_KEY="your-actual-gemini-api-key-here"
export GEMINI_DEFAULT_MODEL="gemini-1.5-flash"  # Optional, defaults to gemini-1.5-flash
export LLM_PROVIDER="gemini"  # Optional, will auto-detect from API key

# Run live tests
mix test --only live_api
```

### **Testing Different Models**
```bash
# Test with specific Gemini model
export GEMINI_DEFAULT_MODEL="gemini-1.5-pro"
mix test --only live_api

# Test with different model during test run
GEMINI_DEFAULT_MODEL="gemini-1.5-flash" mix test --only live_api
```

---

## 📊 **Test Categories**

### **1. Unit Tests**
**Location**: `test/elixir_scope/ai/llm/`  
**Purpose**: Test individual modules in isolation  
**Run Time**: < 5 seconds  

```bash
# Examples
mix test test/elixir_scope/ai/llm/response_test.exs
mix test test/elixir_scope/ai/llm/config_test.exs
mix test test/elixir_scope/ai/llm/providers/mock_test.exs
```

**Coverage**:
- ✅ Response format validation
- ✅ Configuration management
- ✅ Mock provider functionality
- ✅ Error handling

### **2. Integration Tests**
**Location**: `test/elixir_scope/ai/llm/client_test.exs`  
**Purpose**: Test component interactions  
**Run Time**: < 10 seconds  

```bash
mix test test/elixir_scope/ai/llm/client_test.exs
```

**Coverage**:
- ✅ Client-provider interactions
- ✅ Fallback mechanisms
- ✅ Provider selection logic
- ✅ Error propagation

### **3. Live API Tests** 🌐
**Location**: `test/elixir_scope/ai/llm/providers/gemini_live_test.exs`  
**Purpose**: Test real API integration  
**Run Time**: 30-60 seconds  
**Requirements**: Valid `GEMINI_API_KEY`  

```bash
# Prerequisites
export GEMINI_API_KEY="your-key-here"

# Run live tests
mix test test/elixir_scope/ai/llm/providers/gemini_live_test.exs
```

**Coverage**:
- ✅ Real Gemini API calls
- ✅ Response parsing
- ✅ Error handling with invalid keys
- ✅ Model selection via environment variables
- ✅ Performance validation
- ✅ Concurrent request handling

### **4. Compliance Tests**
**Location**: `test/elixir_scope/ai/llm/provider_compliance_test.exs`  
**Purpose**: Ensure all providers implement required interface  
**Run Time**: < 5 seconds  

```bash
mix test test/elixir_scope/ai/llm/provider_compliance_test.exs
```

**Coverage**:
- ✅ Provider behaviour implementation
- ✅ Response format consistency
- ✅ Error handling consistency
- ✅ Input validation

---

## 🎯 **Test Configuration**

### **Test Environment Variables**

| Variable | Purpose | Default | Required |
|----------|---------|---------|----------|
| `GEMINI_API_KEY` | Live Gemini API access | None | For live tests only |
| `GEMINI_DEFAULT_MODEL` | Model for all tests | `gemini-1.5-flash` | No |
| `LLM_PROVIDER` | Force specific provider | Auto-detect | No |
| `LLM_TIMEOUT` | API timeout (ms) | `30000` | No |

### **Test Tags**

| Tag | Purpose | Usage |
|-----|---------|-------|
| `:live_api` | Live API tests | `mix test --only live_api` |
| `:slow` | Slow-running tests | `mix test --exclude slow` |
| `:integration` | Integration tests | `mix test --only integration` |

### **ExUnit Configuration**
```elixir
# In config/test.exs
ExUnit.configure(exclude: [:live_api])  # Exclude live tests by default
```

---

## 🔍 **Test Development Guidelines**

### **Writing New Tests**

#### **Unit Tests**
```elixir
defmodule MyModuleTest do
  use ExUnit.Case, async: true  # Use async: true for unit tests
  
  test "should do something specific" do
    # Test implementation
  end
end
```

#### **Live API Tests**
```elixir
defmodule MyLiveTest do
  use ExUnit.Case, async: false  # Use async: false for live tests
  
  @moduletag :live_api
  @moduletag timeout: 30_000
  
  setup_all do
    case System.get_env("GEMINI_API_KEY") do
      nil -> {:skip, "GEMINI_API_KEY not set"}
      _key -> :ok
    end
  end
  
  @tag :live_api
  test "should work with real API" do
    # Live test implementation
  end
end
```

### **Test Naming Conventions**
- **Unit tests**: `module_name_test.exs`
- **Integration tests**: `feature_integration_test.exs`
- **Live tests**: `provider_live_test.exs`
- **Compliance tests**: `provider_compliance_test.exs`

---

## 📈 **Test Metrics & Coverage**

### **Coverage Targets**
- **Unit Tests**: > 95%
- **Integration Tests**: > 90%
- **Live API Tests**: > 80%
- **Overall Coverage**: > 90%

### **Running Coverage Reports**
```bash
# Generate HTML coverage report
mix test --cover

# Generate detailed coverage
mix coveralls.html

# Check coverage without running tests
mix coveralls.detail
```

### **Performance Benchmarks**
```bash
# Run performance tests
mix test --only performance

# Benchmark specific functions
mix run benchmarks/llm_performance.exs
```

---

## 🚨 **Troubleshooting Tests**

### **Common Issues**

#### **Live API Tests Failing**
```bash
# Check API key
echo $GEMINI_API_KEY

# Verify API key format (should be long string)
if [ ${#GEMINI_API_KEY} -lt 20 ]; then
  echo "API key appears invalid (too short)"
fi

# Test API connectivity
curl -H "Authorization: Bearer $GEMINI_API_KEY" \
     "https://generativelanguage.googleapis.com/v1beta/models"
```

#### **Provider Configuration Issues**
```bash
# Check current provider configuration
iex -S mix
iex> ElixirScope.AI.LLM.Config.debug_config()
```

#### **Test Environment Conflicts**
```bash
# Clear all LLM-related environment variables
unset GEMINI_API_KEY
unset LLM_PROVIDER
unset GEMINI_DEFAULT_MODEL

# Run tests with clean environment
mix test
```

### **Debug Mode**
```bash
# Run tests with debug output
mix test --trace

# Run specific test with detailed output
mix test test/path/to/test.exs:line_number --trace

# Enable debug logging
ELIXIR_SCOPE_LOG_LEVEL=debug mix test
```

---

## 🔄 **Continuous Integration**

### **CI Pipeline Configuration**

#### **Standard CI (No API Keys)**
```yaml
# .github/workflows/test.yml
- name: Run Tests
  run: |
    mix test --exclude live_api
    mix coveralls.github
```

#### **Extended CI (With API Keys)**
```yaml
# .github/workflows/test-extended.yml
- name: Run All Tests
  env:
    GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
  run: |
    mix test --include live_api
```

### **Local CI Simulation**
```bash
# Simulate CI environment locally
unset GEMINI_API_KEY
mix test --exclude live_api

# Test with API key (if available)
export GEMINI_API_KEY="your-key"
mix test --include live_api
```

---

## 📚 **Test Documentation**

### **Test File Structure**
```
test/
├── elixir_scope/
│   └── ai/
│       └── llm/
│           ├── client_test.exs              # Integration tests
│           ├── config_test.exs              # Configuration tests
│           ├── response_test.exs            # Response format tests
│           ├── provider_compliance_test.exs # Behaviour compliance
│           └── providers/
│               ├── mock_test.exs            # Mock provider tests
│               ├── gemini_test.exs          # Gemini unit tests
│               └── gemini_live_test.exs     # Live API tests
└── support/
    ├── test_helpers.ex                      # Shared test utilities
    └── llm_test_helpers.ex                  # LLM-specific helpers
```

### **Adding New Providers**
When adding a new provider (e.g., Anthropic):

1. **Create unit tests**: `test/elixir_scope/ai/llm/providers/anthropic_test.exs`
2. **Create live tests**: `test/elixir_scope/ai/llm/providers/anthropic_live_test.exs`
3. **Update compliance tests**: Add to `@providers` list in `provider_compliance_test.exs`
4. **Update this documentation**: Add provider-specific testing instructions

---

## ✅ **Test Checklist**

### **Before Committing**
- [ ] All unit tests pass: `mix test --exclude live_api`
- [ ] Code coverage > 90%: `mix test --cover`
- [ ] No warnings: `mix compile --warnings-as-errors`
- [ ] Compliance tests pass: `mix test test/elixir_scope/ai/llm/provider_compliance_test.exs`

### **Before Releasing**
- [ ] All tests pass including live: `mix test --include live_api`
- [ ] Performance tests pass: `mix test --only performance`
- [ ] Documentation updated
- [ ] CHANGELOG.md updated

### **Weekly Maintenance**
- [ ] Run live API tests: `mix test --only live_api`
- [ ] Check for deprecated API usage
- [ ] Update test dependencies
- [ ] Review test coverage reports

---

**Document Status**: 🟢 **ACTIVE**  
**Last Updated**: December 2024  
**Next Review**: After Layer 10 completion 