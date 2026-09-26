---
name: pr-plan
description: >
  Creates a bot/ branch with the proposed fix, validates it, and shows
  the diff. Does NOT commit or push. Use when the user says "plan" or
  asks for a fix. Follow with "apply" to commit and open a PR.
---

## What this skill does

Creates a branch, writes the proposed changes to disk, validates them,
and shows `git diff`. The changes are **not committed and not pushed** —
that happens in `apply`.

## Procedure

1. Acquire the git lock:

   ```
   source ${HERMES_SKILL_DIR}/../lib/git-lock.sh && acquire_repo_lock
   ```

   If the lock fails, post the error to Slack and stop.

2. Discard any uncommitted changes from a previous plan (they are
   ephemeral — if the user wanted to keep them, they would have said
   `apply`):

   ```
   cd /opt/data/cscs-reframe-tests
   git checkout -- .
   git clean -fd
   ```

   `git checkout -- .` only reverts tracked changes. `git clean -fd`
   also removes untracked files (like `AGENTS.md`, which is mounted
   into the repo root by the environment) that would otherwise pollute
   the next plan's diff. Read-only mounts may produce "permission
   denied" warnings — that's expected, `git clean` continues anyway.

3. Decide the target branch:

   ```
   eval "$(bash ${HERMES_SKILL_DIR}/../pr-apply/scripts/get_apply_branch.sh <PR-number>)"
   ```

   This sets:
   - `TARGET_BRANCH` — the branch to work on
   - `BRANCH_MODE` — `existing` (bot's own PR) or `new` (someone else's PR)

4. Check out the branch:
   - If `BRANCH_MODE=existing`:
     ```
     git fetch origin
     git checkout "$TARGET_BRANCH"
     git pull origin "$TARGET_BRANCH"
     ```
   - If `BRANCH_MODE=new`:
     ```
     git fetch upstream
     git checkout -b "$TARGET_BRANCH" upstream/main
     ```

5. Implement the agreed change. Write the actual code to disk — do not
   show a text-only diff preview. The user will see `git diff` in step 7.

6. Validate with ReFrame dry-run or py_compile where applicable:
   ```
   python3 -m py_compile <changed-file>
   reframe --dry-run -C config/cscs.py -c <changed-file> --system <system>
   ```

   If validation fails, fix the error and revalidate. If you cannot fix
   it, post the error to Slack, `git checkout -- . && git clean -fd` to
   discard, and stop.

7. Show the diff:

   ```
   git diff
   ```

   This is what `apply` will commit. Post it to Slack.

8. Release the git lock (the trap in git-lock.sh does this automatically
   on exit). Do NOT commit. Do NOT push.

## After plan

Ask the user:
- "apply" — commits and pushes the diff, opens/updates the PR
- "plan ..." again — discards the current diff and starts fresh with
  new instructions (previous uncommitted changes are lost)
