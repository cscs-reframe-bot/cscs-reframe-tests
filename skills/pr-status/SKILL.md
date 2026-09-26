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
a "Readiness checklist:" with one emoji-prefixed line per check and
indented sub-lines for each CI check, and a final "Verdict:" line.
That is the complete output — post all of it, nothing more.
