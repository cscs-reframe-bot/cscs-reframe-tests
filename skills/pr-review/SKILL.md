---
name: pr-review
description: >
  Fetches the diff for a cscs-reframe-tests PR, generates a review comment
  via the LLM, and posts it on GitHub. Use when the user says "review" or
  asks to review a PR.
---

## Procedure (follow exactly)

1. Run the review script, replacing `<PR-number>`:

   ```
   bash ${HERMES_SKILL_DIR}/scripts/pr_review.sh <PR-number>
   ```

2. Post the script's **complete stdout** to Slack verbatim. The actual review
   comment lives on GitHub; Slack only gets a confirmation.

## Critical rules

- **Post the review on GitHub, not in Slack.** The script calls
  `gh pr comment` and returns a confirmation URL. Post only that confirmation
  in Slack.
- **Do not rewrite or summarize the review in Slack.** The LLM-generated
  review is already on GitHub.
- **If the script exits non-zero**, post the exact stderr to Slack and stop.
- **If the user has not explicitly asked for a review**, do not run the script.

## Manual override

To post a review you have drafted yourself, save it to a file and run:

```
bash ${HERMES_SKILL_DIR}/scripts/pr_review.sh <PR-number> /path/to/review.txt
```
