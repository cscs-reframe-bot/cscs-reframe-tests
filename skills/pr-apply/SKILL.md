---
name: pr-apply
description: >
  Commits the changes that 'plan' wrote to disk and opens/updates
  the associated PR. Does NOT generate code — only commits and
  pushes what is already there. Use when the user says "apply"
  after a plan.
---

## What this skill does

Commits the uncommitted changes that `plan` created in this
thread's worktree, pushes them, and opens or updates the PR. **Does
not write or modify code** — that was done in `plan`. This
guarantees: what the user saw in `git diff` after `plan` is exactly
what gets committed.

## Procedure

Run each command below as a separate terminal tool call. Do NOT
chain multiple steps into one compound command with `&&` — the
security scanner blocks compound commands whose full effect it
cannot analyze.

1. Locate this thread's worktree. The `WORKTREE=...` and
   `BRANCH=...` lines appear earlier in this thread (the plan step
   posted them) — use those. If the context has scrolled, recover
   them from the per-thread registry:

   ```
   bash ${HERMES_SKILL_DIR}/../lib/worktree.sh status <slug>
   ```

   The slug is this thread's own — minted from the user's prompt at
   plan time. The registry is per-thread, so this can only ever
   find this thread's worktree, never another thread's.

2. Verify there are uncommitted changes to apply:

   ```
   cd <WORKTREE>
   git status --porcelain
   ```

   If the output is empty, check whether the plan was a **PR
   description/title update only** (no code changes expected). If
   so, skip to step 8 to update the PR body via `gh api`.
   Otherwise, post to Slack: "Nothing to apply — the plan phase did
   not create any changes. Run `plan ...` first." Stop. Do NOT
   generate code yourself.

3. Verify we're on the right branch (it must match `BRANCH` from
   step 1 — the worktree was created with it and nothing may
   switch it):

   ```
   current=$(git branch --show-current)
   if [ "$current" != "<BRANCH>" ]; then
       echo "ERROR: expected <BRANCH> but on $current. Run plan first." >&2
       exit 1
   fi
   ```

4. Show the diff one last time (this is what gets committed):

   ```
   git diff
   ```

5. Stage ONLY the files that `plan` modified and commit:

   ```
   git status --porcelain
   git add <file1> <file2> ...    # only files plan changed
   git commit -m "<description of the change>"
   ```

   Do NOT use `git add -A` or `git add .` — they stage untracked
   environment artifacts the user never saw in the plan diff.
   `AGENTS.md` in the worktree root is an untracked symlink to the
   environment mount — never stage it and never mention it in
   Slack. Other untracked files that aren't part of the plan stay
   unstaged; mention them in your Slack post.

6. Rebase on the latest upstream/main before pushing (prevents
   stale-branch conflicts when main advanced during the plan→apply
   gap):

   ```
   git fetch upstream
   git rebase upstream/main
   ```

   If the rebase fails (conflicts), post the conflicting file names
   to Slack (`git diff --name-only --diff-filter=U`), run
   `git rebase --abort`, and stop. Do NOT force-push to work around
   conflicts — tell the user and let them decide.

7. Push to origin:

   ```
   git push origin "<BRANCH>"
   ```

   If the push is rejected (non-fast-forward because main advanced
   between steps 6 and 7), repeat steps 6-7. Do NOT use `--force`.

8. Open or update the PR. Check deterministically whether one
   already exists for this branch:

   ```
   gh pr list --repo eth-cscs/cscs-reframe-tests \
       --head "cscs-reframe-bot:<BRANCH>" --state open
   ```

   - If a PR exists: if only the code changed (no title/body
     update needed), confirm the update and post the PR URL. If
     the user also asked to update the PR title or body, use the
     REST API directly (`gh pr edit` fails with a Projects
     (classic) deprecation error on this GitHub instance):

     ```
     gh api repos/eth-cscs/cscs-reframe-tests/pulls/<number> \
         -X PATCH -f title="..." -f body="..."
     ```
   - If no PR exists yet:

     ```
     gh pr create --repo eth-cscs/cscs-reframe-tests \
         --head "cscs-reframe-bot:<BRANCH>" \
         --base main \
         --title "Fix for PR #<number>: <short description>" \
         --body "<proposed fix summary and link to original PR>"
     ```

9. Post the diff and the PR URL to Slack.
