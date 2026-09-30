---
name: reframe-external-fix-import
description: Use when importing a fix from an external fork or branch.
version: 1.0.0
author: reframebot
license: MIT
---

## When to use

Use when the user asks you to update an existing PR in
`eth-cscs/cscs-reframe-tests` with changes that live in another fork or
branch (e.g. `gppezzi/cscs-reframe-tests.git#pr-660-starlex-test`).

## Procedure

1. Identify the target PR and branch as usual:
   - Run `bash ${HERMES_HOME}/skills/pr-greet/scripts/greet_pr.sh <n>`.
   - Run `bash /opt/data/skills/pr-apply/scripts/get_apply_branch.sh <n>`
     to obtain `TARGET_BRANCH` and `BRANCH_MODE`.

2. Acquire the shared repo lock before touching the working tree:
   ```
   source /opt/data/skills/lib/git-lock.sh
   acquire_repo_lock
   ```

3. Check out the bot branch fresh:
   ```
   cd /opt/data/cscs-reframe-tests
   git checkout -- .
   git clean -fd   # read-only mounts may warn; ignore warnings
   git fetch origin
   git checkout "$TARGET_BRANCH"
   git pull origin "$TARGET_BRANCH"
   ```

4. Fetch the external source of truth without merging it:
   ```
   cd /tmp
   rm -rf <temp-clone>
   git clone --branch <branch> --single-branch <repo-url> <temp-clone>
   ```

5. Compare the external branch against the same base the bot branch is
   on, so you see only the new fixes. To find the base, add the upstream
   repository as a remote in the temporary clone and compute the merge
   base with `main`:
   ```
   cd /tmp/<temp-clone>
   git remote add upstream https://github.com/eth-cscs/cscs-reframe-tests.git
   git fetch upstream main
   base=$(git merge-base HEAD upstream/main)
   git log --oneline -10 "$base..HEAD"
   git diff "$base..HEAD" --name-only
   git diff "$base..HEAD" --stat
   ```

6. Inspect each changed file. Copy only the intended files into the bot
   checkout. Do not copy unrelated changes, CI artifacts, or untracked
   scratch files.

7. Validate the imported files:
   ```
   python3 -m py_compile <changed-file>
   ```
   For ReFrame checks, also run a dry-run when a suitable system config
   exists:
   ```
   reframe --dry-run -C config/cscs.py -c <file> --system <system>
   ```

8. Show the resulting diff and ask the user to `apply` before
   committing or pushing.

9. When the user says `apply`, run the `pr-apply` skill: stage only
   the imported files, commit with a message that attributes the
   external source, push, and update the PR title/body if needed.

## Pitfalls

- Do not merge the external branch into the bot branch with
  `git merge` or `git pull <repo-url> <branch>`. That brings in the
  external author's merge-commits and unrelated history.
- Do not treat the external repository's working tree as the source of
  truth without diffing against a shared base; the branch may already
  contain upstream changes that would hide the actual fix.
- Stage only the files you imported. Untracked files such as
  `AGENTS.md` are environment artifacts and must not be committed.
- `gh pr edit` may fail with a GraphQL deprecation error about
  Projects (classic). Use the REST API instead:
  `gh api repos/eth-cscs/cscs-reframe-tests/pulls/<n> --method PATCH
  --field title=... --field body=...`.

## References

- `references/ci-trigger-recipes.md` — CI trigger patterns for testing
  opt-in ReFrame options such as `-S flexible=True`.
