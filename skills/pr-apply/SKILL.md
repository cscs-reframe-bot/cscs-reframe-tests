---
name: pr-apply
description: >
  Commits the changes that 'plan' wrote to disk and opens/updates the
  associated PR. Does NOT generate code — only commits and pushes what
  is already there. Use when the user says "apply" after a plan.
---

## What this skill does

Commits the uncommitted changes that `plan` created, pushes them, and
opens or updates the PR. **Does not write or modify code** — that was
done in `plan`. This guarantees: what the user saw in `git diff` after
`plan` is exactly what gets committed.

## Procedure

1. Acquire the git lock:

   ```
   source ${HERMES_SKILL_DIR}/../lib/git-lock.sh && acquire_repo_lock
   ```

   If the lock fails, post the error to Slack and stop.

2. Verify there are uncommitted changes to apply:

   ```
   cd /opt/data/cscs-reframe-tests
   git status --porcelain
   ```

   If the output is empty, post to Slack:
   "Nothing to apply — the plan phase did not create any changes. Run
   `plan ...` first." Stop. Do NOT generate code yourself.

3. Decide the target branch (should match what `plan` checked out):

   ```
   eval "$(bash ${HERMES_SKILL_DIR}/scripts/get_apply_branch.sh <PR-number>)"
   ```

4. Verify we're on the right branch:
   ```
   current=$(git branch --show-current)
   if [ "$current" != "$TARGET_BRANCH" ]; then
       echo "ERROR: expected $TARGET_BRANCH but on $current. Run plan first." >&2
       exit 1
   fi
   ```

5. Show the diff one last time (this is what gets committed):
   ```
   git diff
   ```

6. Stage ONLY the files that `plan` modified and commit:
   ```
   git status --porcelain
   git add <file1> <file2> ...    # only files plan changed
   git commit -m "<description of the change>"
   ```

   Do NOT use `git add -A` or `git add .` — they stage untracked
   environment artifacts (like `AGENTS.md`) that the user never saw
   in the plan diff. Use `git status --porcelain` to identify the
   changed files, then `git add` each one explicitly. If untracked
   files appear that aren't part of the plan, leave them unstaged and
   mention them in your Slack post.

7. Push to origin:
   ```
   git push origin "$TARGET_BRANCH"
   ```

8. Open or update the PR:
   - If `BRANCH_MODE=existing`: the PR already exists — confirm it was
     updated and post the PR URL.
   - If `BRANCH_MODE=new`:
     ```
     gh pr create --repo eth-cscs/cscs-reframe-tests \
         --head cscs-reframe-bot:"$TARGET_BRANCH" \
         --base main \
         --title "Fix for PR #<number>: <short description>" \
         --body "<proposed fix summary and link to original PR>"
     ```

9. Post the diff and the PR URL to Slack.
