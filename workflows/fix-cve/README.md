# CVE Fix Workflow

Systematically identify, analyze, and remediate CVE vulnerabilities in packages, libraries, and container images using a structured, methodical approach that prioritizes safe, verified fixes.

## Overview

This workflow guides you through CVE remediation using a structured 7-phase approach:

### 1. Identify
Scan packages, dependencies, and container images (Docker, etc.) from a GitHub repository to discover all CVE vulnerabilities, creating a comprehensive vulnerability inventory.

### 2. Analyze
Deep-dive into CVE details including severity, exploitability, business impact, and available remediation options to prioritize fixes.

### 3. Review Release
Review release notes, changelogs, and documentation for proposed fixes to identify breaking changes, new dependencies, and ensure fixes are safe and well-documented. Flags fixes with missing documentation.

### 4. Remediate
Apply safe, verified security patches, upgrade vulnerable dependencies, and implement fixes to address identified CVEs.

### 5. Test
Validate that fixes are effective, vulnerabilities are resolved, and no regressions are introduced.

### 6. Verify
Perform final security verification through re-scanning and compliance checks to confirm complete CVE resolution.

### 7. Document
Create comprehensive documentation of vulnerabilities, remediations, and lessons learned for audit and knowledge transfer. Optionally auto-create pull requests with `--create-pr` flag.

## Getting Started

### Prerequisites

**Tools Required:**
- Git (version control)
- GitHub CLI (`gh`) - for automatic PR creation
- Security scanner (Trivy recommended - scans dependencies, containers, and filesystems)
- Language-specific tools (npm/pip/maven/go based on your project)
- Optional: Docker (for container scanning)

**See [TOOLS_REQUIREMENTS.md](TOOLS_REQUIREMENTS.md) for complete installation guide and setup instructions.**

**Other Requirements:**
- GitHub repository URL (required for scanning)
- Understanding of technology stack and deployment environment
- **Recommended:** Validation hooks configured for automated testing (see HOOKS_GUIDE.md)

### Installation

**Step 1: Install Required Tools**

Quick setup (macOS):
```bash
# Core tools
brew install git gh aquasecurity/trivy/trivy

# Authenticate with GitHub
gh auth login

# Language-specific (install as needed)
brew install node  # for Node.js projects
brew install python  # for Python projects
```

Quick setup (Ubuntu/Debian):
```bash
# See TOOLS_REQUIREMENTS.md for complete installation scripts
```

**Verify installation:**
```bash
git --version
gh --version
trivy --version
```

**Step 2: Load the Workflow**
1. Clone this workflow repository
2. Load the workflow in your ACP session

**Step 3: Start Scanning**
```bash
/fix-cve.identify <github-repo-url>
```

**See [TOOLS_REQUIREMENTS.md](TOOLS_REQUIREMENTS.md) for detailed installation instructions.**

## Workflow Phases

### Phase 1: Identify
**Command:** `/fix-cve.identify <github-repo-url>`

Scan packages, dependencies, and container images from a GitHub repository to discover CVE vulnerabilities. Creates a complete vulnerability inventory covering:
- Package dependencies (npm, pip, Maven, Go, Ruby, etc.)
- Container images (Docker base images and layers)
- OS-level vulnerabilities in containers

**Output:**
- `artifacts/fix-cve/reports/vulnerability-inventory-YYYY-MM-DD.md` - Complete CVE inventory by type
- `artifacts/fix-cve/reports/scan-results-YYYY-MM-DD.md` - Raw scanner output

### Phase 2: Analyze
**Command:** `/fix-cve.analyze`

Research CVE technical details, assess exploitability in your environment, evaluate business impact, and identify remediation options. Produces prioritized risk assessment for targeted remediation.

**Output:**
- `artifacts/fix-cve/analysis/cve-analysis-YYYY-MM-DD.md` - Detailed CVE analysis
- `artifacts/fix-cve/analysis/risk-matrix-YYYY-MM-DD.md` - Prioritized risk matrix

### Phase 3: Review Release
**Command:** `/fix-cve.review-release`

Review release notes, changelogs, and documentation for proposed fixes. Identifies breaking changes, new dependencies, and compatibility issues. **Critically important:** Reports fixes with missing or incomplete documentation to help avoid risky updates.

**Output:**
- `artifacts/fix-cve/review/release-review-YYYY-MM-DD.md` - Release documentation review
- `artifacts/fix-cve/review/safe-fixes-YYYY-MM-DD.md` - Safe, well-documented fixes
- `artifacts/fix-cve/review/risky-fixes-YYYY-MM-DD.md` - Risky fixes or missing docs

