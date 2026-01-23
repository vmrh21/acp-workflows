# Fix CVE Workflow - Field Reference

This document provides detailed information about the configuration fields in `.ambient/ambient.json`.

## Required Fields

### name
- **Type:** string
- **Purpose:** Display name shown in ACP UI
- **Current Value:** "CVE Fix Workflow"
- **Guidelines:** Keep concise (2-5 words), use title case

### description
- **Type:** string
- **Purpose:** Explains workflow purpose in UI
- **Current Value:** "Systematically identify, analyze, and remediate CVE vulnerabilities"
- **Guidelines:** 1-3 sentences, clear and specific

### systemPrompt
- **Type:** string
- **Purpose:** Defines AI agent's role and behavior
- **Current Value:** See `.ambient/ambient.json`
- **Guidelines:**
  - Start with clear role definition
  - List key responsibilities
  - Reference available commands
  - Specify output locations

### startupPrompt
- **Type:** string
- **Purpose:** Initial message when workflow activates
- **Current Value:** See `.ambient/ambient.json`
- **Guidelines:**
  - Greet user warmly
  - List available commands
  - Provide clear next steps

## Optional Fields

### results
- **Type:** object with string values
- **Purpose:** Maps artifact types to file paths
- **Current Value:** See `.ambient/ambient.json`
- **Guidelines:** Use glob patterns to match multiple files

### version
- **Type:** string
- **Example:** "1.0.0"
- **Purpose:** Track workflow configuration version

### author
- **Type:** string or object
- **Example:** {"name": "Your Name", "email": "you@example.com"}
- **Purpose:** Identify workflow creator

### tags
- **Type:** array of strings
- **Example:** ["security", "cve", "vulnerability", "remediation"]
- **Purpose:** Categorize workflow for discovery

### icon
- **Type:** string (emoji)
- **Example:** "🔒"
- **Purpose:** Visual identifier in UI

## Customization Examples

### Adding a new output type
```json
"results": {
  "Vulnerability Reports": "artifacts/fix-cve/reports/**/*.md",
  "Analysis Documents": "artifacts/fix-cve/analysis/**/*.md",
  "Remediation Plans": "artifacts/fix-cve/remediation/**/*.md",
  "Test Results": "artifacts/fix-cve/testing/**/*.md",
  "Verification Reports": "artifacts/fix-cve/verification/**/*.md",
  "Documentation": "artifacts/fix-cve/docs/**/*.md",
  "Scan Logs": "artifacts/fix-cve/logs/**/*.json"
}
```

### Changing artifact location
Update all references to the artifact path in:
1. `systemPrompt` - OUTPUT LOCATIONS section
2. `results` - Update file paths
3. Command files - Update ## Output sections

### Adding environment configuration
```json
"environment": {
  "ARTIFACTS_DIR": "artifacts/fix-cve",
  "LOG_LEVEL": "info",
  "SCAN_SEVERITY_THRESHOLD": "medium"
}
```

## Agent Files

Agent persona files are located in `.claude/agents/` and follow this structure:

```markdown
# {Name} - {Role}
## Role
## Expertise
## Responsibilities
## Communication Style
## When to Invoke
## Tools and Techniques
## Key Principles
## Example Artifacts
```

### Current Agents

1. **security-engineer.md** - Security Specialist
   - Focuses on CVE assessment and remediation planning
   - Expertise in CVSS scoring and security frameworks

2. **cve-analyst.md** - Vulnerability Intelligence Specialist
   - Specializes in CVE research and exploit analysis
   - Tracks vulnerability lifecycles and patch quality

3. **test-engineer.md** - Quality Assurance Specialist
   - Expert in security testing and regression prevention
   - Validates vulnerability fixes and system functionality

## Command Files

Slash command files are located in `.claude/commands/` and follow this structure:

```markdown
# /{command-name} - {Description}
## Purpose
## Prerequisites
## Process
## Output
## Usage Examples
## Success Criteria
## Next Steps
## Notes
```

### Current Commands

1. **fix-cve.identify.md** - Scan and identify CVE vulnerabilities (requires GitHub repository)
2. **fix-cve.analyze.md** - Analyze CVE details and impact
3. **fix-cve.review-release.md** - Review release documentation for proposed fixes
4. **fix-cve.remediate.md** - Implement safe, verified CVE fixes and patches (with pre/post hooks)
5. **fix-cve.test.md** - Test CVE remediations
6. **fix-cve.verify.md** - Verify complete CVE resolution
7. **fix-cve.document.md** - Generate CVE documentation (optionally create PR with --create-pr flag)

## File Naming Conventions

- **Workflow directory:** `workflows/fix-cve/`
- **Agent files:** `{name}-{role}.md` (e.g., `security-engineer.md`)
- **Command files:** `fix-cve.{phase}.md` (e.g., `fix-cve.identify.md`)
- **Artifacts:** `artifacts/fix-cve/{category}/{files}`

## Validation Checklist

Before using this workflow, verify:

- [ ] `.ambient/ambient.json` is valid JSON (no comments)
- [ ] All required fields are present
- [ ] All agent files follow the template structure
- [ ] All command files have unique names
- [ ] Output paths in config match those in commands
- [ ] README.md accurately describes the workflow
- [ ] All file references use correct paths

## Workflow Artifact Structure

```
artifacts/fix-cve/
├── reports/
│   ├── vulnerability-inventory-YYYY-MM-DD.md
│   └── scan-results-YYYY-MM-DD.md
├── analysis/
│   ├── cve-analysis-YYYY-MM-DD.md
│   └── risk-matrix-YYYY-MM-DD.md
├── review/
│   ├── release-review-YYYY-MM-DD.md
│   ├── safe-fixes-YYYY-MM-DD.md
│   └── risky-fixes-YYYY-MM-DD.md
├── remediation/
│   ├── remediation-log-YYYY-MM-DD.md
│   └── patch-summary-YYYY-MM-DD.md
├── testing/
│   ├── test-report-YYYY-MM-DD.md
│   └── regression-summary-YYYY-MM-DD.md
├── verification/
│   ├── verification-report-YYYY-MM-DD.md
│   └── residual-risk-YYYY-MM-DD.md
└── docs/
    ├── executive-summary-YYYY-MM-DD.md
    ├── technical-report-YYYY-MM-DD.md
    └── remediation-runbook-YYYY-MM-DD.md
```

## References

- [ACP Documentation](https://ambient-code.github.io/vteam)
- [Template Workflow](https://github.com/ambient-code/workflows/tree/main/workflows/template-workflow)
- [Workflow Best Practices](https://ambient-code.github.io/vteam/guides/workflows)
- [NVD - National Vulnerability Database](https://nvd.nist.gov/)
- [MITRE CVE Database](https://cve.mitre.org/)
- [CVSS Calculator](https://www.first.org/cvss/calculator/3.1)
