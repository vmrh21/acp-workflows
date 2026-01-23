# /fix-cve.verify - Verify Complete CVE Resolution

## Purpose
Perform final verification that all CVE vulnerabilities are fully resolved, security scanners confirm the fixes, and the system is ready for production deployment. This phase provides confidence that remediation is complete and effective.

## Prerequisites
- Completed `/fix-cve.test` with all tests passing
- Security scanning tools available
- Access to updated system for re-scanning
- Original vulnerability inventory for comparison

## Process

1. **Re-scan for Vulnerabilities**
   - Run the same security scanners used in identification phase
   - Query vulnerability databases with updated dependency versions
   - Perform fresh CVE scans on all components
   - Compare results with original vulnerability inventory

2. **CVE Status Verification**
   - Confirm each targeted CVE is no longer detected
   - Validate fixed versions are correctly installed
   - Check for any new vulnerabilities introduced by updates
   - Verify CVSS scores reflect post-remediation state

3. **Security Control Validation**
   - Verify workarounds and mitigations are functioning
   - Test security configurations are properly applied
   - Confirm defense-in-depth controls are active
   - Validate monitoring and logging for security events

4. **Compliance Check**
   - Ensure remediation meets security policy requirements
   - Verify compliance with regulatory standards (if applicable)
   - Confirm audit trail is complete and accurate
   - Check that security documentation is updated

## Output
- **Verification Report**: `artifacts/fix-cve/verification/verification-report-YYYY-MM-DD.md`
  - Final confirmation of CVE resolution with before/after scan comparisons

- **Residual Risk Assessment**: `artifacts/fix-cve/verification/residual-risk-YYYY-MM-DD.md`
  - Analysis of any remaining vulnerabilities and accepted risks

## Usage Examples

Basic usage:
```
/fix-cve.verify
```

With specific focus:
```
/fix-cve.verify Confirm all critical CVEs are resolved
```

For compliance:
```
/fix-cve.verify Generate compliance verification report
```

## Success Criteria

After running this command, you should have:
- [ ] Security scanners confirm targeted CVEs are resolved
- [ ] No new critical or high severity vulnerabilities introduced
- [ ] All security controls validated and functioning
- [ ] Complete audit trail from identification through verification

## Next Steps

After completing this phase:
1. Run `/fix-cve.document` to generate comprehensive documentation
2. Or review verification reports in `artifacts/fix-cve/verification/`
3. Deploy to production with confidence in security posture

## Notes
- Verification should show measurable reduction in vulnerability count
- Some low-severity CVEs may remain if risk is accepted
- Document any false positives from scanners
- Keep verification reports for compliance and audit purposes
- Consider scheduling regular re-scans for continuous security monitoring
