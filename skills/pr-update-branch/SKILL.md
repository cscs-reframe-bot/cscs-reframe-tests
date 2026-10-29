---
name: pr-update-branch
description: >
  Syncs the current bot/ branch with the latest main. Use when the
  user says "update branch" or asks to sync with main.
---

## The thread contract

Branch updates happen in the thread's worktree — the `WORKTREE=...`
line appears earlier in this thread (the plan step posted it). If
the context has scrolled, recover the worktree from the per-thread
registry:

```
bash ${HERMES_SKILL_DIR}/../lib/worktree.sh status <slug>
```

Then run:

```
bash ${HERMES_SKILL_DIR}/scripts/update_branch.sh <branch> <worktree>
```

The script fetches `upstream/main`, merges it into the branch, and
pushes the updated branch — the same behaviour as GitHub's "Update
branch" button. It runs no test validation; GitHub CI covers that
on push.

Do not paste the script output to Slack verbatim. Post a concise
summary instead: the branch name, whether the merge was clean and how
many files changed, and that the branch was pushed. Offer the full
diffstat only if the user asks for it.

If conflicts appear, stop and ask the user to run
`plan resolve conflicts with main`.

If the branch has no owning worktree (the thread never planned, or
the worktree was swept), do NOT fall back to the main repo — use
GitHub's "Update branch" button on the PR, or
`gh pr update-branch <number>`, which merges `main` into the head
branch server-side.
