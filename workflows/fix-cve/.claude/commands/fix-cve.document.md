# /fix-cve.document - Generate CVE Documentation

## Purpose
Create comprehensive documentation of the entire CVE remediation process, including vulnerability details, remediation actions, test results, and lessons learned. This phase ensures knowledge transfer and provides an audit trail for compliance.

**Optional:** Automatically create a pull request with `--create-pr` flag after documentation is generated and validation passes.

## Prerequisites
- Completed all previous workflow phases (identify, analyze, remediate, test, verify)
- Access to all artifacts generated during the workflow
- Understanding of organizational documentation standards
- Stakeholder information needs identified

## Process

1. **Vulnerability Summary**
   - Compile list of all CVEs addressed in this workflow cycle
   - Summarize severity distribution (Critical, High, Medium, Low)
   - Document initially identified vulnerabilities vs. final state
   - Highlight any actively exploited CVEs that were remediated

2. **Remediation Documentation**
   - Document all patches applied with version changes
   - Record configuration changes and security hardening
   - List any workarounds or temporary mitigations implemented
   - Include rollback procedures for each change

3. **Technical Details**
   - Provide detailed CVE analysis for significant vulnerabilities
   - Document root causes and attack vectors
   - Explain remediation approach and rationale
   - Include test results and validation evidence

4. **Lessons Learned**
   - Identify process improvements for future CVE workflows
   - Document challenges encountered and solutions
   - Note tools and techniques that were effective
   - Recommend preventive measures to reduce future CVEs

## Output
- **Executive Summary**: `artifacts/fix-cve/docs/executive-summary-YYYY-MM-DD.md`
  - High-level overview of CVE remediation effort for management and stakeholders

- **Technical Report**: `artifacts/fix-cve/docs/technical-report-YYYY-MM-DD.md`
  - Detailed technical documentation of vulnerabilities, fixes, and validation

- **Runbook**: `artifacts/fix-cve/docs/remediation-runbook-YYYY-MM-DD.md`
  - Step-by-step procedures for future similar CVE remediations

## Usage Examples

**Basic usage (documentation only):**
```
/fix-cve.document
```

**With automatic PR creation:**
```
/fix-cve.document --create-pr
```

This will:
1. Generate all documentation
2. Run pre-PR validation hooks automatically
3. Create pull request with CVE fix details
4. Add security labels and assign reviewers

**With specific audience:**
```
/fix-cve.document Create executive summary for leadership
```

**For compliance:**
```
/fix-cve.document Generate audit-ready documentation package
```

**Custom PR with specific details:**
```
/fix-cve.document --create-pr --title "Fix Critical CVE-2024-1234" --reviewer @security-team
```

## Success Criteria

After running this command, you should have:
- [ ] Complete documentation of all CVEs and remediations
- [ ] Executive summary suitable for non-technical stakeholders
- [ ] Technical documentation with full implementation details
- [ ] Lessons learned and recommendations for future workflows

## Automatic PR Creation (with --create-pr flag)

When you use `/fix-cve.document --create-pr`, the following happens automatically:

### 1. Documentation Generation
All standard documentation is created (executive summary, technical report, runbook)

### 2. Pre-PR Validation (Automatic)
The pre-PR validation hook runs automatically:

```bash
# .claude/hooks/pre-pr.sh
#!/bin/bash
echo "🚀 Running pre-PR validation for CVE fixes..."

# 1. Verify all tests pass
echo "Running full test suite..."
npm test || { echo "❌ Tests failed"; exit 1; }

# 2. Run linter
echo "Running linter..."
npm run lint || { echo "❌ Linting failed"; exit 1; }

# 3. Verify build succeeds
echo "Building project..."
npm run build || { echo "❌ Build failed"; exit 1; }

# 4. Final security scan
echo "Running security scan..."
trivy fs . --severity HIGH,CRITICAL --exit-code 1 || { echo "❌ High/Critical CVEs still present"; exit 1; }

# 5. Check for vulnerable dependencies
echo "Checking dependencies..."
npm audit --audit-level=high || { echo "❌ Vulnerable dependencies detected"; exit 1; }

# 6. Verify documentation exists
echo "Checking documentation..."
[ -f "artifacts/fix-cve/docs/executive-summary-"*.md ] || { echo "❌ Documentation missing"; exit 1; }

echo "✅ All pre-PR validations passed - safe to create PR"
```

