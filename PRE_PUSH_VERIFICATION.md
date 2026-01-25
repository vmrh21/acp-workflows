# Pre-Push Verification Checklist

**Date:** 2026-01-25
**Purpose:** Verify CVE Fix Workflow before pushing to production

---

## ✅ YAML Validation

- [x] **Syntax Valid:** YAML parses without errors
- [x] **Structure:** 20 total steps across 7 phases
- [x] **Permissions:** Only `contents: write` and `pull-requests: write` (no issues)
- [x] **Triggers:** `workflow_call` correctly configured

---

## 📋 Workflow Structure Verification

### Phase Breakdown
- [x] **Phase 1: Identify** - 1 step (scans npm, pip, Trivy)
- [x] **Phase 2: Analyze** - 1 step (severity analysis)
- [x] **Phase 3: Review** - 6 steps (SPLIT to avoid 21k char limit)
  - [x] 3.1: Initialize Review
  - [x] 3.2: Review npm Packages
  - [x] 3.3: Review Python Packages
  - [x] 3.4: Review Other Languages (Ruby, Go, Java, Rust, PHP, .NET, etc.)
  - [x] 3.5: Review Containers
  - [x] 3.6: Generate Review Summary
- [x] **Phase 4: Remediate** - 1 step (npm audit fix, track changes)
- [x] **Phase 5: Test** - 1 step (validate fixes)
- [x] **Phase 6: Verify** - 1 step (re-scan)
- [x] **Phase 7: Document** - 1 step (generate executive summary)

### Additional Steps
- [x] Upload Artifacts
- [x] Create Pull Request
- [x] Workflow Summary

---

## 🔍 Coverage Verification

### What We Scan
- [x] Node.js packages (npm audit)
- [x] Python packages (pip-audit)
- [x] All language packages via Trivy (Ruby, Go, Java, Rust, PHP, .NET, Swift, Elixir, Dart, C/C++, Julia)
- [x] Container images (Docker)
- [x] OS packages (Alpine, Debian, Ubuntu)

### What We Review
- [x] Node.js packages - version analysis, safe/risky classification
- [x] Python packages - version analysis, safe/risky classification
- [x] Other languages - universal Trivy review with registry links
- [x] Containers - OS package details, base image assessment

**Coverage:** 100% (16/16 ecosystems)

---

## 🎯 Expected Behavior

### Scenario 1: CVEs Found with Automatic Fixes
**Expected:**
1. Workflow scans repository
2. Finds CVEs (e.g., 20 total)
3. Review categorizes: 12 safe, 8 risky
4. Remediate applies automatic fixes (npm audit fix)
5. PR created with title: "Security: CVE Fixes Applied - January 2026"
6. PR labels: `security`, `cve-fix`, `automated`, `has-fixes`
7. Executive summary shows:
   - "Automatic Fixes Applied: Yes"
   - Lists what was fixed
   - Lists manual review items (8 risky)

### Scenario 2: CVEs Found, All Require Manual Review
**Expected:**
1. Workflow scans repository
2. Finds CVEs (e.g., 15 total)
3. Review categorizes: 0 safe, 15 risky
4. Remediate runs but no automatic fixes possible
5. PR still created with title: "Security: CVE Scan Results - Manual Review Required - January 2026"
6. PR labels: `security`, `cve-fix`, `automated`, `manual-review`
7. Executive summary shows:
   - "Automatic Fixes Applied: No"
   - Explains why (all major version changes)
   - Lists all 15 manual review items

### Scenario 3: No CVEs Found
**Expected:**
1. Workflow scans repository
2. Finds 0 CVEs
3. Workflow completes successfully
4. No PR created
5. GitHub Actions summary: "✅ No vulnerabilities found"

---

## 📊 Executive Summary Verification

