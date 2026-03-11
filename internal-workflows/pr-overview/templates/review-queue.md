# Review Queue — {{REPO}}

**Date:** {{DATE}}
**Open PRs:** {{TOTAL_PRS}} | **Ready for Review:** {{READY_COUNT}} | **In Queue:** {{MILESTONE_COUNT}}

### At a Glance

{{AT_A_GLANCE}}

---

## Ready for Review ({{READY_COUNT}})

> Priority order: bug fixes > features > refactors > docs. Smallest first.

| # | PR | Type | Author | Size | Updated | Action Needed |
|---|---|---|---|---|---|---|
{{#each READY_PR_ROWS}}
| {{RANK}} | [#{{NUMBER}}]({{URL}}) — {{TITLE}} | {{TYPE}} | {{AUTHOR}} | {{SIZE}} | {{UPDATED}} | {{ACTION_NEEDED}} |
{{/each}}

---

## Blocked PRs ({{BLOCKED_COUNT}})

> Ordered by last updated (most recent first). Showing up to 50.

| # | PR | Type | Author | Updated | Blockers | Issue |
|---|---|---|---|---|---|---|
{{#each BLOCKED_PR_ROWS}}
| {{RANK}} | [#{{NUMBER}}]({{URL}}) — {{TITLE}} | {{TYPE}} | {{AUTHOR}} | {{UPDATED}} | {{BLOCKER_ICONS}} | {{ISSUE_SNIPPET}} |
{{/each}}

<details>
<summary>Blocker legend</summary>

| Icon | Meaning |
|------|---------|
| CI | CI checks failing |
| CONFLICT | Merge conflicts |
| REVIEW | Changes requested or unresolved review |
| STALE | No activity in 30+ days |
| OVERLAP | Diff overlap with another PR |

</details>

---

{{#if ALMOST_READY_ENTRIES}}
## Almost Ready ({{NEAR_COUNT}})

> One thing away from merge. Agent-written context for each.

{{#each ALMOST_READY_ENTRIES}}
**[#{{NUMBER}}]({{URL}}) — {{TITLE}}**
{{TYPE}} · {{AUTHOR}} · {{SIZE}} · {{UPDATED}}
{{CONTEXT}}
**Needs:** {{WHAT_NEEDED}}

{{/each}}

---

{{/if}}

{{#if RECOMMEND_CLOSE_ENTRIES}}
## Recommend Closing ({{CLOSE_COUNT}})

> Abandoned, superseded, or too stale to maintain. Close or ping the author.

| PR | Author | Reason | Last Updated |
|---|---|---|---|
{{#each RECOMMEND_CLOSE_ENTRIES}}
| [#{{NUMBER}}]({{URL}}) — {{TITLE}} | {{AUTHOR}} | {{REASON}} | {{UPDATED}} |
{{/each}}

---

{{/if}}

{{#if DRAFT_ROWS}}
## Drafts ({{DRAFT_COUNT}})

| PR | Type | Author | Updated | Notes |
|---|---|---|---|---|
{{#each DRAFT_ROWS}}
| [#{{NUMBER}}]({{URL}}) — {{TITLE}} | {{TYPE}} | {{AUTHOR}} | {{UPDATED}} | {{NOTES}} |
{{/each}}

---

{{/if}}

## Summary

| Bucket | Count |
|--------|-------|
| Ready for review | {{READY_COUNT}} |
| In queue (milestone) | {{MILESTONE_COUNT}} |
| Almost ready (1 blocker) | {{NEAR_COUNT}} |
| Blocked (2+ blockers) | {{WORK_COUNT}} |
| Recommend closing | {{CLOSE_COUNT}} |
| Drafts | {{DRAFT_COUNT}} |
{{#if FORK_COUNT}}| Fork PRs (need manual review) | {{FORK_COUNT}} |{{/if}}
| **Total open** | **{{TOTAL_PRS}}** |

### By Type

| Type | Count |
|------|-------|
{{#each TYPE_COUNTS}}
| {{TYPE}} | {{COUNT}} |
{{/each}}
