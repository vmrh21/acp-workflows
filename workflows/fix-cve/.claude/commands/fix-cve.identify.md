# /fix-cve.identify - Scan and Identify CVE Vulnerabilities

## Purpose
Systematically scan the codebase, dependencies, container images, and infrastructure to discover CVE vulnerabilities. This phase creates a comprehensive inventory of all known vulnerabilities affecting the system, providing the foundation for analysis and remediation.

## Prerequisites
- GitHub repository URL or name
- Security scanning tools installed (or ability to use online scanners)
- Understanding of the technology stack and dependencies

## Process

1. **Repository Setup**
   - Ask user for GitHub repository URL or name (e.g., "owner/repo" or full URL)
   - Clone or access the repository if not already available
   - Verify access to the codebase and required files

2. **Dependency Inventory**
   - Scan package manifests (package.json, requirements.txt, pom.xml, go.mod, Gemfile, etc.)
   - Extract all direct and transitive dependencies with versions
   - Create a complete dependency tree for analysis

3. **Vulnerability Scanning**
   - Run dependency security scanners (npm audit, pip-audit, Maven dependency-check, etc.)
   - Query vulnerability databases (NVD, GitHub Advisory, Snyk, etc.)
   - Identify all CVEs affecting current dependency versions

4. **Container Image Scanning**
   - Scan Docker images using tools like Trivy, Grype, or Snyk
   - Identify vulnerabilities in base images and layers
   - Check for OS-level vulnerabilities in container environments
   - Scan container registries for image vulnerabilities

5. **System Component Assessment**
   - Check operating system and runtime versions for known CVEs
   - Identify vulnerable libraries and frameworks in use
   - Scan for vulnerabilities in system-level dependencies

6. **Vulnerability Cataloging**
   - Create structured inventory of all identified CVEs
   - Include CVE IDs, affected components (packages, images, OS), versions, and CVSS scores
   - Categorize by severity (Critical, High, Medium, Low) and type (dependency, image, OS)
   - Note any actively exploited vulnerabilities
   - Document the source repository being scanned

## Output
- **Vulnerability Inventory**: `artifacts/fix-cve/reports/vulnerability-inventory-YYYY-MM-DD.md`
  - Complete list of identified CVEs with metadata (CVSS score, affected component, version, type)
  - Repository information and scan timestamp

- **Scan Results**: `artifacts/fix-cve/reports/scan-results-YYYY-MM-DD.md`
  - Raw output from security scanning tools with full technical details
  - Separate sections for dependencies, container images, and OS vulnerabilities

## Usage Examples

Basic usage (will prompt for repository):
```
/fix-cve.identify
```

With repository specified:
```
/fix-cve.identify https://github.com/owner/repo
```

Focus on specific vulnerability types:
```
/fix-cve.identify Scan container images only for owner/repo
```

## Success Criteria

After running this command, you should have:
- [ ] GitHub repository identified and accessible
- [ ] Complete inventory of all dependencies, container images, and OS components with versions
- [ ] List of all CVEs affecting packages, images, and system components with severity ratings
- [ ] Prioritized list of vulnerabilities by CVSS score and type
- [ ] Identification of any actively exploited CVEs requiring immediate attention

## Next Steps

After completing this phase:
1. Run `/fix-cve.analyze` to deep-dive into identified vulnerabilities
2. Or review the vulnerability inventory in `artifacts/fix-cve/reports/`

## Notes
- **Repository is required**: This command will prompt for GitHub repository if not provided
- Scan results are time-sensitive; new CVEs are published daily
- False positives may occur; analysis phase will validate findings
- Some scanners require API keys or internet access
- Consider scanning both production and development dependencies separately
- Container image scanning requires tools like Trivy, Grype, or Snyk
- For private repositories, ensure proper authentication is configured
