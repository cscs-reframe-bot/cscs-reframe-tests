---
name: pr-status
description: >
  Renders a readiness checklist for a cscs-reframe-tests PR (title,
  description, CI, approvals, conflicts). Use when the user says
  "status" or asks whether a PR is ready to merge.
---

## Procedure (follow exactly)

1. Run this single command in the terminal, replacing `<PR-number>`:

   ```
   bash ${HERMES_SKILL_DIR}/scripts/pr_status.sh <PR-number>
   ```

2. Post the script's **complete stdout** to Slack **verbatim**.

## Critical rules

- **Run the script first, always.** Do not inspect the PR yourself,
  call the GitHub API, or scrape the web. The script is the single
  source of truth for the checklist.
- **Post the output verbatim.** Do not reformat, re-derive, edit,
  summarise, add explanations, or substitute your own emojis. The
  script already emits the exact checklist to post, including emoji
  and per-CI-check sub-items.
- **If the script exits non-zero**, post the exact stderr to Slack
  with a short note that the script failed, and stop. Do not fall
  back to your own checklist rendering. A non-zero exit means
  something the user needs to fix (usually `gh` auth), not an
  invitation to work around it.
- **If the script prints no checklist** (empty stdout, exit 0),
  report that and stop. Do not invent output.

## What the output looks like

The script prints a header (PR number, title, author, branch, URL),
followed by either a short state message or a full readiness checklist:

- **Merged PRs** print `✅ Already merged.` and exit (no checklist —
  GitHub doesn't compute mergeability post-merge).
- **Closed PRs** print `❌ Already closed (not merged).` and exit.
- **Open PRs** print a "Readiness checklist:" with one emoji-prefixed
  line per check (including a "Not a draft" line first, then title,
  description, CI with indented sub-lines per check, approvals, and
  merge state), followed by a final "Verdict:" line.

For open PRs where GitHub reports `mergeStateStatus: BLOCKED` (which
is always the case for this bot, since it is not an org member and
cannot see org-level rulesets), but all visible CI checks pass and
reviews are approved, the script computes merge readiness as a
fallback. The merge state line shows `READY (computed) — all CI
checks pass, reviews approved. GitHub reports BLOCKED (bot is not an
org member; verify on GitHub if unsure.)`

When a reviewer has requested changes, the approvals line shows
`❌ Review approvals — changes requested by reviewer(s)` (gated on
`reviewDecision`, not the raw approval count — a stale APPROVED
entry remains in the reviews list even after changes are requested).

That is the complete output — post all of it, nothing more.
