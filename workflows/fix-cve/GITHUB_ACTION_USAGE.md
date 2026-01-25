# Using the CVE Fix Workflow as a GitHub Action

This guide explains how to use the CVE Fix Workflow as a **reusable GitHub Action** in any repository.

## 🎯 Overview

The CVE Fix Workflow is now available as a **reusable GitHub Actions workflow** that any repository can import and use with a single line of code.

**No code duplication needed!** All repositories reference the same workflow from the central `acp-workflows` repository.

## 📦 Quick Setup (5 Minutes)

### Step 1: Add Workflow to Your Repository

Create `.github/workflows/cve-scan.yml` in your repository:

```yaml
name: CVE Scan

on:
  schedule:
    - cron: '0 2 1 * *'  # Monthly on 1st at 2 AM UTC
  workflow_dispatch:     # Manual trigger

jobs:
  cve-fix:
    uses: YOUR_USERNAME/acp-workflows/.github/workflows/cve-fix-workflow.yml@main
    with:
      create_pr: true
      severity_threshold: 'HIGH'
      target_branch: 'main'
    permissions:
      contents: write
      pull-requests: write
```

**That's it!** Replace `YOUR_USERNAME` with your GitHub username.

### Step 2: Enable GitHub Actions

1. Go to repository **Settings** → **Actions** → **General**
2. Under "Workflow permissions":
   - Select: **"Read and write permissions"**
   - Enable: **"Allow GitHub Actions to create pull requests"**
3. Click **Save**

### Step 3: Test It

1. Go to **Actions** tab
2. Click **"CVE Scan"** workflow
3. Click **"Run workflow"**
4. Watch the 7 phases execute automatically

## ✨ Key Features

### 📊 Enhanced Review Summary

The workflow automatically analyzes all proposed fixes and provides a detailed breakdown:

**Safe vs Risky Classification:**
- **Safe Fixes:** Patch or minor version updates (e.g., 1.2.3 → 1.2.4 or 1.2.0 → 1.3.0)
  - Unlikely to introduce breaking changes
  - Recommended for immediate application
  - Minimal testing required

- **Risky Fixes:** Major version updates (e.g., 1.x.x → 2.0.0)
  - May contain breaking changes
  - Require careful review and testing
  - May need code modifications

**Alarming Pattern Detection:**
- Warns if >5 risky fixes detected (suggests staged rollout)
- Flags packages with missing or incomplete documentation
- Highlights fixes requiring extra caution

**Visible in:**
- GitHub Actions summary (real-time during workflow run)
- Pull request description (executive summary)
- Downloadable artifacts (detailed reports)

### 🎯 Automated Decision Support

The workflow helps you prioritize remediation efforts:
1. **Quick wins:** Apply safe fixes immediately
2. **Careful review:** Schedule time for risky fixes
3. **Research needed:** Investigate packages with missing docs

## 🔧 Configuration Options

### Basic Configuration

```yaml
jobs:
  cve-fix:
    uses: YOUR_USERNAME/acp-workflows/.github/workflows/cve-fix-workflow.yml@main
    with:
      create_pr: true              # Auto-create PR with fixes
      severity_threshold: 'HIGH'    # Minimum severity: LOW, MEDIUM, HIGH, CRITICAL
      target_branch: 'main'         # Branch to create PR against
```

### Advanced Configuration

```yaml
jobs:
  cve-fix:
    uses: YOUR_USERNAME/acp-workflows/.github/workflows/cve-fix-workflow.yml@main
    with:
      create_pr: true
      severity_threshold: 'CRITICAL'  # Only critical CVEs
      target_branch: 'develop'        # Target develop branch
    permissions:
      contents: write
      pull-requests: write
      security-events: write    # For SARIF upload
```

### Schedule Options

```yaml
on:
  schedule:
    # Run monthly
    - cron: '0 2 1 * *'

    # Or run weekly
    # - cron: '0 2 * * 1'  # Every Monday at 2 AM

    # Or run daily
    # - cron: '0 2 * * *'  # Every day at 2 AM

  # Allow manual runs
  workflow_dispatch:
```

## 📊 Workflow Outputs

The workflow provides outputs you can use:

```yaml
jobs:
  cve-fix:
    uses: YOUR_USERNAME/acp-workflows/.github/workflows/cve-fix-workflow.yml@main
    # ... configuration ...

  notify:
    needs: cve-fix
    runs-on: ubuntu-latest
    steps:
      - name: Send notification
        run: |
          echo "CVEs found: ${{ needs.cve-fix.outputs.cves_found }}"
          echo "PR URL: ${{ needs.cve-fix.outputs.pr_url }}"
```

**Available outputs:**
- `cves_found` - Number of CVEs detected
- `pr_url` - Pull request URL (if created)

## 📁 What Gets Created

When the workflow runs, it automatically:

### 1. Artifacts (Downloadable)
```
artifacts/
├── reports/           # Scan results (npm, pip, trivy)
├── analysis/          # Severity analysis
├── review/            # Release documentation review with safe/risky fix classification
│   ├── release-review-*.md     # Complete version comparison analysis
│   ├── safe-fixes-*.md         # Patch/minor updates ready to apply
│   └── risky-fixes-*.md        # Major version changes requiring review
├── remediation/       # Fix logs
├── testing/           # Test results
├── verification/      # Re-scan results
└── docs/              # Executive summary with review findings
```