### Phase 4: Remediate
**Command:** `/fix-cve.remediate`

Apply safe, verified security patches, upgrade dependencies to fixed versions, implement workarounds, and configure security controls. Prioritizes fixes marked as "safe" in the review phase.

**Output:**
- `artifacts/fix-cve/remediation/remediation-log-YYYY-MM-DD.md` - Detailed remediation log
- `artifacts/fix-cve/remediation/patch-summary-YYYY-MM-DD.md` - Patch summary

### Phase 5: Test
**Command:** `/fix-cve.test`

Validate fixes are effective through security testing, verify no regressions through functional testing, and assess performance impact of security patches.

**Output:**
- `artifacts/fix-cve/testing/test-report-YYYY-MM-DD.md` - Comprehensive test results
- `artifacts/fix-cve/testing/regression-summary-YYYY-MM-DD.md` - Regression analysis

### Phase 5: Verify
**Command:** `/fix-cve.verify`

Re-scan for vulnerabilities, confirm CVE resolution, validate security controls, and perform compliance checks to ensure complete remediation.

**Output:**
- `artifacts/fix-cve/verification/verification-report-YYYY-MM-DD.md` - Final verification report
- `artifacts/fix-cve/verification/residual-risk-YYYY-MM-DD.md` - Residual risk assessment

### Phase 6: Document
**Command:** `/fix-cve.document` or `/fix-cve.document --create-pr`

Generate comprehensive documentation including executive summaries, technical reports, runbooks, and lessons learned for audit trail and knowledge transfer.

**Optional:** Use `--create-pr` flag to automatically create a pull request with:
- Pre-PR validation hooks run automatically
- Executive summary as PR description
- Security labels and assignments
- Comprehensive validation before PR creation

**Output:**
- `artifacts/fix-cve/docs/executive-summary-YYYY-MM-DD.md` - Executive summary
- `artifacts/fix-cve/docs/technical-report-YYYY-MM-DD.md` - Technical documentation
- `artifacts/fix-cve/docs/remediation-runbook-YYYY-MM-DD.md` - Remediation runbook
- **If --create-pr used:** Pull request created automatically

## Available Agents

This workflow includes the following expert agents:

### Security Engineer - Security Specialist
Expert in CVE assessment, security patch management, and vulnerability remediation with deep knowledge of CVSS scoring and secure coding practices.
**Expertise:** CVE database research, risk assessment, remediation planning

### CVE Analyst - Vulnerability Intelligence Specialist
Specialized in researching CVE technical details, tracking vulnerability lifecycles, and analyzing exploit patterns and patch quality.
**Expertise:** CVE research, exploit analysis, vulnerability intelligence

### Test Engineer - Quality Assurance Specialist
Expert in security patch testing, regression prevention, and validation of vulnerability fixes to ensure effective remediation.
**Expertise:** Security testing, regression testing, patch validation

## Output Artifacts

All workflow outputs are saved in the `artifacts/fix-cve/` directory:

```
artifacts/fix-cve/
├── reports/        # Vulnerability inventories and scan results
├── analysis/       # CVE analysis and risk assessments
├── review/         # Release documentation reviews and safe/risky fix lists
├── remediation/    # Patch logs and remediation summaries
├── testing/        # Test reports and regression analysis
├── verification/   # Verification reports and residual risk
└── docs/           # Executive summaries and technical documentation
```

## Example Usage

```bash
# Step 1: Scan for CVE vulnerabilities (requires GitHub repo)
/fix-cve.identify https://github.com/owner/repo

# Step 2: Analyze CVE severity and impact
/fix-cve.analyze

# Step 3: Review release documentation for proposed fixes
/fix-cve.review-release

# Step 4: Apply safe, verified patches and fixes
/fix-cve.remediate

# Step 5: Test fixes and check for regressions
/fix-cve.test

# Step 6: Verify complete CVE resolution
/fix-cve.verify

# Step 7: Generate documentation (and optionally create PR)
/fix-cve.document

# OR: Automatically create pull request with validation
/fix-cve.document --create-pr
```

## What CVEs Does This Workflow Fix?

This workflow handles CVE vulnerabilities across multiple layers:

### Package Dependencies
- **JavaScript/Node.js:** npm, yarn, pnpm packages
- **Python:** pip, conda packages
- **Java:** Maven, Gradle dependencies
- **Go:** Go modules
- **Ruby:** Bundler gems
- **PHP:** Composer packages
- **.NET:** NuGet packages
- **Rust:** Cargo crates

