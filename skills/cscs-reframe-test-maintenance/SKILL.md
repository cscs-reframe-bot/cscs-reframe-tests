---
name: cscs-reframe-test-maintenance
description: Use when maintaining tests in cscs-reframe-tests.
version: 1.0.0
author: reframebot
license: MIT
---

## When to use

Use whenever you are modifying, adding, or reviewing a ReFrame test in
`eth-cscs/cscs-reframe-tests`, especially when driving the change
through the `plan` → `apply` workflow.

## What this skill does

Guards the `plan` → `apply` workflow and the review-learning loop
used to maintain `eth-cscs/cscs-reframe-tests`. It does not replace
`pr-plan`, `pr-apply`, or `pr-learn`; it adds CSCS/ReFrame-specific
checks and conventions that cost review rounds when missed.

## Class attribute ordering

Inside a ReFrame test class, list attributes in this order:

1. Docstring
2. `descr`
3. `valid_systems`
4. `valid_prog_environs`
5. `maintainers`
6. Build settings (`build_system`, `sourcesdir`, `sourcepath`)
7. Runtime settings (`executable`, `num_tasks`, `num_tasks_per_node`,
   `build_locally`)
8. `tags`
9. Environment tweaks (`env_vars`)
10. ReFrame variables and hooks (`variable(...)`, `flexible`, methods)

Keep `maintainers` immediately after `valid_prog_environs`. Place
`env_vars` after the usual ReFrame settings (e.g. after `tags`), not
mixed into the build/runtime block.

## Procedure

Follow the curated pr-plan and pr-apply skills. This skill adds domain-specific knowledge only.

## Bulk symbol replacements

When the user asks to replace a symbol globally in a test attribute
(e.g. `maintainers`, tags, system names), treat it like any other plan
but add these checks:

1. Scope the replacement to the attribute requested. Use a regex that
   matches the attribute assignment line, not a bare text substitute,
   so you do not rewrite unrelated occurrences such as JIRA ticket IDs,
   URLs, comments, or other string literals.

2. Handle both single and double quote styles. A search that only
   matches one will silently miss files using the other.

3. After the replacement, grep the tree for the old symbol one more
   time. Confirm that the only remaining occurrences are the unrelated
   ones the user intended to keep (e.g. historic JIRA references).

4. Present the result as a per-test-class table with the columns the
   user asked for. Default columns: test class name, current attribute
   value, updated attribute value. Avoid file-level summaries when
   multiple classes are touched in one file.

## Rebasing a worktree onto a PR head

`pr-plan` rebases onto the PR head automatically for PR-scoped edits —
see the curated skill for the procedure.

## Adopting an existing bot/ branch into a thread worktree

Branches created before the per-thread worktree refactor (or pushed
from another context) are checked out in the main repo, not a thread
worktree. Adopt them manually instead of using `worktree.sh create`,
which always mints a fresh branch from `upstream/main` and would
discard the existing commits.

Run each command as a separate terminal tool call:

1. Release the branch from the main repo checkout:

   ```
   cd /opt/data/cscs-reframe-tests
   git fetch origin
   git checkout --detach
   ```

2. Create the thread worktree from the existing branch:

   ```
   git worktree add /opt/data/wt/<slug> <branch>
   ```

3. Register the worktree for the thread:

   ```
   printf '{"worktree":"/opt/data/wt/<slug>","branch":"<branch>","pr":<number>,"created":"YYYY-MM-DD"}\n' > /opt/data/wt/registry-<slug>.json
   ```

   Use the actual PR number if there is one; otherwise omit the `pr`
   field or set it to `null`.

4. Verify the worktree is on the right branch and head:

   ```
   cd /opt/data/wt/<slug>
   git branch --show-current   # must print <branch>
   git log -1 --oneline        # should show the expected tip commit
   ```

5. Post `WORKTREE=/opt/data/wt/<slug>` in the thread. From then on,
   treat that path as this thread's workspace for plan/re-plan, update
   branch, and apply.

## Verifying worktree-sweep candidates

Trust the sweep's PR classifications — the lookup was fixed at the
source. If a deletion candidate surprises you, verify the PR state by
number (`gh pr view <number> --repo eth-cscs/cscs-reframe-tests
--json state`) before confirming deletion.

## Refreshing a PR branch after server-side merges

GitHub's "Update branch" button creates merge commits on the server
that may not exist in the local worktree. This leaves the local branch
behind and can inflate staleness readings (e.g. the worktree sweep
reports the branch age from the local tip, not the server tip).

After adopting or returning to an existing PR worktree:

1. Fetch the latest state:

   ```
   cd <WORKTREE>
   git fetch origin
   ```

2. Fast-forward the local branch to the server tip:

   ```
   git merge --ff-only origin/<branch>
   ```

3. Verify the new tip: `git log -1 --oneline`.

If fast-forward fails, the branch has local commits or diverged —
stop and ask the user before rebasing or merging.

## Deleting dirty worktrees and branches

Before force-removing a worktree the sweep marked `DIRTY`, inspect the
uncommitted changes:

```
cd <WORKTREE>
git status --porcelain
```

Then confirm with the user that the changes are disposable, especially
if the branch has no PR. Only then run:

```
git worktree remove --force <path>
git branch -D <branch>
```

Delete branches from the main repo checkout, not from inside a removed
worktree's path. After deleting a worktree, the shell's cwd may still
point to the removed path; `cd` to the main repo or another valid path
before running further git commands. After deletions, verify the cleanup:

```
cd /opt/data/cscs-reframe-tests
git worktree list
git for-each-ref --format='%(refname:short)' refs/heads/bot
```

## Pitfalls

- A requested move may already be partially satisfied. Verify against
  the exact target neighbor, not the general area of the class.
- `git checkout -- .` reverts tracked changes but leaves untracked files
  behind. Use `git clean -fd` as well when resetting a plan, then
  inspect `git status --porcelain` for persistent artifacts.
- `git add -A` stages files like `AGENTS.md` that are sometimes mounted
  into the repo root by the environment. Stage intended files
  explicitly.
- `pr-plan` worktrees start from `upstream/main`, not the PR head. If
  the target code only exists on the PR branch, a subagent will search
  in vain unless you rebase onto the PR head first.
- `AGENTS.md` is replaced by a symlink to the environment mount after
  worktree creation and after any `git checkout` that restores it. That
  symlink shows as a type-change (`T`) in `git status` and appears in
  `git diff` against the PR head as a deletion. Do not stage it and do
  not let it leak into the reported diff; restore the PR's actual
  `AGENTS.md` content with `git checkout pr-<PR>-head -- AGENTS.md` if
  needed, then recreate the symlink without staging it.
- When a maintainer corrects or dismisses your review findings, use
  the `pr-learn` workflow (`learn from PR #N`). It extracts both
  codebase facts for AGENTS.md and bot review hints for MEMORY.md,
  and it deduplicates against existing knowledge before asking for
  approval. Do not save review lessons manually outside that workflow.
- When including the requestor in a PR description, use their Slack
  @username or real name — never the raw member ID (U...), which doesn't
  render on GitHub.
- Do not patch scripts that are mounted read-only from a GitOps repo
  (e.g. `/opt/data/scripts/worktree-sweep.py`). Route fixes through the
  upstream GitOps PR process instead.
- A local branch may be behind because GitHub created server-side merge
  commits. Always run `git fetch origin && git merge --ff-only
  origin/<branch>` before trusting local staleness readings.
- Force-removing a dirty worktree discards uncommitted changes. Inspect
  `git status --porcelain` and get explicit confirmation first.
