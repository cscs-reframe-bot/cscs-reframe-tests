---
name: pr-plan
description: >
  Creates a bot/ branch, delegates the proposed fix to a GLM-5.2
  subagent, validates it, and shows the diff. Does NOT commit or push.
  Use when the user says "plan" or asks for a fix. Follow with "apply"
  to commit and open a PR.
---

## What this skill does

Creates a branch, delegates the code changes to a subagent running
GLM-5.2 (via `delegation.model` in config.yaml), validates them, and
shows `git diff`. The changes are **not committed and not pushed** —
that happens in `apply`.

## Procedure

Run each command below as a separate terminal tool call. Do NOT chain
multiple steps into one compound command with `&&` — the security
scanner blocks compound commands whose full effect it cannot analyze.

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
   bash ${HERMES_SKILL_DIR}/../pr-apply/scripts/get_apply_branch.sh <PR-number> > /tmp/apply-branch.env
   TARGET_BRANCH=$(grep '^TARGET_BRANCH=' /tmp/apply-branch.env | cut -d= -f2-)
   BRANCH_MODE=$(grep '^BRANCH_MODE=' /tmp/apply-branch.env | cut -d= -f2-)
   ```

   Do NOT use `eval` on the script output — the security scanner
   cannot analyze dynamically generated command bodies and blocks the
   command. This sets:
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

5. Delegate the implementation to a subagent (it runs on GLM-5.2 via
   `delegation.model`):

   Call `delegate_task` with:
   - `goal`: a one-line summary of the requested change
   - `context`: the subagent starts with a **completely fresh context**
     and knows nothing from this conversation. Include ALL of:
     - Repository: `/opt/data/cscs-reframe-tests`
     - Branch already checked out: `<TARGET_BRANCH>`
     - The user's plan instructions, verbatim and complete
     - Relevant conversation context the subagent cannot see (PR
       description, review remarks, CI error messages)
     - Validation: `python3 -m py_compile <changed-file>` and, for
       check files, `reframe --dry-run -C config/cscs.py -c <file> --system <system>`
     - Constraints: do NOT commit, do NOT push, do NOT switch branches,
       do NOT run `git checkout` or `git clean`, and do NOT acquire the
       repo lock — the parent session already holds it

   The subagent works in the same repository checkout, so its file
   changes are on disk when it returns. The call returns a handle and
   your turn ends — but the task is NOT done: the subagent keeps
   working in the background. Close the turn with a message like:

   "Implementation is running on GLM-5.2 — this usually takes a few
   minutes. The diff and validation results will follow in this
   thread as soon as it finishes. ⏳"

   Always end that message with the ⏳ emoji so it is clear the user
   should wait. If the user asks about progress meanwhile, tell them
   it is still running and to wait for the follow-up message.

6. When the delegation completes (a new turn in this session):

   - On success:
     ```
     cd /opt/data/cscs-reframe-tests
     git status --porcelain
     git diff
     ```
     Post the diff to Slack verbatim — this is what `apply` will commit.
   - On failure or interruption: post the error to Slack, then discard
     any partial changes with `git checkout -- .` followed by
     `git clean -fd` (as separate commands), and stop.

7. Release the git lock (the trap in git-lock.sh does this automatically
   on exit). Do NOT commit. Do NOT push.

## After plan

Ask the user:
- "apply" — commits and pushes the diff, opens/updates the PR
- "plan ..." again — discards the current diff and starts fresh with
  new instructions (previous uncommitted changes are lost)

If a delegation is still running when the user asks to re-plan, tell
them it is still in progress; they can wait for it to finish or send
`/stop` to cancel it first.
