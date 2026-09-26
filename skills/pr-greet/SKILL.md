---
name: pr-greet
description: >
  Greets a user who shared a cscs-reframe-tests PR link. Fetches real PR
  metadata and posts a deterministic greeting with available commands.
---

## Procedure (follow exactly)

When the user shares a PR link, run:

```
bash ${HERMES_SKILL_DIR}/scripts/greet_pr.sh <PR-number>
```

Post the script's **complete stdout** to Slack verbatim. Do not invent,
reformat, or summarize the metadata.

## Critical rules

- **Always run the script.** Never generate the greeting from memory or
  imagination.
- **Post the output verbatim.** The script emits the exact PR title (linked
  to the URL), author, branch, state, relative last-update timestamp, and
  command menu.
- **If the script fails**, post the stderr and stop. Do not fall back to a
  hand-written greeting.
