---
name: pr-plan
description: >
  Creates a per-thread worktree and branch, delegates the proposed
  fix to a GLM-5.3 subagent, validates it, and shows the diff. Does
  NOT commit or push. Use when the user says "plan" or asks for a
  fix. Follow with "apply" to commit and open a PR.
---

## What this skill does

Creates a worktree and branch owned by this Slack thread, delegates
the code changes to a subagent running GLM-5.3 (via
`delegation.model` in config.yaml), validates them, and shows
`git diff`. The changes are **not committed and not pushed** — that
happens in `apply`.

## The thread contract

A Slack thread is the unit of work: one conversation, one branch,
one active workspace.

- **Same thread** — continue on the existing worktree and branch.
  The worktree path appears earlier in this thread (the `create`
  step below posts `WORKTREE=...`). Re-planning discards only this
  thread's own uncommitted changes.
- **New thread** — a fresh worktree from a clean `upstream/main`
  with a new branch. What gets refined is the prompt, not an
  inherited diff: the bot does not resolve references to other
  threads. If prior work matters, the user re-states it in the new
  prompt or continues in the original thread.

Concurrent threads never share a working tree: each plan runs in
its own worktree under `/opt/data/wt/<slug>/`. No lock is needed —
there is no shared working tree to clobber.

## Procedure

Run each command below as a separate terminal tool call. Do NOT
chain multiple steps into one compound command with `&&` — the
security scanner blocks compound commands whose full effect it
cannot analyze.

1. Determine the flow:

   - If this thread has already created a worktree for this PR —
     the `WORKTREE=...` line appears earlier in this thread — this
     is a **same-thread re-plan**: skip to step 3.
   - Otherwise this is a **new thread**: mint a thread slug from
     the user's prompt — the lowercase key words of the request
     joined with dashes (e.g. "fix the prgenv indices check" →
     `fix-prgenv-indices-check`).

2. Create the worktree (new thread only):

   ```
   ENV_FILE=$(mktemp)
   bash ${HERMES_SKILL_DIR}/../lib/worktree.sh create <slug> <PR-number> > "$ENV_FILE"
   WORKTREE=$(grep '^WORKTREE=' "$ENV_FILE" | cut -d= -f2-)
   BRANCH=$(grep '^BRANCH=' "$ENV_FILE" | cut -d= -f2-)
   rm -f "$ENV_FILE"
   ```

   The temp file is session-unique (`mktemp`) — never hardcode a
   fixed name in /tmp. If the script fails with a slug collision,
   mint a new slug (append a short random suffix, e.g. `-a7f3`)
   and retry once. Do NOT use `eval` on the script output — the
   security scanner cannot analyze dynamically generated command
   bodies.

3. Discard any uncommitted changes from a previous plan
   (same-thread re-plan only — they are ephemeral; if the user
   wanted to keep them, they would have said `apply`):

   ```
   cd <WORKTREE>
   git checkout -- .
   git clean -fd
   ```

   Run `git checkout -- .` and `git clean -fd` as separate
   commands. This discards only THIS thread's work — other threads
   are unaffected, each has its own worktree. `AGENTS.md` in the
   worktree root is an untracked symlink to the environment mount;
   `git clean` may print a "permission denied" warning for it —
   that is expected and harmless.

4. Rebase on the right base for this plan. The base is decided
   by what the plan edits:

   - **A new change on top of main** (the default): rebase on
     the latest upstream/main, which prevents stale-branch
     conflicts when main has advanced since the worktree was
     created:

     ```
     cd <WORKTREE>
     git fetch upstream
     git rebase upstream/main
     ```

   - **An edit to an existing PR's content** (the request
     references a PR number and the change modifies that PR's
     files — e.g. a `maintainers` line that the PR itself
     introduces): the worktree must contain the PR's actual
     content, which upstream/main does not have yet. Fetch the
     PR head and move the branch onto it:

     ```
     cd <WORKTREE>
     git fetch upstream pull/<PR>/head:pr-<PR>-head
     git rebase --onto pr-<PR>-head upstream/main
     ```

     On a fresh worktree this simply moves the branch onto the
     PR head (there are no own commits to replay yet). The
     branch now sits on the PR head as-is — do NOT also rebase
     the PR onto main; the PR's own base is the right
     foundation for editing it.

   If the rebase fails (conflicts), post the conflicting file names
   to Slack (`git diff --name-only --diff-filter=U`), run
   `git rebase --abort`, and stop. Do NOT attempt to resolve
   conflicts automatically — the user needs to decide.

5. Delegate the implementation to a subagent (it runs on GLM-5.3
   via `delegation.model`):

   Call `delegate_task` with:
   - `goal`: a one-line summary of the requested change
   - `context`: the subagent starts with a **completely fresh
     context** and knows nothing from this conversation. Include
     ALL of:
     - Repository: `<WORKTREE>` — this thread's worktree, NOT
       /opt/data/cscs-reframe-tests
     - Branch already checked out: `<BRANCH>`
     - The user's plan instructions, verbatim and complete
     - Relevant conversation context the subagent cannot see (PR
       description, review remarks, CI error messages)
     - Validation: `python3 -m py_compile <changed-file>` and, for
       check files, `reframe --dry-run -C config/cscs.py -c <file>
       --system <system>` — run from the worktree root
     - PR template: `<WORKTREE>/.github/pull_request_template.md`
   - `constraints`: do NOT commit, do NOT push, do NOT switch
     branches, do NOT run `git checkout` or `git clean`, and never
     stage `AGENTS.md` (untracked environment symlink).

   The call returns a handle and the turn ends — but the task is
   NOT done: the subagent keeps working in the background. Close
   the turn with:

   "Implementation is running on GLM-5.3 — this usually takes a few
   minutes. The diff and validation results will follow in this
   thread as soon as it finishes. ⏳"

   Always end that message with the ⏳ emoji so it is clear the
   user should wait. If the user asks about progress meanwhile,
   say it is still running and to wait for the follow-up message.

6. When the delegation completes (a new turn in this session):

   - On success:
     ```
     cd <WORKTREE>
     git status --porcelain
     git diff
     ```
     Post the diff to Slack verbatim — this is what `apply` will
     commit.

     If the user asked for a PR description, generate one following
     the repo template at
     `<WORKTREE>/.github/pull_request_template.md`. For the Testing
     section, reason about which CI modes are relevant. Use
     `cscs-ci run alps-<system>` commands (NOT `gh workflow run` —
     that only triggers the lint job). Read the PR template for the
     full syntax and examples.

     - Check the test's tags and `valid_prog_environs`. If tagged
       `uenv`, UENV CI is the primary path — non-UENV examples are
       likely not needed (and vice versa).
     - Pick one or two representative systems per relevant CI mode,
       not all systems. If the user mentioned a specific system,
       include it.
     - Keep the Testing section to 2-4 commands total — an
       exhaustive list is noise.
     - If the PR introduces an opt-in option (e.g.
       `flexible=True`), include one example showing how to test
       it via `CSCS_RFM_EXTRA`.

   - On failure or interruption: post the error to Slack, then
     discard the partial changes (the step 3 commands) and stop.

## After plan

Ask the user:
- "apply" — commits and pushes the diff, opens/updates the PR
- "plan ..." again — discards this thread's diff and starts fresh
  with new instructions

If a delegation is still running when the user asks to re-plan,
tell them it is still in progress; they can wait for it to finish
or send `/stop` to cancel it first.
