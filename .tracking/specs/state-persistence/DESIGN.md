# State Persistence — DESIGN (Phase 4 of Error Prevention System)

> One-page spec per Standard #21.
> Created: 2026-04-22 | Owner scope approval: defaults locked same day (continue momentum per Owner directive)

---

## Project in one line
Ship a generic checkpoint-and-resume helper library, plus an audit template, so every live service's in-memory state that tracks real money or real progress is persisted to disk on every change — and restored on restart.

## Why this exists
SOLUTIONS_LOG #9 (crypto bot orphan inventory — $86 of real capital lost to dead in-memory dict across restarts) and #12 (pair-learner recency timestamp drifted because `datetime.now()` was the reference, no persisted "simulated now") document the same failure pattern: **RAM-only state that affects real money disappears on restart.**

Standard #19 (Long Compute) already requires checkpoints for batch processes. This extends that discipline to *stateful daemons* — bots that hold inventory, position, strategy state, learned weights.

Covers failure-pattern #2 from the SOLUTIONS_LOG meta-analysis.

---

## "Done" definition — Phase 4a

Phase 4a ships the **library** and the **audit template**. Actual audits of individual bots (The Machine, VEOE) are Phase 4b and require bot-repo access — deferred to Onyx and Arrow sessions.

1. A Python package at `PKA/state_persistence/` with:
   - `checkpoint.py` — `Checkpoint` class: `.load(path)`, `.save(path, state)` with atomic write + `fsync`. Matches the watchdog cooldown-state pattern.
   - `persistent_dict.py` — `PersistentDict`: behaves like a `dict` but writes to JSON on every mutation. Opt-in mode for high-frequency writes (debounce interval).
   - `audit.py` — `scan_for_ram_only_state(path: Path)` — walks a Python codebase and flags suspicious patterns: module-level dicts/lists that get mutated; `self.<name> = {}` in `__init__` that get written across methods without any `.save()` or `pickle` call in the class; obvious "inventory", "position", "state", "cache" names with no persistence signal.
   - `tests/` — pass/fail fixtures for the audit scanner, round-trip tests for Checkpoint and PersistentDict.
2. An **audit report template** at `PKA/docs/audits/state-persistence-audit-template.md` — the document format Onyx and Arrow will fill out for their respective bots.
3. Integration guide: exactly 5-10 lines of code a bot adds to use the library. "Before," "after" snippets from a realistic case.
4. Phase 1 enforcement passes against the library's own code.
5. Tests cover: atomic write, concurrent write (last-write-wins cleanly, no partial files), crash-during-write simulation (tempfile cleanup), empty state, non-JSON-serializable state raises clearly.

## Who uses it
- **Onyx (Crypto)** — Phase 4b: audit `the-machine/` for RAM-only state. Convert `_inventory` dict in `strategy_mm.py` to `PersistentDict`.
- **Arrow (Options)** — Phase 4b: audit `clawdbottrade/` (VEOE). Persist position state, scheduler cursors, any learned weights.
- **Kit** — Phase 4a builder.
- **10T** — enforcement: future new services are required to use the helper by policy. Will propose this as Standard #24 after Phase 4a ships.
- **Chris** — reads audit reports, approves fixes.

## What breaks if it's wrong
- **Library bug corrupts state on write** → lost money, the exact failure we're preventing. Mitigation: atomic write (tempfile + fsync + os.replace) — same pattern proven in watchdog Session 2a-1. Full crash-during-write test coverage.
- **Audit false positives** (flagging benign dicts) → noise. Acceptable — each flag goes to a human for review, not auto-converted.
- **Audit false negatives** (missing a RAM-only-money pattern) → the bug class survives. Acceptable tradeoff; the audit is a first-pass grep, not proof of correctness. Phase 4b Onyx/Arrow manually review their own bots in addition.
- **Performance** — PersistentDict with a noisy bot could write the state file thousands of times per second. Mitigation: debounce interval (default 1 second); mutations between debounces are batched.

---

## Scope locked (Owner momentum-mode defaults)
- **Language:** Python (matches PKA's stack).
- **Dependencies:** stdlib only. `json`, `pathlib`, `tempfile`, `os`, `ast` (for audit).
- **Location:** `PKA/state_persistence/`.
- **Phase 4a ships:** library + audit scanner + audit report template + integration guide + library tests.
- **Phase 4a does NOT ship:** audits of The Machine or VEOE. Those require bot-repo access and are Phase 4b.

## Team
- **Lead:** Kit (Developer) — library + audit scanner + tests.
- **QA (future session):** Gauge (QA) — expanded regression, perf.
- **Bot audits (future sessions):**
  - Onyx (Crypto) — `the-machine/` audit + `_inventory` persistence fix.
  - Arrow (Options) — `clawdbottrade/` audit + position persistence fix.
- **Manager:** 10T.

## Decisions (per Standard #22)

### Decision: Build library + audit in Phase 4a; actual bot audits in Phase 4b
**Date:** 2026-04-22
**Why:** I (10T) don't have access to the bot repos from this sandbox. Chris would need to mount `the-machine/` and `clawdbottrade/` for me to audit them directly. Building the library + audit scanner + integration guide is fully doable in PKA's own workspace. Phase 4b can be delegated to Onyx and Arrow in future sessions when bot repos are accessible, or Chris can run the audit scanner himself.
**Alternatives considered:** Require bot-repo mount now (rejected — breaks Owner's "I'll do my stuff at the end" flow). Skip the library entirely and write manual fixes later (rejected — library is reusable, fixes aren't).

### Decision: JSON-based PersistentDict with debounced writes
**Date:** 2026-04-22
**Why:** JSON is human-readable (Chris can `cat` the state file), stdlib-supported, matches SOLUTIONS_LOG #9's `/var/lib/pka-watchdog/cooldown_state.json` pattern already proven in watchdog. Debounce prevents thrash on high-frequency mutations. One persistence model for the whole team.
**Alternatives considered:** SQLite (overkill for dict-like state). Pickle (not human-readable; version-brittle). Per-service custom schema (silo risk, duplicates logic).

### Decision: Audit scanner is advisory, not blocking
**Date:** 2026-04-22
**Why:** Audit output feeds a human-review report. False positives are expected and cheap (ignored). Auto-conversion of flagged dicts would be dangerous — `__init__` dicts that never persist are sometimes intentional (caches, fast lookup tables).
**Alternatives considered:** Add audit as a Phase 1 pre-commit rule — deferred; false-positive tolerance too low for commit-blocking.

---

## Version log

| Date | Change | By |
|------|--------|----|
| 2026-04-22 | Initial spec — Phase 4a scope (library + audit scanner; bot audits deferred to Phase 4b) | 10T |
