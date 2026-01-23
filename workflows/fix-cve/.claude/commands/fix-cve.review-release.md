# /fix-cve.review-release - Review Release Documents for Fixes

## Purpose
Review release notes, changelogs, and documentation for proposed CVE fixes before applying them. This phase identifies breaking changes, new dependencies, compatibility issues, and validates that fixes are safe and well-documented, helping avoid risky updates.

## Prerequisites
- Completed `/fix-cve.analyze` with remediation options identified
- Access to vendor documentation, release notes, and changelogs
- Understanding of current system architecture and dependencies

## Process

1. **Release Documentation Research**
   - Locate release notes and changelogs for each proposed fix version
   - Check vendor security advisories for fix details
   - Search for migration guides and upgrade documentation
   - Identify if documentation is available or missing

2. **Breaking Changes Analysis**
   - Review CHANGELOG.md and BREAKING_CHANGES documentation
   - Identify API changes, deprecations, and removals
   - Check for configuration changes required
   - Assess impact on current codebase
   - Flag fixes with breaking changes for careful consideration

3. **Dependency Impact Assessment**
   - Review new dependencies introduced by the fix
   - Check for peer dependency conflicts
   - Identify minimum version requirements for related packages
   - Assess transitive dependency changes
   - Flag potential dependency conflicts

4. **Compatibility Verification**
   - Check minimum runtime/platform version requirements
   - Verify compatibility with current framework versions
   - Review known issues and bug reports for the fix version
   - Identify any platform-specific concerns (OS, architecture)

5. **Documentation Status Tracking**
   - Create list of fixes with complete documentation
   - **IMPORTANT**: Document fixes with missing or incomplete release notes
   - Flag undocumented fixes as higher risk
   - Note quality of available documentation (comprehensive vs minimal)

## Output
- **Release Review Report**: `artifacts/fix-cve/review/release-review-YYYY-MM-DD.md`
  - Comprehensive review of release documentation for each proposed fix
  - Breaking changes identified with impact assessment
  - New dependencies and compatibility requirements
  - **Missing Documentation Report**: List of fixes without adequate release notes

- **Safe Fixes List**: `artifacts/fix-cve/review/safe-fixes-YYYY-MM-DD.md`
  - Prioritized list of safe, well-documented fixes recommended for immediate application
  - Fixes with no breaking changes and good documentation

- **Risky Fixes List**: `artifacts/fix-cve/review/risky-fixes-YYYY-MM-DD.md`
  - Fixes with breaking changes, missing documentation, or compatibility concerns
  - Recommended alternative approaches or workarounds

## Usage Examples

Basic usage:
```
/fix-cve.review-release
```

Focus on specific CVEs:
```
/fix-cve.review-release Review release docs for CVE-2024-1234 fixes
```

Check for breaking changes:
```
/fix-cve.review-release Focus on identifying breaking changes in proposed fixes
```

## Success Criteria

After running this command, you should have:
- [ ] Release documentation reviewed for all proposed fixes
- [ ] Breaking changes identified and documented
- [ ] Dependency impacts assessed for each fix
- [ ] **Missing documentation clearly reported** for fixes without adequate release notes
- [ ] Fixes categorized as "safe" (well-documented, no breaking changes) or "risky"
- [ ] Alternative approaches identified for risky fixes

## Next Steps

After completing this phase:
1. Review the safe-fixes and risky-fixes lists
2. Make informed decisions about which fixes to apply
3. Run `/fix-cve.remediate` to apply approved fixes (starting with safe ones)
4. Consider workarounds or alternative mitigations for risky fixes

## Notes
- **Always prioritize safe, verified fixes** - well-documented fixes with no breaking changes
- **Missing documentation is a red flag** - proceed cautiously with poorly documented fixes
- Some vendors provide better documentation than others; adjust risk assessment accordingly
- Breaking changes may be acceptable if the CVE is critical and actively exploited
- Consider staying on current version with workarounds if fix introduces significant risk
- Beta/RC versions should be flagged as higher risk even if they fix CVEs
- Check community discussions (GitHub issues, forums) for real-world fix experiences
- Document your risk assessment to inform future decisions