### Required Sections (in order)
- [x] **Findings Summary** - CVE count, fixes applied status, safe/risky/missing counts
- [x] **Automatic Fixes Applied** - Shows what was fixed OR why nothing was fixed
- [x] **Manual Review Required** - Lists risky packages OR confirms none
- [x] **Release Review Summary** - Table with counts
- [x] **Alarming Findings** - Placeholder (will be enhanced if patterns detected)
- [x] **Fix Classification** - Explains safe vs risky
- [x] **Phases Completed** - Checklist of 7 phases
- [x] **Next Steps** - Conditional recommendations based on safe/risky counts

### Variables Used Correctly
- [x] `$SAFE_FIXES` - from temp file
- [x] `$RISKY_FIXES` - from temp file
- [x] `$MISSING_DOCS` - from temp file
- [x] `$FIXES_APPLIED_STATUS` - Yes/No
- [x] `${{ steps.identify.outputs.cves_found }}` - from Phase 1
- [x] `${{ env.changes_made }}` - from Phase 4

---

## 🔧 PR Creation Verification

### Conditions
- [x] PR created when: `inputs.create_pr == true && cves_found != '0'`
- [x] Skipped when: `create_pr == false` OR `cves_found == 0`

### Dynamic Behavior
- [x] **If changes made:** Title includes "Fixes Applied", commits code changes
- [x] **If no changes:** Title includes "Manual Review Required", commits artifacts only

### Branch Strategy
- [x] Always creates branch: `cve-fix/automated-YYYY-MM-DD`
- [x] Pushes branch even without code changes (to preserve artifacts)

---

## 🚨 Known Limitations

### Current State
1. **Python fixes:** Detected but not automatically applied (requires manual requirements.txt update)
2. **Other languages:** Reviewed but not automatically fixed (only npm has auto-fix)
3. **Remediation:** Only handles npm automatically

### This is Expected
- npm has `npm audit fix` command (automatic)
- Python, Ruby, Go, etc. don't have universal auto-fix commands
- The workflow CORRECTLY identifies these as manual review items

---

## 📝 Test Repository Setup

### cve-test-repo Configuration
- [x] Has vulnerable npm packages (15-20 CVEs expected)
- [x] Has vulnerable Python packages (10-15 CVEs expected)
- [x] Has vulnerable Dockerfile (5-10 CVEs expected)
- [x] Total expected: 30-45 CVEs

### Monthly Scan Workflow
- [x] File: `.github/workflows/monthly-cve-scan.yml`
- [x] References: `vmrh21/acp-workflows/.github/workflows/cve-fix-workflow.yml@main`
- [x] Inputs: `create_pr: true`, `severity_threshold: HIGH`
- [x] Permissions: `contents: write`, `pull-requests: write`

---

## 🎯 What to Verify After Push

### Step 1: Push to GitHub
```bash
cd /Users/vaishnavimodi/Workspace/acp-workflows
git add .
git commit -m "fix: Complete CVE workflow with 100% review coverage and enhanced PR creation"
git push origin main
```

### Step 2: Trigger Test Workflow
```bash
cd /Users/vaishnavimodi/Workspace/cve-test-repo
git push origin main  # This triggers monthly-cve-scan.yml
```

OR manually trigger:
- Go to cve-test-repo → Actions → "Monthly CVE Scan"
- Click "Run workflow"

### Step 3: Monitor Execution

**Watch for:**
1. ✅ Phase 1 completes (scans npm, pip, Trivy)
2. ✅ Phase 2 completes (severity analysis)
3. ✅ Phase 3 completes (6 sub-steps, all succeed)
4. ✅ Phase 4 completes (npm fixes applied)
5. ✅ Phase 5 completes (tests run)
6. ✅ Phase 6 completes (verification)
7. ✅ Phase 7 completes (documentation)
8. ✅ PR created

### Step 4: Verify PR Content

**PR Title should be:**
- "Security: CVE Fixes Applied - January 2026" (if npm fixes applied)
- OR "Security: CVE Scan Results - Manual Review Required - January 2026" (if only manual fixes)

