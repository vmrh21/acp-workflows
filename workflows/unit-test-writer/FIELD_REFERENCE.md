# Unit Test Writer - Field Reference

This document provides detailed information about the configuration fields in `.ambient/ambient.json`.

## Required Fields

### name
- **Type:** string
- **Purpose:** Display name shown in ACP UI
- **Current Value:** "Unit Test Writer"
- **Guidelines:** Keep concise (2-5 words), use title case

### description
- **Type:** string
- **Purpose:** Explains workflow purpose in UI
- **Current Value:** "Analyzes a repository to understand its functionality and generates comprehensive unit tests"
- **Guidelines:** 1-3 sentences, clear and specific about what the workflow does

### systemPrompt
- **Type:** string
- **Purpose:** Defines AI agent's role and behavior throughout the workflow
- **Current Value:** See `.ambient/ambient.json`
- **Guidelines:**
  - Start with clear role definition
  - List key responsibilities
  - Describe workflow methodology step-by-step
  - Reference available commands
  - Specify output locations
  - Include critical requirements (never modify source code, use same language, etc.)

### startupPrompt
- **Type:** string
- **Purpose:** Initial message when workflow activates
- **Current Value:** See `.ambient/ambient.json`
- **Guidelines:**
  - Greet user warmly
  - Explain what the workflow does
  - List workflow phases
  - Show available commands
  - Provide clear next steps
  - Highlight important notes

## Optional Fields

### results
- **Type:** object with string values
- **Purpose:** Maps artifact types to file paths using glob patterns
- **Current Value:**
  ```json
  {
    "Test Files": "**/*test*.*",
    "Analysis Reports": "artifacts/unit-test-writer/analysis/**/*.md",
    "Coverage Reports": "artifacts/unit-test-writer/reports/**/*.md",
    "Test Plans": "artifacts/unit-test-writer/plans/**/*.md"
  }
  ```
- **Guidelines:** Use glob patterns to match multiple files. Helps users find generated artifacts.

### version
- **Type:** string
- **Example:** "1.0.0"
- **Purpose:** Track workflow configuration version
- **Usage:** Useful for managing workflow updates and compatibility

### author
- **Type:** string or object
- **Example:** `{"name": "Your Name", "email": "you@example.com"}`
- **Purpose:** Identify workflow creator
- **Usage:** Attribution and contact information

### tags
- **Type:** array of strings
- **Example:** `["testing", "unit-tests", "quality-assurance", "automation"]`
- **Purpose:** Categorize workflow for discovery
- **Usage:** Helps users find relevant workflows

### icon
- **Type:** string (emoji)
- **Example:** "🧪"
- **Purpose:** Visual identifier in UI
- **Usage:** Makes workflow easily recognizable

## Customization Examples

### Adding a new output type
```json
"results": {
  "Test Files": "**/*test*.*",
  "Analysis Reports": "artifacts/unit-test-writer/analysis/**/*.md",
  "Coverage Reports": "artifacts/unit-test-writer/reports/**/*.md",
  "Test Plans": "artifacts/unit-test-writer/plans/**/*.md",
  "Integration Tests": "**/*integration.test.*"
}
```

### Changing artifact location
Update all references to the artifact path in:
1. `systemPrompt` - OUTPUT LOCATIONS section
2. `results` - Update file paths
3. Command files - Update ## Output sections

Example:
```json
"results": {
  "Test Files": "**/*test*.*",
  "Analysis Reports": "test-artifacts/analysis/**/*.md",
  "Coverage Reports": "test-artifacts/reports/**/*.md",
  "Test Plans": "test-artifacts/plans/**/*.md"
}
```

Then update command files to use `test-artifacts/` instead of `artifacts/unit-test-writer/`.

### Adding environment configuration
```json
"environment": {
  "COVERAGE_THRESHOLD": "80",
  "TEST_TIMEOUT": "5000",
  "MOCK_EXTERNAL_APIS": "true"
}
```

## Agent Files

Agent persona files are located in `.claude/agents/` and follow this structure:

```markdown
# {Name} - {Role}
## Role
## Expertise
## Responsibilities
## Communication Style
## When to Invoke
## Tools and Techniques
## Key Principles
## Example Artifacts
```

### Current Agents

**tessa-test_engineer.md**
- Focus: Unit testing and test generation
- Expertise: Testing frameworks, TDD, mocking, coverage

**carlos-code_analyst.md**
- Focus: Code analysis and functionality mapping
- Expertise: Static analysis, repository structure, dependencies

**quinn-qa_specialist.md**
- Focus: Test validation and quality assurance
- Expertise: Test execution, coverage metrics, quality standards

## Command Files

Slash command files are located in `.claude/commands/` and follow this structure:

```markdown
# /{command-name} - {Description}
## Purpose
## Prerequisites
## Process
## Output
## Usage Examples
## Success Criteria
## Next Steps
## Notes
```

