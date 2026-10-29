#!/usr/bin/env bash
# update_branch.sh — Sync the current bot/ branch with upstream/main
# Usage: update_branch.sh <branch-name> <worktree>
#   <branch-name>: the bot/ branch to update (e.g., bot/pr-660-fix-xyz)
#   <worktree>:    the OWNING thread's worktree path. The worktree
#                 already holds the branch, so the script operates
#                 there: no checkout and no repo lock are needed
#                 (the worktree is private to that thread).
# Behaves like GitHub's "Update Branch" button: fetch, merge, push.
# No test validation — GitHub CI covers that on push.
set -euo pipefail

BRANCH="${1:?Usage: $0 <branch-name> <worktree>}"
WORKTREE="${2:?Usage: $0 <branch-name> <worktree>}"

# Safety: only work on bot/ branches
if [[ "$BRANCH" != bot/* ]]; then
    echo "ERROR: Refusing to update non-bot branch: $BRANCH" >&2
    echo "Only bot/ prefixed branches are allowed." >&2
    exit 1
fi

if [ ! -d "$WORKTREE" ]; then
    echo "ERROR: worktree not found: $WORKTREE" >&2
    echo "Say 'update branch' in the thread that owns this branch," >&2
    echo "or use GitHub's 'Update branch' button." >&2
    exit 1
fi

# The thread's worktree already holds the branch: verify, then
# fetch/merge/push in place. No checkout (it is already checked
# out — git would refuse anyway) and no lock (the worktree is
# private to the thread that owns it).
cd "$WORKTREE"
current=$(git branch --show-current)
if [ "$current" != "$BRANCH" ]; then
    echo "ERROR: worktree ${WORKTREE} is on '${current}', not '${BRANCH}'." >&2
    echo "Say 'update branch' in the thread that owns this branch," >&2
    echo "or use GitHub's 'Update branch' button." >&2
    exit 1
fi

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
