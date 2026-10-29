---
name: pr-summarize
description: >
  Generates a PR description following the repo template, including
  suggested CI triggers. Use when the user says "summarize" or asks
  for a PR description.
---

Fetch the diff and understand the change. Locate this thread's
worktree first: the `WORKTREE=...` line appears earlier in this
thread (the plan step posted it); if the context has scrolled,
recover it from the per-thread registry
(`bash ${HERMES_SKILL_DIR}/../lib/worktree.sh status <slug>`).
Fetch the diff from the worktree when one exists — a thread
without a worktree has no local diff: for an existing PR, fetch
it with `gh pr diff <number>` instead. Read the PR template from
`<WORKTREE>/.github/pull_request_template.md` (or
`/opt/data/cscs-reframe-tests/.github/pull_request_template.md`
when this thread has no worktree) and generate a PR description
following its structure.

Include suggested `cscs-ci run` commands. Reason about which CI modes
are relevant before listing them. Use `cscs-ci run alps-<system>` (NOT
`gh workflow run` — that only triggers the lint job). Read the PR
template at `<WORKTREE>/.github/pull_request_template.md` (or
`/opt/data/cscs-reframe-tests/.github/pull_request_template.md`
when this thread has no worktree) for the full syntax and examples.

- Check the test's tags and `valid_prog_environs`. If tagged `uenv`,
  UENV CI is the primary path — non-UENV examples are likely not
  needed (and vice versa).
- Pick one or two representative systems per relevant CI mode, not all
  systems. If the user mentioned a specific system (e.g. "test on
  starlex"), include that system.
- Keep the Testing section to 2-4 commands total. An exhaustive list
  of every system is noise — the reviewer can extrapolate.
- If the PR introduces an opt-in option (e.g. `flexible=True`), include
  one example showing how to test it via `CSCS_RFM_EXTRA`.

Output the description in Slack so the user can copy-paste it into
GitHub.
