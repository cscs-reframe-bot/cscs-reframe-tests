#!/usr/bin/env bash
# get_apply_branch.sh — Decide whether to reuse the bot's existing PR branch
# or create a new bot/ branch.
# Usage: get_apply_branch.sh <PR-number>
# Output: TARGET_BRANCH=<name>
#         BRANCH_MODE=existing|new
set -euo pipefail

REPO="eth-cscs/cscs-reframe-tests"
BOT_AUTHOR="cscs-reframe-bot"
PR_NUMBER="${1:?Usage: $0 <PR-number>}"

# Use the Hermes-managed gh wrapper if available.
GH_BIN="${HERMES_HOME:-/opt/data}/.local/bin/gh"
if [ ! -x "$GH_BIN" ]; then
    GH_BIN="gh"
fi

PR_JSON=$("$GH_BIN" pr view "$PR_NUMBER" --repo "$REPO" \
    --json author,headRefName,title)

# Extract values safely without jq.
author=$(printf '%s' "$PR_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("author",{}).get("login",""))')
head_ref=$(printf '%s' "$PR_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("headRefName",""))')
title=$(printf '%s' "$PR_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("title",""))')

if [ "$author" = "$BOT_AUTHOR" ] && [[ "$head_ref" == bot/* ]]; then
    target_branch="$head_ref"
    mode="existing"
else
    # Slug the title: lowercase, keep alphanumerics and dashes, collapse multiples.
    slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '-' | sed 's/-\+/-/g; s/^-//; s/-$//')
    # Truncate slug to keep branch name reasonable.
    slug="${slug:0:40}"
    target_branch="bot/pr-${PR_NUMBER}-${slug}"
    mode="new"
fi

printf 'TARGET_BRANCH=%s\nBRANCH_MODE=%s\n' "$target_branch" "$mode"
