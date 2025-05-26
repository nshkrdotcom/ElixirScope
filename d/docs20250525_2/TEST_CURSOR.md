# ElixirScope Testing Guide

**Date**: December 2024  
**Purpose**: Comprehensive testing strategy for ElixirScope LLM Integration  
**Status**: 🟢 **ACTIVE** - Updated with Focused Test Suites  

---

## 📋 **Testing Overview**

ElixirScope uses a multi-tiered testing approach to ensure reliability across different environments and use cases:

1. **Unit Tests** - Fast, isolated tests for individual components
2. **Integration Tests** - Tests for component interactions
3. **Live API Tests** - Real API calls to external services (separate from main test suite)
4. **Compliance Tests** - Ensure all providers implement required interfaces
5. **Focused Test Suites** - Provider-specific and LLM-focused test runs

---

## 🚀 **Running Tests**

### **Quick Test Commands (Recommended)**
```bash
# Fast test run with detailed output (excludes live API calls)
mix test.trace

# Test only mock provider (super fast, no API calls)
mix test.mock

# Test only Gemini provider (requires GOOGLE_API_KEY)
mix test.gemini

# Test only Vertex AI provider (requires VERTEX_JSON_FILE)
mix test.vertex

# Test all LLM components (excludes live API calls)
mix test.llm

# Test all LLM components including live API calls
mix test.llm.live

# Fast parallel test run
mix test.fast
```

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
# Run ONLY live API tests (requires credentials)
mix test.live

# Run all tests including live API tests
mix test.all

# Run live tests with verbose output
mix test --only live_api --trace
```

### **Provider-Specific Testing**
```bash
# Test individual providers with focused test suites
mix test.mock      # Mock provider tests (27 tests, ~0.2s)
mix test.gemini    # Gemini live API tests (requires GOOGLE_API_KEY)
mix test.vertex    # Vertex AI live API tests (requires VERTEX_JSON_FILE)

# Test specific provider files directly
mix test test/elixir_scope/ai/llm/providers/gemini_live_test.exs
mix test test/elixir_scope/ai/llm/providers/vertex_live_test.exs
```

### **LLM-Focused Testing**
```bash
# Test all LLM components (fast, no API calls)
mix test.llm

# Test all LLM components including live API tests
mix test.llm.live

# Test LLM directory with specific options
mix test test/elixir_scope/ai/llm/ --exclude live_api
```

---

## 🔧 **Environment Setup for Testing**

### **Standard Tests (No API Keys Required)**
```bash
# Standard tests use mock providers by default in test environment
# No environment variables needed - mock is automatic
mix test.trace

# Explicitly set mock provider (optional)
export LLM_PROVIDER=mock
mix test
```

**🎯 Key Change**: Tests now **automatically use mock providers** in test environment, regardless of whether you have API keys or credentials configured. This ensures fast, reliable tests without external dependencies.

### **Live API Tests (Requires Credentials)**

#### **Vertex AI Setup (Recommended)**
```bash
# Set up Vertex AI credentials for live testing
export VERTEX_JSON_FILE="/path/to/your/service-account.json"
export VERTEX_DEFAULT_MODEL="gemini-2.0-flash"  # Optional

# Run Vertex-specific tests
mix test.vertex

# Run all live tests
mix test.live
```

#### **Gemini API Setup (Alternative)**
```bash
# Set up Gemini API key for live testing
export GOOGLE_API_KEY="your-actual-gemini-api-key-here"
export GEMINI_DEFAULT_MODEL="gemini-2.0-flash"  # Optional

# Run Gemini-specific tests
mix test.gemini

# Run all live tests
mix test.live
```

### **Testing Different Models**
```bash
# Test with specific Vertex model
export VERTEX_DEFAULT_MODEL="gemini-1.5-pro"
mix test.vertex

# Test with specific Gemini model
export GEMINI_DEFAULT_MODEL="gemini-1.5-pro"
mix test.gemini

# Test with different model during test run
VERTEX_DEFAULT_MODEL="gemini-2.0-flash" mix test.vertex
```

### **Multi-Provider Testing**
```bash
# Test all providers with credentials
export VERTEX_JSON_FILE="/path/to/valid/credentials.json"
export GOOGLE_API_KEY="your-api-key"

# Test each provider individually
mix test.vertex
mix test.gemini
mix test.mock

