# Error Prevention System — Umbrella Overview

> Single entry point to the multi-phase error-prevention initiative built for Chris Everding on 2026-04-22.
> Each phase is a separate project with its own DESIGN.md and PROGRESS.md.
> This doc is the index — read this first, then follow the links into the phase you care about.

---

## The problem this system solves

From the SOLUTIONS_LOG meta-analysis, four patterns produce nearly every documented incident:

1. **Silent failures** — process crashes inside a try/except, nobody alerted (VEOE zombie bug, Strategy A SQLite crash).
2. **State lost on restart** — in-memory state tracking real money disappears on reboot (orphan inventory $86 lost, pair-learner timestamp drift).
3. **Change not cascaded** — one location fixed, others missed (HCP key rotation, `frappe.enqueue` fix, ngrok patch).
4. **Recurring bug class** — a new instance of a documented incident because nobody re-read the log.

The 23 Standards in `STANDARDS.md` already encode the lessons. But every Standard ended with *"Enforcement: 10T self-enforces"* or *"code review"* — which means **memory is the weakest link**. The four phases below convert memory-dependent enforcement into automatic enforcement at every layer.

---

## Phases at a glance

| Phase | Layer | Catches pattern | Status | Primary folder |
|-------|-------|-----------------|--------|----------------|
| **1** | Prevention at commit | #3 (cascaded), #4 (recurring) | ✅ CLOSED | [`PKA/enforcement/`](../../enforcement/README.md) |
| **2a** | Detection at runtime | #1 (silent failures) | ✅ CLOSED (ready to deploy) | [`PKA/watchdog/`](../../watchdog/README.md) |
| **3a** | Retrieval at task intake | #4 (recurring) | ✅ CLOSED | [`PKA/incident_memory/`](../../incident_memory/README.md) |
| **4a** | Persistence by default | #2 (state lost on restart) | ✅ CLOSED (library ready; bot audits deferred to 4b) | [`PKA/state_persistence/`](../../state_persistence/README.md) |
| **2b** | Runtime sanity checks + multi-recipient + escalation | #1 deeper | Future | TBD |
| **3b** | MCP wrapper for incident memory (Claude Code tool) | #4 deeper | Future | TBD |
| **4b** | Actual audits of The Machine + VEOE | #2 applied | Future (Owner + Onyx + Arrow) | TBD |

---

## Phase 1 — Enforcement (commit-time prevention)

**Elevator:** Six Phase-1 rules encode Standards #6, #7, #11, #14, #19, #20 as automatic pre-commit checks. Any commit violating any of them is blocked with a clear error quoting the Standard.

- **Full spec:** [`enforcement-system/DESIGN.md`](enforcement-system/DESIGN.md)
- **Session log:** [`enforcement-system/PROGRESS.md`](enforcement-system/PROGRESS.md)
- **Code:** [`PKA/enforcement/`](../../enforcement/README.md)
- **Tests:** 55 passing, 0 xfailed, 0 failed. Self-dogfood proven (Phase 1 rules applied to Phases 2/3/4 code with zero or justified noqa).
- **Deployment:** Pre-built install script. One PowerShell command on Windows: see enforcement-system/PROGRESS.md Session 1d.

## Phase 2a — Watchdog (runtime detection)

**Elevator:** A lightweight Python daemon on the droplet reads heartbeat files written by each monitored bot and sends a consolidated email alert when any bot goes silent past its threshold. Per-service 30-min cooldown prevents restart-storm spam. Watchdog itself pings Healthchecks.io so the watcher is watched.

- **Full spec:** [`watchdog/DESIGN.md`](watchdog/DESIGN.md)
- **Session log:** [`watchdog/PROGRESS.md`](watchdog/PROGRESS.md)
- **Code:** [`PKA/watchdog/`](../../watchdog/README.md)
- **Deployment package:** [`PKA/watchdog/DEPLOY.md`](../../watchdog/DEPLOY.md) — 11-section copy-paste walkthrough, ~20-30 min droplet install.
- **Tests:** 74 passing, 0 xfailed. Perf 70× under budget.
- **Fail-closed guarantee:** naive timestamps from a regressed bot are treated as malformed (not silently upgraded). The watchdog catches bot regressions that Phase 1 didn't block at commit.

## Phase 3a — Incident Memory (retrieval)

**Elevator:** `python -m pka_incident_memory "query"` returns the top matches from SOLUTIONS_LOG, every team member's LESSONS.md, and every project's PROGRESS.md. Scored by keyword density × file priority × recency. 85 ms on the real PKA corpus.

