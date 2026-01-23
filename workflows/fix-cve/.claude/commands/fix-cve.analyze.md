# /fix-cve.analyze - Analyze CVE Details and Impact

## Purpose
Conduct deep analysis of identified CVE vulnerabilities to understand severity, exploitability, business impact, and remediation options. This phase transforms raw vulnerability data into actionable intelligence for prioritized remediation.

## Prerequisites
- Completed `/fix-cve.identify` with vulnerability inventory available
- Access to CVE databases (NVD, MITRE, vendor advisories)
- Understanding of system architecture and deployment environment

## Process

1. **CVE Deep Research**
   - Research each CVE in NVD, MITRE, and vendor security advisories
   - Understand technical details: vulnerability type (CWE), attack vector, complexity
   - Review CVSS v3 score breakdown (Attack Vector, Privileges Required, User Interaction, etc.)
   - Identify proof-of-concept exploits and in-the-wild exploitation status

2. **Exploitability Assessment**
   - Evaluate if vulnerability is exploitable in current system configuration
   - Assess network exposure and attack surface
   - Determine required attacker privileges and attack complexity
   - Review compensating controls already in place

3. **Business Impact Analysis**
   - Map vulnerabilities to business-critical systems and data
   - Assess potential impact on confidentiality, integrity, and availability
   - Evaluate regulatory and compliance implications
   - Prioritize based on risk = likelihood × impact

4. **Remediation Research**
   - Identify available patches, updates, and fixed versions
   - Research vendor patch timelines and availability
   - Document workarounds and temporary mitigations
   - Assess patch compatibility and breaking changes

## Output
- **CVE Analysis Report**: `artifacts/fix-cve/analysis/cve-analysis-YYYY-MM-DD.md`
  - Detailed analysis of each CVE including severity, exploitability, impact, and remediation options

- **Risk Matrix**: `artifacts/fix-cve/analysis/risk-matrix-YYYY-MM-DD.md`
  - Prioritized vulnerability list based on risk scoring with recommended remediation order

## Usage Examples

Basic usage:
```
/fix-cve.analyze
```

With specific focus:
```
/fix-cve.analyze Focus on critical and high severity CVEs only
```

For specific CVEs:
```
/fix-cve.analyze Analyze CVE-2024-1234 and CVE-2024-5678
```

## Success Criteria

After running this command, you should have:
- [ ] Deep understanding of each CVE's technical details and root cause
- [ ] Exploitability assessment for your specific environment
- [ ] Business impact evaluation with risk prioritization
- [ ] Remediation options identified (patches, upgrades, workarounds)

## Next Steps

After completing this phase:
1. Run `/fix-cve.review-release` to review release documentation for proposed fixes
2. Or review the analysis reports in `artifacts/fix-cve/analysis/` before proceeding

## Notes
- Not all CVEs are exploitable in every environment; context matters
- CVSS scores are generic; adjust for your specific deployment
- Some vulnerabilities may have temporary mitigations if patches aren't available
- Consider both technical risk and business impact when prioritizing
