#!/usr/bin/env bash
# pr_review.sh — Review a cscs-reframe-tests PR and post the comment on GitHub.
# Usage:
#   pr_review.sh <PR-number>              # auto-generate review via LLM and post
#   pr_review.sh --grumpy <PR-number>     # use the grumpy-reviewer personality
#   pr_review.sh <PR-number> <file>       # post the review text from <file>
set -euo pipefail

REPO="eth-cscs/cscs-reframe-tests"
GRUMPY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --grumpy)
      GRUMPY=true
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "ERROR: unknown option: $1" >&2
      echo "Usage: $0 [--grumpy] <PR-number> [comment-file]" >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

PR_NUMBER="${1:?Usage: $0 [--grumpy] <PR-number> [comment-file]}"
COMMENT_FILE="${2:-}"

API_BASE="${OPENAI_API_BASE:-https://api.inference.cscs.ch/v1}"
# OPENAI_API_KEY is stripped from terminal subprocesses by Hermes
# (_ALWAYS_STRIP_KEYS / _HERMES_PROVIDER_ENV_BLOCKLIST), same as
# GITHUB_TOKEN. Read it from /opt/data/.env (written by the init
# container) when the env var is not set.
API_KEY="${OPENAI_API_KEY:-}"
if [ -z "$API_KEY" ]; then
    API_KEY=$(grep '^OPENAI_API_KEY=' /opt/data/.env 2>/dev/null | cut -d= -f2-)
fi
MODEL="${OPENAI_MODEL:-moonshotai/Kimi-K2.7-Code}"
GRUMPY_PERSONALITY="${GRUMPY_PERSONALITY:-/opt/data/cscs-reframe-tests/.opencode/agents/grumpy-reviewer.md}"

# Use the Hermes-managed gh wrapper if available.
GH_BIN="${HERMES_HOME:-/opt/data}/.local/bin/gh"
if [ ! -x "$GH_BIN" ]; then
    GH_BIN="gh"
fi

# ── Manual mode: post the provided file ────────────────────────────
if [ -n "$COMMENT_FILE" ]; then
    if [ ! -f "$COMMENT_FILE" ]; then
        echo "ERROR: comment file not found: $COMMENT_FILE" >&2
        exit 1
    fi
    if ! "$GH_BIN" pr comment "$PR_NUMBER" --repo "$REPO" --body-file "$COMMENT_FILE"; then
        echo "ERROR: failed to post review comment to PR #$PR_NUMBER" >&2
        exit 1
    fi
    echo "Review comment posted to https://github.com/$REPO/pull/$PR_NUMBER"
    exit 0
fi

# ── Auto mode: fetch diff, ask LLM, post comment ───────────────────
if [ -z "$API_KEY" ]; then
    echo "ERROR: OPENAI_API_KEY is not set. Set it in .env.local or pass a comment file." >&2
    exit 1
fi

echo "Fetching diff for PR #$PR_NUMBER ..." >&2
DIFF=$("$GH_BIN" pr diff "$PR_NUMBER" --repo "$REPO")

if [ -z "$DIFF" ]; then
    echo "ERROR: empty diff for PR #$PR_NUMBER" >&2
    exit 1
fi

GENERATED_FILE="/tmp/review-${PR_NUMBER}.txt"

echo "Generating review via $MODEL ..." >&2
API_BASE="$API_BASE" API_KEY="$API_KEY" MODEL="$MODEL" \
GRUMPY="$GRUMPY" GRUMPY_PERSONALITY="$GRUMPY_PERSONALITY" \
python3 - "$DIFF" "$PR_NUMBER" "$REPO" "$GENERATED_FILE" << 'PYEOF'
import json, os, re, sys, urllib.request

diff, pr_number, repo, out_path = sys.argv[1:5]
api_base = os.environ["API_BASE"]
api_key = os.environ["API_KEY"]
model = os.environ["MODEL"]
grumpy = os.environ.get("GRUMPY", "false").lower() == "true"
grumpy_path = os.environ.get("GRUMPY_PERSONALITY", "")

# Truncate very large diffs to stay within context limits.
MAX_DIFF_CHARS = 30000
if len(diff) > MAX_DIFF_CHARS:
    diff = diff[:MAX_DIFF_CHARS] + "\n\n... [diff truncated] ...\n"

if grumpy:
    if grumpy_path and os.path.exists(grumpy_path):
        with open(grumpy_path, encoding="utf-8") as f:
            personality = f.read()
        # Strip YAML frontmatter.
        personality = re.sub(r"^---\n.*?\n---\n", "", personality, count=1, flags=re.DOTALL)
        system_msg = personality.strip()
    else:
        system_msg = (
            "You are a grumpy senior developer with 40+ years of experience. "
            "You are sarcastic and thorough, but your feedback is constructive."
        )
    user_prefix = "Review this diff in your grumpy, sarcastic style.\n\n"
    header = f"🤖 Grumpy bot review for PR #{pr_number}\n\n"
else:
    system_msg = "You are a thorough, concise, constructive code reviewer."
    user_prefix = ""
    header = f"🤖 Bot-generated review for PR #{pr_number}\n\n"

prompt = f"""{user_prefix}You are reviewing a pull request for the {repo} repository.
Provide a concise, actionable code review based on the diff below.

Focus on:
- Correctness issues or potential bugs
- Code clarity and maintainability
- Whether the change matches the PR description / intent
- Suggested improvements or questions

Keep the review brief. Start with a one-line summary, then list specific
findings as bullet points. If the change looks good overall, say so.

PR diff:
```diff
{diff}
```
"""

req = urllib.request.Request(
    f"{api_base}/chat/completions",
    data=json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": system_msg},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.4,
        "max_tokens": 2048
    }).encode(),
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}"
    },
    method="POST"
)

with urllib.request.urlopen(req, timeout=120) as resp:
    result = json.loads(resp.read())
    review = result["choices"][0]["message"]["content"].strip()

review = header + review

with open(out_path, "w", encoding="utf-8") as f:
    f.write(review + "\n")

print(out_path)
PYEOF

echo "Posting review comment ..." >&2
if ! "$GH_BIN" pr comment "$PR_NUMBER" --repo "$REPO" --body-file "$GENERATED_FILE"; then
    echo "ERROR: failed to post review comment to PR #$PR_NUMBER" >&2
    exit 1
fi

echo "Review comment posted to https://github.com/$REPO/pull/$PR_NUMBER"
