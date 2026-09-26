#!/usr/bin/env bash
# greet_pr.sh — Deterministic greeting when a user shares a PR link.
# Usage: greet_pr.sh <PR-number>
set -euo pipefail

REPO="eth-cscs/cscs-reframe-tests"
PR_NUMBER="${1:?Usage: $0 <PR-number>}"

# Use the Hermes-managed gh wrapper if available.
GH_BIN="${HERMES_HOME:-/opt/data}/.local/bin/gh"
if [ ! -x "$GH_BIN" ]; then
    GH_BIN="gh"
fi

PR_JSON=$("$GH_BIN" pr view "$PR_NUMBER" --repo "$REPO" \
    --json number,title,author,headRefName,baseRefName,state,url,updatedAt)

python3 - "$PR_JSON" "$PR_NUMBER" << 'PYEOF'
import json, sys
from datetime import datetime, timezone

pr = json.loads(sys.argv[1])
number = pr.get("number", sys.argv[2])
title = pr.get("title", "unknown")
author_obj = pr.get("author", {})
author = author_obj.get("login", "unknown") if isinstance(author_obj, dict) else str(author_obj)
head = pr.get("headRefName", "?")
base = pr.get("baseRefName", "?")
state = pr.get("state", "unknown").lower()
url = pr.get("url", "")
updated = pr.get("updatedAt", "")

def relative_time(iso_str):
    if not iso_str:
        return "unknown"
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        delta = now - dt
        seconds = int(delta.total_seconds())
        if seconds < 60:
            return "just now"
        if seconds < 3600:
            return f"{seconds // 60}m ago"
        if seconds < 86400:
            return f"{seconds // 3600}h ago"
        days = seconds // 86400
        if days < 7:
            return f"{days} day{'s' if days != 1 else ''} ago"
        return dt.strftime("%Y-%m-%d")
    except ValueError:
        return iso_str

updated_str = relative_time(updated)

print(f"- **PR #{number}: [{title}]({url})**")
print(f"- **Author:** @{author}")
print(f"- **Branch:** {head} \u2192 {base}")
print(f"- **State:** {state} (updated {updated_str})")
print()
print("What would you like me to do?")
print("- `review` \u2014 fetch the diff and post a review comment on the PR")
print("- `summarize` \u2014 generate a PR description following the repo template")
print("- `status` \u2014 show a PR readiness checklist")
print("- `update branch` \u2014 sync the current branch with the latest main")
print("- `plan [instructions]` \u2014 propose a design/plan for any task (no code changes)")
print("- `apply` \u2014 implement the agreed plan and open/update the PR")
PYEOF