**This hook runs automatically when using `--create-pr` flag.**

### 3. Pull Request Creation (Automatic)

If validation passes, PR is created automatically:

```bash
# Automatically executed when using --create-pr flag
gh pr create \
  --title "Security: Fix CVE vulnerabilities - $(date +%Y-%m-%d)" \
  --body "$(cat artifacts/fix-cve/docs/executive-summary-*.md)" \
  --label "security,cve-fix,automated" \
  --assignee "@me"
```

**PR includes:**
- Executive summary as PR description
- Security labels for visibility
- Links to all artifact reports
- CVE identifiers in the title
- Automated label for tracking

### 4. Success Confirmation

You'll receive:
- PR URL for review
- Link to all generated artifacts
- Summary of validation results
- Next steps for PR review

## Manual PR Creation

If you don't use `--create-pr`, you can still create PR manually:

```bash
# 1. Run validation hook manually
bash .claude/hooks/pre-pr.sh

# 2. Create PR manually
gh pr create \
  --title "Security: Fix CVE-2024-XXXX vulnerabilities" \
  --body "$(cat artifacts/fix-cve/docs/executive-summary-*.md)" \
  --label "security,cve-fix"
```

## Next Steps

**If using --create-pr:**
1. Review the created pull request
2. Address any reviewer feedback
3. Merge once approved
4. Monitor for any issues post-deployment

**If NOT creating PR automatically:**
1. Run pre-PR validation hooks manually (see above)
2. Create PR when ready
3. Share documentation with stakeholders and security team
4. Archive reports for compliance and audit purposes
5. Schedule follow-up security scans for ongoing monitoring

## PR Creation Options

### Default Behavior (--create-pr with no options)
- **Title:** "Security: Fix CVE vulnerabilities - YYYY-MM-DD"
- **Body:** Executive summary content
- **Labels:** security, cve-fix, automated
- **Assignee:** Current user
- **Reviewers:** None (configure in project settings)

### Custom PR Options

```bash
# Custom title
/fix-cve.document --create-pr --title "Critical: Fix CVE-2024-1234 in auth module"

# Add reviewers
/fix-cve.document --create-pr --reviewer @security-team,@lead-engineer

# Target specific branch
/fix-cve.document --create-pr --base develop

# Draft PR
/fix-cve.document --create-pr --draft

# Multiple options
/fix-cve.document --create-pr \
  --title "Security: Fix authentication CVEs" \
  --reviewer @security-team \
  --base main \
  --label "priority-high,security"
```

## Validation Failure Handling

If pre-PR validation fails when using `--create-pr`:

1. **Documentation is still created** - All reports are generated
2. **PR creation is skipped** - Validation errors prevent PR
3. **Error details provided** - See which validation failed
4. **Guidance given** - Instructions to fix issues

Example output:
```
✅ Documentation generated successfully
🧪 Running pre-PR validation...
❌ Tests failed - do not create PR
❌ Pre-PR validation FAILED

PR creation skipped due to validation failures.
Fix the issues above and run:
  bash .claude/hooks/pre-pr.sh
  /fix-cve.document --create-pr
```

## Notes
- **--create-pr flag is optional** - Default behavior is documentation only
- Documentation should be clear enough for future team members to understand
- Include both successes and challenges for organizational learning
- Keep sensitive security details on a need-to-know basis
- Consider creating a changelog for production deployments
- Update security policies based on lessons learned
- **Pre-PR hooks must pass** - PR won't be created if validation fails
- Requires `gh` CLI tool installed and authenticated
- PR body automatically includes executive summary for reviewer context
