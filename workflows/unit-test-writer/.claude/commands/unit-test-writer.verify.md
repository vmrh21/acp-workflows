# /unit-test-writer.verify - Run and Validate Generated Tests

## Purpose
Executes all generated tests to ensure they run correctly, validates test quality, identifies and fixes any failures, and confirms that tests accurately validate the intended functionality.

## Prerequisites
- `/unit-test-writer.generate` has created test files
- Testing framework is installed
- Dependencies are available

## Process

1. **Detect Test Command**
   - Identify how to run tests based on language/framework:
     * JavaScript: `npm test`, `jest`, `mocha`
     * Python: `pytest`, `python -m unittest`
     * Java: `mvn test`, `gradle test`
     * Go: `go test ./...`
     * Ruby: `rspec`, `rake test`
   - Check project configuration (package.json scripts, Makefile, etc.)
   - Verify testing framework is installed

2. **Run All Tests**
   - Execute test suite using detected command
   - Capture test output (stdout, stderr)
   - Record execution time
   - Track pass/fail status for each test
   - Show real-time progress:
   ```
   Running tests...
   ✓ validation.test.js (8/8 passed) - 0.5s
   ✓ user.test.js (12/12 passed) - 0.8s
   ✗ auth.test.js (10/12 passed, 2 failed) - 1.2s
   ```

3. **Analyze Test Results**

   **Passing Tests:**
   - Count total passing tests
   - Verify tests are meaningful (not just empty passes)
   - Check assertions are being made
   - Validate test isolation (no interdependencies)

   **Failing Tests:**
   - Identify which tests failed
   - Capture error messages and stack traces
   - Categorize failure types:
     * Syntax errors in test code
     * Mock/stub configuration issues
     * Incorrect assertions
     * Actual bugs in source code (rare, but possible)
     * Environmental issues (missing dependencies, etc.)
   - Prioritize fixes by failure type

4. **Fix Test Failures**

   For each failing test:

   **Syntax Errors:**
   - Fix import statements
   - Correct function/method calls
   - Fix typos in test code
   - Update to match language syntax

   **Mock Configuration Issues:**
   - Properly configure mock objects
   - Set up mock return values
   - Ensure mocks are applied before tests run
   - Verify mock expectations

   **Assertion Problems:**
   - Fix incorrect expected values
   - Use correct assertion methods
   - Handle async assertions properly
   - Check for type mismatches

   **Environment Issues:**
   - Install missing test dependencies
   - Configure test environment variables
   - Set up required test fixtures
   - Handle platform-specific issues

5. **Re-run Fixed Tests**
   - Run tests again after fixes
   - Verify failures are resolved
   - Ensure no new failures introduced
   - Continue until all tests pass or issues are documented

6. **Validate Test Quality**

   **Check Test Independence:**
   - Run tests in random order
   - Verify each test can run standalone
   - Ensure no shared state between tests
   - Check for side effects

   **Verify Assertions:**
   - Ensure every test makes assertions
   - Check assertions are meaningful
   - Verify tests actually test something
   - Confirm tests would fail if code breaks

   **Review Test Coverage:**
   - Ensure happy path is covered
   - Verify edge cases are tested
   - Check error handling is validated
   - Confirm boundary conditions tested

7. **Performance Check**
   - Measure total test execution time
   - Identify slow tests (>1s)
   - Check for timeout issues
   - Recommend optimizations for slow tests

8. **Generate Verification Report**
   - Create detailed report with:
     * Total tests run
     * Pass/fail breakdown
     * Execution time
     * Failures fixed vs. remaining issues
     * Quality assessment
     * Recommendations
   - Save to `artifacts/unit-test-writer/reports/verification-report-{timestamp}.md`

## Output

- **Verification Report**: `artifacts/unit-test-writer/reports/verification-report-{timestamp}.md`
  - Test execution summary
  - Pass/fail statistics
  - Detailed failure analysis (if any)
  - Fixes applied
  - Quality assessment
  - Performance metrics
  - Recommendations for improvements

- **Updated Test Files**: Fixed versions of any tests that had failures
  - Syntax errors corrected
  - Mocks properly configured
  - Assertions fixed

## Usage Examples

Verify all tests:
```
/unit-test-writer.verify
```

Verify specific test file:
```
/unit-test-writer.verify __tests__/auth.test.js
```

Verify with verbose output:
```
/unit-test-writer.verify --verbose
```

## Success Criteria

After running this command, you should have:
- [ ] All tests executed successfully
- [ ] Test failures identified and fixed
- [ ] Test quality validated
- [ ] Test independence confirmed
- [ ] Performance issues identified
- [ ] Verification report generated
- [ ] All tests passing (or issues documented)

## Next Steps

After completing this phase:
1. Review verification report in `artifacts/unit-test-writer/reports/`
2. Address any remaining failures or quality issues
3. Run `/unit-test-writer.report` to generate coverage analysis
4. Or run tests manually with coverage: `npm test -- --coverage`

## Notes

- **Iterative Fixes**: May need multiple runs to fix all failures
- **Auto-Fix**: Attempts to automatically fix common issues
- **Manual Review**: Complex failures may need manual investigation
- **Quality Focus**: Ensures tests are meaningful, not just passing
- **Performance**: Identifies and reports slow tests
- **Test Commands**:
  - JavaScript: `npm test` or `jest --coverage`
  - Python: `pytest --cov` or `python -m unittest`
  - Java: `mvn test` with JaCoCo
  - Go: `go test -cover ./...`
  - Ruby: `rspec --format documentation`
