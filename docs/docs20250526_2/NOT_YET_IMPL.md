based on the attach docs, where do these 'not yet implemented' tests fall on our priority list?

```bash
home@Desktop:~/p/g/n/ElixirScope$ mix test.trace | grep "not yet"
warning: the following clause will never match:

    {:error, reason}

because it attempts to match on the result of:

    save_to_database(data)

which has type:

    dynamic(:ok)

└─ nofile: ComplexModule.save_results/1

    warning: ElixirScope.Capture.TemporalStorage.start_link/0 is undefined (module ElixirScope.Capture.TemporalStorage is not available or is yet to be defined)
    │
 12 │       {:ok, storage} = TemporalStorage.start_link()
    │                                        ~
    │
    └─ test/elixir_scope/capture/temporal_storage_test.exs:12:40: ElixirScope.Capture.TemporalStorageTest."test temporal event storage with AST correlation stores events with temporal indexing and AST links"/1

    warning: ElixirScope.Capture.TemporalStorage.store_event/2 is undefined (module ElixirScope.Capture.TemporalStorage is not available or is yet to be defined)
    │
 23 │         :ok = TemporalStorage.store_event(storage, event)
    │                               ~
    │
    └─ test/elixir_scope/capture/temporal_storage_test.exs:23:31: ElixirScope.Capture.TemporalStorageTest."test temporal event storage with AST correlation stores events with temporal indexing and AST links"/1

    warning: ElixirScope.Capture.TemporalStorage.get_events_in_range/3 is undefined (module ElixirScope.Capture.TemporalStorage is not available or is yet to be defined)
    │
 27 │       {:ok, range_events} = TemporalStorage.get_events_in_range(storage, 1000, 2000)
    │                                             ~
    │
    └─ test/elixir_scope/capture/temporal_storage_test.exs:27:45: ElixirScope.Capture.TemporalStorageTest."test temporal event storage with AST correlation stores events with temporal indexing and AST links"/1

  * test AI and instrumentation (not yet implemented) update_instrumentation returns not implemented error (1.3ms) [L#231]
  * test AI and instrumentation (not yet implemented) AI functions return not running error when stopped (0.4ms) [L#236]
  * test event querying (not yet implemented) get_state_at returns not implemented error (0.1ms) [L#197]
  * test event querying (not yet implemented) get_state_history returns not implemented error (0.1ms) [L#192]
  * test event querying (not yet implemented) get_events returns not implemented error (0.1ms) [L#182]
  * test event querying (not yet implemented) get_events with query returns not implemented error (0.07ms) [L#187]
  * test AI and instrumentation (not yet implemented) analyze_codebase returns not implemented error (0.09ms) [L#226]
  * test event querying (not yet implemented) functions return not running error when stopped (0.4ms) [L#208]
  * test event querying (not yet implemented) get_message_flow returns not implemented error (0.1ms) [L#203]
ElixirScope: Failed to instrument 1 files:
  lib/broken_module.ex: "** (ArgumentError) cannot convert the given list to a string.\n\nTo be converted to a string, a list must either be empty or only\ncontain the following elements:\n\n  * strings\n  * integers representing Unicode code points\n  * a list containing one of these three elements\n\nPlease check the given list or call inspect/1 to get the list representation, got:\n\n[line: 2, column: 12, end_line: 4, end_column: 3, error_type: :mismatched_delimiter, opening_delimiter: :\"(\", closing_delimiter: :end, expected_delimiter: :\")\"]\n\n    (elixir 1.18.3) lib/list.ex:1124: List.to_string/1\n    (elixir_scope 0.1.0) lib/elixir_scope/compiler/mix_task.ex:117: Mix.Tasks.Compile.ElixirScope.transform_file/3\n    (elixir 1.18.3) lib/enum.ex:1714: Enum.\"-map/2-lists^map/1-1-\"/2\n    (elixir_scope 0.1.0) lib/elixir_scope/compiler/mix_task.ex:63: Mix.Tasks.Compile.ElixirScope.transform_project/2\n    (elixir_scope 0.1.0) lib/elixir_scope/compiler/mix_task.ex:27: Mix.Tasks.Compile.ElixirScope.run/1\n    test/elixir_scope/compiler/mix_task_test.exs:98: ElixirScope.Compiler.MixTaskTest.\"test run/1 handles parse errors gracefully\"/1\n    (ex_unit 1.18.3) lib/ex_unit/runner.ex:511: ExUnit.Runner.exec_test/2\n    (stdlib 6.2.2) timer.erl:595: :timer.tc/2\n    (ex_unit 1.18.3) lib/ex_unit/runner.ex:433: anonymous fn/6 in ExUnit.Runner.spawn_test_monitor/4\n"

```