# Test all live providers
mix test.live
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
mix test.mock  # Comprehensive mock provider tests
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
# Or use focused LLM tests
mix test.llm
```

**Coverage**:
- ✅ Client-provider interactions
- ✅ Fallback mechanisms
- ✅ Provider selection logic
- ✅ Error propagation

### **3. Live API Tests** 🌐
**Location**: `test/elixir_scope/ai/llm/providers/*_live_test.exs`  
**Purpose**: Test real API integration  
**Run Time**: 30-60 seconds per provider  

```bash
# Prerequisites for Gemini
export GOOGLE_API_KEY="your-key-here"
mix test.gemini

# Prerequisites for Vertex AI
export VERTEX_JSON_FILE="/path/to/service-account.json"
mix test.vertex

# Run all live tests
mix test.live
```

**Coverage**:
- ✅ Real API calls (Gemini & Vertex AI)
- ✅ Response parsing and validation
- ✅ Error handling with invalid credentials
- ✅ Model selection via environment variables
- ✅ Performance validation
- ✅ Unicode and special character handling
- ✅ Large input handling
- ✅ Context processing

### **4. Compliance Tests**
**Location**: `test/elixir_scope/ai/llm/provider_compliance_test.exs`  
**Purpose**: Ensure all providers implement required interface  
**Run Time**: < 5 seconds  

```bash
mix test test/elixir_scope/ai/llm/provider_compliance_test.exs
# Or include in LLM-focused tests
mix test.llm
```

**Coverage**:
- ✅ Provider behaviour implementation
- ✅ Response format consistency
- ✅ Error handling consistency
- ✅ Input validation

---

## 🎯 **Test Configuration & Mix Aliases**

### **Available Mix Aliases**

| Alias | Purpose | Excludes Live API | Run Time |
|-------|---------|-------------------|----------|
| `mix test.trace` | Main test suite with detailed output | ✅ | ~0.2s |
| `mix test.fast` | Parallel test execution | ✅ | ~0.1s |
| `mix test.mock` | Mock provider tests only | ✅ | ~0.2s |
| `mix test.llm` | All LLM tests (safe) | ✅ | ~0.3s |
| `mix test.gemini` | Gemini live API tests | ❌ | ~30s |
| `mix test.vertex` | Vertex AI live API tests | ❌ | ~45s |
| `mix test.live` | All live API tests | ❌ | ~60s |
| `mix test.llm.live` | LLM tests including live API | ❌ | ~60s |
| `mix test.all` | Everything including live API | ❌ | ~90s |

### **Test Environment Variables**

| Variable | Purpose | Default | Required |
|----------|---------|---------|----------|
| `VERTEX_JSON_FILE` | Vertex AI credentials file path | None | For Vertex live tests only |
| `VERTEX_DEFAULT_MODEL` | Vertex model for tests | `gemini-2.0-flash` | No |
| `GOOGLE_API_KEY` | Live Gemini API access | None | For Gemini live tests only |
| `GEMINI_DEFAULT_MODEL` | Gemini model for tests | `gemini-2.0-flash` | No |
| `LLM_PROVIDER` | Force specific provider | `mock` (in test env) | No |
| `LLM_TIMEOUT` | API timeout (ms) | `30000` | No |

---

## 🏃‍♂️ **Recommended Testing Workflow**

### **During Development**
```bash
# Quick feedback loop (recommended for TDD)
mix test.trace

# Test specific provider functionality
mix test.mock

# Test LLM components without API calls
mix test.llm
```

### **Before Committing**
```bash
# Run full test suite (excludes live API)
mix test.trace

# Verify all tests pass
mix test.fast
```

### **Before Releasing**
```bash
# Test with live APIs (requires credentials)
export VERTEX_JSON_FILE="/path/to/credentials.json"
export GOOGLE_API_KEY="your-api-key"

# Test each provider
mix test.vertex
mix test.gemini

# Full test suite including live APIs
mix test.all
```

### **CI/CD Pipeline**
```bash
# Fast test run for CI (no external dependencies)
mix test.trace

# Optional: Live API tests in separate CI job
# (requires secure credential management)
mix test.live
```

---

## ⚠️ **Common Test Warnings**

### **Configuration Sampling Rate Warning**
```
Configuration update rejected: "ai.planning.sampling_rate must be a number between 0 and 1"
```

**This is expected behavior** - some tests intentionally try to set invalid configuration values (like `sampling_rate: 1.5`) to verify that validation is working correctly. This warning indicates the validation system is functioning properly.

### **Vertex Credentials Not Found**
```
Vertex: Failed to generate token: {:error, "No Vertex AI credentials found"}
```

**This is expected in standard tests** - when running `mix test.trace` without live API tests, the system correctly reports that Vertex credentials are not available and falls back to mock provider.

### **Live API Test Skipping**
```
⚠️  Skipping Gemini tests - GOOGLE_API_KEY not configured
⚠️  Skipping Vertex tests - VERTEX_JSON_FILE not configured
```

**This is expected behavior** - live API tests automatically skip when credentials are not available, allowing the test suite to run in any environment.

### **Bearer Token Security**
All HTTP requests and responses are automatically redacted in logs to prevent accidental exposure of API keys or access tokens. You should never see actual bearer tokens in test output.

---

## 🎉 **Test Results Summary**

### **Current Test Coverage**
- **Total Tests**: 530+ tests
- **Mock Provider Tests**: 27 tests (comprehensive offline testing)
- **Live API Tests**: 21 tests (Gemini + Vertex AI)
- **Standard Test Run Time**: ~0.2 seconds
- **Live API Test Run Time**: ~60 seconds

### **Test Success Metrics**
- ✅ **0 failures** in standard test suite
- ✅ **Fast execution** (~0.2s for 530+ tests)
- ✅ **No external dependencies** in default test run
- ✅ **Comprehensive provider coverage**
- ✅ **Clear test output** with individual test timing
- ✅ **Proper test isolation** (live API tests tagged separately)

**Key Achievement**: Tests now run in ~0.2 seconds instead of 8+ seconds, with clear one-line-per-test output showing exactly which tests are running and their timing.