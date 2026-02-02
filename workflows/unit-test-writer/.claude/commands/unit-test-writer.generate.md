# /unit-test-writer.generate - Generate Unit Tests for All Components

## Purpose
Generates comprehensive unit tests for all identified functions and methods in the repository, using the same programming language as the source code, following best practices, and ensuring NO modifications are made to existing source code.

## Prerequisites
- `/unit-test-writer.analyze` has been run successfully
- `/unit-test-writer.plan` has created test coverage plan
- Test file structure is defined
- Testing frameworks are identified

## Process

1. **Load Test Plan and Style Guide**
   - Read test coverage plan
   - Get prioritized list of components to test
   - Understand test file structure
   - Review testing frameworks and tools to use
   - **CRITICAL: Load test style guide** (if existing tests were analyzed)
   - **Understand scope** (PR, specific functionality, or comprehensive)
   - Prepare to match detected patterns and conventions

2. **For Each Source File (in Priority Order)**

   **Step A: Read Source Code**
   - Load the source file
   - Identify all testable functions/methods
   - Understand function signatures, parameters, and return types
   - Note dependencies and imports
   - **CRITICAL**: Do NOT modify the source file

   **Step B: Create Test File**
   - Determine test file path based on conventions
   - Create test file in appropriate location
   - Add necessary imports and setup
   - Import the source module/class being tested

   **Step C: Generate Test Setup (Following Style Guide)**
   - Add test framework imports (Jest, pytest, JUnit, etc.)
   - **If style guide exists**:
     * Match exact import patterns from existing tests
     * Use same setup/teardown structure (beforeEach, setUp, etc.)
     * Follow detected indentation and formatting
     * Replicate mock creation patterns
   - **If no style guide**:
     * Use framework best practices
   - Create test fixtures if needed
   - Set up mocks for external dependencies
   - Add before/after hooks if necessary

   **Step D: Generate Tests for Each Function (Matching Detected Style)**

   For each function/method, create test cases:

   **CRITICAL: If style guide exists, follow it exactly:**
   - Use detected test naming conventions (describe/it, test_, etc.)
   - Match assertion styles from existing tests
   - Replicate mock/stub patterns
   - Follow same test organization structure
   - Use same code formatting and indentation

   **Happy Path Tests:**
   - Test normal operation with valid inputs
   - Verify correct return values
   - Check expected side effects
   - **Example (style guide present)**: Match naming pattern like `it('should calculate total with valid items', ...)`
   - **Example (no style guide)**: `test_calculate_total_with_valid_items()`

   **Edge Case Tests:**
   - Empty inputs ([], "", null, undefined, 0)
   - Boundary values (min, max, -1, +1)
   - Special characters and unicode
   - Large datasets or values
   - Example: `test_calculate_total_with_empty_cart()`

   **Error Handling Tests:**
   - Invalid input types
   - Missing required parameters
   - Exception/error throwing
   - Error recovery behavior
   - Example: `test_calculate_total_throws_on_negative_price()`

   **Specific Language Patterns:**
   - **JavaScript**: undefined vs null, async/await, promises
   - **Python**: None handling, type errors, exceptions
   - **Java**: null pointer, type safety, exceptions
   - **Go**: error returns, nil checks, panic recovery
   - **Ruby**: nil, exceptions, blocks

   **Step D.1: Ask for Clarification When Uncertain**
   - **If confused about how to test something**: ASK the user
   - **If multiple valid approaches exist**: Present options and ask for preference
   - **If source code is ambiguous**: Request clarification on intended behavior
   - **If unsure about edge cases**: Confirm which scenarios to test
   - **Never guess** - always seek user input when uncertain

   **Step E: Add Test Documentation (Matching Style)**
   - Clear, descriptive test names
   - **If style guide exists**: Match documentation style from existing tests
   - Comments explaining complex test scenarios (if existing tests use comments)
   - Documentation of mocked behavior
   - Expected vs actual value descriptions

3. **Apply Language-Specific Best Practices**

   **JavaScript/TypeScript:**
   ```javascript
   describe('moduleName', () => {
     describe('functionName', () => {
       it('should return correct value for valid input', () => {
         expect(functionName(input)).toBe(expected);
       });

       it('should handle empty input', () => {
         expect(functionName('')).toBe(defaultValue);
       });

       it('should throw error for invalid input', () => {
         expect(() => functionName(null)).toThrow();
       });
     });
   });
   ```

   **Python:**
   ```python
   class TestModuleName:
       def test_function_name_with_valid_input(self):
           result = function_name(valid_input)
           assert result == expected_value

       def test_function_name_with_empty_input(self):
           result = function_name("")
           assert result == default_value

       def test_function_name_raises_on_invalid_input(self):
           with pytest.raises(ValueError):
               function_name(None)
   ```

   **Java:**
   ```java
   class TestClassName {
       @Test
       void testMethodNameWithValidInput() {
           assertEquals(expected, className.methodName(validInput));
       }

       @Test
       void testMethodNameWithEmptyInput() {
           assertEquals(defaultValue, className.methodName(""));
       }

       @Test
       void testMethodNameThrowsOnInvalidInput() {
           assertThrows(IllegalArgumentException.class,
               () -> className.methodName(null));
       }
   }
   ```

   **Go:**
   ```go
   func TestFunctionNameWithValidInput(t *testing.T) {
       result := FunctionName(validInput)
       if result != expected {
           t.Errorf("Expected %v, got %v", expected, result)
       }
   }

   func TestFunctionNameWithEmptyInput(t *testing.T) {
       result := FunctionName("")
       if result != defaultValue {
           t.Errorf("Expected %v, got %v", defaultValue, result)
       }
   }
   ```

