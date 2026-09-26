---
name: pr-review-grumpy
description: >
  Reviews a cscs-reframe-tests PR using the grumpy-reviewer personality and
  posts the comment on GitHub. Use when the user asks for a grumpy,
  sarcastic, or curmudgeonly review.
---

## Procedure (follow exactly)

1. Run the grumpy review script, replacing `<PR-number>`:

   ```
   bash ${HERMES_HOME}/skills/pr-review/scripts/pr_review.sh --grumpy <PR-number>
   ```

2. Post the script's **complete stdout** to Slack verbatim.

## Critical rules

- **Post the review on GitHub, not in Slack.** The script calls
  `gh pr comment` and returns a confirmation URL. Post only that confirmation
  in Slack.
- **Do not rewrite or summarize the review in Slack.** The grumpy review is
  already on GitHub.
- **If the grumpy-reviewer.md personality file is missing**, the script falls
  back to a default grumpy system prompt.
- **If the script exits non-zero**, post the exact stderr to Slack and stop.
