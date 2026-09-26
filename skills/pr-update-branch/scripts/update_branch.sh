#!/usr/bin/env bash
# update_branch.sh — Sync the current bot/ branch with upstream/main
# Usage: update_branch.sh <branch-name>
# The branch name is the bot/ branch to update (e.g., bot/pr-660-fix-xyz).
set -euo pipefail

REPO_DIR="/opt/data/cscs-reframe-tests"
BRANCH="${1:?Usage: $0 <branch-name>}"

cd "$REPO_DIR"

# Acquire the repo lock (non-blocking). Prevents concurrent git
# operations from different Slack sessions clobbering each other.
source /opt/data/skills/lib/git-lock.sh
acquire_repo_lock

# Safety: only work on bot/ branches
if [[ "$BRANCH" != bot/* ]]; then
    echo "ERROR: Refusing to update non-bot branch: $BRANCH" >&2
    echo "Only bot/ prefixed branches are allowed." >&2
    exit 1
fi

# Ensure we're on the right branch
git checkout "$BRANCH"

# Fetch upstream
git fetch upstream

# Check if check files changed between HEAD and upstream/main
CHECK_FILES_CHANGED=$(git diff --name-only HEAD upstream/main -- checks/ 2>/dev/null | head -1)

# Merge main into the current branch
echo "Merging upstream/main into $BRANCH..."
if git merge upstream/main --no-edit; then
    echo "Merge successful."
else
    echo
    echo "MERGE CONFLICTS DETECTED"
    echo "─────────────────────────"
    git diff --name-only --diff-filter=U
    echo
    echo "Run 'plan resolve conflicts with main' to get help resolving conflicts."
    exit 1
fi

# ReFrame dry-run if check files changed
if [ -n "$CHECK_FILES_CHANGED" ]; then
    echo
    echo "Check files changed — running ReFrame dry-run..."
    if ! reframe --dry-run -C config/cscs.py --system generic 2>&1; then
        echo "WARNING: ReFrame dry-run failed. Check syntax manually."
    fi
fi

# Push the updated branch
echo
echo "Pushing updated branch..."
git push origin "$BRANCH"

echo
echo "Branch $BRANCH updated successfully."