4. **Handle Dependencies and Mocking**
   - Identify external dependencies (API calls, database, file system)
   - Create appropriate mocks/stubs
   - Use mocking libraries:
     * JavaScript: jest.mock(), sinon
     * Python: unittest.mock, pytest-mock
     * Java: Mockito
     * Go: gomock, testify/mock
   - Ensure tests are isolated and don't hit real external services

5. **Track Progress**
   - Show progress as tests are generated:
   ```
   Generating tests: [15/47 files]
   ✓ src/utils/validation.js → __tests__/validation.test.js (8 tests)
   ✓ src/models/user.js → __tests__/user.test.js (12 tests)
   🔧 src/services/auth.js → __tests__/auth.test.js (in progress...)
   ```
   - Count tests generated per file
   - Note any complex cases or warnings

6. **Save Generated Tests**
   - Write each test file to appropriate location
   - Ensure correct file permissions
   - Follow project naming conventions
   - Maintain source code organization structure

7. **Create Generation Summary**
   - List all test files created
   - Count total tests generated
   - Note any functions skipped (with reasons)
   - Highlight any warnings or special considerations
   - Save to `artifacts/unit-test-writer/reports/generation-summary-{timestamp}.md`

## Output

- **Test Files**: Created in repository test directories
  - Follow project structure and naming conventions
  - Use detected or recommended testing frameworks
  - Include comprehensive test coverage

- **Generation Summary**: `artifacts/unit-test-writer/reports/generation-summary-{timestamp}.md`
  - List of all test files created
  - Test counts per file and total
  - Functions tested vs. skipped
  - Warnings and recommendations
  - Next steps for verification

## Usage Examples

Generate all tests:
```
/unit-test-writer.generate
```

Generate tests for specific directory:
```
/unit-test-writer.generate src/utils/
```

Generate tests for specific file:
```
/unit-test-writer.generate src/services/auth.js
```

## Success Criteria

After running this command, you should have:
- [ ] Test files created for all source files
- [ ] Tests written in same language as source code
- [ ] Comprehensive coverage (happy path, edge cases, errors)
- [ ] Proper use of testing framework and conventions
- [ ] External dependencies properly mocked
- [ ] Clear, descriptive test names
- [ ] NO modifications to source code files
- [ ] Generation summary report created

## Next Steps

After completing this phase:
1. Review generated test files
2. Run `/unit-test-writer.verify` to execute and validate tests
3. Check generation summary for any warnings
4. Run tests manually to verify they work

## Notes

- **No Source Modification**: Source code files are NEVER modified - only test files are created
- **Language Matching**: Tests use the same language as source code
- **Framework Respect**: Uses existing frameworks or best practices for language
- **Comprehensive Coverage**: Aims for thorough testing of all scenarios
- **Incremental Generation**: Can generate tests incrementally by directory or file
- **Mock Isolation**: External dependencies are mocked to keep tests fast and reliable
- **Best Practices**: Follows language-specific testing conventions
- **Documentation**: Tests include clear names and comments
- **CRITICAL - Style Matching**:
  - **If existing tests found**: Generated tests will look and feel exactly like your existing tests
  - Matches naming conventions (describe, it, test_, should, etc.)
  - Uses same assertion styles (expect, assert, should)
  - Replicates mock/stub patterns from your codebase
  - Follows same indentation, formatting, and code style
  - Copies test organization structure
  - Uses same documentation and comment patterns
  - **Goal**: New tests should be indistinguishable from your existing tests
- **Interactive & Adaptive**:
  - **Asks questions when uncertain** about how to test something
  - Presents options when multiple valid approaches exist
  - Seeks clarification on ambiguous code behavior
  - Confirms edge case scenarios with user
  - **Never guesses** - always asks rather than assuming
- **Scope-Based Generation**:
  - **PR scope**: Generates tests only for changed/new code in the pull request
  - **Specific scope**: Generates tests only for specified functionality or files
  - **Comprehensive**: Generates tests for all untested code