### Current Commands

**unit-test-writer.analyze.md**
- Analyzes repository structure and identifies testable code
- Read-only operation, never modifies source

**unit-test-writer.plan.md**
- Creates comprehensive test coverage plan
- Defines test file structure and strategy

**unit-test-writer.generate.md**
- Generates actual unit test files
- Uses same language as source code
- Comprehensive coverage (happy path, edge cases, errors)

**unit-test-writer.verify.md**
- Runs generated tests and validates quality
- Fixes failures automatically when possible

**unit-test-writer.report.md**
- Generates detailed coverage reports
- Identifies gaps and provides recommendations

## File Naming Conventions

- **Workflow directory:** `workflows/unit-test-writer/`
- **Agent files:** `{name}-{role}.md` (e.g., `tessa-test_engineer.md`)
- **Command files:** `{workflow-prefix}.{phase}.md` (e.g., `unit-test-writer.analyze.md`)
- **Artifacts:**
  - Analysis: `artifacts/unit-test-writer/analysis/`
  - Plans: `artifacts/unit-test-writer/plans/`
  - Reports: `artifacts/unit-test-writer/reports/`
- **Test files:** Follow language conventions in repository

## Workflow Behavior

### Critical Requirements

**Never Modify Source Code:**
- Workflow only reads source code files
- All modifications are to test files only
- This is enforced in systemPrompt and all commands

**Use Same Language as Source:**
- Tests are written in the same programming language
- Testing frameworks match language conventions
- Automatically detected from repository

**Comprehensive Coverage:**
- Happy path testing
- Edge case testing
- Error handling testing
- Boundary condition testing

**Follow Best Practices:**
- Clear, descriptive test names
- Proper mocking of dependencies
- Independent, isolated tests
- Meaningful assertions

### Language-Specific Behavior

**JavaScript/TypeScript:**
- Uses Jest, Mocha, or detected framework
- Tests in `__tests__/` or `*.test.js`
- Mocks with `jest.mock()` or sinon

**Python:**
- Uses pytest or unittest
- Tests in `tests/test_*.py`
- Mocks with `unittest.mock` or pytest-mock

**Java:**
- Uses JUnit 5 or detected framework
- Tests in `src/test/java/`
- Mocks with Mockito

**Go:**
- Uses built-in testing package
- Tests in `*_test.go`
- Table-driven tests when appropriate

**Ruby:**
- Uses RSpec or Minitest
- Tests in `spec/*_spec.rb`
- Mocks with RSpec mocks

## Validation Checklist

Before using this workflow, verify:

- [ ] `.ambient/ambient.json` is valid JSON (no comments)
- [ ] All required fields are present (name, description, systemPrompt, startupPrompt)
- [ ] All agent files follow the template structure
- [ ] All command files have unique names
- [ ] Output paths in config match those in commands
- [ ] README.md accurately describes the workflow
- [ ] All file references use correct paths

## References

- [ACP Documentation](https://ambient-code.github.io/vteam)
- [Template Workflow](https://github.com/ambient-code/workflows/tree/main/workflows/template-workflow)
- [Workflow Best Practices](https://ambient-code.github.io/vteam/guides/workflows)
- [Testing Framework Documentation](https://jestjs.io/docs/getting-started) (Jest example)
- [Test-Driven Development](https://martinfowler.com/bliki/TestDrivenDevelopment.html)

## Troubleshooting

### Configuration Issues

**Error: Invalid JSON in ambient.json**
- Ensure no trailing commas in JSON
- Check all quotes are properly closed
- Validate JSON syntax with a linter

**Error: Missing required field**
- Verify all required fields are present: name, description, systemPrompt, startupPrompt
- Check field names are spelled correctly

### Workflow Issues

**Tests not generating in correct location**
- Check command files specify correct output paths
- Verify language detection is working correctly
- Ensure repository structure matches expected conventions

**Coverage goals not being met**
- Review test plan and adjust priorities
- Run `/generate` for specific uncovered files
- Check that critical code paths are identified correctly

**Tests failing after generation**
- Run `/verify` to identify and fix failures
- Review verification report for specific issues
- Check that mocks are properly configured

## Advanced Customization

### Custom Test Templates

You can customize test generation by modifying agent personas to include specific test templates or patterns preferred by your team.

### Integration with CI/CD

Export coverage data in JSON format for integration with CI/CD pipelines:
- Use coverage data file: `artifacts/unit-test-writer/reports/coverage-data-{timestamp}.json`
- Set up coverage thresholds in CI configuration
- Track coverage trends over time

### Multi-Language Projects

For projects with multiple languages:
- Workflow automatically detects all languages
- Generates appropriate tests for each language
- Uses language-specific frameworks and conventions
- Organizes tests following each language's conventions
