# CVE Fix Workflow - Hooks Configuration Guide

This guide explains how to set up automated validation hooks to ensure safety and quality throughout the CVE remediation workflow.

## Overview

Hooks provide automated safety nets at critical workflow phases:
- **Pre-Remediation:** Validate baseline before making changes
- **Post-Remediation:** Verify changes didn't break anything
- **Pre-PR:** Comprehensive validation before creating pull requests

## Why Use Hooks?

✅ **Prevent Breaking Changes:** Catch issues before they're committed
✅ **Automate Testing:** Run tests automatically at critical phases
✅ **Ensure Quality:** Validate fixes actually work
✅ **Save Time:** Catch errors early instead of in PR review
✅ **Build Confidence:** Know your fixes are safe

## Hook Types

### 1. Pre-Remediation Hooks

**When:** Before applying any CVE fixes (step 1 of `/fix-cve.remediate`)

**Purpose:** Establish a known-good baseline to compare against

**Example Hook Script:**

```bash
#!/bin/bash
# .claude/hooks/pre-remediate.sh

set -e  # Exit on any error

echo "🔍 Pre-Remediation Validation Started"
echo "======================================"

# 1. Verify existing tests pass
echo ""
echo "📋 Running existing test suite..."
npm test || {
    echo "❌ Existing tests are failing - fix these first before remediation"
    exit 1
}

# 2. Baseline security scan
echo ""
echo "🔒 Running baseline security scan..."
trivy fs . \
    --severity HIGH,CRITICAL \
    --format json \
    --output artifacts/fix-cve/baseline-scan.json
echo "✅ Baseline scan saved for comparison"

# 3. Verify build works
echo ""
echo "🏗️  Verifying build..."
npm run build || {
    echo "❌ Build is broken - fix before remediation"
    exit 1
}

# 4. Create snapshot of current dependencies
echo ""
echo "📸 Snapshotting current dependencies..."
cp package-lock.json artifacts/fix-cve/package-lock.json.backup
cp package.json artifacts/fix-cve/package.json.backup

# 5. Document current versions
echo ""
echo "📝 Documenting current versions..."
npm list --depth=0 > artifacts/fix-cve/versions-before.txt

echo ""
echo "✅ Pre-remediation validation PASSED"
echo "======================================"
echo "Safe to proceed with remediation"
```

**For Python Projects:**

```bash
#!/bin/bash
# .claude/hooks/pre-remediate-python.sh

set -e

echo "🔍 Pre-Remediation Validation (Python)"
echo "======================================"

# Run tests
pytest || exit 1

# Security scan
pip-audit --desc || exit 1

# Snapshot requirements
cp requirements.txt artifacts/fix-cve/requirements.txt.backup

echo "✅ Pre-remediation validation PASSED"
```

**For Docker/Container Projects:**

```bash
#!/bin/bash
# .claude/hooks/pre-remediate-docker.sh

set -e

echo "🔍 Pre-Remediation Validation (Docker)"
echo "======================================"

# Baseline image scan
trivy image my-app:latest \
    --severity HIGH,CRITICAL \
    --format json \
    --output artifacts/fix-cve/baseline-image-scan.json

# Test containers start
docker-compose up -d || exit 1
docker-compose ps || exit 1
docker-compose down

echo "✅ Pre-remediation validation PASSED"
```

### 2. Post-Remediation Hooks

**When:** After applying CVE fixes (step 5 of `/fix-cve.remediate`)

**Purpose:** Quickly verify changes didn't break anything critical

**Example Hook Script:**

```bash
#!/bin/bash
# .claude/hooks/post-remediate.sh

set -e

echo "🧪 Post-Remediation Validation Started"
echo "======================================="

# 1. Install new dependencies
echo ""
echo "📦 Installing updated dependencies..."
npm install || {
    echo "❌ Dependency installation failed"
    exit 1
}

# 2. Run smoke tests
echo ""
echo "💨 Running smoke tests..."
npm run test:smoke || {
    echo "❌ Smoke tests failed - remediation may have broken something"
    exit 1
}

# 3. Quick security scan
echo ""
echo "🔒 Running quick security scan..."
trivy fs . \
    --severity CRITICAL \
    --exit-code 1 || {
    echo "❌ Critical vulnerabilities still present"
    exit 1
}

# 4. Verify build still works
echo ""
echo "🏗️  Verifying build..."
npm run build || {
    echo "❌ Build broken by remediation"
    exit 1
}

# 5. Compare dependency versions
echo ""
echo "📊 Dependency changes:"
npm list --depth=0 > artifacts/fix-cve/versions-after.txt
diff artifacts/fix-cve/versions-before.txt artifacts/fix-cve/versions-after.txt || true

echo ""
echo "✅ Post-remediation validation PASSED"
echo "======================================="
echo "Proceed to /fix-cve.test for comprehensive testing"
```

