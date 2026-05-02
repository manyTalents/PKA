# Watchdog — PROGRESS

> Per Standard #15. Updated regularly across sessions.

---

## Project description
Phase 2 of the Error Prevention System. Alert the Owner when any monitored live service goes silent. See `DESIGN.md` for full scope.

## Current status
**Phase:** 2a — Liveness-only monitoring for VEOE and The Machine.
**State:** DESIGN.md drafted. Scope approved by Owner (services, alert channel, depth). Kit beginning implementation.
**Parent project:** `../enforcement-system/` (Phase 1, shipped same day). This is a peer project under the Error Prevention umbrella.

## Resume point
If the session ends:
1. Read this file and DESIGN.md end-to-end.
2. Check `PKA/watchdog/` — is Kit's Session 2a-1 delivered? (`client.py`, `watchdog.py`, `alerts.py`, `config.yaml`, tests?)
3. If yes → Helm produces deployment guide for droplet 104.131.176.130 (cron + dead-man's-switch + SMTP creds from Bitwarden).
4. If yes + Helm done → Gauge writes expanded regression coverage (cooldown edge cases, alert format verification).
5. If yes + Helm + Gauge done → Future sessions delegate Onyx (The Machine) and Arrow (VEOE) to integrate heartbeat calls into their respective bots, then Chris deploys.

---

## Session log

### Session 2a-0 — 2026-04-22 (10T + Owner — design)

**Context.** Followed Phase 1 (enforcement) completion same day. Owner chose to skip MTM enforcement pilot for now and pivot to Phase 2 runtime monitoring. MTM enforcement pilot remains ready-to-run whenever Owner runs the one-liner.

**Owner scope decisions captured in DESIGN.md:**
- Services: VEOE + The Machine (the two live-money bots).
- Alert delivery: Email to christoph3reverding@gmail.com.
- Check depth: Liveness only (Phase 2a). Sanity checks deferred to Phase 2b.
- Code location: `PKA/watchdog/`.

**Architecture decisions (DESIGN.md Decisions section):**
- Central watchdog on droplet 104.131.176.130 (not external SaaS, not per-service).
- File-based heartbeats at `/var/lib/pka-watchdog/heartbeats/<service>.json` (not DB, not HTTP).
- 30-min alert cooldown reusing SOLUTIONS_LOG #8 pattern.
- Build Phase 1 (prevention) before Phase 2 (detection) — done.

**Work completed this session:**
- Created `PKA/docs/superpowers/specs/watchdog/` folder.
- Wrote DESIGN.md (~1 page, Owner-approved scope + 4 captured decisions).
- Wrote this PROGRESS.md.
- Updated task list with Phase 2 sub-tasks.

**Next step:** Delegate Kit to build client.py, watchdog.py, alerts.py, config.yaml, and unit tests at `PKA/watchdog/`.

---

### Session 2a-1 — 2026-04-22 (Kit — watchdog core build)

**Scope delivered:** the full `PKA/watchdog/` tree per DESIGN.md Phase 2a.

**Files created (11):**
- `watchdog/README.md` — install + usage + integration guide + rehearsal commands.
- `watchdog/requirements.txt` — `pyyaml>=6.0`, `pytest>=7.0`. Runtime is stdlib + pyyaml.
- `watchdog/pyproject.toml` — package metadata, optional console-script `pka-watchdog`.
- `watchdog/config.yaml` + `watchdog/config.example.yaml` — default config (veoe + the-machine, 180s thresholds, 1800s cooldown) and a commented example.
- `watchdog/pka_watchdog/__init__.py`
- `watchdog/pka_watchdog/client.py` — `heartbeat()` and `read_heartbeat()`. Atomic write (tempfile + fsync + os.replace). Raises `OSError`/`ValueError`; never silent. Env var `PKA_HEARTBEAT_DIR` override; explicit kwarg beats env.
- `watchdog/pka_watchdog/watchdog.py` — CLI daemon + programmatic `run()` entrypoint. Reads config, assesses each service (fresh / stale / missing / malformed-ts / unreadable), emits consolidated alert, writes self-heartbeat, returns exit 0/1/2.
- `watchdog/pka_watchdog/alerts.py` — `AlertSender` with per-service cooldown persisted to JSON (SOLUTIONS_LOG #8 + #9 addressed together). Dry-run when credentials absent. Atomic state-file write. Corrupt-state warning + graceful fallback.
- `watchdog/pka_watchdog/config.py` — dataclass-based loader, `ConfigError` on missing keys, non-positive numbers, bool-masquerading-as-int, bad email, empty services.
- `watchdog/tests/__init__.py` + `conftest.py` — path setup so `import pka_watchdog` works without install.
- `watchdog/tests/test_{client,config,alerts,watchdog}.py` — 36 tests, 1.68s run.

**Test results:** `python -m pytest tests/` → **36/36 passing in 1.68s**. Covers atomic write, unwritable-dir, invalid-service rejection, env-var precedence, config validation, cooldown (within-window / expiry / per-service independence / cross-instance persistence), dry-run, consolidated email, watchdog end-to-end (fresh / missing / stale / malformed-ts / unreadable heartbeat).

**Phase 1 self-check (all 6 rules against own code):** all 6 rules exit 0. Rule #19 flagged 5 small bounded loops (over `services` dict, over 5-key required tuple) — silenced with inline `# noqa: long-compute` + justification.

**Patterns worth sharing (added to Kit's LESSONS.md):**
- **Persistent cooldown state is just as important as the cooldown itself.** SOLUTIONS_LOG #8 and #9 are the same bug when combined — a cooldown that resets on every cron restart has zero practical effect. State file loaded in `__init__`, saved atomically after every `send_consolidated`, per-service keys.
- **Corrupt state file ≠ drop alerts.** Surface a stderr warning and start fresh rather than raising. Missed alerts are worse than a one-time cooldown reset.
- **Dry-run also writes state.** Otherwise the persistence path is untested in rehearsal.
- **Self-heartbeat writes AFTER assessment, with its own OSError surfacing.** If it fails, the external dead-man's-switch is the backstop — watchdog must not silently swallow its own write failure.

**Ready for Helm:** deployment guide for droplet 104.131.176.130 — cron or systemd timer running `python -m pka_watchdog.watchdog --config /etc/pka-watchdog/config.yaml` every 1 min; `PKA_SMTP_USER` + `PKA_SMTP_APP_PASSWORD` wired from Bitwarden; external dead-man's-switch (Healthchecks.io recommended) pointed at `watchdog-self.json` staleness.

**Ready for Gauge:** regression expansion — mixed stale+missing scenarios, email format assertions, SMTP error path tests, larger counters dicts, cross-timezone ts parsing.

**Deferred / flagged:**
- No retry logic for SMTP transient errors — next cron tick retries; acceptable for 1-min cadence.
- No size cap on counters dict — fine for the two live services today.
- Sandbox has Python 3.10; code uses `from __future__ import annotations` so runs everywhere.

---

### Session 2a-2 — 2026-04-22 (Helm — droplet deploy guide)

**Scope delivered:** full droplet deployment package for Kit's watchdog core, targeting `104.131.176.130`. Documentation + systemd units + config + wrapper only — Kit's Python code untouched.

**Files created (6):**
- `watchdog/DEPLOY.md` — 11-section copy-paste walkthrough (prereqs → scp → users/dirs → venv → Bitwarden wrapper → systemd → config → Healthchecks.io dead-man's-switch → test checklist → troubleshooting keyed to wrapper exit codes → Onyx/Arrow handoff snippets → one-liner appendix).
- `watchdog/deploy/pka-watchdog.service` — oneshot unit, `User/Group=pka-watchdog`, hardened (`ProtectSystem=strict`, `NoNewPrivileges=yes`, `ProtectHome=yes`, `PrivateTmp=yes`, `ReadWritePaths=/var/lib/pka-watchdog`), `EnvironmentFile=-/etc/pka-watchdog/env`, `TimeoutStartSec=90`, inline audit comments on every directive.
- `watchdog/deploy/pka-watchdog.timer` — `OnBootSec=30s`, `OnUnitActiveSec=60s`, `AccuracySec=1s`, `Persistent=true`. Chosen systemd timer over cron for journalctl-correlated logs, `list-timers` visibility, drift-free catch-up after reboot.
- `watchdog/deploy/pka-watchdog-wrapper.sh` — `set -euo pipefail`, sanity-checks venv/config/bw/BW_SESSION with numbered exit codes 10–14, pulls `PKA_SMTP_USER` + `PKA_SMTP_APP_PASSWORD` live from `bw get username|password "Gmail - alltecplumbing SMTP"` per Standard #20, execs `python -m pka_watchdog.watchdog`, pings Healthchecks.io with `/$rc` suffix only on clean completion (exit 0 or 1).
- `watchdog/deploy/config.production.yaml` — `alert_to: christoph3reverding@gmail.com`, `heartbeat_dir: /var/lib/pka-watchdog/heartbeats`, cooldown 1800s, veoe + the-machine both at 180s.
- `Team/Helm (DevOps)/LESSONS.md` — two new lessons: (a) wrapper + `bw get` beats static EnvironmentFile for rotatable creds (Standard #20 one-source-of-truth intent); (b) Healthchecks.io ping belongs AFTER the workload, never in ExecStartPre, because a pre-hook ping lies about liveness.

**Key design calls:**
- Wrapper pulls secrets at runtime (not baked into env file) so rotation = update Bitwarden, done. Tradeoff: `BW_SESSION` expires and needs manual refresh — acknowledged in DEPLOY.md §5; when it expires, the external dead-man's-switch catches the gap.
- Bot write access via `usermod -aG pka-watchdog the-machine|veoe` + service restart.
- Healthchecks.io on 2-min expected interval (2× cadence) so one missed tick is normal jitter, two means a real problem.

**Ready for Chris:** open SSH to droplet, paste DEPLOY.md blocks top-to-bottom. ~20–30 min end-to-end.
**Ready for Onyx + Arrow:** copy-paste snippets in DEPLOY.md §11 for `heartbeat(...)` integration in The Machine and VEOE main loops.

**Deferred / flagged:**
- PKA not on GitHub yet → Option A (scp) recommended today; switch to `git clone` once PKA is pushed.
- Bitwarden item name `"Gmail - alltecplumbing SMTP"` is best guess from Standard #20 context — Chris confirms via `bw list items --search alltecplumbing` in §1(d).

---

### Session 2a-3 — 2026-04-22 (Gauge — watchdog regression + perf)

**Scope delivered:** regression matrix expansion on top of Kit's 36-test baseline — mixed scenarios, email format + privacy, SMTP error paths, cross-timezone ts parsing, large counters, atomic-contention, and a performance budget suite. Plus `tests/COVERAGE.md` (one-page map with risk ratings per module).

**Files touched:**
- `tests/conftest.py` — expanded with 5 fixtures (`make_config`, `make_silent`, `make_sender`, `write_heartbeat`, `patch_smtp`) to DRY out setup.
- `tests/test_client.py` — +5 tests (100-key counters, 1000-char string values, nested dicts, parametrised counter shapes, 2-thread concurrent-write contention).
- `tests/test_watchdog.py` — +5 tests (UTC fresh, `+05:30` offset, microseconds, naive-ts actual behavior, strict xfail for fail-closed expectation).
- `tests/test_alerts.py` — +15 tests: subject format parametrised, subject-collapse xfail (Bug #1), UTC timestamp in body, per-service threshold + reason in body, human-readable age xfail (Bug #3), SMTP credential privacy, key-shaped counter privacy, 3 parametrised SMTP error paths (SMTPServerDisconnected / SMTPAuthenticationError / OSError) all asserting cooldown is NOT marked on failed send, SMTP success path assertions.
- `tests/test_mixed_scenarios.py` (new) — fresh+stale+missing in one run, two-stale-one-in-cooldown, all-fresh-plus-one-malformed-ts, parametrised subject-contents sanity.
- `tests/test_performance.py` (new) — 20 fresh <500 ms, 20 stale dry-run <1 s, 1000 sequential heartbeats <5 s, parametrised scale (5/10/20) printing per-service cost.
- `tests/COVERAGE.md` (new) — one-page coverage map with per-module risk ratings, three documented bugs, perf table, and seven planned Phase 2b additions.

**Test results:** `python -m pytest tests/` → **71 passed, 3 xfailed in 5.32 s** (74 total, up from 36). All xfails are strict — flip to xpass when Kit fixes the underlying code.

**Performance measured (sandbox container, tmpfs):**
- 20 fresh services, 1 run: 7.0 ms (70× under budget)
- 20 stale services, dry-run: 14.0 ms (70× under budget)
- 1000 sequential heartbeats: 3192.9 ms → 3.19 ms/write (1.6× under budget, fsync-bound)
- Scale n=5/10/20: 0.62 / 0.38 / 0.22 ms/service — sublinear, no O(n²)

**Bugs found (pinned strict xfail — NOT fixed per constraints):**
1. Subject does not collapse to "N services silent" when >3 silent services (LOW; triggers only with Phase 2b service expansion).
2. `_assess_service` upgrades naive timestamps to UTC (fail-OPEN) instead of flagging as stale/malformed. Spec wants fail-CLOSED because Standard #6 requires tz-aware. **MEDIUM — prevention defect: a bot regressing to naive ts escapes monitoring silently.**
3. Email body reports `age_seconds: 252` instead of human-readable "4m 12s". LOW — pure UX.

**Patterns added to Gauge LESSONS.md (four entries):** cooldown-never-marks-on-failed-send invariant, perf tests that print numbers, naive-ts fail-open footgun, strict xfail for documented limitations.

**Ready for Helm/deploy:** regression + perf suite proves cooldown prevents spam (SOLUTIONS_LOG #8), cross-instance state persists (#9), SMTP failures don't silence future alerts, watchdog completes in ~14 ms worst-case. Safe to ship to droplet.

**Next step:** Kit 2a-4 tightening pass recommended for Bug #2 (the fail-closed prevention defect) before droplet deployment. Bugs #1 and #3 can be Phase 2b.

---

### Session 2a-4 — 2026-04-22 (Kit — fail-closed tightening)

**Scope delivered:** Fix Bug #2 from Gauge's Session 2a-3 coverage writeup — the medium-severity fail-OPEN on naive timestamps in `_assess_service`. Bugs #1 and #3 deferred to Phase 2b per 10T's dispatch.

**Files touched (3):**
- `watchdog/pka_watchdog/watchdog.py` — `_assess_service` no longer silently upgrades `parsed.tzinfo is None` to UTC. Instead returns a `malformed-ts` assessment whose reason string points at Standard #6 and the exact remediation: *"update bot heartbeat to datetime.now(timezone.utc)"*. Same shape as the existing unparseable-ts branch — the two error paths are now symmetric.
- `watchdog/tests/test_watchdog.py` — removed strict-xfail decorator on `test_naive_ts_should_fail_closed`; updated docstring to note fix lands in 2a-4. Also renamed and inverted its sibling (`test_heartbeat_with_naive_ts_is_treated_as_utc` → `test_heartbeat_with_naive_ts_is_treated_as_malformed`) which was pinning the old buggy behavior; now asserts exit 1 + "malformed-ts" in output.
- `Team/Kit (Developer)/LESSONS.md` — one new lesson: "Monitoring code defaults to fail-CLOSED, never fail-open." Covers the rule, the prevention-defect failure mode, remediation-pointer message pattern, and cross-pollinate targets.

**Test results:** `python -m pytest tests/` → **72 passed, 2 xfailed in 5.4s**. Matches 10T's target exactly. Remaining xfails are Bug #1 (subject collapse >3 silent services, LOW) and Bug #3 (age format UX, LOW) — both Phase 2b scope.

**Phase 1 self-check:** all 6 rules exit 0 on modified watchdog.py. No new `# noqa` added.

**What the fix prevents:** A bot whose code regresses from `datetime.now(timezone.utc)` to `datetime.now()` (Standard #6 violation) used to write a naive ISO timestamp that the watchdog silently upgraded and accepted as fresh. The regressed bot escaped monitoring entirely — the exact silent-regression class the watchdog exists to catch. Now the naive ts fires a `malformed-ts` alert whose body tells the on-call which file to fix.

**Pattern added to Kit LESSONS.md (cross-pollinate):** Watchers must fail closed by default. "Silently normalize" is an adapter pattern, not a watcher pattern — a watcher that normalizes its inputs hides the very bugs it was built to surface. Symmetry with Phase 1 enforcement (which exits non-zero on violation by construction): same discipline, runtime layer. Cross-pollinate targets: Echo/Sage/Forge (bot monitors), Gauge (test helpers), Link (webhook validators), Ohm (NEC validators).

**Ready for droplet deployment:** Helm's Session 2a-2 deploy package is unchanged by this fix — same module, same entrypoint, same exit codes. Chris can proceed with DEPLOY.md whenever the Bitwarden SMTP credentials are confirmed.

**Deferred / flagged:**
- Bugs #1 and #3 remain pinned strict-xfail; Phase 2b scope per Gauge's COVERAGE.md.
- Kit flipped a sibling test that was asserting the old buggy behavior (couldn't coexist with the fix). Flagged transparently in report; suite now internally consistent.

**Next step:** Onyx (The Machine) and Arrow (VEOE) wire `heartbeat(...)` into bot main loops per DEPLOY.md §11. Or Chris runs the droplet deploy directly.

---

### Session 2b-1 — 2026-04-22 (Kit — close Phase 2a polish)

Closed the two strict-xfail bugs Gauge pinned in Session 2a-3, both lived in `alerts.py::_format_email`.

**Bug #1 — subject collapse.** When >3 services are silent, subject now reads `"[PKA Watchdog] N services silent"` so mobile mail clients show magnitude first. For ≤3 services the existing enumeration (comma-joined names) is unchanged.

**Bug #3 — human-readable age.** Added `_humanize_age(seconds)` static helper. Body now emits `last_seen: 4m 12s ago (raw: 252 seconds)` — human form first for on-call eyeballing, raw integer preserved for future machine-parsing. Replaces the old `age_seconds: 252` line.

**Tests:** Unpinned both xfails in `tests/test_alerts.py`. Docstrings reference this session.

**Suite:** 74 passed, 0 xfailed, 0 failed in 4.95s. Phase 2a ship-clean — Gauge's three bugs all closed (Bug #2 in 2a-4, Bugs #1 and #3 here).

**Phase 1 enforcement:** all 6 rules still pass on modified `alerts.py`. No new `# noqa` needed.

**LESSONS.md:** new entry on carrying both human-readable AND raw machine-parseable values in alert/log lines — the `raw: N` tail costs nothing and preserves downstream parseability.

**Phase 2a status:** CLOSED. Zero pending bugs. Ready for droplet deployment (Helm's DEPLOY.md) and bot integration (Onyx + Arrow snippets in DEPLOY.md §11).

---

## Open questions awaiting Owner
(Canonical list in DESIGN.md.)

1. Deployment in this session or defer to later (I cannot SSH the droplet from sandbox)?
2. Gmail account: `alltecplumbing@gmail.com` (existing, in Bitwarden) or new?
3. Dead-man's-switch: Healthchecks.io (recommended) or UptimeRobot?

## Archive / older sessions
*(None yet.)*
