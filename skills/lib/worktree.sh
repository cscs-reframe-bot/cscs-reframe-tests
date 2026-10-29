#!/usr/bin/env bash
# worktree.sh — Per-thread git worktree helper for ReframeBot.
#
# Implements the thread contract (per-thread-workspace-plan.md): a
# Slack thread is the unit of work — one conversation, one branch,
# one active workspace. Each thread gets its own git worktree under
# /opt/data/wt/<slug>/ so concurrent plans in different threads
# never clobber each other. concurrent-plan.md R1/R2 (working-tree
# clobber across the plan→apply gap; background delegation
# outliving the parent turn) close by construction: there is no
# shared working tree.
#
# Usage:
#   worktree.sh create <slug> <pr-number>   # new thread: fresh worktree + branch
#   worktree.sh status <slug>              # report state (for apply/continuation)
#   worktree.sh list                       # all worktrees (for the report sweep)
#
# Output is env-style (KEY=value) so the calling skill can read it
# back with grep — the same pattern as get_apply_branch.sh.
#
# Design notes:
# - create does NOT fetch: the branch is based on the local
#   upstream/main remote-tracking ref; the calling skill's plan flow
#   rebases on upstream/main anyway, so a stale base self-corrects.
# - A fresh worktree contains an AGENTS.md checked out from
#   upstream (where it is a tracked file). It is REPLACED by a
#   symlink to the ConfigMap-mounted copy in the main repo — the
#   bot-facing curated context, identical to what the main worktree
#   shows. Never stage AGENTS.md (environment mount, not part of a
#   plan).
# - A per-thread registry file (/opt/data/wt/registry-<slug>.json)
#   records {worktree, branch, pr, created} as a fallback for very
#   long threads whose context has scrolled the path away. It is
#   deliberately NOT inside the worktree (it would pollute git
#   status) and NOT a shared registry: each thread can only
#   discover its own record, because the slug derives from the
#   worktree path it already knows from its own context.
# - The slug is minted by the calling skill from the user's prompt
#   (independent threads have independent prompts, so slugs diverge
#   naturally) and sanitized here — strict whitelist of lowercase
#   alphanumerics and dashes, so path traversal cannot survive. On
#   a slug collision the script fails with a clear message:
#   near-identical prompts must mint a different slug (random
#   suffix).
set -euo pipefail

MAIN_REPO="${MAIN_REPO:-/opt/data/cscs-reframe-tests}"
AGENTS_MD_SOURCE="${MAIN_REPO}/AGENTS.md"   # ConfigMap subPath mount
WT_ROOT="${WT_ROOT:-/opt/data/wt}"
BASE_REF="${BASE_REF:-upstream/main}"
MAX_SLUG_LEN=30

usage() {
    cat >&2 <<EOF
Usage:
  worktree.sh create <slug> <pr-number>   new thread: fresh worktree + branch
  worktree.sh status <slug>              report worktree state
  worktree.sh list                       list all worktrees
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }

# Sanitize a thread slug into a safe component for both filesystem
# paths and git branch names (same recipe as get_apply_branch.sh):
# lowercase, alphanumerics and dashes only, collapsed runs, trimmed
# edges, truncated to MAX_SLUG_LEN. Anything else (slashes, dots,
# absolute paths) is mapped to dashes or dropped — traversal is
# impossible by construction.
sanitize_slug() {
    local slug="${1:?slug required}"
    slug=$(printf '%s' "$slug" \
        | tr '[:upper:]' '[:lower:]' \
        | tr -c '[:alnum:]' '-' \
        | sed 's/-\+/-/g; s/^-//; s/-$//')
    slug="${slug:0:$MAX_SLUG_LEN}"
    slug="${slug%-}"   # truncation can leave a trailing dash
    [ -n "$slug" ] || die "slug sanitizes to empty — mint a more descriptive slug from the user's prompt"
    printf '%s\n' "$slug"
}

