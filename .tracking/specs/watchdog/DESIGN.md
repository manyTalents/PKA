# Watchdog — DESIGN (Phase 2 of Error Prevention System)

> One-page spec per Standard #21. Short by design.
> Created: 2026-04-22 | Owner scope approval: locked same day

---

## Project in one line
Alert the Owner via email within minutes when any monitored live service goes silent. Catches the runtime-failure class Phase 1 enforcement cannot prevent — processes that keep "running" but stop producing correct output.

## Why this exists
Phase 1 blocks bugs at commit time. A different class of failure survives Phase 1: the VEOE zombie bug (89% of losses were phantom — documented in OWNER_CONTEXT), Strategy A's silent SQLite schema crash (`SOLUTIONS_LOG #7` — caught by try/except, no alert, ran hourly for days). Liveness monitoring is the minimum prevention layer for these.

Phase 2a (this spec) = **liveness only.** Phase 2b (future) adds sanity checks that can catch zombie-logic bugs.

---

## "Done" definition — Phase 2a

1. A `watchdog/` Python package exists at `PKA/watchdog/` containing:
   - `client.py` — library imported by each monitored service. Single-call API: `heartbeat("veoe", status="ok")`. Writes atomically to a heartbeat file.
   - `watchdog.py` — daemon/cron script. Reads all heartbeat files, alerts if any is older than its configured threshold.
   - `config.yaml` — per-service map of threshold-in-seconds and alert-tier.
   - `alerts.py` — Gmail SMTP email sender with 30-min per-service cooldown (reuses the SOLUTIONS_LOG #8 pattern).
2. Heartbeat files live at `/var/lib/pka-watchdog/heartbeats/<service>.json` on the droplet. Schema: `{service, status, ts, last_error, counters}`.
3. Watchdog runs every 1 minute on droplet 104.131.176.130 via cron (or systemd timer — Helm's call).
4. **Watchdog watches itself.** A dead-man's-switch: if the watchdog fails to run for >5 min, an external check (UptimeRobot free tier or a droplet `at`-job) sends an alert. Who watches the watchman must not be a single point of failure.
5. Email alerts go to `christoph3reverding@gmail.com`. Single consolidated email per cycle (not per-service) to avoid spam.
6. SMTP credentials from Bitwarden (Standard #20) — never hardcoded, never committed.
7. Tests cover: (a) heartbeat write/read round-trip, (b) stale detection at threshold boundary, (c) 30-min cooldown prevents spam, (d) email payload format, (e) missing heartbeat file is treated as "never reported" and alerts immediately.
8. Integration guide documented: exactly what lines to add in `the-machine/main.py` and in VEOE's scheduler to call the heartbeat client.

## Who uses it
- **The Machine** (crypto bot) — calls `heartbeat("the-machine")` every main loop tick (~30s).
- **VEOE** (options bot) — calls `heartbeat("veoe")` every scheduler iteration.
- **Chris** — receives email alerts; Phase 2b adds a dashboard at `manytalentsmore.com/health`.
- **10T** — during monthly SOP review, reads the watchdog alert log to identify recurring silences (candidates for deeper sanity checks in Phase 2b).

## What breaks if it's wrong
- **False alerts** → alert fatigue → Chris ignores real ones. Mitigation: 30-min cooldown per service; consolidated email; threshold configurable per service.
- **Missed alerts** (real silence, no email sent) → defeats the purpose. Mitigation: watchdog self-heartbeats; external dead-man's-switch (see "Done" #4); tests exercise every failure path.
- **Heartbeat write fails silently** (disk full, perm error, OneDrive hiccup) → false security. Mitigation: `client.py` raises on write failure; bot code must log it; Phase 1 Rule #14 already blocks silent try/except.
- **SMTP creds leak in logs** → security incident. Mitigation: creds always from Bitwarden; Phase 1 Rule #20 blocks accidental commit; `alerts.py` must never log credentials.

---

## Scope locked (Owner approved 2026-04-22)
- **Services monitored Phase 2a:** VEOE and The Machine. (Owner-selected the two live-money bots.)
- **Alert delivery:** Email to christoph3reverding@gmail.com. SMS and Slack deferred to future phases.
- **Check depth:** Liveness only. Sanity checks (Phase 2b) deferred to catch a future phase.
- **Code location:** `PKA/watchdog/` — matches Phase 1's pattern (`PKA/enforcement/`).

## Team
- **Lead:** Kit (Developer) — build `client.py`, `watchdog.py`, `alerts.py`, config schema, unit tests.
- **DevOps:** Helm — deployment guide for droplet (cron vs systemd timer), Bitwarden SMTP cred retrieval, self-heartbeat mechanism, external dead-man's-switch setup.
- **QA:** Gauge — expanded regression + cooldown edge cases + alert format verification.
- **Bot integration (future sessions, out of scope this build):**
  - Onyx (Crypto) — integrate `heartbeat("the-machine")` into main loop.
  - Arrow (Options) — integrate `heartbeat("veoe")` into scheduler.
- **Manager:** 10T — scope review, monthly silence-log review.

## Decisions (captured per Standard #22)

### Decision: Central watchdog on the droplet (not external SaaS, not per-service)
**Date:** 2026-04-22
**Why:** Both monitored services already run on droplet 104.131.176.130. Central watchdog = one code path for alerts, one place to add services later. Phase 2b sanity checks will need bot-internal state access, which is easier from the same host.
**Alternatives considered:** UptimeRobot / Healthchecks.io (rejected — can't see bot-internal state for future sanity checks). Per-service cron jobs (rejected — duplicates alert logic, hard to maintain cooldown state).

### Decision: File-based heartbeats (atomic write), not DB or HTTP
**Date:** 2026-04-22
**Why:** Simplest. Zero deps. Race-free with `tempfile + os.replace()`. Visible by hand with `ls`. Works even if the watchdog is down. No always-on listener required.
**Alternatives considered:** SQLite — overkill for two services. HTTP endpoint — adds a listening process (more moving parts, more failure modes).

### Decision: 30-min alert cooldown per service (reuses SOLUTIONS_LOG #8 pattern)
**Date:** 2026-04-22
**Why:** Documented, battle-tested pattern. Short enough that a real ongoing outage re-alerts within the half-hour. Prevents restart-storm spam.
**Alternatives considered:** Escalating backoff (5/15/60 min) — nicer UX but defer to Phase 2b when alert volume justifies complexity.

### Decision: Build enforcement (Phase 1) before monitoring (Phase 2), not parallel
**Date:** 2026-04-22
**Why:** Prevention at commit is cheaper than detection at runtime per bug caught. Phase 1 makes Phase 2's own code safer from day one.
**Alternatives considered:** Parallel build — rejected to preserve focus and avoid scope creep.

---

## Open items to confirm before Kit starts

1. **Droplet deployment in this session or later?** I cannot SSH into 104.131.176.130 from this sandbox (no key). Proposal: Kit builds and unit-tests locally in `PKA/watchdog/`; Helm produces a deployment guide; actual droplet install happens when Chris opens Claude Code or runs the steps himself. This matches the Phase 1 MTM-pilot pattern.
2. **Gmail account for SMTP:** `alltecplumbing@gmail.com` (existing MTM outgoing email — already has App Password in Bitwarden per Standard #20) or a new account? Default recommendation: reuse existing.
3. **External dead-man's-switch:** UptimeRobot free tier (5-min granularity, free) or Healthchecks.io (flexible, free tier)? Default recommendation: Healthchecks.io — purpose-built for this exact "did my cron run?" use case.

---

## Version log

| Date | Change | By |
|------|--------|----|
| 2026-04-22 | Initial spec — Phase 2a scope (liveness only, VEOE + The Machine, email alerts) | 10T + Owner |
