# /unit-test-writer.plan - Create Comprehensive Test Coverage Plan

## Purpose
Creates a detailed plan for test coverage based on repository analysis, defining which tests will be written, test file structure, coverage goals, and testing strategy for each component.

## Prerequisites
- `/unit-test-writer.analyze` has been run successfully
- Repository analysis report exists
- Testable code map is available

## Process

1. **Load Analysis Results**
   - Read repository analysis report
   - Load testable code map
   - Understand repository structure and languages
   - Review existing test coverage
   - **Load test style guide** (if existing tests were found)
   - **Understand testing scope** (PR, specific functionality, or comprehensive)
   - **Adjust planning approach** based on scope:
     * PR scope: Plan tests only for changed/new code
     * Specific scope: Plan tests only for specified functionality
     * Comprehensive: Plan tests for all untested code

2. **Define Test File Structure**
   - **If test style guide exists**:
     * Follow detected file naming conventions exactly
     * Match existing directory structure patterns
     * Use same file organization as existing tests
   - **If no style guide**:
     * Use language/framework defaults:
       - JavaScript/TypeScript: `__tests__/{filename}.test.js` or `{filename}.spec.ts`
       - Python: `tests/test_{filename}.py`
       - Java: `src/test/java/{package}/Test{ClassName}.java`
       - Go: `{filename}_test.go` (same directory)
       - Ruby: `spec/{filename}_spec.rb`
   - Match existing project test conventions if present
   - Create directory structure plan
   - **Ask user for preferences** if multiple valid approaches exist

3. **Prioritize Test Generation**
   - Categorize code by priority:
     * **Critical**: Core business logic, auth, data handling
     * **High**: Public APIs, user-facing features
     * **Medium**: Utility functions, helpers
     * **Low**: Simple getters/setters, trivial functions
   - Order test generation by priority
   - Estimate number of tests per component

4. **Define Test Scope Per Function**
   - For each function/method, plan test cases:
     * **Happy Path**: Normal operation with valid inputs
     * **Edge Cases**: Boundary values, empty inputs, null/undefined
     * **Error Handling**: Invalid inputs, exceptions, error states
     * **Special Cases**: Language-specific edge cases
   - Identify required mocks and stubs
   - Note complex dependencies

5. **Set Coverage Goals**
   - Define target coverage metrics:
     * Line coverage goal (e.g., 80%)
     * Branch coverage goal (e.g., 75%)
     * Function coverage goal (e.g., 90%)
   - Identify acceptable gaps (legacy code, trivial functions)
   - Set priorities for incremental progress

6. **Select Testing Frameworks and Tools**
   - Choose framework for each language:
     * JavaScript/TypeScript: Jest, Mocha, Vitest
     * Python: pytest, unittest
     * Java: JUnit 5, Mockito
     * Go: testing package, testify
     * Ruby: RSpec, Minitest
   - Identify mocking libraries needed
   - Plan test utilities and helpers

7. **Generate Test Plan Document**
   - Create comprehensive plan with:
     * Test file structure map
     * Test generation order (by priority)
     * Detailed test case breakdown per function
     * Coverage goals and metrics
     * Framework and tool selections
     * Estimated test counts
     * Timeline estimate (optional)
   - Save to `artifacts/unit-test-writer/plans/test-coverage-plan-{timestamp}.md`

## Output

- **Test Coverage Plan**: `artifacts/unit-test-writer/plans/test-coverage-plan-{timestamp}.md`
  - Executive summary of plan
  - Test file structure map
  - Component-by-component test breakdown
  - Coverage goals and metrics
  - Frameworks and tools to use
  - Test generation priority order
  - Estimated test counts

- **Test Generation Checklist**: `artifacts/unit-test-writer/plans/test-checklist-{timestamp}.md`
  - Checkbox list of all tests to generate
  - Organized by priority
  - Can be used to track progress

## Usage Examples

Basic usage:
```
/unit-test-writer.plan
```

With custom coverage goals:
```
/unit-test-writer.plan --target-coverage 90%
```

## Success Criteria

After running this command, you should have:
- [ ] Clear test file structure defined
- [ ] All functions categorized by test priority
- [ ] Specific test cases identified for each function
- [ ] Testing frameworks and tools selected
- [ ] Coverage goals established
- [ ] Test generation order determined
- [ ] Comprehensive plan document created

## Next Steps

After completing this phase:
1. Review the test coverage plan in `artifacts/unit-test-writer/plans/`
2. Adjust priorities or coverage goals if needed
3. Run `/unit-test-writer.generate` to start creating tests
4. Or generate tests for specific components first

## Notes

- **Flexible Planning**: Plan can be adjusted based on your needs
- **Incremental Approach**: Tests can be generated in priority order
- **Framework Flexibility**: Respects existing frameworks or suggests best practices
- **Coverage Balance**: Aims for high coverage without over-testing trivial code
- **Estimation**: Provides realistic estimates of test quantity and complexity
- **Scope-Based Planning**:
  - PR scope: Plan focuses only on changed/new code in the pull request
  - Specific scope: Plan targets only specified functionality or files
  - Comprehensive: Plan covers all untested code in repository
- **Style Consistency**:
  - Incorporates detected patterns from existing tests
  - Ensures new tests will match your team's style
  - Uses style guide to define test structure and organization
- **Interactive Approach**:
  - Asks for user preferences when multiple valid approaches exist
  - Seeks clarification on ambiguous requirements
  - Confirms strategy before proceeding to generation
