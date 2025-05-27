# Contributing to ElixirScope

Thank you for your interest in contributing to ElixirScope! We're excited to have you join our community and help us build a revolutionary debugging and code intelligence platform for Elixir.

This document provides guidelines for contributing to the project, from setting up your development environment to submitting pull requests.

## Table of Contents

1.  [Code of Conduct](#code-of-conduct)
2.  [Getting Started](#getting-started)
    *   [Prerequisites](#prerequisites)
    *   [Forking and Cloning](#forking-and-cloning)
    *   [Setting Up Your Development Environment](#setting-up-your-development-environment)
    *   [Running the Cinema Demo](#running-the-cinema-demo)
3.  [How to Contribute](#how-to-contribute)
    *   [Reporting Bugs](#reporting-bugs)
    *   [Suggesting Enhancements](#suggesting-enhancements)
    *   [Your First Code Contribution](#your-first-code-contribution)
    *   [Pull Request Process](#pull-request-process)
4.  [Development Guidelines](#development-guidelines)
    *   [Branching Strategy](#branching-strategy)
    *   [Code Style and Formatting](#code-style-and-formatting)
    *   [Testing](#testing)
    *   [Documentation](#documentation)
    *   [Commit Messages](#commit-messages)
5.  [Understanding the Codebase](#understanding-the-codebase)
    *   [Core Components](#core-components)
    *   [Instrumentation Flow](#instrumentation-flow)
    *   [AST Handling](#ast-handling)
6.  [Focus Areas for Contributions](#focus-areas-for-contributions)
7.  [LLM Provider Setup (for AI-related contributions)](#llm-provider-setup-for-ai-related-contributions)
8.  [Community and Communication](#community-and-communication)

## 1. Code of Conduct

ElixirScope is dedicated to providing a welcoming and inclusive experience for everyone. All contributors are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) (you'll need to create this file). Please read it before participating.

## 2. Getting Started

### Prerequisites

*   Elixir ~> 1.15 (Check `mix.exs` for the exact version).
*   Erlang/OTP (compatible with your Elixir version).
*   Git.
*   (Optional, for AI/LLM contributions) API keys for Google Gemini or Vertex AI.

### Forking and Cloning

1.  **Fork** the `nshkrdotcom/ElixirScope` repository on GitHub.
2.  **Clone** your fork locally:
    ```bash
    git clone https://github.com/YOUR_USERNAME/ElixirScope.git
    cd ElixirScope
    ```
3.  **Add an upstream remote** to keep your fork in sync:
    ```bash
    git remote add upstream https://github.com/nshkrdotcom/ElixirScope.git
    ```

### Setting Up Your Development Environment

1.  **Install Dependencies:**
    ```bash
    mix deps.get
    ```
2.  **Compile the Project:**
    ```bash
    mix compile
    ```
    This will also run the ElixirScope compile-time instrumentation on its own code (if configured, though usually ElixirScope excludes itself).

3.  **Run Tests:** Ensure everything is set up correctly by running the basic test suite:
    ```bash
    mix test
    ```
    This command excludes live API tests by default. See the [Testing](#testing) section for more details.

### Running the Cinema Demo

The `cinema_demo` application within `test_apps/` is a great way to see ElixirScope in action and test your changes:

```bash
cd test_apps/cinema_demo
mix deps.get
mix compile
./run_showcase.sh
```
This script starts ElixirScope, runs various scenarios, and demonstrates its core features.

## 3. How to Contribute

### Reporting Bugs

*   **Check Existing Issues:** Before submitting a new bug report, please search the [GitHub Issues](https://github.com/nshkrdotcom/ElixirScope/issues) to see if the bug has already been reported.
*   **Provide Detailed Information:** If you find a new bug, please open an issue and include:
    *   A clear and descriptive title.
    *   Steps to reproduce the bug.
    *   What you expected to happen.
    *   What actually happened (including error messages and stack traces if applicable).
    *   Your Elixir and Erlang versions.
    *   ElixirScope version (or commit SHA if using a development branch).
    *   Relevant code snippets if possible.

### Suggesting Enhancements

*   We welcome suggestions for new features or improvements to existing ones!
*   Please open an issue on GitHub, clearly describing your suggestion, why it would be beneficial, and any potential implementation ideas you might have.
*   Check existing issues first to see if a similar enhancement has already been discussed.

### Your First Code Contribution

If you're new to ElixirScope or open source, here are some good places to start:

*   **"Good First Issue" Label:** Look for issues tagged with `good first issue` or `help wanted` in the [GitHub Issues](https://github.com/nshkrdotcom/ElixirScope/issues).
*   **Improve Documentation:** Typos, unclear explanations, or missing examples in the README, guides, or code comments are always great contributions.
*   **Add More Tests:** Increasing test coverage, especially for edge cases or new features, is highly valuable.
*   **Refactor Small Pieces of Code:** If you see an area that could be clarified or made more efficient, propose a small refactor.

Before starting on a significant code contribution, it's a good idea to open an issue or comment on an existing one to discuss your approach with the maintainers.

### Pull Request Process

1.  **Ensure your fork is up-to-date** with the `upstream/main` branch:
    ```bash
    git checkout main
    git pull upstream main
    git push origin main # Update your fork's main
    ```
2.  **Create a new feature branch** from your `main` branch:
    ```bash
    git checkout -b my-feature-branch
    ```
3.  **Make your changes.**
    *   Follow the [Code Style and Formatting](#code-style-and-formatting) guidelines.
    *   Add relevant tests for your changes.
    *   Ensure all tests pass (`mix test`).
    *   Update documentation if necessary.
4.  **Commit your changes** following the [Commit Messages](#commit-messages) guidelines.
5.  **Push your feature branch** to your fork:
    ```bash
    git push origin my-feature-branch
    ```
6.  **Open a Pull Request (PR)** on the `nshkrdotcom/ElixirScope` repository.
    *   Provide a clear title and description for your PR.
    *   Reference any related issues (e.g., "Closes #123").
    *   Explain the "why" and "what" of your changes.
    *   If your PR is a work in progress, mark it as a "Draft Pull Request."
7.  **Engage in the PR review process.** Be responsive to feedback and make necessary adjustments.
8.  Once your PR is approved and CI checks pass, a maintainer will merge it.

## 4. Development Guidelines

### Branching Strategy

*   We generally follow a Gitflow-like model.
*   `main`: Represents the latest stable release. Do not commit directly to `main`.
*   Development happens on feature branches (e.g., `feature/new-ast-parser`, `fix/genserver-instrumentation-bug`).
*   Feature branches should be based on `main` (or a relevant development/release branch if active).

### Code Style and Formatting

*   We use `mix format` for code formatting. Please run it before committing your changes:
    ```bash
    mix format
    ```
*   Adhere to common Elixir conventions and best practices.
*   Use `Credo` for static code analysis and aim to address its suggestions:
    ```bash
    mix credo --strict
    ```

### Testing

*   **Write Tests:** All new features and bug fixes should be accompanied by tests.
*   **Unit Tests:** For individual modules and functions.
*   **Integration Tests:** For interactions between different components of ElixirScope.
*   **Test Coverage:** Aim to maintain or increase test coverage. You can check coverage with:
    ```bash
    mix test --cover
    # For HTML report (after running with --cover)
    mix coveralls.html
    open cover/excoveralls.html
    ```
*   **Running Test Suites:**
    *   `mix test`: Runs most tests (excludes `:live_api` by default).
    *   `mix test.all`: Runs all tests, including those tagged `:live_api` (requires LLM API keys for some).
    *   `mix test.fast`: A quicker subset for rapid feedback.
    *   `mix test.gemini`, `mix test.vertex`, `mix test.mock`: For LLM provider-specific tests.
    *   `mix test path/to/your_test.exs`: To run a specific test file.

### Documentation

*   **Module and Function Docs:** Use `@moduledoc` and `@doc` extensively. Explain the purpose, arguments, return values, and provide examples.
*   **README and Guides:** Update relevant sections of `README.md`, this `CONTRIBUTING.md`, or other guides if your changes affect them.
*   **Generate Docs:** You can generate documentation locally using:
    ```bash
    mix docs
    ```

### Commit Messages

*   Follow conventional commit message format (e.g., `feat: Add support for XYZ`, `fix: Correct race condition in ABC`).
*   Use a clear and concise subject line (max 50 characters).
*   Provide a more detailed body if necessary, explaining the "why" of the change.
*   Reference issue numbers if applicable (e.g., `Fixes #42`).

## 5. Understanding the Codebase

ElixirScope is a complex system. Here's a brief overview of key areas:

*   **`lib/elixir_scope.ex`**: Main public API module.
*   **`lib/elixir_scope/application.ex`**: Application supervision tree.
*   **`lib/elixir_scope/config.ex`**: Configuration management.
*   **Core Subdirectories:**
    *   **`lib/elixir_scope/compiler/`**: Contains the `Mix.Tasks.Compile.ElixirScope` custom compiler.
    *   **`lib/elixir_scope/ast/`**: Modules for AST transformation (`Transformer`, `EnhancedTransformer`, `InjectorHelpers`).
    *   **`lib/elixir_scope/capture/`**: Modules responsible for runtime event capture (`InstrumentationRuntime`, `Ingestor`, `RingBuffer`, `TemporalBridge`, `TemporalStorage`).
    *   **`lib/elixir_scope/storage/`**: Data storage mechanisms (`DataAccess`, `EventStore`).
    *   **`lib/elixir_scope/query/`**: Query engine for retrieving events.
    *   **`lib/elixir_scope/ai/`**: AI and rule-based analysis components (`CodeAnalyzer`, `PatternRecognizer`, `ComplexityAnalyzer`, LLM clients and providers).
    *   **`lib/elixir_scope/ast_repository/`**: Foundation for the future AST repository (`Parser`, `ModuleData`, `FunctionData`, `Repository`, `RuntimeCorrelator`).
    *   **`lib/elixir_scope/distributed/`**: (Likely for future use) Distributed tracing components.
*   **`test_apps/cinema_demo/`**: A full-fledged demo application that uses ElixirScope. Excellent for testing end-to-end functionality.

### Instrumentation Flow (Simplified)

1.  **`Mix.Tasks.Compile.ElixirScope`** (compile-time):
    *   Reads `.ex` file.
    *   Calls `AI.CodeAnalyzer` (which uses `PatternRecognizer` & `ComplexityAnalyzer`) to get a basic instrumentation plan.
    *   Uses `AST.Transformer` (with `AST.InjectorHelpers`) to modify the code's AST, injecting calls.
    *   (Future: `AST.EnhancedTransformer` and `CompileTime.Orchestrator` will allow more granular, plan-driven instrumentation).
2.  **Instrumented Code** (runtime):
    *   Calls functions in `Capture.InstrumentationRuntime`.
3.  **`Capture.InstrumentationRuntime`** (runtime):
    *   Formats event data.
    *   Passes data to `Capture.Ingestor`.
    *   For AST-correlated events, forwards to `Capture.TemporalBridge`.
4.  **`Capture.Ingestor`** (runtime): Writes to `Capture.RingBuffer`.
5.  **Async Workers** (e.g., `Capture.AsyncWriterPool` consuming from ring buffers - runtime): Process and store events, potentially in `Storage.EventStore` or `Storage.DataAccess`.
6.  **`Capture.TemporalBridge`** (runtime): Works with `Capture.TemporalStorage` to store and query AST-correlated events for the "Cinema Debugger."

### AST Handling

*   **Parsing:** Primarily done via `Code.string_to_quoted/2` in the compiler and analysis modules.
*   **Transformation:** `AST.Transformer` and `AST.EnhancedTransformer` use `Macro.prewalk/3` and `quote do ... end` to manipulate ASTs.
*   **AST Node IDs:** `ASTRepository.Parser` can assign unique `:ast_node_id` metadata to AST nodes. `ASTRepository.InstrumentationMapper` also generates these for its plans. These IDs are crucial for linking runtime events back to specific code constructs.

## 6. Focus Areas for Contributions

(As listed in the README)

*   🌐 Phoenix web interface for Cinema Debugger
*   🎨 Visual debugging tools and timeline UI
*   🔍 Enhanced AST analysis patterns (improving `PatternRecognizer`, `ComplexityAnalyzer`)
*   🧠 Deeper AI/LLM integration into instrumentation planning and debugging suggestions.
*   🌳 Implementing the persistent AST Repository and Code Property Graph generation.
*   🔗 Enhancing the `RuntimeCorrelator` and `TemporalBridge` for more sophisticated AST-runtime linking.
*   📚 Documentation improvements and tutorials.
*   🧪 Adding more property-based tests (using `StreamData`) and chaos testing.

## 7. LLM Provider Setup (for AI-related contributions)

If you're working on features involving the LLM clients (`lib/elixir_scope/ai/llm/`):

*   **Mock Provider:** `ElixirScope.AI.LLM.Providers.Mock` is used by default and for most tests. It requires no setup.
*   **Gemini:**
    *   Set the `GOOGLE_API_KEY` environment variable:
        ```bash
        export GOOGLE_API_KEY="your-actual-gemini-api-key"
        ```
    *   To run tests that make live calls to Gemini: `mix test.gemini` or `mix test.llm.live`.
*   **Vertex AI:**
    *   Set the `VERTEX_JSON_FILE` environment variable to the path of your Google Cloud service account JSON key file:
        ```bash
        export VERTEX_JSON_FILE="/path/to/your-service-account-key.json"
        ```
    *   Ensure the service account has permissions for Vertex AI.
    *   To run tests that make live calls to Vertex AI: `mix test.vertex` or `mix test.llm.live`.

**Important:** Never commit your API keys or service account files to the repository.

## 8. Community and Communication

*   **GitHub Issues:** For bug reports, feature requests, and discussions.
*   **Pull Requests:** For submitting code changes.
*   (Consider adding a Discord/Slack channel if the community grows).

We're excited to see your contributions and build an amazing tool together! If you have any questions, don't hesitate to open an issue.