### 2. Pull Request (if fixes available)
- **Title:** "Security: CVE Fixes - [Month Year]"
- **Labels:** security, cve-fix, automated
- **Body:** Executive summary with detailed review findings including:
  - Safe fixes count (patch/minor updates)
  - Risky fixes count (major version changes)
  - Alarming patterns detected
  - Conditional recommendations based on fix types

**Note:** If no automatic fixes are available, the workflow completes without creating a PR. All scan results are available in the downloadable artifacts.

## 🌟 Benefits of This Approach

### ✅ No Code Duplication
- **Single source of truth** in `acp-workflows` repository
- All repositories reference the same workflow
- Updates to workflow automatically apply to all users

### ✅ Easy to Use
- Add 1 file to any repository
- 20 lines of YAML
- No scripts to maintain

### ✅ Centralized Updates
- Fix bugs in one place
- Add features once, everyone benefits
- Version pinning available (`@main`, `@v1`, etc.)

### ✅ Consistent Results
- Same scanning tools across all repos
- Same 7-phase methodology
- Same reporting format

## 🔄 How It Works

```
┌─────────────────────────────────────┐
│  Your Repository                    │
│  .github/workflows/cve-scan.yml     │
│                                     │
│  uses: acp-workflows/...@main       │ ← Single line reference
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  acp-workflows Repository           │
│  .github/workflows/                 │
│    cve-fix-workflow.yml             │ ← The actual workflow
│                                     │
│  Phases:                            │
│  1. Identify   → Scan for CVEs      │
│  2. Analyze    → Assess severity    │
│  3. Review     → Check releases     │
│  4. Remediate  → Apply fixes        │
│  5. Test       → Validate fixes     │
│  6. Verify     → Confirm resolution │
│  7. Document   → Generate reports   │
└─────────────────────────────────────┘
```

## 📖 Examples

### Example 1: Node.js Project

```yaml
# .github/workflows/cve-scan.yml
name: Monthly Security Scan

on:
  schedule:
    - cron: '0 2 1 * *'
  workflow_dispatch:

jobs:
  security-scan:
    uses: YOUR_USERNAME/acp-workflows/.github/workflows/cve-fix-workflow.yml@main
    with:
      create_pr: true
      severity_threshold: 'HIGH'
    permissions:
      contents: write
      pull-requests: write
```

### Example 2: Python Project

Same configuration! The workflow automatically detects project type and uses appropriate tools.

### Example 3: Multiple Languages

Works automatically! Scans Node.js, Python, Docker, and more in the same run.

### Example 4: Custom Branch Strategy

```yaml
jobs:
  cve-scan:
    uses: YOUR_USERNAME/acp-workflows/.github/workflows/cve-fix-workflow.yml@main
    with:
      create_pr: true
      severity_threshold: 'CRITICAL'
      target_branch: 'develop'  # Create PR against develop
```

## 🔐 Security Considerations

### Required Permissions

The workflow needs:
- `contents: write` - To push fix branches
- `pull-requests: write` - To create PRs

### Private Repositories

For private repos:
1. The `acp-workflows` repository can be public (workflow is public)
2. Your repository can be private (scanned repo is private)
3. The workflow runs in YOUR repository's context with YOUR secrets

### Public Repositories

Works out of the box with no additional configuration.

## 🛠️ Troubleshooting

### "Resource not accessible by integration"

**Problem:** Workflow can't create PRs

**Solution:** Enable workflow permissions:
1. Settings → Actions → General
2. Workflow permissions → "Read and write"
3. Enable "Allow GitHub Actions to create PRs"

### "Workflow not found"

**Problem:** Can't find the reusable workflow

**Solution:** Check:
1. Repository name is correct (`YOUR_USERNAME/acp-workflows`)
2. Path is correct (`.github/workflows/cve-fix-workflow.yml`)
3. Branch/tag is correct (`@main`)
4. Repository is accessible (public or you have access)

### No CVEs Found

**Problem:** Scan completes but finds 0 CVEs

**Solution:**
- Your dependencies are up to date! ✅
- Or check scan logs for errors
- Try lowering severity threshold: `severity_threshold: 'MEDIUM'`

## 📚 Additional Resources

- **Main Workflow Documentation:** See workflows/fix-cve/README.md
- **Tools Requirements:** See workflows/fix-cve/TOOLS_REQUIREMENTS.md
- **Hooks Guide:** See workflows/fix-cve/HOOKS_GUIDE.md

## 🚀 Getting Started Checklist

- [ ] Push `acp-workflows` repository to GitHub
- [ ] Verify `.github/workflows/cve-fix-workflow.yml` exists
- [ ] Make repository public (or grant access to users)
- [ ] In your target repository:
  - [ ] Create `.github/workflows/cve-scan.yml`
  - [ ] Replace `YOUR_USERNAME` with actual username
  - [ ] Enable workflow permissions
  - [ ] Test run the workflow
- [ ] Review the PR or issue created
- [ ] Merge fixes when validated

## 📞 Support

**Issues with the workflow itself:**
Open issue in `acp-workflows` repository

**Issues with scanning your repository:**
Check workflow run logs in Actions tab

---

**Version:** 1.0.0
**Last Updated:** 2024
**Maintained by:** CVE Fix Workflow Team
