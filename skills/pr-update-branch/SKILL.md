---
name: pr-update-branch
description: >
  Syncs the current bot/ branch with the latest main. Use when the
  user says "update branch" or asks to sync with main.
---

Run `bash ${HERMES_SKILL_DIR}/scripts/update_branch.sh <branch-name>`,
then post the output to Slack verbatim.

The script fetches `upstream/main`, merges it into the current `bot/`
branch, runs a ReFrame dry-run if check files changed, and pushes the
updated branch.

If conflicts appear, stop and ask the user to run
`plan resolve conflicts with main`.
