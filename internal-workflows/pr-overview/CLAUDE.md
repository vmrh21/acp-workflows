# Review Queue

You evaluate all open PRs in a repo and produce a prioritized review queue — what needs human attention, ranked by type and urgency.

## What You Do

1. **Fetch all PR data** using the script
2. **Analyze PRs** using the script (blocker checks, type classification)
3. **Evaluate each PR's comments** via sub-agents
4. **Manage the "Review Queue" milestone** — add clean PRs, remove blocked ones
5. **Comment on blocked PRs** with blocker summaries
6. **Write the review queue report** and update the milestone description
7. **Self-evaluate** using `.ambient/rubric.md`

## Scripts

### Fetch

```bash
./scripts/fetch-prs.sh --repo <owner/repo> --output-dir artifacts/pr-review
```

Produces per-PR directories:

```text
artifacts/pr-review/
├── index.json                     # List of all open PRs
├── queue.json                     # Ranked queue (written by analyze step)
└── {number}/
    ├── summary.json               # PR metadata, CI status, comment counts
    ├── analysis.json              # Blocker statuses, type, fail_count (written by analyze)
    ├── comments/
    │   ├── overview.json          # Comment counts, has_agent_prompts flag
    │   └── 01.json, 02.json...  # Chronological comment stream
    ├── ci/
    │   └── overview.json          # Pass/fail/pending check lists
    ├── diff.json                  # Changed files with patches
    └── reviews/
        └── overview.json          # Approvals, changes requested
```

### Analyze

```bash
python3 ./scripts/analyze-prs.py --output-dir artifacts/pr-review
```

Reads each `summary.json`, writes `analysis.json` per PR and `queue.json` at top level.

## Sub-Agent Evaluation

The analyze script handles mechanical checks. Sub-agents handle the nuanced part — reading comment conversations and making judgment calls.

Spawn sub-agents in parallel (batches of ~10). Each reads `summary.json` + `comments/` for its PRs and returns:

- **verdict**: ready / almost / blocked / stale
- **review_summary**: who reviewed, what was raised, was it addressed
- **action_needed**: what a human should do next
- **action_owner**: who needs to act

Key judgment calls:
- Stale bot review on old commit = not blocking
- Author pushed a fix but no re-approval = needs reviewer, not a blocker
- "nit" with CHANGES_REQUESTED state = not a real blocker
- Unresolved substantive disagreement = blocked

## Ranking

Bug fixes > features > refactors > docs. Fewer blockers first. Smaller first. Drafts last.

## Milestone

Find or create **"Review Queue"** milestone (also check for "Merge Queue"). Add clean PRs, remove blocked ones. Overwrite description with the report.

## Blocker Comments

Post on PRs with `fail_count > 0` using `<!-- review-queue-bot -->` marker. Skip if unchanged since last comment. Skip drafts and recommend-close PRs.

## Report

Use `templates/review-queue.md`. Ready PRs in a condensed table, blocked PRs with full blocker tables, recommend-close PRs in a separate table.

## Blocker Checklist

| Check | Clear | Warn | Blocker |
|-------|-------|------|---------|
| CI | All pass | In progress | Any failed |
| Conflicts | MERGEABLE | UNKNOWN | CONFLICTING |
| Reviews | No issues | — | CHANGES_REQUESTED, sub-agent FAIL |
| Jira | Reference found | No reference | — |
| Fork | Internal | Fork (no bot review) | — |
| Staleness | < 30 days | — | > 30 days |