cmd_create() {
    local raw_slug="${1:?create: slug required}"
    local pr="${2:?create: PR number required}"
    [[ "$pr" =~ ^[0-9]+$ ]] || die "PR number must be numeric (got: $pr)"

    local slug
    slug=$(sanitize_slug "$raw_slug")

    local wt="${WT_ROOT}/${slug}"
    local branch="bot/pr-${pr}-${slug}"

    # Refuse to clobber. An existing worktree means a slug collision:
    # near-identical prompts must mint a different slug (random
    # suffix) — the script never reuses or overwrites silently.
    [ -e "$wt" ] && die "worktree ${wt} already exists — mint a different slug (near-identical prompts get a random suffix)"

    # The branch could also exist without a worktree (e.g. pushed
    # from an older thread whose worktree was already cleaned up).
    if git -C "$MAIN_REPO" show-ref --verify --quiet "refs/heads/${branch}"; then
        die "branch ${branch} already exists — mint a different slug"
    fi

    mkdir -p "$WT_ROOT" || die "cannot create ${WT_ROOT}"

    # Fresh worktree + branch, based on the local upstream/main
    # remote-tracking ref. No fetch here (deterministic, offline);
    # the calling skill's plan flow rebases on upstream/main, so a
    # stale base self-corrects.
    git -C "$MAIN_REPO" worktree add "$wt" -b "$branch" "$BASE_REF" \
        || die "git worktree add failed (base ref ${BASE_REF} missing? run 'git fetch upstream' in the main repo and retry)"

    # Replace the checked-out AGENTS.md (tracked in upstream) with a
    # symlink to the ConfigMap-mounted copy — the bot-facing curated
    # context, identical to what the main worktree shows.
    if [ -e "$AGENTS_MD_SOURCE" ]; then
        rm -f "${wt}/AGENTS.md"
        ln -s "$AGENTS_MD_SOURCE" "${wt}/AGENTS.md"
    else
        echo "WARNING: ${AGENTS_MD_SOURCE} not found — worktree keeps upstream's checked-out AGENTS.md" >&2
    fi

    # Per-thread registry (fallback for very long threads; NOT
    # inside the worktree — it would pollute git status).
    printf '{"worktree":"%s","branch":"%s","pr":"%s","created":"%s"}\n' \
        "$wt" "$branch" "$pr" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        > "${WT_ROOT}/registry-${slug}.json"

    # Env-style output for the calling skill.
    printf 'WORKTREE=%s\nBRANCH=%s\nPR=%s\n' "$wt" "$branch" "$pr"
}

cmd_status() {
    local slug
    slug=$(sanitize_slug "${1:?status: slug required}")

    local wt="${WT_ROOT}/${slug}"
    [ -d "$wt" ] || die "no worktree for slug '${slug}' (looked in ${wt})"

    local branch
    branch=$(git -C "$wt" branch --show-current)
    [ -n "$branch" ] || die "worktree ${wt} has a detached HEAD — unexpected state"

    # The AGENTS.md symlink is expected (created at worktree
    # creation); report its state rather than assuming.
    local agents="missing"
    [ -L "${wt}/AGENTS.md" ] && agents="ok"

    local registry="missing"
    [ -f "${WT_ROOT}/registry-${slug}.json" ] && registry="ok"

    printf 'WORKTREE=%s\nBRANCH=%s\nAGENTS_MD=%s\nREGISTRY=%s\n' \
        "$wt" "$branch" "$agents" "$registry"
}

cmd_list() {
    # Authoritative list from git (main, skills and thread
    # worktrees, including stale metadata). The report sweep (2f)
    # formats this for Slack; deletion stays gated on user
    # confirmation.
    git -C "$MAIN_REPO" worktree list --porcelain
}

case "${1:-}" in
    create) shift; cmd_create "$@" ;;
    status) shift; cmd_status "$@" ;;
    list)   shift; cmd_list "$@" ;;
    *)      usage; exit 1 ;;
esac
