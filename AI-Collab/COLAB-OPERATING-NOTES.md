# Colab Operating Notes v3 — How Claude & Grok Work Together

> Both AIs MUST read this at the start of any colab session.
> Last updated: 2026-05-30 — v3 multi-instance protocol adopted.
> v2 rules (one file per round, settling, watcher honesty, termination) carry forward unchanged.

---

## The "colab" Trigger — CRITICAL BEHAVIOR

When Chris says **"colab"** or **"colab!"** to EITHER AI:

1. **Re-read the `colab` file FIRST.** It may have changed. Chris edits it between sessions (and sometimes mid-session without saving immediately). Do NOT assume you know the task.
2. **Follow the cold-start read order** (see below).
3. **Inform the other AI** by updating COLAB-STATUS.md with: "colab file updated at [time] — re-read required."
4. The watcher on the other side will detect the STATUS change and alert.

**It does not matter which AI Chris prompts.** Whichever one hears "colab" is responsible for relaying to the other via STATUS.

---

## Cold-Start Read Order

On any "colab" trigger or new session:

1. `AI-Collab/colab` — the actual task (may have changed)
2. `AI-Collab/COLAB-STATUS.md` — current state, round, mode, who's doing what
3. Latest 2 response files from the other AI
4. `AI-Collab/COLAB-LESSONS.md` — top entries for cross-session learning
5. `AI-Collab/Owners-Instructions.md` — standing orders (rarely changes)
6. This file (`COLAB-OPERATING-NOTES.md`) — protocol reference

No assumptions. Explicit folder scan with timestamps before any action.

---

## Session Structure

### Time-Boxing (Not Round-Boxing)
- **Default session:** 5 hours, unless the `colab` file specifies otherwise
- **No limit on exchanges** within the time box — go as many rounds as needed
- **Mode** in COLAB-STATUS controls behavior: ACTIVE, AUTO-PILOT, HALTED, ENDED

### One File Per Round — NON-NEGOTIABLE
- Each AI drops **exactly ONE file per round**
- No splitting analysis across multiple files
- If you need to add more, extend the single file or wait for the next round
- **Case study:** 2026-05-28 meta-session — Grok dropped two files, Claude's watcher caught only the first, wasted a response cycle on "you dodged my questions" when the answers were in the second file

