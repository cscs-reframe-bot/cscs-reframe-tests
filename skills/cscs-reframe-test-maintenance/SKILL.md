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

Guards the `plan` → `apply` workflow used to maintain
`eth-cscs/cscs-reframe-tests`. It does not replace `pr-plan` or
`pr-apply`; it adds CSCS/ReFrame-specific checks and conventions that
cost review rounds when missed.

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

1. Before planning a move, read the current file and identify the exact
   neighbor attributes the user named. Do not treat "earlier" as
   "anywhere in the first half of the class."

2. Run `plan` via the `pr-plan` skill. After writing the change, run
   `python3 -m py_compile <file>` and show the diff with `git diff`.

3. If `git diff` is empty, stop. Tell the user the file already matches
   the requested state and ask whether they want a different placement
   or an explicit no-op commit. Do not ask for `apply`.

4. When `apply` runs, stage only the files that the plan modified. Do
   not use `git add -A` — it commits untracked environment artifacts.
   If `git status --porcelain` shows untracked files that reappear after
   cleanup, leave them out of the commit.

5. After pushing, verify the PR state with `gh pr view` and post the
   commit hash and PR URL to Slack.

## Pitfalls

- `git checkout -- .` reverts tracked changes but leaves untracked files
  behind. Use `git clean -fd` as well when resetting a plan, then
  inspect `git status --porcelain` for persistent artifacts.
- `git add -A` stages files like `AGENTS.md` that are sometimes mounted
  into the repo root by the environment. Stage intended files
  explicitly.
- A requested move may already be partially satisfied. Verify against
  the exact target neighbor, not the general area of the class.
