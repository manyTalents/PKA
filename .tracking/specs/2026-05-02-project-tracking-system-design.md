# Project Tracking System — Design Spec

**Date:** 2026-05-02
**Author:** 10T (brainstormed with Owner)
**Research:** DATA — `Owner's Inbox/progress-tracking-alternatives-research.md`
**Status:** Approved

---

## Problem Statement

The current PROGRESS.md system tracks project state in a single append-only file per project. This worked initially but has three compounding problems:

1. **File bloat** — `.10T/PROGRESS.md` is 625+ lines and growing. Every session appends. Nothing is pruned.
2. **Mixed signal density** — Routine session entries ("updated CSS") sit next to critical architectural decisions, making both hard to find.
3. **Token waste on cold start** — An agent must load the entire file to find the 5-10 lines that matter (resume point + current status). At 625 lines, that's ~2,500 tokens of mostly stale history.
4. **Crash fragility** — Updates only happen at session close. If the PC crashes, terminal freezes, or the session dies mid-work, all context since the last clean close is lost. This is the original reason PROGRESS.md was created, and the new system must solve it better.

## Design Goals

- **Crash-resilient** — Context loss on unexpected termination is capped at ~15 minutes max.
- **Fast cold start** — An agent can fully orient in ~50-60 lines of reading (CURRENT.md + today's session file).
- **Decisions are permanent** — Significant decisions are never buried, never pruned, always findable.
- **History is preserved** — The Owner can always rewind and see what happened (PROGRESS.md + session files).
- **Zero dependencies** — Pure markdown + git. No external tools, databases, or services.
- **Git-committed** — Tracking files live in each project's repo and push to GitHub for persistence.

---

## File Structure

### Per-Project Tracking Folder

Every project repo gets a `.tracking/` folder at its root, committed to git:

```
project-root/
├── .tracking/
│   ├── CURRENT.md              ← Agent cold-start briefing (20 lines max)
│   ├── DECISIONS.md            ← Append-only decision log (never pruned)
│   ├── PROGRESS.md             ← Append-only full history (Owner's black box)
│   ├── specs/                  ← Design docs — source of truth for what we're building
│   │   └── YYYY-MM-DD-topic-design.md
│   └── sessions/
│       ├── 2026-05-02.md       ← Today's session log
│       └── 2026-05-01.md       ← Yesterday's (immutable after day ends)
├── src/
└── ...
```

### PKA Orchestrator

PKA is a project too and gets the same structure. PKA also gets its own private GitHub repo (`manyTalents/PKA`):

```
PKA/
├── .tracking/
│   ├── CURRENT.md              ← System-wide state (active projects, blockers)
│   ├── DECISIONS.md            ← Org-level decisions
│   ├── PROGRESS.md             ← Master orchestrator log
│   ├── specs/                  ← PKA-level specs only (e.g. this tracking system)
│   └── sessions/
├── .10T/                       ← 10T orchestrator system files
├── Team/                       ← Team member identities
├── Owner's Inbox/
├── Team Inbox/
└── CLAUDE.md
```

### Projects and Their Repos

Each project lives in `C:\Users\chris\OneDrive\Documentos\{project}\` with its own GitHub repo. Unless the Owner specifies otherwise, all projects push to GitHub under the `manyTalents` account.

| Project | Local Path | GitHub Repo |
|---------|-----------|-------------|
| PKA (orchestrator) | `Documents/PKA/` | `manyTalents/PKA` (private) — NEW |
| The Machine | `Documents/the-machine/` | existing |
| ManyTalentsMore | `Documents/ManyTalentsMore/` | existing |
| AllTec Pro | `Documents/AllTecPro/` | existing |
| VEOE | `Documents/clawdbottrade/` | existing |

---

## File Formats

### CURRENT.md — Agent Cold-Start Briefing

**Purpose:** The single file every agent reads first. Answers: "What is this project? Where is it? What do I do next?"

**Hard rules:**
- Maximum 20 lines. If it's longer, content belongs in DECISIONS.md or the session file.
- Only active members listed. If a member isn't working on this project right now, they're not in the file.
- Blockers include dates so stale blockers are obvious.
- Updated on time + event triggers (see Update Triggers section), not just session close.

**Format:**

```markdown
# {Project Name} — CURRENT

## Status
{One line: what state is this project in right now}

## Active Work
- **{Member}:** {What they're doing / what's next for them}
- **{Member}:** {Same}

## Handoff
{Member} → {Member}: {Critical context the next person needs}

## Blockers
- {Blocker description} (since YYYY-MM-DD)

## Next
1. {Priority 1}
2. {Priority 2}
3. {Priority 3}
```

**Handoff section:** Present only when work is passing between members. Contains the context the receiving member needs that isn't obvious from the status or active work bullets. Removed once the receiving member picks up and confirms they have context.

### DECISIONS.md — Permanent Decision Log

**Purpose:** Every significant decision, with date, context, and rationale. Prevents agents from re-litigating settled questions.

**Hard rules:**
- Append-only. Never pruned, never edited after the day it was written.
- One entry per decision. Short and scannable.
- Header line with count and last-updated date so agents know if it's fresh.
- Agents grep this file for relevant decisions rather than loading the whole thing.

**Format:**

```markdown
# {Project Name} — DECISIONS

> {N} decisions logged | Last: YYYY-MM-DD

---

### YYYY-MM-DD — {Decision title}
**Context:** {Why this came up}
**Decision:** {What was decided}
**Rationale:** {Why this option over alternatives}
**Members:** {Who was involved}

---
```

### sessions/YYYY-MM-DD.md — Daily Session Log

**Purpose:** Detailed log of what happened today. Provides continuity within a day and recent history for investigation.

**Hard rules:**
- One file per calendar day (UTC-6 / Central Time).
- Append-only during the day. Immutable after the day ends — never modified retroactively.
- Agents load today's session file on startup for continuity. Older files are searched via grep only when investigating history.
- Each entry is timestamped with HH:MM and the member doing the work.

**Format:**

```markdown
# {Project Name} — Session {YYYY-MM-DD}

## HH:MM — {Member} — {Brief summary}
{What was done, decisions made, files changed, errors encountered}

## HH:MM — {Member} — {Brief summary}
{Next entry}
```

### PROGRESS.md — Owner's Black Box

**Purpose:** Full append-only history for the Owner's reference and for reverting. This is the existing PROGRESS.md format, preserved.

**Hard rules:**
- Append-only. Never pruned by agents (Owner may compress manually if desired).
- Agents do NOT load this file on startup. It is not part of the cold-start package.
- Updated at session close (or via periodic checkpoint if session dies).
- Structured the same way current PROGRESS.md entries are structured (session log blocks with "What was done," "Decisions made," "Files created/modified," "Resume point").

**No format change from current system** — the existing PROGRESS.md format is kept exactly as-is. The difference is that it's no longer the primary cold-start file.

### specs/ — Design Documents (Source of Truth)

**Purpose:** Design specs define *what* is being built and *how*. They are the ultimate authority for a project's intended behavior and architecture.

**Location:** Each project's specs live in `{project}/.tracking/specs/`. PKA-level specs (like this tracking system) stay in `PKA/.tracking/specs/`. Project specs do NOT live in PKA — they live next to the code they describe.

**Hard rules:**
- Design specs are the source of truth. If code and spec disagree, the agent **flags the disagreement and asks the Owner** before proceeding. Do not silently follow the code. Do not silently follow the spec. Flag it.
- Specs follow the naming convention: `YYYY-MM-DD-topic-design.md`
- Agents read the relevant spec when starting work on a feature or system described by that spec.
- Specs are living documents — they can be updated, but only with Owner approval. Changes are noted with date and reason at the top of the spec.

**Code vs Spec Disagreement Protocol:**
1. Agent detects that code behavior does not match spec description.
2. Agent **stops** — does not continue building on top of the disagreement.
3. Agent flags the specific disagreement to the Owner: what the spec says, what the code does, and where.
4. Owner decides: update the spec (intent changed) or fix the code (implementation drifted).
5. Agent proceeds only after resolution.

This prevents silent drift where code evolves away from the original design without anyone noticing.

---

## Update Triggers

CURRENT.md is updated on both time and event triggers to survive crashes.

### Time-Driven Updates

| Trigger | Target | Method |
|---------|--------|--------|
| Every ~15 minutes of active work | CURRENT.md, today's session file | Claude Code hook (PostToolUse with elapsed-time check) |

The hook tracks the timestamp of the last checkpoint. After each tool use, if ≥15 minutes have elapsed since the last checkpoint, the agent updates CURRENT.md and appends to today's session file. This is transparent to the user — no prompts, no interruptions.

### Event-Driven Updates

| Event | CURRENT.md | Session File | DECISIONS.md | PROGRESS.md |
|-------|-----------|--------------|--------------|-------------|
| Task completed | ✓ | ✓ | | |
| Decision made | ✓ (if it changes status/next) | ✓ | ✓ | |
| Deployment | ✓ | ✓ | | |
| Blocker hit or resolved | ✓ | ✓ | | |
| Handoff between members | ✓ | ✓ | | |
| Error that changes the plan | ✓ | ✓ | | |
| Session close (clean) | ✓ | ✓ | | ✓ |
| Periodic checkpoint (~15 min) | ✓ | ✓ | | |

### Crash Recovery

**Worst case:** 15 minutes of session log lost. CURRENT.md was checkpointed within the last 15 minutes.

**Recovery flow:**
1. Next agent reads CURRENT.md → knows project state within ~15 min accuracy
2. Reads today's session file → sees last logged entry
3. Checks git log for any commits made after the last session entry → fills gap
4. Resumes work

---

## Agent Cold-Start Protocol

When 10T dispatches a team member to work on a project, the member loads files in this order:

| Step | File | Purpose | Expected Size |
|------|------|---------|---------------|
| 1 | `Team/{Member}/IDENTITY.md` | Who I am, how I think | ~20 lines |
| 2 | `{project}/.tracking/CURRENT.md` | Project state + my assignment | ≤20 lines |
| 3 | `{project}/.tracking/sessions/{today}.md` | Today's context (if exists) | Variable |
| 4 | `{project}/.tracking/specs/{relevant-spec}.md` | Design spec for the feature being worked on | As needed |
| 5 | `{project}/.tracking/DECISIONS.md` | Only if needed — grep for relevant decisions | Searchable |

**Never loaded on startup:** PROGRESS.md, old session files. Searched only when investigating history.

**Total cold-start context:** ~50-70 lines (excluding spec, which varies by feature scope) vs 625+ lines today.

---

## Migration Plan

### Existing Projects with PROGRESS.md Files

For each existing PROGRESS.md:
1. Create `.tracking/` folder in the project repo
2. Extract the current resume point → write CURRENT.md
3. Extract significant decisions from session logs → seed DECISIONS.md
4. Move existing PROGRESS.md into `.tracking/PROGRESS.md` (preserving full history)
5. Start today's session file

### Existing PROGRESS.md Locations to Migrate

| Current Location | Project | Action |
|-----------------|---------|--------|
| `PKA/.10T/PROGRESS.md` | PKA Orchestrator | → `PKA/.tracking/PROGRESS.md` |
| `docs/The Machine/PROGRESS.md` | The Machine | → `the-machine/.tracking/PROGRESS.md` |
| `Team Inbox/money-api-infra/PROGRESS.md` | Money Dashboard | → Already complete; archive to `ManyTalentsMore/.tracking/PROGRESS.md` |
| `docs/superpowers/specs/watchdog/PROGRESS.md` | Watchdog | → `PKA/.tracking/` (PKA sub-project) or own repo |
| `docs/superpowers/specs/incident-memory/PROGRESS.md` | Incident Memory | → same |
| `docs/superpowers/specs/state-persistence/PROGRESS.md` | State Persistence | → same |
| `docs/superpowers/specs/enforcement-system/PROGRESS.md` | Enforcement | → same |

### PKA GitHub Repo

1. Create `manyTalents/PKA` as private repo on GitHub
2. Initialize with current PKA folder contents
3. Add `.gitignore` for sensitive files (API keys, credentials, `.env`)
4. Push initial commit
5. Verify clone works from a clean state

---

## Hook Implementation

A Claude Code PostToolUse hook handles the time-driven checkpoints. Pseudocode:

```
on PostToolUse:
  if (now - last_checkpoint) >= 15 minutes:
    update .tracking/CURRENT.md with current state
    append checkpoint entry to .tracking/sessions/{today}.md
    last_checkpoint = now
```

Event-driven updates are handled by team member discipline enforced via CLAUDE.md rules — when a triggering event occurs, the member updates the tracking files as part of completing that event. This is codified as a rule in CLAUDE.md so all agents follow it.

---

## Rules to Add to CLAUDE.md

The following rules will be added to the PKA `CLAUDE.md` to enforce the system:

1. **Every project has a `.tracking/` folder** with CURRENT.md, DECISIONS.md, PROGRESS.md, specs/, and sessions/.
2. **CURRENT.md is max 20 lines** and is updated on every event trigger and every ~15 minutes.
3. **Agents read CURRENT.md first** — never PROGRESS.md on cold start.
4. **Design specs are the source of truth** — they live in `.tracking/specs/` in the project repo, not in PKA.
5. **Code vs spec disagreements are flagged** — agent stops, flags to Owner, waits for resolution. Never silently follow either side.
6. **DECISIONS.md is append-only** — never edit or delete entries.
7. **Session files are per-day and immutable after the day ends.**
8. **PROGRESS.md is the Owner's file** — append at session close, never load on startup.
9. **Handoff context is mandatory** when work passes between members.
10. **10T updates CURRENT.md before closing any session** — non-negotiable, even for "quick" sessions.

---

## What This Replaces

| Before | After |
|--------|-------|
| Single PROGRESS.md per project (all-in-one) | 4 files with distinct purposes |
| Cold start loads 625+ lines | Cold start loads ~50-60 lines |
| Updates only on session close | Updates every ~15 min + on events |
| Crash loses all session context | Crash loses max ~15 min |
| Decisions buried in session logs | Decisions in dedicated searchable file |
| No handoff context between members | Explicit handoff section in CURRENT.md |
| PROGRESS files scattered across PKA | `.tracking/` folder in each project repo, committed to GitHub |

---

## Out of Scope (Future Considerations)

- **Automated memory systems** (AgentMemory, CASS) — revisit in 6 months when tooling matures
- **MADR** (individual decision files) — adopt per-project if DECISIONS.md exceeds 100 entries
- **Cross-project knowledge sharing** — handled by PKA's own MEMORY.md system for now
- **Semantic search over session history** — grep is sufficient at current scale
