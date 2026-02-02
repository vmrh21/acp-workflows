# /unit-test-writer.analyze - Analyze Repository and Map Testable Code

## Purpose
Scans the repository to identify all source files, detect programming languages, understand functionality, and create a comprehensive map of what needs testing without modifying any existing code.

## Prerequisites
- Repository path or URL provided by user
- Read access to the repository
- Repository contains source code files

## Process

1. **Request Repository Information and Scope**
   - Ask user for GitHub repository URL if not provided
   - Validate the repository exists and is accessible
   - Confirm the repository root directory
   - **Ask user to clarify testing scope:**
     * Option 1: Specific pull request (provide PR number)
     * Option 2: Specific functionality or files (describe or list)
     * Option 3: Comprehensive - find all missing tests
   - Confirm scope with user before proceeding

2. **Scan Repository Structure**
   - Traverse all directories recursively
   - Identify all source code files (exclude node_modules, vendor, build directories)
   - Detect programming languages by file extensions and content
   - Identify existing test files and test frameworks
   - Map directory structure and organization patterns

3. **Language and Framework Detection**
   - Analyze file extensions (.js, .py, .java, .go, .rb, etc.)
   - Detect testing frameworks from:
     * package.json (Jest, Mocha, Jasmine)
     * requirements.txt or pyproject.toml (pytest, unittest)
     * pom.xml or build.gradle (JUnit, TestNG)
     * go.mod and test file patterns
     * Gemfile (RSpec, Minitest)
   - Identify build systems and project configuration

4. **Functionality Mapping**
   - For each source file:
     * Identify all functions, methods, and classes
     * Determine function signatures and parameters
     * Understand purpose based on names and context
     * Identify public vs. private/internal functions
     * Note dependencies and imports
   - Group related functionality by module/component
   - Create hierarchical map of codebase structure

5. **Test Coverage Assessment**
   - Identify existing test files and what they cover
   - Match test files to source files
   - Calculate current coverage percentage (if tests exist)
   - Identify code with NO test coverage
   - List all untested functions/methods
   - **If analyzing a PR**: Focus on changed/new code in the PR

6. **Analyze Existing Test Patterns (CRITICAL)**
   - **ONLY if existing tests are found**, analyze their patterns:
     * **Test Naming Conventions:**
       - How test suites are named (describe, context, test suite)
       - How test cases are named (it, test, should)
       - Naming patterns for test files
     * **Assertion Styles:**
       - Which assertion library is used (expect, assert, should)
       - Common matchers and assertion patterns
       - Error assertion approaches
     * **Mock/Stub Patterns:**
       - How mocks are created (jest.mock, sinon, unittest.mock)
       - Mock setup and configuration patterns
       - Stub return value patterns
     * **Test Organization:**
       - Setup/teardown patterns (beforeEach, setUp, tearDown)
       - Test grouping and structure
       - File organization conventions
     * **Code Style:**
       - Indentation (spaces vs tabs, count)
       - Formatting and code style
       - Comment and documentation style
   - **Create style guide** from detected patterns
   - **If no existing tests**: Note that language/framework best practices will be used
   - **Ask user** if they have specific style preferences not evident in existing tests

7. **Generate Analysis Report**
   - Create comprehensive inventory of testable code
   - List all functions/methods by file and module
   - Note language(s) and framework(s) detected
   - Show current test coverage status
   - Highlight priority areas for test generation
   - Save to `artifacts/unit-test-writer/analysis/repository-analysis-{timestamp}.md`

## Output

- **Repository Analysis Report**: `artifacts/unit-test-writer/analysis/repository-analysis-{timestamp}.md`
  - Repository structure overview
  - Testing scope (PR, specific functionality, or comprehensive)
  - Languages and frameworks detected
  - Complete inventory of functions/methods
  - Current test coverage status
  - List of untested code
  - Recommendations for test approach

- **Testable Code Map**: `artifacts/unit-test-writer/analysis/testable-code-map-{timestamp}.json`
  - Structured JSON with all testable units
  - Organized by file, module, and component
  - Includes function signatures and metadata

- **Test Style Guide** (if existing tests found): `artifacts/unit-test-writer/analysis/test-style-guide-{timestamp}.md`
  - Detected test naming conventions
  - Assertion styles and patterns
  - Mock/stub patterns
  - Test organization structure
  - Code formatting guidelines
  - Examples from existing tests

## Usage Examples

Basic usage:
```
/unit-test-writer.analyze
```

With repository path:
```
/unit-test-writer.analyze /path/to/repository
```

With repository URL:
```
/unit-test-writer.analyze https://github.com/user/repo
```

## Success Criteria

After running this command, you should have:
- [ ] Complete understanding of repository structure
- [ ] Identified all programming languages used
- [ ] Detected testing frameworks (if present)
- [ ] Mapped all testable functions and methods
- [ ] Identified existing test coverage
- [ ] Generated comprehensive analysis report
- [ ] NO modifications made to source code

## Next Steps

After completing this phase:
1. Review the analysis report in `artifacts/unit-test-writer/analysis/`
2. Run `/unit-test-writer.plan` to create a test coverage strategy
3. Or manually specify which components to test first

## Notes

- **Read-Only Operation**: This command only reads code, never modifies it
- **Language Support**: Works with any programming language
- **Framework Detection**: Automatically identifies testing frameworks to use
- **Performance**: Large repositories may take a few minutes to analyze
- **Interactive Approach**:
  - Always asks for GitHub repository URL at start
  - Clarifies testing scope (PR, specific functionality, comprehensive)
  - Asks for style preferences if not evident from existing tests
  - Seeks clarification when encountering ambiguous code
- **Pattern Learning**:
  - Analyzes existing tests to learn your team's style
  - Creates style guide to ensure generated tests match
  - Respects established conventions and patterns
- **Scope Flexibility**:
  - Can analyze specific PR changes only
  - Can focus on specific functionality or files
  - Can comprehensively analyze entire repository
- **Exclusions**: Automatically skips common non-source directories:
  - node_modules, vendor, venv, .git
  - build, dist, out, target
  - __pycache__, .pytest_cache
  - coverage, .coverage
