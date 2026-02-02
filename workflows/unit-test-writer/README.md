# Unit Test Writer

Analyzes a repository to understand its functionality and generates comprehensive unit tests in the same programming language without introducing any new features.

## Overview

This workflow guides you through automated unit test generation using a structured 5-phase approach:

### 1. Analyze
Scans the repository to identify all source files, detect programming languages, understand functionality, and create a comprehensive map of what needs testing.

### 2. Plan
Creates a detailed test coverage plan defining which tests will be written, test file structure, coverage goals, and testing strategy for each component.

### 3. Generate
Generates comprehensive unit tests for all identified functions and methods using the same programming language as source code, with thorough coverage of happy paths, edge cases, and error handling.

### 4. Verify
Executes all generated tests, validates quality, identifies and fixes failures, and confirms tests accurately validate intended functionality.

### 5. Report
Generates comprehensive test coverage reports including metrics, gap analysis, and recommendations for complete coverage.

## Getting Started

### Prerequisites
- Repository with source code to test
- Read/write access to the repository
- Testing framework installed (or will be recommended)
- Language-specific development environment

### Installation
1. Clone this workflow repository
2. Load the workflow in your ACP session
3. Run `/unit-test-writer.analyze` to begin

## Workflow Phases

### Phase 1: Analyze
**Command:** `/unit-test-writer.analyze`

Performs comprehensive repository analysis to understand structure, identify languages, map all functions/methods, and assess current test coverage. This is a read-only operation that never modifies source code.

**Output:**
- `artifacts/unit-test-writer/analysis/repository-analysis-{timestamp}.md` - Complete repository analysis
- `artifacts/unit-test-writer/analysis/testable-code-map-{timestamp}.json` - Structured map of testable code

### Phase 2: Plan
**Command:** `/unit-test-writer.plan`

Creates a comprehensive test coverage strategy including test file structure, prioritized test generation order, specific test cases for each function, coverage goals, and framework selections.

**Output:**
- `artifacts/unit-test-writer/plans/test-coverage-plan-{timestamp}.md` - Detailed test plan
- `artifacts/unit-test-writer/plans/test-checklist-{timestamp}.md` - Progress tracking checklist

### Phase 3: Generate
**Command:** `/unit-test-writer.generate`

Generates actual unit test files for all components, writing tests in the same language as source code, following best practices, with comprehensive coverage including happy paths, edge cases, error handling, and proper mocking of dependencies.

**Output:**
- Test files created in repository test directories
- `artifacts/unit-test-writer/reports/generation-summary-{timestamp}.md` - Summary of generated tests

### Phase 4: Verify
**Command:** `/unit-test-writer.verify`

Runs all generated tests, validates quality, fixes any failures (syntax errors, mock issues, assertion problems), and ensures tests are meaningful and properly isolated.

**Output:**
- Updated test files with fixes applied
- `artifacts/unit-test-writer/reports/verification-report-{timestamp}.md` - Test execution results

### Phase 5: Report
**Command:** `/unit-test-writer.report`

Generates comprehensive coverage reports with metrics (line, branch, function, statement coverage), identifies gaps, provides recommendations, and creates visualizations of test coverage.

**Output:**
- `artifacts/unit-test-writer/reports/coverage-report-{timestamp}.md` - Detailed coverage analysis
- `artifacts/unit-test-writer/reports/coverage-data-{timestamp}.json` - Machine-readable coverage data
- HTML coverage reports (if supported by framework)

## Available Agents

This workflow includes the following expert agents:

### Tessa - Test Engineer
Unit testing specialist focused on generating comprehensive, maintainable test suites.

**Expertise:** TDD principles, unit testing frameworks, test coverage analysis, mocking/stubbing, edge case testing

### Carlos - Code Analyst
Code analysis specialist for understanding repository structure and mapping testable code.

**Expertise:** Static code analysis, repository architecture, dependency tracing, function identification, complexity assessment

### Quinn - QA Specialist
Quality assurance expert for validating tests and ensuring comprehensive coverage.

