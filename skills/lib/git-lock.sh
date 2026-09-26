#!/usr/bin/env bash
# git-lock.sh — Non-blocking flock around all git operations in the
# shared working directory (/opt/data/cscs-reframe-tests).
#
# Hermes serialises agent turns per Slack session (per thread), but
# different threads run concurrently. Without a lock, a second `apply`
# or `update branch` in a different thread clobbers the first user's
# uncommitted work via `git checkout`.
#
# Usage:  source ${HERMES_SKILL_DIR}/../lib/git-lock.sh && acquire_repo_lock
# Or:     source /opt/data/skills/lib/git-lock.sh && acquire_repo_lock
#
# The lock is NON-BLOCKING (flock -n): a second concurrent request
# fails immediately with a clear message rather than hanging silently
# (the LLM could hold the lock for minutes while editing files).
# Auto-released on EXIT via trap.
#
# Future (Phase 3): replace with `git worktree` so each apply gets its
# own isolated working directory and no lock is needed.

REPO_LOCK="${REPO_DIR:-/opt/data/cscs-reframe-tests}/.git/reframe-bot.lock"

acquire_repo_lock() {
    exec 9>"$REPO_LOCK"
    if ! flock -n 9; then
        cat >&2 <<EOF
ERROR: Another git operation is in progress in ${REPO_LOCK%/*}.
Please wait for it to finish and retry your command.
EOF
        exit 1
    fi
}

# Auto-release on exit (covers crash, interrupt, or normal return)
_release_repo_lock() { exec 9>&- 2>/dev/null || true; }
trap _release_repo_lock EXIT
