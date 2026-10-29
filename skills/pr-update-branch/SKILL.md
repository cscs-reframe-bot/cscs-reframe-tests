---
name: pr-update-branch
description: >
  Syncs the current bot/ branch with the latest main. Use when the
  user says "update branch" or asks to sync with main.
---

## The thread contract

Branch updates happen where the branch lives:

- **This thread has a worktree** — the `WORKTREE=...` line appears
  earlier in this thread (the plan step posted it). The worktree
  already holds the branch, so update it there: no checkout and no
  repo lock are needed (the worktree is private to this thread).

  ```
  bash ${HERMES_SKILL_DIR}/scripts/update_branch.sh <branch> <worktree>
  ```

  If the context has scrolled, recover the worktree from the
  per-thread registry:

  ```
  bash ${HERMES_SKILL_DIR}/../lib/worktree.sh status <slug>
  ```

- **This thread has no worktree** — run the legacy form with no
  second argument; the script uses the main repo worktree behind
  the repo lock:

  ```
  bash ${HERMES_SKILL_DIR}/scripts/update_branch.sh <branch>
  ```

  If that fails with git's branch-exclusivity error, the branch is
  held by another thread's worktree: tell the user to say "update
  branch" in the thread that did the work, or use GitHub's
  "Update branch" button.

The script fetches `upstream/main`, merges it into the branch, and
pushes the updated branch — the same behaviour as GitHub's "Update
branch" button. It runs no test validation; GitHub CI covers that on
push.

Do not paste the script output to Slack verbatim. Post a concise
summary instead: the branch name, whether the merge was clean and how
many files changed, and that the branch was pushed. Offer the full
diffstat only if the user asks for it.

If conflicts appear, stop and ask the user to run
`plan resolve conflicts with main`.