**PR Description should show:**
```markdown
## Findings Summary
- Total CVEs Found: 30-45
- Automatic Fixes Applied: Yes/No
- Safe Fixes Available: X
- Manual Review Required: Y

## Automatic Fixes Applied
[Section with npm fixes OR explanation why none]

## Manual Review Required
[List of risky packages OR confirmation none needed]

## Release Review Summary
| Category | Count | Status |
[Table with counts]
```

### Step 5: Verify Artifacts

**Download artifacts from Actions run:**
- `artifacts/fix-cve/reports/` - Scan results
- `artifacts/fix-cve/review/` - Review reports (release-review, safe-fixes, risky-fixes)
- `artifacts/fix-cve/docs/` - Executive summary

**Check review reports contain:**
- `release-review-*.md` - Sections for npm, Python, Other Languages, Containers
- `safe-fixes-*.md` - List of safe updates
- `risky-fixes-*.md` - List of risky updates

### Step 6: Verify GitHub Actions Summary

**Should show:**
```
📝 Phase 3: Review Release Documentation

### 📦 Node.js Package Review
  - ✅ package1: 1.0.0 → 1.0.1 (Safe)
  - ⚠️  package2: 1.0.0 → 2.0.0 (Major)

### 🐍 Python Package Review
  - ✅ package3: 2.0.0 → 2.1.0 (Safe)

### 📚 Other Language Packages
  [Any Ruby, Go, Java findings]

### 🐳 Container Image Review
  [OS package vulnerabilities]

### 📊 Release Review Summary
| Metric | Count |
| Safe Fixes | X |
| Risky Fixes | Y |
| Missing Docs | Z |
```

---

## ✅ Success Criteria

### Must Have
- [x] YAML validation passes
- [x] All 7 phases defined
- [x] Phase 3 split into 6 sub-steps (avoid char limit)
- [x] 100% package ecosystem coverage (16/16)
- [x] PR always created when CVEs found
- [x] Executive summary has all sections
- [x] Safe/risky classification works
- [x] Counters tracked via temp files
- [x] No syntax errors

### Expected Outcomes
- [ ] Workflow runs without errors (verify after push)
- [ ] PR created with correct title/labels (verify after push)
- [ ] Executive summary shows automatic vs manual (verify after push)
- [ ] All package types reviewed (verify in artifacts)
- [ ] Counts accurate (verify matches scan results)

---

## 🐛 Potential Issues to Watch For

### Issue 1: Temp File Persistence
**Symptom:** Counters show 0 in final summary
**Cause:** Temp files not persisting between steps
**Fix:** Already using `/tmp/` which persists across steps in same job

### Issue 2: Git Commit Fails
**Symptom:** "nothing to commit" error in remediate phase
**Cause:** npm audit fix made no changes
**Fix:** Already handled with `if ! git diff --quiet`

### Issue 3: PR Creation Fails
**Symptom:** Permissions error
**Cause:** Workflow permissions not granted
**Fix:** User needs to enable in cve-test-repo settings

### Issue 4: Multiline Variables
**Symptom:** Environment variable truncated
**Cause:** Newlines in `fixes_applied`
**Fix:** Already sanitized with `tr '\n' ' '`

---

## 📚 Reference Documentation

- **WORKFLOW_COVERAGE_AUDIT.md** - Gap analysis (before fix)
- **COMPLETE_COVERAGE_SUMMARY.md** - 100% coverage verification
- **PR_CREATION_FIX_SUMMARY.md** - PR creation enhancement details
- **GITHUB_ACTION_USAGE.md** - How to use as reusable workflow

---

## 🚀 Ready to Push?

**Checklist before pushing:**
- [x] YAML validation passed
- [x] All phases verified
- [x] Coverage complete (16/16 ecosystems)
- [x] PR creation logic updated
- [x] Executive summary enhanced
- [x] No syntax errors
- [x] Documentation updated

**Status: ✅ READY TO PUSH**

After pushing, trigger the workflow in cve-test-repo and verify the PR created matches the expected behavior above.