Based on the attached documentation, the 'not yet implemented' tests fall into **different priority categories**:

## **High Priority (Part of Current Action Plan)**

These are directly related to the current 7-day implementation plan:

### **Day 2 (Current Focus) - TemporalBridge**
- `test/elixir_scope/capture/temporal_storage_test.exs` - **HIGH PRIORITY**
  - This is core to the TemporalBridge implementation happening today
  - Foundation for Cinema Debugger

### **Day 3 - InstrumentationMapper**
- `test/elixir_scope/capture/instrumentation_runtime_integration_test.exs` - **HIGH PRIORITY**
  - Critical for AST-runtime correlation

### **Day 4-5 - Enhanced Correlation & Storage**
- `test/elixir_scope/llm/hybrid_analyzer_test.exs` - **MEDIUM-HIGH PRIORITY**
- `test/elixir_scope/llm/context_builder_test.exs` - **MEDIUM-HIGH PRIORITY**
  - These support the hybrid AST-runtime analysis

### **Day 6-7 - Integration Testing**
- `test/elixir_scope/integration/end_to_end_hybrid_test.exs` - **HIGH PRIORITY**
  - Critical for validating the entire system

## **Medium Priority (Future Phases)**

These are valuable but not part of the immediate 7-day plan:

### **AST Repository Parser Tests**
- `test/elixir_scope/ast_repository/parser_test.exs` - **MEDIUM PRIORITY**
  - Parser is already implemented and working

### **Performance Tests**
- `test/elixir_scope/performance/hybrid_benchmarks_test.exs` - **MEDIUM PRIORITY**
  - Explicitly out of scope per action plan

### **Distributed System Tests**
- `test/elixir_scope/distributed/multi_node_test.exs` - **MEDIUM PRIORITY**
  - Not part of core AST functionality

## **Low Priority (Explicitly Out of Scope)**

Per the action plan, these are **explicitly out of scope**:

### **Main API Tests**
- `test/elixir_scope_test.exs` - AI/instrumentation functions - **LOW PRIORITY**
  - `analyze_codebase/0`
  - `update_instrumentation/1`
  - `get_events/0`
  - `get_state_history/1`
  - `get_state_at/2`
  - `get_message_flow/2`

### **Production Tests**
- `test/integration/production_phoenix_test.exs` - **LOW PRIORITY**
  - Marked as skip, no production app available

## **Implementation Order**

Based on the action plan, focus should be:

1. **Today (Day 2)**: Complete TemporalBridge implementation
   - Focus on `temporal_storage_test.exs` functionality
   
2. **Day 3**: InstrumentationMapper
   - Focus on `instrumentation_runtime_integration_test.exs`
   
3. **Day 4-5**: Enhanced correlation
   - Focus on hybrid analyzer and context builder tests
   
4. **Day 6-7**: Integration testing
   - Focus on end-to-end hybrid test

The main ElixirScope API functions (`get_events`, `get_state_history`, etc.) are placeholders for future functionality and should remain as "not implemented yet" for now, as they're not part of the core AST repository value proposition.

