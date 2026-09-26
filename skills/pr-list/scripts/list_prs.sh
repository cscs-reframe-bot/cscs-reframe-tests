#!/usr/bin/env bash
# list_prs.sh — List open PRs for cscs-reframe-tests.
# Usage: list_prs.sh [limit]
set -euo pipefail

REPO="eth-cscs/cscs-reframe-tests"
LIMIT="${1:-20}"

# Use the Hermes-managed gh wrapper if available.
GH_BIN="${HERMES_HOME:-/opt/data}/.local/bin/gh"
if [ ! -x "$GH_BIN" ]; then
    GH_BIN="gh"
fi

PRS_JSON=$("$GH_BIN" pr list --repo "$REPO" --state open --limit "$LIMIT" \
    --json number,title,author,url,headRefName,updatedAt)

python3 - "$PRS_JSON" "$REPO" << 'PYEOF'
import json, sys
from datetime import datetime, timezone

prs = json.loads(sys.argv[1])
repo = sys.argv[2]

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

if not prs:
    print("No open PRs found.")
    sys.exit(0)

print(f"Open PRs in {repo} ({len(prs)} total):")
print()

for idx, pr in enumerate(prs, start=1):
    number = pr.get("number", "?")
    title = pr.get("title", "unknown")
    author_obj = pr.get("author", {})
    author = author_obj.get("login", "unknown") if isinstance(author_obj, dict) else str(author_obj)
    url = pr.get("url", "")
    updated_str = relative_time(pr.get("updatedAt", ""))
    print(f"{idx}. [#{number} {title}]({url}) — @{author} — updated {updated_str}")

print()
print("Reply with the number, or paste the PR link, to start working on it.")
PYEOF
