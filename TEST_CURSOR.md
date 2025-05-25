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

# Run ONLY live Vertex AI tests (requires VERTEX_JSON_FILE)
mix test test/elixir_scope/ai/llm/providers/vertex_live_test.exs

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
# Standard tests use mock providers by default in test environment
# No environment variables needed - mock is automatic
mix test

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
export LLM_PROVIDER="vertex"  # Required in test environment to override mock

# Run live tests
mix test --only live_api
```

#### **Gemini API Setup (Alternative)**
```bash
# Set up Gemini API key for live testing
export GEMINI_API_KEY="your-actual-gemini-api-key-here"
export GEMINI_DEFAULT_MODEL="gemini-2.0-flash"  # Optional
export LLM_PROVIDER="gemini"  # Required in test environment to override mock

# Run live tests
mix test --only live_api
```

### **Testing Different Models**
```bash
# Test with specific Vertex model
export VERTEX_DEFAULT_MODEL="gemini-1.5-pro"
mix test --only live_api

# Test with specific Gemini model
export GEMINI_DEFAULT_MODEL="gemini-1.5-pro"
mix test --only live_api

# Test with different model during test run
VERTEX_DEFAULT_MODEL="gemini-2.0-flash" mix test --only live_api
```

### **Multi-Provider Testing**
```bash
# Test provider fallback behavior
export VERTEX_JSON_FILE="/path/to/valid/credentials.json"
export GEMINI_API_KEY="your-api-key"
export LLM_PROVIDER="vertex"  # Primary provider (required in test env)
mix test --only live_api

# Test with Gemini as primary
export LLM_PROVIDER="gemini"  # Switch to Gemini (required in test env)
mix test --only live_api

# Note: In test environment, you must explicitly set LLM_PROVIDER
# Auto-detection is disabled to ensure predictable test behavior
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
| `VERTEX_JSON_FILE` | Vertex AI credentials file path | None | For Vertex live tests only |
| `VERTEX_DEFAULT_MODEL` | Vertex model for tests | `gemini-2.0-flash` | No |
| `GEMINI_API_KEY` | Live Gemini API access | None | For Gemini live tests only |
| `GEMINI_DEFAULT_MODEL` | Gemini model for tests | `gemini-2.0-flash` | No |
| `LLM_PROVIDER` | Force specific provider | `mock` (in test env) | No |
| `LLM_TIMEOUT` | API timeout (ms) | `30000` | No |

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

**This is expected in standard tests** - when running `mix test` without live API tests, the system correctly reports that Vertex credentials are not available and falls back to mock provider.

### **Bearer Token Security**
All HTTP requests and responses are automatically redacted in logs to prevent accidental exposure of API keys or access tokens. You should never see actual bearer tokens in test output.