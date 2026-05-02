# Enforcement System — DESIGN

> One-page spec per Standard #21. Short by design.
> Created: 2026-04-22 | Owner approval: PENDING

---

## Project in one line
Convert the advisory rules in `STANDARDS.md` and the incidents in `SOLUTIONS_LOG.md` into **automatic checks** that block bugs at commit time, at deploy time, and during runtime — across every repo the Owner works in.

## Why this exists
Every standard currently ends with "Enforcement: code review" or "10T self-enforces." Memory is the weakest link. The Owner runs 50-60 hour weeks and works in late-night margins — the system must survive that cadence without demanding discipline.

The four failure patterns extracted from SOLUTIONS_LOG are:

1. **Silent failures** — process crashes inside a try/except, nobody alerted. (Issues #7, #9, VEOE zombie bug.)
2. **State lost on restart** — in-memory state tracking real money disappears on reboot. (Issues #9, #12.)
3. **Change not cascaded** — one location fixed, others missed. (Issues #1, #4, #6.)
4. **Recurring bug class** — a new instance of a documented incident because nobody re-read the log. (Standard #13's origin.)

## Phased scope

| Phase | Target | Catches |
|-------|--------|---------|
| 1 | Pre-commit + CI static checks | Pattern #3 (cascaded changes), Pattern #4 (recurring classes) before commit |
| 2 | Heartbeat + silent-failure monitor | Pattern #1 (silent failures) during runtime |
| 3 | Searchable SOLUTIONS_LOG / LESSONS MCP | Pattern #4 (recurring classes) at task intake |
| 4 | State-persistence audit + shared checkpoint helper | Pattern #2 (state lost on restart) |

This DESIGN.md covers **Phase 1 only**. Phases 2-4 get their own DESIGN.md once Phase 1 ships.

---

## Phase 1 — "Done" definition

**Phase 1 is done when:**

1. A central `pka-enforcement` package exists (location TBD with Owner) containing hook scripts, lint rules, and an install script.
2. Running `./install-enforcement.sh` in any repo installs pre-commit hooks that enforce the initial rule set.
3. The initial rule set encodes these Standards (regex or AST-detectable):
   - #6 Timezone-Aware Datetimes — block `datetime.now()` without `timezone.utc`
   - #7 `frappe.enqueue` requires `job_id` with `deduplicate=True`
   - #11 HCP customer data from correct fields (flag `job.company_name` used as customer)
   - #14 No workaround comments (flag `# TODO: workaround` / `# HACK:` without ticket link)
   - #20 No plaintext secrets (flag patterns matching API keys, `.env` contents in non-`.env` files)
4. The MTM repo has it installed. A baseline scan has run. All pre-existing violations are either fixed or whitelisted with a dated exception.
5. Gauge has a regression test for every rule: one input that must pass, one that must fail, verified.
6. The install runs in under 10 seconds; the hooks run in under 5 seconds on a typical commit.
7. `LESSONS.md` for Kit, Helm, and Gauge each contain one entry from this build.
8. This DESIGN.md has a filled-in **Decisions** section below (per Standard #22).

## Who uses it

- **Every developer team member** (Kit, Swift, Forge, Glass, Echo, Onyx, Arrow) — on every commit to every repo they touch.
- **The Owner (Chris)** — when committing manually; the hook is the last line of defense before code ships.
- **10T** — during monthly SOP review, reads the hook-failure log to identify which rules fire most (candidates for auto-fixers, or rules to revisit).

## What breaks if it's wrong

- **False positives (blocks valid code)** — developers bypass the hook, trust erodes, system becomes shelfware. Mitigation: every rule has a test pair (pass + fail) signed off by Gauge before it ships. Whitelist mechanism is documented and easy.
- **False negatives (lets bugs through)** — the point of the system is lost. Mitigation: when SOLUTIONS_LOG gets a new entry, 10T reviews whether a new rule should encode it (this is already the monthly protocol; now it has a code outlet).
- **Performance too slow** — devs disable hooks. Mitigation: hard target of <5 sec on typical commit. Heavier checks go to CI, not pre-commit.
- **Central-repo coupling** — if the enforcement code is copy-pasted into each repo, a fix cascades badly (the exact pattern #3 we're trying to prevent). Mitigation: central repo, installed via script that clones/updates as needed. Each repo pins a version.

---

## Team

- **Lead:** Kit (Developer) — hook scripts, lint rules
- **DevOps:** Helm — install script, CI integration, update workflow
- **QA:** Gauge — regression tests (one pass + one fail per rule)
- **Manager:** 10T — scope, review, monthly violation log

## Decisions (captured per Standard #22)

### Decision: Build enforcement before adding any new knowledge-management tool
**Date:** 2026-04-22
**Why:** Owner's primary goal is "keeping errors out of projects," not retrieval. Analysis of SOLUTIONS_LOG showed 12/12 incidents were prevention problems, not retrieval problems. A graph/embedding knowledge tool (Open Brain, InfraNodus, etc.) improves access to existing knowledge but does not block errors. Enforcement does.
**Alternatives considered:** Start with knowledge-retrieval (rejected — doesn't touch the actual failure patterns). Start with monitoring / Phase 2 (deferred — catches errors after they ship; prevention is higher ROI per hour). Do all phases in parallel (rejected — violates "one thing well" discipline; DESIGN.md-per-phase keeps scope honest).

### Decision: Phase 1 starts with 5 Standards, not all 23
**Date:** 2026-04-22
**Why:** The five chosen (#6, #7, #11, #14, #20) are regex-detectable, have documented incidents, and cover three of the four failure patterns. The remaining 18 either require semantic understanding (hard to automate), are process rules (e.g. "read full context"), or have lower incident counts. Better to ship 5 that work than spec 23 that don't.
**Alternatives considered:** Encode all 23 upfront (rejected — scope creep, slow ship, many rules can't be pure regex). Encode only #6 and #7 (rejected — under-scopes; these are too easy alone).

### Decision: MTM pilots first, crypto bot and VEOE follow
**Date:** 2026-04-22
**Why:** Owner is actively working MTM this session; immediate feedback loop. Trading bots are higher blast radius but have real money on the line — pilot on code where a false positive is cheaper.
**Alternatives considered:** Pilot on crypto bot first (rejected — false positive risk higher). Pilot on all repos simultaneously (rejected — no debug feedback, hard to iterate on hook logic).

---

## Locked scope decisions (Owner approved 2026-04-22)

1. **Location:** `PKA/enforcement/` — lives inside the PKA folder next to STANDARDS.md itself.
2. **Engine:** `pre-commit` framework (Python-based, industry standard).
3. **Language:** Python (matches Owner's stack and the pre-commit ecosystem).
4. **Starter rule set:** Standards #6, #7, #11, #14, #19, #20 — six rules total. Standard #19 (Long Compute) is added to the original five and will be implemented as a heuristic check (flags for-loops over a configurable iteration threshold that lack visible checkpoint/persist patterns).
5. **Pilot target:** MTM (ManyTalentsMore) repo first. Rollout order after MTM: crypto bot, VEOE, AllTec Pro, RouteIQ, Providence.

---

## Version log

| Date | Change | By |
|------|--------|----|
| 2026-04-22 | Initial spec — Phase 1 scope, 5 starter rules, MTM pilot | 10T + Owner |
| 2026-04-22 | Scope locked: location=PKA/enforcement, engine=pre-commit, lang=Python, rules=6 (added #19), pilot=MTM | 10T + Owner |
