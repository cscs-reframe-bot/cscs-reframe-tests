#!/usr/bin/env bash
# learn_from_prs.sh — Fetch PR review threads for the learning loop.
#
# Usage:
#   learn_from_prs.sh [days]           # batch: last <days> days (default 7)
#   learn_from_prs.sh pr <PR-number>   # single PR
#
# Fetches issue comments, inline review comments, and review bodies
# (pulls/{n}/reviews) via the GitHub API, merges them by timestamp,
# groups by PR, and tags each thread with whether it contains a
# bot-generated review (🤖 Bot-generated review or 🤖 Grumpy bot
# review). ALL threads are emitted as Markdown sections with a source
# label:
#
#   - threads WITH a bot review  → correction lessons (bot findings
#     dismissed/accepted by maintainers)
#   - human-only threads          → convention lessons (how humans
#     expect the repo to work, regardless of who wrote the remark)
#
# The script is deterministic: it fetches and formats raw data only.
# Classification (corrections vs conventions) and lesson extraction
# are done by the LLM following the SKILL.md procedure.
set -euo pipefail

REPO="eth-cscs/cscs-reframe-tests"

# Use the Hermes-managed gh wrapper if available.
GH_BIN="${HERMES_HOME:-/opt/data}/.local/bin/gh"
if [ ! -x "$GH_BIN" ]; then
    GH_BIN="gh"
fi