### 3. Pre-PR Hooks

**When:** Before creating pull request (in `/fix-cve.document` phase)

**Purpose:** Comprehensive validation that everything is ready for review

**Example Hook Script:**

```bash
#!/bin/bash
# .claude/hooks/pre-pr.sh

set -e

echo "🚀 Pre-PR Validation Started"
echo "======================================"

# 1. Full test suite
echo ""
echo "🧪 Running full test suite..."
npm test || {
    echo "❌ Tests failed - do not create PR"
    exit 1
}

# 2. Linting
echo ""
echo "🔍 Running linter..."
npm run lint || {
    echo "❌ Linting failed"
    exit 1
}

# 3. Type checking (if TypeScript)
if [ -f "tsconfig.json" ]; then
    echo ""
    echo "📘 Running type check..."
    npm run type-check || {
        echo "❌ Type check failed"
        exit 1
    }
fi

# 4. Build verification
echo ""
echo "🏗️  Building project..."
npm run build || {
    echo "❌ Build failed"
    exit 1
}

# 5. Comprehensive security scan
echo ""
echo "🔒 Running comprehensive security scan..."
trivy fs . \
    --severity HIGH,CRITICAL \
    --exit-code 1 || {
    echo "❌ High/Critical CVEs still present"
    exit 1
}

# 6. Dependency audit
echo ""
echo "📦 Auditing dependencies..."
npm audit --audit-level=high || {
    echo "❌ High severity vulnerabilities in dependencies"
    exit 1
}

# 7. Container scan (if applicable)
if [ -f "Dockerfile" ]; then
    echo ""
    echo "🐳 Scanning Docker image..."
    docker build -t cve-fix-validation:latest . || exit 1
    trivy image cve-fix-validation:latest \
        --severity HIGH,CRITICAL \
        --exit-code 1 || {
        echo "❌ Container image has vulnerabilities"
        exit 1
    }
fi

# 8. Verify documentation exists
echo ""
echo "📚 Checking documentation..."
if [ ! -f artifacts/fix-cve/docs/executive-summary-*.md ]; then
    echo "❌ Executive summary missing - run /fix-cve.document"
    exit 1
fi

# 9. Verify all phases completed
echo ""
echo "✅ Checking workflow completion..."
required_dirs=(
    "artifacts/fix-cve/reports"
    "artifacts/fix-cve/analysis"
    "artifacts/fix-cve/review"
    "artifacts/fix-cve/remediation"
    "artifacts/fix-cve/testing"
    "artifacts/fix-cve/verification"
    "artifacts/fix-cve/docs"
)

for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ] || [ -z "$(ls -A $dir)" ]; then
        echo "❌ Missing artifacts in $dir - workflow incomplete"
        exit 1
    fi
done

echo ""
echo "✅ Pre-PR validation PASSED"
echo "======================================"
echo "Safe to create pull request!"
echo ""
echo "Create PR with:"
echo "  gh pr create --title 'Security: Fix CVE vulnerabilities' \\"
echo "               --body \"\$(cat artifacts/fix-cve/docs/executive-summary-*.md)\" \\"
echo "               --label 'security,cve-fix'"
```

## Hook Configuration

### Option 1: Manual Execution

Run hooks manually at each phase:

```bash
# Before remediation
bash .claude/hooks/pre-remediate.sh

# After remediation
bash .claude/hooks/post-remediate.sh

# Before creating PR
bash .claude/hooks/pre-pr.sh
```

### Option 2: Git Hooks

Integrate with git hooks for automatic execution:

