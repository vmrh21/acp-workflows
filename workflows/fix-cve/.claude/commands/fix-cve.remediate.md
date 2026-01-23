# /fix-cve.remediate - Implement CVE Fixes and Patches

## Purpose
Apply security patches, upgrade vulnerable dependencies, and implement fixes to remediate identified CVE vulnerabilities. This phase executes the remediation strategy developed during analysis, with careful attention to compatibility and stability.

## Prerequisites
- Completed `/fix-cve.analyze` with prioritized remediation plan
- Understanding of patch compatibility and breaking changes
- Backup or version control for rollback capability
- Access to modify dependencies and configurations

## Process

1. **Pre-Remediation Validation** ⚠️
   - **Run pre-remediation hooks** to validate system state
   - Execute baseline tests to establish known-good state
   - Verify all tests pass before making changes
   - Create backup/snapshot for rollback capability
   - Document current versions for comparison

2. **Remediation Planning**
   - Review remediation strategy from analysis and review-release phases
   - Prioritize "safe fixes" identified in review phase
   - Identify patch application order (handle dependencies first)
   - Plan for breaking changes and compatibility issues
   - Prepare rollback procedures

3. **Dependency Updates**
   - Update vulnerable packages to fixed versions
   - Apply security patches from vendors
   - Test for breaking changes in staging environment
   - Update lock files and dependency manifests

4. **Configuration Changes**
   - Implement workarounds for vulnerabilities without patches
   - Apply security hardening configurations
   - Enable security features and disable vulnerable functionality
   - Update security policies and access controls

5. **Post-Remediation Validation** ✅
   - **Run post-remediation hooks** to verify changes
   - Execute smoke tests to catch immediate issues
   - Validate updated versions are correctly applied
   - Check for new dependency conflicts introduced by updates
   - Document all changes made for audit trail

## Output
- **Remediation Log**: `artifacts/fix-cve/remediation/remediation-log-YYYY-MM-DD.md`
  - Detailed record of all patches applied, versions updated, and configurations changed

- **Patch Summary**: `artifacts/fix-cve/remediation/patch-summary-YYYY-MM-DD.md`
  - Summary of remediation actions with before/after version comparisons

## Usage Examples

Basic usage:
```
/fix-cve.remediate
```

With specific priority:
```
/fix-cve.remediate Address critical CVEs first
```

For specific CVEs:
```
/fix-cve.remediate Fix CVE-2024-1234 by upgrading to patched version
```

## Success Criteria

After running this command, you should have:
- [ ] All targeted CVE vulnerabilities patched or mitigated
- [ ] Dependency versions updated to secure releases
- [ ] Configuration changes applied and documented
- [ ] Complete audit trail of remediation actions

## Next Steps

After completing this phase:
1. Run `/fix-cve.test` to validate fixes and check for regressions
2. Or review the remediation log in `artifacts/fix-cve/remediation/`

## Recommended Hooks

Configure hooks in your development environment to automate validation:

### Pre-Remediation Hooks
Run before applying any fixes to establish baseline:

```bash
# .claude/hooks/pre-remediate.sh
#!/bin/bash
echo "🧪 Running pre-remediation validation..."

# Run existing test suite
npm test || exit 1

# Run security baseline scan
trivy fs . --severity HIGH,CRITICAL || exit 1

# Verify build succeeds
npm run build || exit 1

echo "✅ Pre-remediation validation passed"
```

### Post-Remediation Hooks
Run after applying fixes to catch immediate issues:

```bash
# .claude/hooks/post-remediate.sh
#!/bin/bash
echo "🧪 Running post-remediation validation..."

# Verify dependencies install correctly
npm install || exit 1

# Run smoke tests
npm run test:smoke || exit 1

# Quick security scan
trivy fs . --severity CRITICAL || exit 1

echo "✅ Post-remediation validation passed"
```

## Notes
- **Hooks provide automated safety nets** - Configure them before starting remediation
- Always test patches in staging before production deployment
- Some updates may introduce breaking changes; review changelogs carefully
- Create git commits for each logical group of changes for easier rollback
- Consider maintenance windows for applying patches to production systems
- Keep original vulnerability scan results for before/after comparison
- If hooks fail, **stop and investigate** - don't proceed with broken state
