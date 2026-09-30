---
name: pr-update-branch
description: >
  Syncs the current bot/ branch with the latest main. Use when the
  user says "update branch" or asks to sync with main.
---

Run `bash ${HERMES_SKILL_DIR}/scripts/update_branch.sh <branch-name>`.

The script fetches `upstream/main`, merges it into the current `bot/`
branch, and pushes the updated branch — the same behaviour as
GitHub's "Update branch" button. It runs no test validation; GitHub
CI covers that on push.

Do not paste the script output to Slack verbatim. Post a concise
summary instead: the branch name, whether the merge was clean and how
many files changed, and that the branch was pushed. Offer the full
diffstat only if the user asks for it.

If conflicts appear, stop and ask the user to run
`plan resolve conflicts with main`.
