#!/usr/bin/env bash
# update_branch.sh — Sync the current bot/ branch with upstream/main
# Usage: update_branch.sh <branch-name>
# The branch name is the bot/ branch to update (e.g., bot/pr-660-fix-xyz).
# Behaves like GitHub's "Update branch" button: fetch, merge, push.
# No test validation — GitHub CI covers that on push.
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

# Ensure we're on the right branch (quiet: the switch message is noise)
git checkout -q "$BRANCH"

# Fetch upstream (quiet: the refspec update line is noise)
git fetch -q upstream

# Merge main into the current branch. Git prints the diffstat — keep it,
# it is the useful part of the output.
echo "Merging upstream/main into $BRANCH..."
if git merge upstream/main --no-edit; then
    :
else
    echo
    echo "MERGE CONFLICTS DETECTED"
    echo "─────────────────────────"
    git diff --name-only --diff-filter=U
    echo
    echo "Run 'plan resolve conflicts with main' to get help resolving conflicts."
    exit 1
fi

# Push the updated branch (quiet: the push refspec output is noise)
git push -q origin "$BRANCH"
echo "Pushed to origin."

echo
echo "Branch $BRANCH updated successfully."