### Container Images
- **Docker Images:** Base images and layers
- **Kubernetes:** Container registry images
- **OS-Level:** Alpine, Ubuntu, Debian, RHEL base images
- **Image Layers:** Vulnerabilities in intermediate layers

### System Components
- Runtime vulnerabilities (Node.js, Python, JVM, etc.)
- Operating system packages
- System libraries

## Configuration

This workflow is configured via `.ambient/ambient.json`. Key settings:

- **Name:** fix-cve
- **Description:** Systematically identify, analyze, and remediate CVE vulnerabilities in packages, libraries, and container images
- **Artifact Path:** `artifacts/fix-cve/`

## Customization

You can customize this workflow by:

1. **Modifying agents:** Edit files in `.claude/agents/` to adjust agent expertise and behavior
2. **Adding commands:** Create new command files in `.claude/commands/` for additional phases
3. **Adjusting configuration:** Update `.ambient/ambient.json` to change prompts or artifact paths
4. **Changing output paths:** Modify the `results` section in config to customize artifact locations

## Automated Testing with Hooks

This workflow supports **validation hooks** to automate testing at critical phases:

### Pre-Remediation Hooks
Run before applying fixes to establish a baseline:
- Verify existing tests pass
- Create dependency snapshots
- Baseline security scan

### Post-Remediation Hooks
Run after applying fixes to catch immediate issues:
- Quick smoke tests
- Dependency installation check
- Critical vulnerability scan

### Pre-PR Hooks
Run before creating pull requests for comprehensive validation:
- Full test suite
- Linting and type checking
- Build verification
- Complete security scan
- Documentation verification

**See [HOOKS_GUIDE.md](HOOKS_GUIDE.md) for complete setup instructions and examples.**

## Automatic Pull Request Creation

The workflow supports **automatic PR creation** with the `--create-pr` flag:

```bash
/fix-cve.document --create-pr
```

**What happens automatically:**
1. ✅ All documentation is generated
2. ✅ Pre-PR validation hooks run (tests, linting, security scans)
3. ✅ Pull request created with executive summary as description
4. ✅ Security labels and assignments applied
5. ✅ PR URL returned for review

**If validation fails:** Documentation is created but PR is skipped with error details.

**Custom PR options:**
```bash
# Custom title and reviewers
/fix-cve.document --create-pr --title "Critical: Fix CVE-2024-1234" --reviewer @security-team

# Draft PR for review
/fix-cve.document --create-pr --draft

# Target specific branch
/fix-cve.document --create-pr --base develop
```

## Best Practices

1. **Provide GitHub Repository:** Always specify the repository URL when running `/fix-cve.identify`
2. **Configure Hooks:** Set up validation hooks before starting remediation (see HOOKS_GUIDE.md)
3. **Review Release Documentation:** Never skip the review-release phase - it protects against risky updates
4. **Prioritize Safe Fixes:** Start with fixes marked as "safe" with good documentation and no breaking changes
5. **Watch for Missing Documentation:** Treat poorly documented fixes as higher risk
6. **Scan Multiple Layers:** Include both package dependencies and container images in scans
7. **Run Hooks at Each Phase:** Let automated hooks catch issues early
8. **Use Automatic PR Creation:** Add `--create-pr` flag to automate PR creation with validation
9. **Test Before Production:** Always validate patches in staging environments before deploying to production
10. **Maintain Audit Trail:** Document all changes for compliance and future reference
11. **Regular Scanning:** Schedule periodic vulnerability scans to catch new CVEs early

## Troubleshooting

**Problem:** Security scanners report false positives
**Solution:** Verify CVE applicability in your specific environment during the analyze phase; not all CVEs affect all configurations

**Problem:** Patches introduce breaking changes
**Solution:** Review vendor changelogs carefully, test thoroughly, and consider alternative remediation strategies if upgrades aren't feasible

## Contributing

To improve this workflow:
1. Fork the repository
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## License

MIT

## Key Documentation

- **[README.md](README.md)** - Workflow overview and getting started
- **[TOOLS_REQUIREMENTS.md](TOOLS_REQUIREMENTS.md)** - Required tools installation guide
- **[HOOKS_GUIDE.md](HOOKS_GUIDE.md)** - Automated testing hooks setup
- **[FIELD_REFERENCE.md](FIELD_REFERENCE.md)** - Configuration reference

## Support

For issues or questions:
- Open an issue in the repository
- Refer to the [ACP documentation](https://ambient-code.github.io/vteam)

---

**Created with:** ACP Workflow Creator
**Workflow Type:** Custom CVE Remediation with Automated Validation Hooks
**Version:** 1.0.0
