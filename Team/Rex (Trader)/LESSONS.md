# Rex — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->

### 2026-05-11: Self-DOS via Recursive Error Handler
- **Category:** execution / api-safety
- **Lesson:** A catch block must NEVER re-invoke the function that failed; recursive error handlers can self-DOS the exchange API in seconds.
- **Context:** `fetchFeatureFlags` failed (CORS) and the catch block returned `getFeatureFlags()`, which re-called `fetchFeatureFlags()` when the cache expired. This created an infinite loop that fired 10,000+ requests in minutes, hit the Coinbase daily rate limit, and took the entire site down for hours. Fix: max 3 retries, exponential backoff, 60s cooldown on disk, static fallback from catch blocks.
- **Keywords:** self-dos, recursive, retry, rate-limit, exponential-backoff, cooldown, circuit-breaker, api-safety

### 2026-05-04: CDE Contract Sizing — Fractional Orders Fail Silently
- **Category:** trading / order-management
- **Lesson:** CDE futures require integer contract counts; fractional sizes return `success:false` without throwing an exception, silently failing every order.
- **Context:** The grid computed fractional base sizes (e.g., "0.000297") but CDE products have `base_min_size=1` and `base_increment=1`. Every order returned `success:false` and stored empty order_ids, which then caused `get_order("")` to spam 404 errors (40+ per tick, every 30 seconds). Fix: `_compute_order_qty()` for integer contract counts, `_order_succeeded()` to explicitly validate order responses.
- **Keywords:** cde, contract-size, fractional, integer, base_increment, base_min_size, order-validation, silent-failure

### 2026-05-20: Hardcoded Starting Equity Hid Real Losses
- **Category:** trading / reporting
- **Lesson:** Never hardcode financial baselines as literals; a stale starting equity makes profits appear where losses exist.
- **Context:** `/api/v1/stats` had `starting = 338.47` hardcoded in main.py — a leftover literal from an earlier state. This made the dashboard show +$178 profit when the account was actually down $176 from the $950 funded baseline. Fix: changed to config constant `STARTING_EQUITY = 950.0`.
- **Keywords:** starting-equity, hardcoded, literal, baseline, pnl, reporting, config-constant

### 2026-05-20: ADX Regime Deadlock — Grid Idle 7 Days
- **Category:** trading / strategy
- **Lesson:** Regime-filter thresholds must be calibrated to the actual volatility profile of each instrument; overly tight thresholds cause indefinite grid deadlock.
- **Context:** ETH ADX sat between 40-52 but the grid paused at ADX > 25 and only resumed below 20. These thresholds were designed for low-vol instruments and were far too tight for ETH's normal volatility. The grid was idle for 7 consecutive days producing zero fills. Fix: raised ADX trending threshold from 25 to 40, ranging from 20 to 30, pause from 30 to 45, resume from 25 to 35.
- **Keywords:** adx, regime, deadlock, idle, threshold, volatility, calibration, eth

### 2026-05-19: Email Alert Spam — Per-Cycle Notifications Flooded Inbox
- **Category:** trading / alerting
- **Lesson:** Bot email alerts must be deduped per subject with a 24-hour window; per-cycle alerts will flood the Owner's inbox.
- **Context:** Reconciliation alerts, phantom scans, and broker-close-failed emails all fired once per cycle or per restart, generating dozens of identical emails. This happened at least 4 separate times. Fix: `send_email_alert()` in `messenger.py` now has a 24-hour dedup cache — same subject only sends once per 24 hours.
- **Keywords:** email, spam, alert, dedup, rate-limit, notification, messenger, 24-hour

### 2026-04-02: Massive Sweep Failure — 303/303 Configs Timed Out
- **Category:** trading / backtesting
- **Lesson:** Always validate the first iteration of a batch process before committing to the full run; 303 silent timeouts wasted days.
- **Context:** `massive_sweep.py` ran 303 backtest configs and every single one timed out at the 600s limit. Nobody knew for days because there were no early-validation checks, no progress logging, and no checkpoint saves. Fix: validate first iteration succeeds before launching full batch, add checkpoints every 10 iterations, log progress with ETA.
- **Keywords:** sweep, batch, timeout, early-validation, checkpoint, progress-logging, massive_sweep

---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->

- **Error cooldown on disk:** Write last-error timestamp to a file so cooldown survives restarts. Check on every retry attempt.
- **Config constants for baselines:** Starting equity, funded amount, and any financial reference point lives in config.py, never as a literal in endpoint code.
- **Per-instrument parameter overrides:** `INSTRUMENT_PARAMS` dict in config.py with per-instrument tuning (spacing, max_levels, stop_spacing, hold_hours) — falls back to global defaults.

---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->

- Automated order-response validator that flags any `success:false` return and logs the full response body
- Threshold profiler that measures actual ADX/volatility ranges per instrument over 30 days and recommends regime thresholds

---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

- **Validate first iteration before full batch:** Any batch process (sweep, download, training) must succeed on iteration 1 before running the rest. Seen in massive_sweep.py (2026-04-02) and reinforced by STANDARDS.md #19.
- **No hardcoded financial literals:** Starting equity, funded amount, fee rates — all must be config constants. Hardcoded literals become stale and produce misleading reports.
