---
name: pr-summarize
description: >
  Generates a PR description following the repo template, including
  suggested CI triggers. Use when the user says "summarize" or asks
  for a PR description.
---

Fetch the diff and understand the change. Read the PR template from
`/opt/data/cscs-reframe-tests/.github/pull_request_template.md` and
generate a PR description following its structure.

Include suggested `cscs-ci run` commands. Reason about which CI modes
are relevant before listing them. Use `cscs-ci run alps-<system>` (NOT
`gh workflow run` — that only triggers the lint job). Read the PR
template at
`/opt/data/cscs-reframe-tests/.github/pull_request_template.md` for
the full syntax and examples.

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
