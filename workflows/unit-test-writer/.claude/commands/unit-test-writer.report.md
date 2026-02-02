# /unit-test-writer.report - Create Detailed Test Coverage Report

## Purpose
Generates a comprehensive test coverage report including metrics, gap analysis, and recommendations for achieving complete test coverage of the repository.

## Prerequisites
- Tests have been generated with `/unit-test-writer.generate`
- Tests have been verified with `/unit-test-writer.verify`
- Test suite is passing (or failures are documented)

## Process

1. **Run Coverage Analysis**
   - Execute tests with coverage instrumentation:
     * JavaScript: `jest --coverage` or `nyc npm test`
     * Python: `pytest --cov=.` or `coverage run -m pytest`
     * Java: `mvn test` (with JaCoCo plugin)
     * Go: `go test -cover ./...`
     * Ruby: `rspec --coverage` (with SimpleCov)
   - Collect coverage data
   - Generate coverage reports

2. **Calculate Coverage Metrics**

   **Line Coverage:**
   - Percentage of lines executed during tests
   - Identify uncovered lines
   - Calculate per-file and overall

   **Branch Coverage:**
   - Percentage of code branches (if/else) executed
   - Identify untested branches
   - Highlight critical decision points missed

   **Function Coverage:**
   - Percentage of functions/methods tested
   - List untested functions
   - Note private vs. public function coverage

   **Statement Coverage:**
   - Percentage of statements executed
   - Identify dead code
   - Calculate coverage by module/component

3. **Identify Coverage Gaps**

   **Completely Untested Files:**
   - List files with 0% coverage
   - Explain why they might be missing tests
   - Prioritize for additional test generation

   **Partially Covered Files:**
   - Files below target coverage threshold
   - Identify specific functions needing tests
   - List uncovered branches and conditions

   **Uncovered Edge Cases:**
   - Error handling paths not tested
   - Boundary conditions not covered
   - Exception scenarios not validated

4. **Analyze Test Quality**

   **Test Distribution:**
   - Count tests per source file
   - Identify over/under-tested areas
   - Check balance of test types (unit vs. integration)

   **Test Effectiveness:**
   - Mutation testing concepts (would tests catch bugs?)
   - Assertion quality and thoroughness
   - Test maintenance burden

5. **Generate Visualizations**

   **Coverage Heatmap:**
   ```
   File                    Coverage    Tests    Status
   ────────────────────────────────────────────────────
   src/utils/validation    ████████░░  92%      12      ✓
   src/models/user         ██████████  100%     18      ✓
   src/services/auth       ██████░░░░  78%      15      ⚠️
   src/api/endpoints       ████░░░░░░  45%      8       ❌
   ```

   **Coverage by Category:**
   ```
   Overall Coverage: 87%
   ├─ Line Coverage:     89%
   ├─ Branch Coverage:   82%
   ├─ Function Coverage: 91%
   └─ Statement Coverage: 88%
   ```

6. **Provide Recommendations**

   **Quick Wins:**
   - Easy-to-test functions currently untested
   - Files needing just a few more tests for high coverage
   - Common patterns that could use more tests

   **Priority Gaps:**
   - Critical functions without coverage
   - Security-sensitive code needing tests
   - Complex logic with low coverage

   **Testing Strategy:**
   - Recommended next steps for improvement
   - Suggested coverage targets by component
   - Balance between coverage and maintainability

7. **Compare to Goals**
   - Compare current coverage to target goals
   - Show progress from initial state
   - Highlight achievements and remaining work
   - Calculate coverage improvement

8. **Create Comprehensive Report**
   - Generate detailed markdown report with:
     * Executive summary
     * Coverage metrics and visualizations
     * Gap analysis
     * File-by-file breakdown
     * Recommendations
     * Next steps
   - Save to `artifacts/unit-test-writer/reports/coverage-report-{timestamp}.md`

## Output

- **Coverage Report**: `artifacts/unit-test-writer/reports/coverage-report-{timestamp}.md`
  - Executive summary with key metrics
  - Overall coverage statistics
  - Coverage breakdown by file and module
  - Gap analysis and uncovered code
  - Test quality assessment
  - Prioritized recommendations
  - Next steps for improvement

- **Coverage Data**: `artifacts/unit-test-writer/reports/coverage-data-{timestamp}.json`
  - Machine-readable coverage data
  - Can be used for CI/CD integration
  - Historical tracking

- **HTML Coverage Report**: (if supported by framework)
  - Interactive coverage visualization
  - Line-by-line coverage view
  - Branch coverage details

## Usage Examples

Generate coverage report:
```
/unit-test-writer.report
```

Generate with custom threshold:
```
/unit-test-writer.report --threshold 90%
```

Generate for specific directory:
```
/unit-test-writer.report src/services/
```

## Success Criteria

After running this command, you should have:
- [ ] Complete coverage metrics calculated
- [ ] Coverage gaps identified
- [ ] File-by-file coverage breakdown
- [ ] Quality assessment completed
- [ ] Recommendations provided
- [ ] Comprehensive report generated
- [ ] Coverage data exported

## Next Steps

After completing this phase:
1. Review coverage report in `artifacts/unit-test-writer/reports/`
2. Address critical coverage gaps if needed
3. Run `/unit-test-writer.generate` for specific gaps
4. Set up CI/CD to track coverage over time
5. Celebrate comprehensive test coverage! 🎉

## Notes

- **Coverage Tools**:
  - JavaScript: Istanbul/NYC, Jest coverage
  - Python: Coverage.py, pytest-cov
  - Java: JaCoCo, Cobertura
  - Go: Built-in coverage tool
  - Ruby: SimpleCov

- **Coverage Goals**:
  - **80%+**: Generally considered good coverage
  - **90%+**: Excellent coverage for critical code
  - **100%**: May not be practical or valuable for all code

- **Quality vs. Quantity**:
  - High coverage doesn't guarantee bug-free code
  - Focus on meaningful tests, not just coverage numbers
  - Some code (getters/setters) may not need tests

- **Continuous Tracking**:
  - Export coverage data for CI/CD tracking
  - Monitor coverage trends over time
  - Set coverage requirements for new code

- **Report Formats**:
  - Markdown: Human-readable summary
  - JSON: Machine-readable data
  - HTML: Interactive visualization
  - Console: Quick overview
