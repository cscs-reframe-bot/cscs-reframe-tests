#!/usr/bin/env bash
# pr_status.sh — Render a PR readiness checklist (deterministic output)
# Usage: pr_status.sh <PR-number>
# Output is posted to Slack verbatim — do not reformat, re-derive, or edit.
set -euo pipefail

# ── Tunable constants ──────────────────────────────────────────────
MIN_TITLE_WORDS=5        # Title needs at least this many words
MIN_BODY_WORDS=40        # Description needs at least this many words
MIN_TEMPLATE_HEADINGS=2  # … or at least this many ## headings
MIN_APPROVALS=1          # Minimum approvals required
REPO="eth-cscs/cscs-reframe-tests"
# ───────────────────────────────────────────────────────────────────

PR_NUMBER="${1:?Usage: $0 <PR-number>}"

# Use the Hermes-managed gh wrapper if available. The wrapper reads
# GH_TOKEN from /opt/data/.env so the script works even when the skill
# subprocess does not inherit the container's GH_TOKEN env var.
GH_BIN="${HERMES_HOME:-/opt/data}/.local/bin/gh"
if [ ! -x "$GH_BIN" ]; then
    GH_BIN="gh"
fi

# Fetch PR metadata + CI status in a single API call
if ! PR_JSON=$("$GH_BIN" pr view "$PR_NUMBER" --repo "$REPO" \
    --json number,title,body,state,author,headRefName,baseRefName,mergeable,mergeStateStatus,reviewDecision,reviews,statusCheckRollup,url); then
    echo "ERROR: failed to fetch PR #$PR_NUMBER from $REPO" >&2
    exit 1
fi

if [ -z "$PR_JSON" ]; then
    echo "ERROR: gh pr view returned empty output (check gh auth)" >&2
    exit 1
fi

# Render the checklist. NOTE: do NOT pipe PR_JSON to stdin — the heredoc
# below already takes over stdin for the Python source, so a pipe would
# be consumed by the interpreter and json.load would get empty input
# (JSONDecodeError: Expecting value: line 1 column 1). Write the JSON to
# a temp file and pass the path as argv[1] instead.
_json_tmp=$(mktemp)
printf '%s' "$PR_JSON" > "$_json_tmp"
MIN_TITLE_WORDS="$MIN_TITLE_WORDS" \
    MIN_BODY_WORDS="$MIN_BODY_WORDS" MIN_TEMPLATE_HEADINGS="$MIN_TEMPLATE_HEADINGS" \
    MIN_APPROVALS="$MIN_APPROVALS" python3 - "$_json_tmp" << 'PYEOF'
import json, os, re, sys

with open(sys.argv[1]) as f:
    pr = json.load(f)
number      = pr.get("number", "?")
title       = pr.get("title", "")
body        = pr.get("body") or ""
state       = pr.get("state", "unknown")
author_obj  = pr.get("author", {})
author      = author_obj.get("login", "unknown") if isinstance(author_obj, dict) else str(author_obj)
head        = pr.get("headRefName", "?")
base        = pr.get("baseRefName", "?")
merge_state = pr.get("mergeStateStatus")
reviews     = pr.get("reviews", [])
checks      = pr.get("statusCheckRollup", [])
url         = pr.get("url", "")

min_title   = int(os.environ.get("MIN_TITLE_WORDS", "5"))
min_body    = int(os.environ.get("MIN_BODY_WORDS", "40"))
min_head    = int(os.environ.get("MIN_TEMPLATE_HEADINGS", "2"))
min_appr    = int(os.environ.get("MIN_APPROVALS", "1"))

# ── Title ──
title_words = len(title.split())
title_ok = title_words >= min_title

# ── Description ──
word_count = len(body.split())
headings = len(re.findall(r'^##+\s+\S', body, re.MULTILINE))
desc_ok = word_count >= min_body or headings >= min_head
if word_count >= min_body:
    desc_evidence = f"{word_count} words"
elif headings >= min_head:
    desc_evidence = f"{headings} headings"
else:
    desc_evidence = f"{word_count} words"

# ── CI ──
ci_triggered = len(checks) > 0
if ci_triggered:
    # Aggregate check states
    any_running = any(c.get("status") in ("IN_PROGRESS", "QUEUED", "PENDING") for c in checks)
    any_failed = any(
        c.get("conclusion") in ("FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED")
        for c in checks if c.get("status") == "COMPLETED"
    )
    all_completed = all(c.get("status") == "COMPLETED" for c in checks)
    if any_running:
        ci_passed = None
        ci_pass_evidence = "running"
    elif any_failed:
        ci_passed = False
        ci_pass_evidence = "failed"
    elif all_completed:
        ci_passed = True
        ci_pass_evidence = "passed"
    else:
        ci_passed = None
        ci_pass_evidence = "unknown"
    # Evidence for the trigger line: link the workflow name to the details URL.
    first = checks[0]
    wf_name = first.get("workflowName") or first.get("name", "?")
    details_url = first.get("detailsUrl", "")
    if details_url:
        ci_trigger_evidence = f"[{wf_name}]({details_url})"
    else:
        ci_trigger_evidence = wf_name
