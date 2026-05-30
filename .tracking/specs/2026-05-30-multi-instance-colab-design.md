# Design: Multi-Instance Colab System (v3)

**Date:** 2026-05-30
**Author:** 10T (Orchestrator)
**Status:** Approved — awaiting implementation
**Builds on:** Colab v2 protocol (2026-05-28)

---

## Problem

The current colab system is single-instance: one `colab` task file, one `COLAB-STATUS.md`, one flat directory of response files. Claude and Grok can only work on one topic at a time. Chris needs to run multiple concurrent colab sessions (same AI pair, different topics) without them interfering with each other.

## Constraints

- The active VEOE colab session (running in the flat `AI-Collab/` root) must NOT be disrupted
- Same participants for now: Claude + Grok
- Shared protocol files (operating notes, lessons, template) should not be duplicated
- Watchers should remain one process per AI, not one per session

---

## Directory Structure

```
AI-Collab/
├── COLAB-OPERATING-NOTES.md    # shared protocol (updated for v3)
├── COLAB-LESSONS.md            # shared lessons (all sessions append here)
├── RESPONSE-TEMPLATE.md        # shared template
├── Owners-Instructions.md      # shared standing orders
├── SESSIONS.md                 # index of active/ended sessions
├── sessions/
│   ├── {topic}/                # one folder per session
│   │   ├── colab              # task file for THIS session
│   │   ├── STATUS.md          # state for THIS session only
│   │   └── *.md               # response files scoped to this session
│   └── ...
├── archive/                   # completed sessions
│   └── YYYY-MM-DD-{topic}/
│       ├── SUMMARY.md
│       ├── colab
│       ├── STATUS.md
│       └── *.md
├── COLAB-STATUS.md            # LEGACY — used by active VEOE session only
└── [legacy flat files]        # current VEOE response files, untouched
```

### Rules

- Each session gets exactly one folder under `sessions/`
- Folder name = short topic slug (lowercase, hyphens): `invoice`, `veoe-next`, `machine-v3`
- All response files for a session live inside that session's folder
- Shared protocol files stay in `AI-Collab/` root — never duplicated into session folders
- Legacy flat files in root are untouched until the active VEOE session ends

---

## SESSIONS.md — Session Index

Single source of truth for what's running.

```markdown
# Active Colab Sessions

| Session | Status | Started | Participants | Path |
|---------|--------|---------|--------------|------|
| veoe (legacy) | ACTIVE | 2026-05-28 | Claude + Grok | AI-Collab/ (root) |
| invoice | ACTIVE | 2026-05-30 | Claude + Grok | AI-Collab/sessions/invoice/ |
```

### Fields

- **Session:** Short name. `(legacy)` tag for sessions running in the old flat structure.
- **Status:** `ACTIVE`, `ENDED`, `HALTED`
- **Started:** Date session was created
- **Participants:** Which AIs are involved
- **Path:** Filesystem path relative to repo root. Legacy sessions point to `AI-Collab/ (root)`.

### Update Rules

- Row added when a session is created
- Status updated when session ends or halts
- Ended sessions stay in the table (for reference) until archived, then removed

---

## Session Lifecycle

### Creating a Session

Two paths:

**Chris creates directly:**
1. Creates `AI-Collab/sessions/{topic}/colab` with the task description
2. Adds a row to `SESSIONS.md`
3. Tells one or both AIs: `colab {topic}`

**Chris tells 10T:**
1. Chris says "start a colab on {topic}"
2. 10T creates the session folder, writes the `colab` file from Chris's description
3. 10T adds the row to `SESSIONS.md`
4. 10T informs both AIs via their next interaction

### Triggering a Session

| Chris says | AI behavior |
|------------|-------------|
| `colab {topic}` | Target that specific session. Read its `colab`, `STATUS.md`, latest files. |
| `colab` (one active session) | Target the only active session. Same as today. |
| `colab` (multiple active sessions) | Ask Chris which session. Never guess. |
| `colab!` | Re-read the `colab` file for the current/specified session (same as v2). |

### Cold-Start Read Order (per session)

When triggered for a specific session:

1. `AI-Collab/SESSIONS.md` — which sessions exist, which are active
2. `AI-Collab/sessions/{topic}/colab` — the task (may have changed)
3. `AI-Collab/sessions/{topic}/STATUS.md` — current state
4. Latest 2 response files from the other AI in that session folder
5. `AI-Collab/COLAB-LESSONS.md` — shared cross-session learning
6. `AI-Collab/COLAB-OPERATING-NOTES.md` — shared protocol reference

For legacy sessions (VEOE), the read order stays the same as v2 — files in `AI-Collab/` root, `COLAB-STATUS.md` in root.

### Ending a Session

1. Either AI proposes `ENDED` in the session's `STATUS.md`
2. Both AIs append to shared `COLAB-LESSONS.md` (tagged with session name)
3. Session folder moves to `AI-Collab/archive/YYYY-MM-DD-{topic}/`
4. `SESSIONS.md` row updated to `ENDED`, then removed after archive

### Archiving Legacy Sessions

When the active VEOE session ends:
1. All `2026-05-*` response files from `AI-Collab/` root move to `archive/2026-05-28-veoe/`
2. Root `COLAB-STATUS.md` moves into the archive folder
3. Legacy row removed from `SESSIONS.md`
4. Root `AI-Collab/` is clean — only shared protocol files remain

---

## STATUS.md — Per-Session State

