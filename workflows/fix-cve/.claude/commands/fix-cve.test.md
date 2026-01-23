# /fix-cve.test - Test CVE Remediations

## Purpose
Thoroughly test security patches and remediations to ensure vulnerabilities are fixed, system functionality is preserved, and no regressions are introduced. This phase validates that fixes are effective before deployment.

## Prerequisites
- Completed `/fix-cve.remediate` with patches applied
- Access to testing environments (unit, integration, staging)
- Test frameworks and security testing tools available
- Baseline functionality tests for regression detection

## Process

1. **Test Planning**
   - Identify critical functionality affected by patches
   - Design test cases covering security fix validation
   - Plan regression tests for unchanged functionality
   - Prepare test data and test environments

2. **Security Validation Testing**
   - Verify vulnerabilities are no longer exploitable (negative testing)
   - Test that attack vectors from CVE descriptions now fail
   - Validate input validation and boundary conditions
   - Confirm security controls are functioning correctly

3. **Functional Regression Testing**
   - Run existing test suites (unit, integration, end-to-end)
   - Test normal user workflows and edge cases
   - Verify no functionality broke due to security patches
   - Check integration points and dependent systems

4. **Performance Testing**
   - Measure performance impact of security patches
   - Compare metrics before and after remediation
   - Identify any performance degradation
   - Validate performance remains within acceptable limits

## Output
- **Test Report**: `artifacts/fix-cve/testing/test-report-YYYY-MM-DD.md`
  - Comprehensive test results including pass/fail status, coverage metrics, and identified issues

- **Regression Summary**: `artifacts/fix-cve/testing/regression-summary-YYYY-MM-DD.md`
  - Analysis of any regressions or issues introduced by patches

## Usage Examples

Basic usage:
```
/fix-cve.test
```

With specific scope:
```
/fix-cve.test Focus on authentication and authorization modules
```

For specific fixes:
```
/fix-cve.test Validate CVE-2024-1234 fix effectiveness
```

## Success Criteria

After running this command, you should have:
- [ ] Confirmation that CVE vulnerabilities are no longer exploitable
- [ ] All functional tests passing (no regressions)
- [ ] Performance impact assessed and acceptable
- [ ] Documented test coverage for all remediated CVEs

## Next Steps

After completing this phase:
1. Run `/fix-cve.verify` to perform final security verification
2. Or review test results in `artifacts/fix-cve/testing/`
3. If tests fail, return to `/fix-cve.remediate` to adjust fixes

## Notes
- Negative testing (proving exploits fail) is as important as positive testing
- Some security patches may have subtle behavioral changes
- Automated security scanners should show reduced CVE counts
- Document any test failures immediately for quick remediation
- Consider both automated and manual security testing
