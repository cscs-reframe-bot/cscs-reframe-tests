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

## Pitfalls

- A requested move may already be partially satisfied. Verify against
  the exact target neighbor, not the general area of the class.
- `git checkout -- .` reverts tracked changes but leaves untracked files
  behind. Use `git clean -fd` as well when resetting a plan, then
  inspect `git status --porcelain` for persistent artifacts.
- `git add -A` stages files like `AGENTS.md` that are sometimes mounted
  into the repo root by the environment. Stage intended files
  explicitly.
- When a maintainer corrects or dismisses your review findings, save
  each lesson via the memory tool (SOUL.md rule 9). Focus on
  generalizable rules.
- When including the requestor in a PR description, use their Slack
  @username or real name — never the raw member ID (U...), which doesn't
  render on GitHub.
