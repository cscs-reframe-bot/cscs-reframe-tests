---
name: pr-list
description: >
  Lists open PRs for cscs-reframe-tests with titles, authors, and relative
  last-update timestamps. Use when the user asks to list open PRs or wants
  to pick a PR to work on.
---

## Procedure (follow exactly)

1. Run the list script:

   ```
   bash ${HERMES_SKILL_DIR}/scripts/list_prs.sh [limit]
   ```

   The default limit is 20 PRs.

2. Post the script's **complete stdout** to Slack verbatim.

3. If the user replies with a number, map it to the PR from the list and
   continue with that PR (e.g., run `pr-greet` for it). If the user pastes a
   PR link, treat it as a fresh PR share.

## Critical rules

- **Always run the script.** Do not invent PR lists.
- **Post the output verbatim.** The script emits the exact numbered list.
- **If the script fails**, post the stderr and stop.