- **Full spec:** [`incident-memory/DESIGN.md`](incident-memory/DESIGN.md)
- **Session log:** [`incident-memory/PROGRESS.md`](incident-memory/PROGRESS.md)
- **Code:** [`PKA/incident_memory/`](../../incident_memory/README.md)
- **Tests:** 43 passing. Regression fixtures against the real corpus prove SOLUTIONS_LOG Issues #1, #9, #12 surface as top-3 for queries built from their own error messages.
- **Next (Phase 3b):** MCP wrapper so Claude Code can invoke search as a tool call automatically at task intake.

## Phase 4a — State Persistence (library + audit)

**Elevator:** A generic `PersistentDict` + `Checkpoint` library using the atomic-write pattern proven in the watchdog. An AST-based audit scanner flags RAM-only state that affects real money — the exact shape of SOLUTIONS_LOG #9. Library and scanner shipped; bot-specific audits deferred to Phase 4b (requires bot repo mount).

- **Full spec:** [`state-persistence/DESIGN.md`](state-persistence/DESIGN.md)
- **Session log:** [`state-persistence/PROGRESS.md`](state-persistence/PROGRESS.md)
- **Code:** [`PKA/state_persistence/`](../../state_persistence/README.md)
- **Audit template:** [`PKA/docs/audits/state-persistence-audit-template.md`](../audits/state-persistence-audit-template.md)
- **Tests:** 41 passing. Audit run on PKA itself returns 0 findings (as expected — PKA's watchdog already persists its state).

---

## What Chris does — the "at the end" list

All of this was built with Chris working at the end. Each deploy is a single-command or single-paste step, but each needs his hands:

1. **MTM pilot.** `python C:\Users\chris\OneDrive\Documentos\PKA\enforcement\install.py "C:\Users\chris\OneDrive\Documentos\ManyTalentsMore" --baseline-sweep`. Baseline log lands in the MTM folder; 10T can read it from there.

2. **Droplet watchdog deploy.** Open [`PKA/watchdog/DEPLOY.md`](../../watchdog/DEPLOY.md), paste 11 sections top to bottom. ~20-30 min including Healthchecks.io signup. The §9 end-to-end test is the validation — expect one real alert email.

3. **Bot heartbeat integrations.** Exact one-line snippets in DEPLOY.md §11. Onyx + Arrow can execute if given access to The Machine and VEOE repos.

4. **Phase 4b bot audits.** Mount `the-machine/` and `clawdbottrade/` in a future session. Run `python -m pka_state_persistence.audit <bot-path>`. Delegate Onyx + Arrow to fill out the audit template per finding. SOLUTIONS_LOG #9 (`_inventory` dict) is the known fix target.

5. **(Optional, any time)** Try the incident memory CLI on any error: `python -m pka_incident_memory "<error message>"`. If you find a useful hit, the system is already paying back its build cost.

---

## Queued for future sessions

- **Phase 2b** — Sanity-check sentinels ("VEOE should produce at least one trade-decision log per market-open hour"). Escalation ladder (email → SMS via Twilio for critical). Multiple-recipient support.
- **Phase 3b** — MCP wrapper so Claude Code automatically invokes incident memory at task intake.
- **Phase 4b** — Actual bot audits (Onyx, Arrow). Propose Standard #24 ("Live-service state must use PKA state-persistence library") at the next monthly review once 4b lands.
- **Dashboard (Phase 5?)** — `manytalentsmore.com/health` surface summarizing all four prevention layers' status at a glance.

---

## Cross-cutting patterns that worked

Across all four phases, five patterns proved themselves repeatedly:

- **Atomic writes (tempfile + fsync + os.replace).** Used by watchdog alerts cooldown state, watchdog heartbeats, Phase 4 Checkpoint + PersistentDict. One proven pattern, four places.
- **Persistent cooldown / state across restarts.** SOLUTIONS_LOG #8 + #9 are the same bug seen from two angles. Solved generically in Phase 4's library.
- **Self-dogfooding.** Every phase's own code passes Phase 1 enforcement. Standards applied to themselves.
- **Fail-closed defaults.** Naive timestamps, malformed heartbeats, missing config, missing corpus files — every ambiguous input defaults to the loud/safe interpretation.
- **Structured output with raw data preserved.** Emails carry both human-readable and raw-integer forms. CLI tools support `--json` alongside human output. Future automation inherits both.

---

## Version log

| Date | Change | By |
|------|--------|----|
| 2026-04-22 | Initial umbrella — all four Phase-a projects shipped and linked. | 10T |