```bash
# .git/hooks/pre-commit
#!/bin/bash

# Only run if CVE fix files changed
if git diff --cached --name-only | grep -q "package.*\.json\|requirements\.txt\|Dockerfile"; then
    echo "CVE-related files changed, running validation..."
    bash .claude/hooks/post-remediate.sh || exit 1
fi
```

### Option 3: CI/CD Integration

Add hooks to your CI/CD pipeline:

```yaml
# .github/workflows/cve-fix-validation.yml
name: CVE Fix Validation

on:
  pull_request:
    paths:
      - 'package*.json'
      - 'requirements.txt'
      - 'Dockerfile'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Pre-PR Validation
        run: bash .claude/hooks/pre-pr.sh

      - name: Upload Scan Results
        uses: actions/upload-artifact@v3
        with:
          name: cve-scan-results
          path: artifacts/fix-cve/
```

## Technology-Specific Examples

### Node.js/JavaScript

```bash
# Pre-check: npm test, npm audit
# Post-check: npm install, smoke tests
# Scanners: npm audit, Snyk, Trivy
```

### Python

```bash
# Pre-check: pytest, pip-audit
# Post-check: pip install, smoke tests
# Scanners: pip-audit, safety, Bandit
```

### Java/Maven

```bash
# Pre-check: mvn test, mvn dependency-check:check
# Post-check: mvn install, integration tests
# Scanners: OWASP Dependency-Check, Snyk
```

### Go

```bash
# Pre-check: go test ./..., go mod verify
# Post-check: go mod download, smoke tests
# Scanners: govulncheck, Trivy
```

### Docker/Containers

```bash
# Pre-check: Docker build, image scan
# Post-check: Container start test, runtime scan
# Scanners: Trivy, Grype, Snyk Container
```

## Best Practices

1. **Make Hooks Fast:** Use smoke tests in post-remediation, full tests in pre-PR
2. **Fail Fast:** Exit immediately on first error
3. **Clear Output:** Use emojis and formatting for readability
4. **Save Artifacts:** Store scan results for comparison
5. **Version Snapshots:** Keep before/after dependency lists
6. **Technology Agnostic:** Create hooks for your specific stack
7. **Document Failures:** Log why hooks failed for debugging

## Troubleshooting

### Hook Fails on Pre-Remediation
**Problem:** Baseline tests failing before fixes applied

**Solution:** Fix existing issues first, then run workflow

### Hook Fails on Post-Remediation
**Problem:** Smoke tests fail after applying patches

**Solution:** Rollback changes, review breaking changes in `/fix-cve.review-release`

### Hook Fails on Pre-PR
**Problem:** Full validation fails before PR creation

**Solution:** Run `/fix-cve.test` and `/fix-cve.verify` again, ensure all phases completed

## Example Workflow with Hooks

```bash
# 1. Identify CVEs
/fix-cve.identify https://github.com/owner/repo

# 2. Analyze CVEs
/fix-cve.analyze

# 3. Review release docs
/fix-cve.review-release

# 4. Remediate with hooks
bash .claude/hooks/pre-remediate.sh   # ← Hook validates baseline
/fix-cve.remediate
bash .claude/hooks/post-remediate.sh  # ← Hook catches immediate issues

# 5. Full testing
/fix-cve.test

# 6. Verification
/fix-cve.verify

# 7. Documentation
/fix-cve.document

# 8. Create PR with validation
bash .claude/hooks/pre-pr.sh          # ← Hook ensures PR quality
gh pr create --title "Security: Fix CVE-2024-XXXX" \
             --body "$(cat artifacts/fix-cve/docs/executive-summary-*.md)" \
             --label "security,cve-fix"
```

## Customization

Adapt hooks to your project needs:

- Add custom test commands
- Include performance benchmarks
- Add code coverage checks
- Include security policy validation
- Add custom compliance checks

## References

- [Git Hooks Documentation](https://git-scm.com/docs/githooks)
- [Trivy Security Scanner](https://github.com/aquasecurity/trivy)
- [GitHub Actions](https://docs.github.com/en/actions)
- [npm audit](https://docs.npmjs.com/cli/v8/commands/npm-audit)
- [pip-audit](https://github.com/pypa/pip-audit)