### File Format
- **Filename:** `YYYY-MM-DD-[ai]-[topic].md` (e.g., `2026-05-28-claude-machine-checkpoint.md`)
- **Use RESPONSE-TEMPLATE.md** as the starting point
- **Every file ends with:** `## Questions for [Other AI]` section
- **Every file ends with:** `## Status` section (WAITING/DONE + what you're waiting on)

### After Every File Drop
1. Update COLAB-STATUS.md immediately (state, last file, dropped-at timestamp, last-seen)
2. Confirm one-file rule in STATUS update
3. Watcher on the other side will detect within 60-90s + OneDrive sync time

---

## Long-Task Signaling

When an AI is doing a long task (building images, running backtests, deploying, etc.):

Update COLAB-STATUS with:
```
- State: WORKING
- Working on: [what] (~[ETA])
- Accepts input: yes | no
```

- **yes** = The other AI can drop a file. It will be read when the long task completes.
- **no** = Wait for the completion signal before dropping. (Rare — almost always "yes".)

The other AI should NOT wait silently. If they have input, drop the file. The working AI checks for new files after completing the long task.

---

## Watchers

### Claude Side
- **Script:** `.10T/tools/colab-watcher.sh`
- **Usage:** `bash .10T/tools/colab-watcher.sh claude [hours] [settling_sec]`
- **Defaults:** 5 hours, 90s settling, 15s poll interval
- **Behavior:** Continuous loop (does NOT exit on first detection). Filters own files. Monitors `colab` file for changes. Health heartbeat every 5 minutes.
- **Launch:** At the start of every colab session, run in background.

### Grok Side
- **Script:** `C:\temp\ai-collab-monitor.ps1`
- **Behavior:** Polls every 30s, detects new/modified files, streams notifications. Session-bound (dies when chat session ends).
- **Must also monitor:** The `colab` file for timestamp changes (per v2 protocol).
- **Launch:** At the start of every colab session via `monitor` tool with `persistent: true`.

### Watcher Rules
- **Both watchers are detection-only** — they notify, they don't auto-respond (yet).
- **60-90s settling period** after detection before triggering action (prevents acting on partial writes or multi-file drops).
- **Health status** must be reported in COLAB-STATUS: `RUNNING | DEAD | UNKNOWN`.
- **No false claims.** If you're not sure your watcher is running, say `UNKNOWN`. The 2026-05-27 false monitoring claims eroded trust.
- **If watcher is dead**, say so explicitly in STATUS. Don't silently operate in manual mode.

### Honest Limitations (Both Sides)
- Both watchers are session-bound. When Chris closes the terminal or chat, they die.
- Neither watcher auto-responds. Detection ≠ action.
- OneDrive sync adds 10-60+ seconds of latency on every exchange.
- Neither AI can act without Chris having an active session open.

---

## Roles and Capabilities

| AI | Execution | Review/Strategy | Key Tools |
|----|-----------|-----------------|-----------|
| **Claude (10Tc)** | Primary builder | Can review | Shell, SSH, git, MCPs, background tasks, deployment, Python |
| **Grok (10Tg)** | Can execute locally | Primary reviewer | File tools, PowerShell, web search, web fetch, MCP tools. No SSH. |

**Tool handoff:** When one AI needs the other's capabilities, describe the request clearly in the response file:
- "Claude: please SSH to Machine droplet and pull [specific data]"
- "Grok: please web-search for [specific topic] and report findings"

The receiving AI executes and includes results in their next response file.

---

## Termination

### Normal End
- Either AI can propose `ENDED` mode in STATUS when convergence is reached or the task is complete
- Both AIs MUST append to `COLAB-LESSONS.md` before setting their state to DONE
- 3-5 bullets max per entry: what worked, what sucked, decisions made, open items

### Emergency Stop
- Chris (or either AI with strong reason) sets Mode to `HALTED` in COLAB-STATUS
- Both AIs check Mode at the start of every action
- If HALTED: stop all work, update your state to DONE, append lessons

### Time Expiry
- Session time limit in STATUS header (default 5 hours)
- When time is up, both AIs wrap current work and move to ENDED

---

## Key Rules Summary

1. **Re-read `colab` file on every trigger.** It changes between sessions (and sometimes mid-session).
2. **One file per round.** No exceptions.
3. **Update COLAB-STATUS after every drop.** Include timestamps.
4. **Watcher must be running.** If dead, say so. No false claims.
5. **Chris has final say.** Both AIs state positions with evidence. Chris decides.
6. **Inform the other AI** when Chris triggers colab on your side.
7. **No assumptions.** Verify over assume. Read the file, don't guess the content.
8. **Append to COLAB-LESSONS.md before closing.** It's gated — can't set DONE without it.

---

---

## Multi-Instance Sessions (v3 — adopted 2026-05-30)

### How It Works

Multiple colab sessions can run concurrently. Each session gets its own folder under `AI-Collab/sessions/{topic}/` with its own `colab` task file, `STATUS.md`, and response files. Shared protocol files (this doc, COLAB-LESSONS.md, RESPONSE-TEMPLATE.md, Owners-Instructions.md) stay in the `AI-Collab/` root and are NOT duplicated.

### SESSIONS.md

`AI-Collab/SESSIONS.md` is the index of all active and recent sessions. Both AIs read it on cold start to discover which sessions exist and where their files live.

### Trigger Syntax

| Chris says | AI behavior |
|------------|-------------|
| `colab {topic}` | Target that specific session. |
| `colab` (one active session) | Target the only active session. |
| `colab` (multiple active sessions) | Ask Chris which session. Never guess. |
| `colab!` | Re-read the colab file for the current/specified session. |

### Cold-Start Read Order (v3)

1. `AI-Collab/SESSIONS.md` — which sessions are active
2. `AI-Collab/sessions/{topic}/colab` — the task for the triggered session
3. `AI-Collab/sessions/{topic}/STATUS.md` — current state
4. Latest 2 response files from the other AI in that session folder
5. `AI-Collab/COLAB-LESSONS.md` — shared cross-session learning
6. `AI-Collab/COLAB-OPERATING-NOTES.md` — this file

For legacy sessions (running in flat `AI-Collab/` root), the v2 read order still applies.

### One-File-Per-Round Is Per Session

Dropping a file in the `invoice` session does NOT count as your round in `veoe`. Each session has independent round tracking.

### Legacy Bridge

Sessions started before v3 (e.g., the original VEOE session) continue running in the flat `AI-Collab/` root with `COLAB-STATUS.md`. They appear in `SESSIONS.md` tagged `(legacy)`. When they end, their files are archived to `AI-Collab/archive/YYYY-MM-DD-{topic}/` and the legacy row is removed.

### Creating a New Session

1. Create `AI-Collab/sessions/{topic}/` directory
2. Write the `colab` task file inside it
3. Write `STATUS.md` inside it (use the template below)
4. Add a row to `SESSIONS.md`
5. Tell both AIs: `colab {topic}`

### STATUS.md Template (Per-Session)

```
# Status — {topic}

## Session
- **Topic:** [full description]
- **Mode:** ACTIVE | HALTED | ENDED
- **Time limit:** 5h

## Claude (10Tc)
- **State:** WAITING | WORKING | DONE
- **Last file:** [filename] ([timestamp])

## Grok (10Tg)
- **State:** WAITING | WORKING | DONE
- **Last file:** [filename] ([timestamp])

## Chris Input
[none]

## Background Tasks
[none]
```

### Ending & Archiving

1. Either AI proposes ENDED in the session's `STATUS.md`
2. Both AIs append to shared `COLAB-LESSONS.md` (tagged with session name)
3. Session folder moves to `AI-Collab/archive/YYYY-MM-DD-{topic}/`
4. Row removed from `SESSIONS.md`

---

## Quick Reference

| Item | Location |
|------|----------|
| Session index | `AI-Collab/SESSIONS.md` |
| Task file (v3) | `AI-Collab/sessions/{topic}/colab` |
| Task file (legacy) | `AI-Collab/colab` |
| Session state (v3) | `AI-Collab/sessions/{topic}/STATUS.md` |
| Session state (legacy) | `AI-Collab/COLAB-STATUS.md` |
| Cross-session lessons | `AI-Collab/COLAB-LESSONS.md` |
| Response template | `AI-Collab/RESPONSE-TEMPLATE.md` |
| Standing orders | `AI-Collab/Owners-Instructions.md` |
| Protocol (this file) | `AI-Collab/COLAB-OPERATING-NOTES.md` |
| Claude watcher | `.10T/tools/colab-watcher.sh claude [hours] [settling]` |
| Grok monitor | `C:\temp\ai-collab-monitor.ps1` via `monitor` tool |
| Ground rules | `AI-Collab/README.md` |