Each session has its own `STATUS.md` inside its folder. Same format as today's `COLAB-STATUS.md`, scoped to one topic.

```markdown
# Status — {topic}

## Session
- **Topic:** [full description]
- **Mode:** ACTIVE | HALTED | ENDED
- **Time limit:** 5h (default)

## Claude (10Tc)
- **State:** WAITING | WORKING | DONE
- **Last file:** {filename} ({timestamp})
- **Working on:** [description] (~ETA)  # only when WORKING
- **Accepts input:** yes | no            # only when WORKING

## Grok (10Tg)
- **State:** WAITING | WORKING | DONE
- **Last file:** {filename} ({timestamp})

## Chris Input
[Relay any Chris suggestions here for the other AI to see]

## Background Tasks
[Any long-running work relevant to this session]
```

### Rules

- Updated after every file drop (same as v2)
- Each AI only updates their own section + shared fields (Mode, Chris Input)
- No cross-session state in a session's STATUS — each file is self-contained

---

## Watcher Upgrade (v3)

### Behavior Change

Current (v2): One watcher, watches one flat directory.
New (v3): One watcher, reads `SESSIONS.md` to discover all active session paths, watches each one.

### Startup

1. Parse `SESSIONS.md` for all rows where Status = `ACTIVE`
2. Extract each session's path
3. For legacy sessions, watch `AI-Collab/` root (filter `*{other-ai}*` as today)
4. For new sessions, watch `AI-Collab/sessions/{topic}/` (same filter)

### Detection Output

Include the session name in every detection message:

```
[14:32:15] === GROK RESPONDED [invoice] ===
  -> 2026-05-30-grok-surcharge-research.md
[14:45:02] === GROK RESPONDED [veoe] ===
  -> 2026-05-30-grok-sweep-results.md
[15:01:00] === COLAB FILE UPDATED [invoice] ===
  Chris changed the task file. Re-read sessions/invoice/colab immediately.
```

### Script Changes (`colab-watcher.sh`)

- Add function to parse `SESSIONS.md` and return list of `(session_name, path)` tuples
- Main loop iterates over all active sessions instead of one hardcoded path
- Re-parse `SESSIONS.md` every 5 minutes (in case a session was added/removed mid-run)
- Heartbeat reports count of active sessions being watched
- All other behavior (settling, poll interval, heartbeat, duration) unchanged

### Grok's PowerShell Monitor

Same conceptual upgrade:
- Parse `SESSIONS.md` for active paths
- Poll each session directory
- Report session name in notifications
- Implementation is Grok's responsibility; this spec defines the contract

---

## Response Files

### Naming Convention

Same as v2, just scoped to the session folder:

```
AI-Collab/sessions/invoice/2026-05-30-claude-arch-overview.md
AI-Collab/sessions/invoice/2026-05-30-grok-surcharge-research.md
```

No need for a session tag in the filename — the folder provides the namespace.

### Template

Same shared `RESPONSE-TEMPLATE.md` from root. No changes needed — the template is session-agnostic.

---

## COLAB-LESSONS.md — Shared Across Sessions

Lessons stay in one shared file (not per-session). Entries are tagged with the session name:

```markdown
## 2026-05-30 — Invoice Colab

**What worked:**
- ...

**What didn't:**
- ...
```

This keeps cross-pollination working — lessons from one session inform others.

---

## COLAB-OPERATING-NOTES.md — Updates for v3

The shared protocol doc gets a new section explaining multi-instance:

- How `SESSIONS.md` works
- Trigger syntax (`colab {topic}` vs bare `colab`)
- Cold-start read order includes `SESSIONS.md` as step 1
- Legacy bridge explanation (old sessions in root, new sessions in `sessions/`)
- One-file-per-round rule applies per session (dropping a file in `invoice` doesn't count as your round in `veoe`)

All other v2 rules (settling, one file per round, STATUS updates, watcher honesty, termination) carry forward unchanged.

---

## Legacy Bridge

The current VEOE session runs undisturbed:

| Aspect | VEOE (legacy) | New sessions |
|--------|---------------|--------------|
| Task file | `AI-Collab/colab` | `AI-Collab/sessions/{topic}/colab` |
| Status | `AI-Collab/COLAB-STATUS.md` | `AI-Collab/sessions/{topic}/STATUS.md` |
| Response files | `AI-Collab/*.md` (flat) | `AI-Collab/sessions/{topic}/*.md` |
| Watcher | Watches root (existing behavior) | Watches session folder |
| Trigger | `colab veoe` or `colab` (if only legacy active) | `colab {topic}` |

When VEOE ends, its files archive to `archive/2026-05-28-veoe/` and the legacy bridge is removed from `SESSIONS.md`.

---

## Implementation Order

1. Create `AI-Collab/SESSIONS.md` with the legacy VEOE row
2. Create `AI-Collab/sessions/` directory
3. Create first new session folder (e.g., `sessions/invoice/`)
4. Upgrade `colab-watcher.sh` to v3 (multi-directory)
5. Update `COLAB-OPERATING-NOTES.md` with v3 multi-instance section
6. Notify active VEOE colab of the new system (via STATUS update + next response file)
7. Grok upgrades PowerShell monitor to v3 spec

---

## What Does NOT Change

- One file per round rule (per session)
- Settling period (60-90s)
- Watcher honesty (report RUNNING/DEAD/UNKNOWN)
- 5hr default time box (per session)
- Shared COLAB-LESSONS.md (all sessions write here)
- Response template format
- Chris has final say on everything
