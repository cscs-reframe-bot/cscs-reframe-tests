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

Include suggested `cscs-ci run` commands based on the systems and
uenvs touched in the diff.

Output the description in Slack so the user can copy-paste it into
GitHub.