# Resolve arguments: either "pr <N>" (single) or "<days>" (batch).
MODE="batch"
PR_NUMBER=""
DAYS=7
if [ "${1:-}" = "pr" ]; then
    if [ $# -lt 2 ]; then
        echo "Usage: learn_from_prs.sh [days] | learn_from_prs.sh pr <PR-number>" >&2
        exit 1
    fi
    MODE="single"
    PR_NUMBER="$2"
elif [ $# -ge 1 ]; then
    DAYS="$1"
fi

# Compute the "since" timestamp for batch mode.
SINCE=""
if [ "$MODE" = "batch" ]; then
    if date -u -v-${DAYS}d +%Y-%m-%dT00:00:00Z >/dev/null 2>&1; then
        SINCE=$(date -u -v-${DAYS}d +%Y-%m-%dT00:00:00Z)
    else
        SINCE=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT00:00:00Z)
    fi
fi

# --- Fetch issue comments -------------------------------------------------
# The bot's reviews are posted as issue comments (verified 2026-10-12).
# Maintainer responses and human remarks are also typically issue
# comments.

if [ "$MODE" = "single" ]; then
    ISSUE_JSON=$("$GH_BIN" api "repos/${REPO}/issues/${PR_NUMBER}/comments?per_page=100" --paginate 2>/dev/null || echo "[]")
else
    ISSUE_JSON=$("$GH_BIN" api "repos/${REPO}/issues/comments?per_page=100&since=${SINCE}" --paginate 2>/dev/null || echo "[]")
fi

# --- Determine the PR set --------------------------------------------------
# Single mode: the given number. Batch mode: distinct numbers from the
# issue comments, validated as actual PRs (issues and PRs share the
# comment namespace — a comment on plain issue #N must not become a
# "review thread").

if [ "$MODE" = "single" ]; then
    PR_LIST="$PR_NUMBER"
else
    CANDIDATES=$(printf '%s' "$ISSUE_JSON" | python3 -c "
import json, sys, re
try:
    comments = json.load(sys.stdin)
except Exception:
    comments = []
prs = set()
for c in comments:
    url = c.get('issue_url', '')
    m = re.search(r'/(\d+)$', url)
    if m:
        prs.add(m.group(1))
print(' '.join(sorted(prs, key=int)))
" 2>/dev/null || true)

    PR_LIST=""
    for pn in $CANDIDATES; do
        if "$GH_BIN" api "repos/${REPO}/pulls/${pn}" --jq .number >/dev/null 2>&1; then
            PR_LIST="$PR_LIST $pn"
        fi
    done
fi

# --- Fetch inline review comments and review bodies, per PR ----------------
TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

for pn in $PR_LIST; do
    "$GH_BIN" api "repos/${REPO}/pulls/${pn}/comments?per_page=100" \
        > "$TMPDIR_LOCAL/inline_${pn}.json" 2>/dev/null \
        || echo "[]" > "$TMPDIR_LOCAL/inline_${pn}.json"
    "$GH_BIN" api "repos/${REPO}/pulls/${pn}/reviews?per_page=100" \
        > "$TMPDIR_LOCAL/bodies_${pn}.json" 2>/dev/null \
        || echo "[]" > "$TMPDIR_LOCAL/bodies_${pn}.json"
done

# --- Merge, tag, and format -----------------------------------------------
# Group all comments by PR. Tag each thread with whether it contains
# a bot-generated review. Emit every thread with a source label.

printf '%s\0%s\0%s\0%s\0' "$MODE" "$PR_NUMBER" "$ISSUE_JSON" "$TMPDIR_LOCAL" | \
python3 -c "
import json, sys, re, os, glob
from datetime import datetime

data = sys.stdin.buffer.read().split(b'\x00', 4)
mode = data[0].decode()
pr_number = data[1].decode()
issue_json = data[2].decode()
tmpdir = data[3].decode()

def parse_dt(s):
    if not s:
        return datetime.min
    try:
        return datetime.fromisoformat(s.replace('Z', '+00:00'))
    except ValueError:
        return datetime.min

def is_bot_review(body):
    if not body:
        return False
    return body.startswith('🤖 Bot-generated review') or \
           body.startswith('🤖 Grumpy bot review')

# The validated PR set is encoded in the temp-dir filenames.
pr_set = set()
for path in glob.glob(os.path.join(tmpdir, 'inline_*.json')):
    m = re.search(r'inline_(\d+)\.json$', os.path.basename(path))
    if m:
        pr_set.add(int(m.group(1)))

# Parse issue comments, keeping only comments on validated PRs.
try:
    issue_comments = json.loads(issue_json) if issue_json.strip() else []
except json.JSONDecodeError:
    issue_comments = []

norm = []
for c in issue_comments:
    if mode == 'single':
        pn = int(pr_number) if pr_number else None
    else:
        url = c.get('issue_url', '')
        m = re.search(r'/(\d+)$', url)
        pn = int(m.group(1)) if m else None
    if pn is None or pn not in pr_set:
        continue
    norm.append({
        'pr': pn,
        'user': (c.get('user') or {}).get('login', 'unknown'),
        'created_at': c.get('created_at', ''),
        'body': c.get('body', ''),
        'kind': 'issue',
    })

# Inline review comments.
for path in glob.glob(os.path.join(tmpdir, 'inline_*.json')):
    m = re.search(r'inline_(\d+)\.json$', os.path.basename(path))
    if not m:
        continue
    pn = int(m.group(1))
    try:
        arr = json.load(open(path))
    except Exception:
        continue
    for c in arr:
        body = c.get('body', '')
        if not body:
            continue
        norm.append({
            'pr': pn,
            'user': (c.get('user') or {}).get('login', 'unknown'),
            'created_at': c.get('created_at', ''),
            'body': body,
            'kind': 'review-inline',
        })

# Review bodies (pulls/{n}/reviews) — human review remarks often live
# here. Skip approvals with no comment body.
for path in glob.glob(os.path.join(tmpdir, 'bodies_*.json')):
    m = re.search(r'bodies_(\d+)\.json$', os.path.basename(path))
    if not m:
        continue
    pn = int(m.group(1))
    try:
        arr = json.load(open(path))
    except Exception:
        continue
    for c in arr:
        body = c.get('body', '')
        if not body:
            continue
        norm.append({
            'pr': pn,
            'user': (c.get('user') or {}).get('login', 'unknown'),
            'created_at': c.get('submitted_at', '') or c.get('created_at', ''),
            'body': body,
            'kind': 'review-body',
            'state': c.get('state', ''),
        })

# Group by PR and tag with has_bot_review.
groups = {}
for c in norm:
    groups.setdefault(c['pr'], []).append(c)

tagged = {}
for pn, comments in groups.items():
    comments.sort(key=lambda c: parse_dt(c['created_at']))
    tagged[pn] = {
        'comments': comments,
        'has_bot_review': any(is_bot_review(c['body']) for c in comments),
    }

if not tagged:
    print('No PR review threads found in the requested range.')
    sys.exit(0)

# Emit every thread as Markdown sections with a source label.
if mode == 'single':
    print(f'# PR #{pr_number} — review thread')
else:
    print(f'# PR review threads ({len(tagged)} total)')
print()
print('Each thread below is tagged with its source:')
print('- **bot review** — the thread contains a bot-generated review')
print('  (🤖 Bot-generated review or 🤖 Grumpy bot review). Extract')
print('  CORRECTION lessons: classify the bot findings as dismissed /')
print('  accepted / fixed / no response, then extract codebase facts')
print('  and bot review hints from dismissed findings.')
print('- **human review** — the thread is human-only (no bot review).')
print('  Extract CONVENTION lessons: classify each human remark as a')
print('  convention statement, a dismissal with rationale, an accepted')
print('  fix request, or noise (social/merge/CI — ignore).')
print()
print('---')
print()

for pn in sorted(tagged.keys()):
    entry = tagged[pn]
    comments = entry['comments']
    src = 'bot review' if entry['has_bot_review'] else 'human review'
    print(f'## PR #{pn} — source: {src}')
    print()
    for c in comments:
        user = c['user']
        ts = c['created_at'][:19].replace('T', ' ') if c['created_at'] else '?'
        kind_label = ''
        if c['kind'] == 'review-inline':
            kind_label = ' (inline review comment)'
        elif c['kind'] == 'review-body':
            state = c.get('state', '')
            kind_label = f' (review: {state})' if state else ' (review)'
        print(f'### {user} — {ts}{kind_label}')
        print()
        print(c['body'])
        print()
    print('---')
    print()
"