**Expertise:** Test quality assessment, test coverage metrics, test execution, quality standards, test maintainability

## Output Artifacts

All workflow outputs are saved in the `artifacts/unit-test-writer/` directory:

```
artifacts/unit-test-writer/
├── analysis/        # Repository analysis and code maps
├── plans/          # Test coverage plans and checklists
└── reports/        # Generation summaries and coverage reports
```

Test files are created in the repository following language conventions:
- JavaScript/TypeScript: `__tests__/` or `*.test.js`
- Python: `tests/test_*.py`
- Java: `src/test/java/`
- Go: `*_test.go`
- Ruby: `spec/*_spec.rb`

## Example Usage

```bash
# Step 1: Analyze the repository
/unit-test-writer.analyze /path/to/repository

# Step 2: Create test coverage plan
/unit-test-writer.plan

# Step 3: Generate all unit tests
/unit-test-writer.generate

# Step 4: Verify tests run correctly
/unit-test-writer.verify

# Step 5: Generate coverage report
/unit-test-writer.report
```

## Configuration

This workflow is configured via `.ambient/ambient.json`. Key settings:

- **Name:** Unit Test Writer
- **Description:** Analyzes a repository to understand its functionality and generates comprehensive unit tests
- **Artifact Paths:**
  - Analysis Reports: `artifacts/unit-test-writer/analysis/`
  - Coverage Reports: `artifacts/unit-test-writer/reports/`
  - Test Plans: `artifacts/unit-test-writer/plans/`

## Customization

You can customize this workflow by:

1. **Modifying agents:** Edit files in `.claude/agents/` to adjust agent expertise or behavior
2. **Adding commands:** Create new command files in `.claude/commands/` for additional test generation strategies
3. **Adjusting configuration:** Update `.ambient/ambient.json` to change prompts or output locations
4. **Changing coverage goals:** Modify test plans to target different coverage percentages

## Best Practices

1. **Run analysis first** - Always start with `/analyze` to understand repository structure
2. **Review the plan** - Check test coverage plan before generating tests
3. **Generate incrementally** - Can generate tests by directory or file for large repositories
4. **Verify early and often** - Run `/verify` after generating each batch of tests
5. **Never modify source** - Workflow only reads source code, never changes it
6. **Use existing frameworks** - Respects and uses existing testing frameworks when present
7. **Focus on quality** - Aim for meaningful tests, not just high coverage numbers
8. **Keep tests maintainable** - Generated tests follow best practices for long-term maintenance

## Language Support

This workflow supports multiple programming languages:

- **JavaScript/TypeScript**: Jest, Mocha, Jasmine, Vitest
- **Python**: pytest, unittest, nose2
- **Java**: JUnit, TestNG, Mockito
- **Go**: testing package, testify
- **Ruby**: RSpec, Minitest
- **And more**: Automatically adapts to detected languages

## Troubleshooting

**Problem:** Tests fail during verification
**Solution:** Review verification report for specific failures. Common issues include mock configuration, assertion errors, or missing dependencies. The workflow attempts to auto-fix many issues.

**Problem:** Coverage report shows gaps
**Solution:** Review gap analysis in coverage report. Run `/generate` for specific files or directories to add tests for uncovered code.

**Problem:** Test framework not detected
**Solution:** Ensure project has standard configuration files (package.json, requirements.txt, etc.). Workflow will recommend frameworks if none found.

**Problem:** Generated tests don't match project style
**Solution:** Edit agent personas in `.claude/agents/` to specify preferred testing patterns, or manually adjust generated tests to match team conventions.

## Contributing

To improve this workflow:
1. Fork the repository
2. Make your changes to agents or commands
3. Test thoroughly with different repositories
4. Submit a pull request

## License

MIT

## Support

For issues or questions:
- Open an issue in the repository
- Refer to the [ACP documentation](https://ambient-code.github.io/vteam)

---

**Created with:** ACP Workflow Creator
**Workflow Type:** Custom
**Version:** 1.0.0