else:
    ci_passed = None
    ci_pass_evidence = "no checks"
    ci_trigger_evidence = "no checks"

# ── Approvals ──
approval_count = sum(1 for r in reviews if r.get("state") == "APPROVED")
approvals_ok = approval_count >= min_appr

# ── Merge state ──
# mergeStateStatus values: MERGEABLE, BLOCKED, DIRTY, HAS_HOOKS, UNKNOWN, UNSTABLE, BEHIND
merge_ok = merge_state == "MERGEABLE"
if merge_state == "MERGEABLE":
    merge_evidence = "MERGEABLE"
elif merge_state == "BLOCKED":
    merge_evidence = "BLOCKED (branch protection / required checks)"
elif merge_state == "DIRTY":
    merge_evidence = "DIRTY (merge conflicts)"
elif merge_state:
    merge_evidence = merge_state
else:
    merge_evidence = "unknown"

# ── Render ──
# Every checklist line (including sub-items) carries an emoji so the
# status is scannable at a glance in Slack.
E_OK   = "\u2705"  # ✅
E_FAIL = "\u274C"  # ❌
E_WARN = "\u26A0\uFE0F"  # ⚠️
E_RUN  = "\u23F3"  # ⏳

def emoji(status):
    """Map a tri-state (True/False/None) to an emoji glyph."""
    if status is True:
        return E_OK
    if status is False:
        return E_FAIL
    return E_WARN  # None — unknown / pending

def check_emoji(check):
    """Per-check emoji for a single statusCheckRollup entry."""
    s = check.get("status", "")
    c = check.get("conclusion", "")
    if s in ("IN_PROGRESS", "QUEUED", "PENDING"):
        return E_RUN
    if s == "COMPLETED":
        if c == "SUCCESS":
            return E_OK
        if c in ("FAILURE", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED"):
            return E_FAIL
    return E_WARN

def check_label(check):
    """Human-readable name + result for a single check."""
    name = check.get("workflowName") or check.get("name", "?")
    s = check.get("status", "")
    c = check.get("conclusion", "")
    if s in ("IN_PROGRESS", "QUEUED", "PENDING"):
        result = s.lower()
    elif s == "COMPLETED":
        result = (c or "unknown").lower()
    else:
        result = "unknown"
    return f"{name} — {result}"

print(f"PR #{number}: {title}")
print(f"Author: @{author}  Branch: {head} \u2192 {base}  State: {state}")
print(f"URL: {url}")
print()
print("Readiness checklist:")
print(f"- {emoji(title_ok)} Title is descriptive — {title_words} words")
print(f"- {emoji(desc_ok)} Description is meaningful — {desc_evidence}")
print(f"- {emoji(ci_triggered)} CI was triggered — {ci_trigger_evidence}")
if ci_triggered:
    for chk in checks:
        print(f"  - {check_emoji(chk)} {check_label(chk)}")
print(f"- {emoji(ci_passed)} CI passed — {ci_pass_evidence}")
print(f"- {emoji(approvals_ok)} Review approvals — {approval_count} approval(s) (need \u2265{min_appr})")
print(f"- {emoji(merge_ok)} Merge state clean — {merge_evidence}")
print()

# ── Verdict ──
issues = []
if not title_ok:
    issues.append("title too short")
if not desc_ok:
    issues.append("description missing or too short")
if not ci_triggered:
    issues.append("CI not triggered")
if ci_passed is False:
    issues.append("CI failed")
elif ci_triggered and ci_passed is None:
    issues.append("CI still running")
if not approvals_ok:
    issues.append("not enough approvals")
if not merge_ok:
    if merge_state == "DIRTY":
        issues.append("merge conflicts")
    elif merge_state == "BLOCKED":
        issues.append("blocked by branch protection")
    elif merge_state:
        issues.append(f"merge state {merge_state.lower()}")
    else:
        issues.append("merge state unknown")

if issues:
    print(f"Verdict: NOT READY — {', '.join(issues)}")
else:
    print("Verdict: READY — all checks passed")
PYEOF
rm -f "$_json_tmp"
