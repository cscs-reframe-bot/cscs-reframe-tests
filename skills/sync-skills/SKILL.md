---
name: sync-skills
description: >
  Versions all skills on the `skills` branch of the bot's fork
  (cscs-reframe-bot/cscs-reframe-tests). Use when the user says
  "sync skills". Never runs automatically.
---

Run `bash ${HERMES_SKILL_DIR}/scripts/sync_skills.sh`, then post the
output to Slack verbatim.

The script checks out the `skills` branch on the bot's fork, mirrors
all skills from `/opt/data/skills/` (full sync — overwrites the branch
with the PVC contents), commits, and pushes.

## Update protocol

The PVC is the source of truth. `sync skills` is a full mirror — any
edits made directly on GitHub will be overwritten on the next sync.
To modify a skill:

- **Bot-created skills** — tell the bot in Slack, then `sync skills`.
- **Curated `pr-*` skills** — open a PR on the `reframe-agent` repo
  (the authoritative source for curated skills).

GitHub is for review only. The bot never syncs automatically — only
when the user explicitly asks.
