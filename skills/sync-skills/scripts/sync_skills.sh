#!/usr/bin/env bash
# sync_skills.sh — Version all skills on the bot's fork.
# Usage: sync_skills.sh
#
# Full mirror of /opt/data/skills/ → `skills` branch on
# cscs-reframe-bot/cscs-reframe-tests. The PVC is the source of truth;
# any edits made directly on GitHub are overwritten on the next sync.
#
# Uses a git worktree at /opt/data/cscs-reframe-tests-skills — a
# separate working directory sharing the main repo's .git. This avoids
# conflicts with plan/apply, which use the main worktree at
# /opt/data/cscs-reframe-tests. The worktree is always on the `skills`
# branch; no branch switching needed.
#
# The user must explicitly say "sync skills" — this never runs
# automatically.
set -euo pipefail

MAIN_REPO="/opt/data/cscs-reframe-tests"
SKILLS_WT="/opt/data/cscs-reframe-tests-skills"
SKILLS_SRC="/opt/data/skills"
SKILLS_LOCK="/opt/data/.reframe-bot-skills.lock"

# Acquire a SEPARATE lock for the skills worktree (non-blocking). This
# is intentionally NOT the main repo lock (/opt/data/cscs-reframe-tests
# /.git/reframe-bot.lock) so that sync skills doesn't conflict with
# plan/apply running concurrently in another Slack session.
exec 9>"$SKILLS_LOCK"
if ! flock -n 9; then
    echo "ERROR: Another sync skills is in progress. Please wait and retry."
    exit 1
fi

cd "$MAIN_REPO"

# Fetch latest from origin (the bot's fork).
git fetch origin

# Create the worktree if it doesn't exist (first run).
if [ ! -d "$SKILLS_WT" ]; then
    if git show-ref --verify --quiet refs/remotes/origin/skills; then
        # `skills` branch exists on remote — check it out as a worktree.
        git worktree add "$SKILLS_WT" origin/skills -b skills
    else
        # Bootstrap: `skills` branch doesn't exist. Create it from
        # origin/main (or main if origin/main doesn't exist).
        git worktree add "$SKILLS_WT" -b skills origin/main 2>/dev/null \
            || git worktree add "$SKILLS_WT" -b skills main
    fi
fi

cd "$SKILLS_WT"

# Reset to origin/skills (handles force-push, stale local branch).
# Silently ignored if origin/skills doesn't exist (bootstrap case).
git fetch origin
git reset --hard origin/skills 2>/dev/null || true

# Full mirror: remove the target directory and copy all skills from
# the PVC. Only copy directories with a SKILL.md (actual skills) or
# the lib/ directory (contains git-lock.sh).
rm -rf "$SKILLS_WT/skills"
mkdir -p "$SKILLS_WT/skills"

SYNCED_COUNT=0
for item in "$SKILLS_SRC"/*/; do
    [ -d "$item" ] || continue
    name=$(basename "$item")
    if [ -f "$item/SKILL.md" ] || [ "$name" = "lib" ]; then
        cp -r "$item" "$SKILLS_WT/skills/$name"
        SYNCED_COUNT=$((SYNCED_COUNT + 1))
    fi
done

# Stage skills/.
git add skills/

# Check if there's anything to commit.
if git diff --cached --quiet; then
    echo "No new or modified skills to sync."
    exit 0
fi

# Show what changed.
echo "Changes to sync:"
git diff --cached --stat
echo

# Commit and push.
git commit -m "Sync skills ($SYNCED_COUNT total)"
git push origin skills

echo
echo "Synced $SYNCED_COUNT skill(s) to the 'skills' branch."
echo "Review: https://github.com/cscs-reframe-bot/cscs-reframe-tests/tree/skills"
