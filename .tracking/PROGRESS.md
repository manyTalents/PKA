# 10T Toolbox Buildout — PROGRESS

## Project Description
Building a comprehensive toolbox for the 10T team across all 3 active projects (VEOE trading bot, ManyTalents prep app, AllTec HCP replacement). Walking through HCP tools first, one at a time.

> **Archived sessions:** `.tracking/archives/PROGRESS-archive-2026-Q1Q2.md` (March-April 2026)

---

## 2026-06-28 — AllTec Pro: expanded emulator coverage + Monday-readiness hardening

**Session:** continuation of the 06-27 UI-test work. 10T orchestrated; Swift (flow authoring + triage + harness fixes), Forge (seed/cleanup + OCR verify + invoice-branding build), Glass (web parity build), general-purpose (readiness audit), main loop ran maestro + install + eas submit (credential boundary).

**v2.2.9 shipped to Play internal** (build 99d255d4, submission 9cfda676; per-device download ~32-34MB via bundletool get-size). Installed on Pixel_8 via AAB→bundletool universal APK→adb install (debug-signed for emulator; internal testers got the real signed AAB).

**Expanded emulator coverage:** Swift authored 15 new Maestro flows → `mobile/.maestro/COVERAGE-MATRIX.md` (57 functions catalogued; 26 flows total; 12 deferred-need-testID; 4 not-emulator-feasible: invoice-PDF share sheet, real camera capture, live-Stripe card, QR login). Used emulator capabilities: `adb svc wifi/data disable` (real offline), mock GPS, gallery image push, Stripe test mode.

**First full 26-flow run: 15 PASS / 11 FAIL → triaged to 0 real product bugs.** All 11 fails were test-harness: 5 flow syntax errors (QUE-02/03/MAT-02/NOTE-02/HIST-01 crashed at PARSE — offline never actually tested), 2 wrong fixtures (JOB-02 accept-job pre-assigned to Adam so accept button correctly hidden — accept WORKS, button at StatusControls.tsx:86 `(Entered||Scheduled)&&!isAssignedToMe`; SEND-01 job already advanced), timing/selectors (AUTH-01 greeting async, MAT-01 label "My Truck" not "Truck Stock", HOME-01 below-fold, LAB-01 blur). CONFIRMED WORKING on emulator: accept/finish-job (timer+finish+send-to-check), schedule, inventory, receipts, custom parts, cash payment, tabs, notes. Swift fixed all 11 (commit 0bc2374); re-run to validate (incl. first real offline test) in progress.

**Pre-Monday readiness audit (general-purpose, read-only):** no P0 code blocker; most prior field-test bugs already fixed in v2.2.9 (Coburn parser rebuilt, UOM fixed, 70-stuck-uploads data-loss fixed, Needs-Check list pollution fixed). #1 flagged risk (Vision OCR enabled?) → Forge VERIFIED LIVE: ocr_provider="Google Cloud Vision", creds loaded, 96.2% clean OCR incl fresh Coburn receipt. Receipt scanning ready for Monday.

**Monday fixes built (Owner-approved, STAGED — not yet deployed):**
- Invoice branding: new "AllTec Invoice" Frappe print format (logo via Letter Head, address, terms, Google-review QR) wired into both invoice.py PDF paths; "Lows"→"Lowe's" + "Cash" added to material sources (Forge, branch `feat/invoice-branding-constants-monday` 3bd0b00; needs `bench migrate`; FLAGGED: Owner to provide logo asset + Google-review URL).
- Web office parity: labor-description edit + completion-checklist toggle on web job page (Glass, branch `feat/web-office-parity-monday` 46c905a; tsc+build green; endpoints already whitelisted, no backend change).

**Cleanups (Forge, RED-A):** 3 full cleanups across the day's runs — all ZZTEST jobs + Sales Invoices + Payment Entries removed; real customer "ZZTEST Martinez" preserved each time.

## 2026-06-27 — AllTec Pro full Maestro UI regression (v2.2.8, Pixel_8)

**Session:** crash-recovery → full mobile UI test. 10T orchestrated; Swift (env prep + failure diagnosis), Forge (seed + RED-A financial cleanup), main loop ran the maestro flows (credential boundary).

**Context:** PC shut down mid-MTM work; Owner asked for "full ui test." Scope confirmed: full mobile Maestro suite on the installed build. Build on emulator was **release v2.2.8/code23** (not a dev build) → points to LIVE backend `erp.manytalentsmore.com`. Owner approved RED-A full-suite-on-live + cleanup after being shown the per-flow data-impact table.

**Setup:** Pixel_8 booted (`emulator-5554`); Adam app login (`adam@manytalentsmore.com` / pattern `{First}123!`) added to Bitwarden (`fd3526b4`) — was missing despite AUTH-01 header claiming it existed. 5 ZZTEST seed jobs created on dev.localhost (customer AllTec, tag `ZZTEST-MAESTRO-SEED`).

**Result: 8 PASS / 3 FAIL** (AUTH-01, NOT-01, PRT-03, PRT-05, PRT-02, RCP-01, QUE-01, CHK-02 pass).
- **LAB-01 FAIL** — TEST ISSUE (95%): value 1.5 persisted but scrolled above viewport after pull-to-refresh; assert needs scroll-to-top first. App fine (onEndEditing bug already fixed a28d784).
- **TAB-01 FAIL** — TEST ISSUE (98%): fixture `ZZTEST_JOB_NAME_4`=ZZTEST-INV-005 is Completed; My Jobs categorically excludes Completed → card never renders. Seed slot 4 must be Assigned.
- **COL-01 FAIL** — **REAL BACKEND BUG (99%)**: `finalize_invoice` (invoice.py:239) calls `flt(...)` but `flt` is never imported → `NameError` 500 on the re-finalize/idempotency path. First invoice created OK (SI-00014 + PE-00013, both cleaned up); the regenerate path 500s. Fix = add `from frappe.utils import flt`. RED-A adjacent (live invoicing) — needs Owner sign-off to deploy.

**Cleanup (Forge, RED-A):** cancelled+deleted ACC-SINV-2026-00014 ($77.50) + ACC-PAY-2026-00013; deleted 5 ZZTEST jobs. Live ledger verified clean. Left real customer "ZZTEST Martinez" (job #15) untouched.

**Fixes + re-run (Owner-approved):**
- COL-01 (real backend bug): deployed `from frappe.utils import flt` to live backend (Forge; branch fix/par-match-reconcile 9ed04a6 → main 8ea7d05; pre-deploy backup 20260627_181853; import verified). **COL-01 re-run PASS.**
- TAB-01 (test fixture): Swift added ZZTEST-TAB-001/002 (Assigned) to seed-test-jobs.sh + corrected slot mapping (commit 05c3640). **TAB-01 re-run PASS.**
- LAB-01 (initial scroll fix did NOT work): re-run FAIL. Deeper diagnosis → **2nd real bug**: `saveHours` 500ms debounce applies to manual edits; PTR within window reverts hours to server value. Fix = delay 0 when isManual in LaborRateSection.tsx + flow assert on labor-hours-display-button. Requires mobile rebuild/OTA → flagged to Owner, not yet applied.
- 2nd cleanup (Forge, RED-A): cancelled+deleted the new ACC-SINV-2026-00014/ACC-PAY-2026-00013 from COL-01 success + deleted all 7 ZZTEST jobs. Ledger clean.

**Final: 10/11 PASS** (only LAB-01 open, pending the hours-race mobile fix). COL-01 bug fix is LIVE.

## 2026-06-23 — Watchtower Phase 0: Alternative Data Observatory

**Session:** 10T orchestrated, 6 DATA/Rex research agents + Kit build agents

**Research:** Owner saw satellite-imagery→commodities concept, extracted deeper principle ("observable reality diverges from reported reality"). 6 parallel agents researched physical world, digital exhaust, government/regulatory, market microstructure, human behavior, supply chain signals. Synthesized 60 signals → top 15 (12/15 free). Synthesis: `Owner's Inbox/alternative-data-synthesis-2026-06-23.md`.

**Build:** Phase 0 = 4 scrapers (insider cluster buys, job posting velocity, prediction market divergence, Philly Fed benchmark) + confluence engine + accuracy tracker. Docker on droplet, email alerts, paper mode, $0/mo. Task 1/8 DONE (foundation: DB + email + config, 8/8 tests). Spec: `.tracking/specs/2026-06-23-watchtower-phase0-design.md`. Plan: `.tracking/specs/2026-06-23-watchtower-phase0-plan.md`.

**VEOE:** Crontab cleanup — removed 6 stale `clawdbot-operator` entries (RED, Owner-approved). Status: $4,206.80, 0 positions, healthy.

---

## Colab Sessions Log
| Session | Dates | Result | Deliverables | Archive |
|---------|-------|--------|--------------|---------|
| machine-review | 05-26>27 | distress fix dep, ERP migration prep | SPE: machine distress analysis | AI-Collab/archive/2026-05-26-machine-review/ |
| veoe-machine | 05-28>30 | 60% exit +255% backtest, distress gate | dep to droplet, backtest cache | AI-Collab/archive/2026-05-28-veoe-machine/ |
| v1-process | 05-30 | protocol v4, PV app scaffolded | 5 DocTypes, COLAB-OPERATING-NOTES v4 | AI-Collab/sessions/v1/ |
| mtm-app-fixes | 05-31 | STALLED (Grok tokens), solo agent cont'd | H1-H11 partial | AI-Collab/sessions/mtm-app-fixes/ |

NOTE: v5 protocol adopted 2026-06-03. Compressed exchanges, progressive compression every 7 rounds, chain relay for Grok persistence (1hr max). See AI-Collab/COLAB-V5-PROTOCOL.z.md + .10T/COMPRESSION-RUBRIC.md.

---

## 2026-06-10 — MTM Manager v2.1.0: 6 Fixes Deployed

### Context
Owner reported Adam getting logged out and customer/tenant confusion in HCP transfers. Investigated both, then worked through the remaining open issue list.

### Fixes Deployed (6)
1. **Login persistence** — Removed `validateToken` on cold start that silently wiped credentials on any server blip (502, maintenance, slow response). API keys are permanent in Frappe — no validation needed. Added 401/403 session-expired handler in `client.ts` that shows an alert before logout. Removed exposed logout button from QueueScreen (only HomeScreen has it). `auth.ts`, `client.ts`, `QueueScreen.tsx`
2. **Customer/Tenant split** — Company is now the Customer name (WW Holdings, not "Brandon Carmouche (Greenwood Star)"). When company exists, `customer_type=Company`, `customer_group=Commercial`. Legacy "Person (Company)" records auto-migrate on next sync. New `_extract_tenant_from_description()` parser extracts tenant name/phone from description patterns ("Tenant: John Smith 318-555-1234"). Populates `occupant_name` + `occupant_phone` on every HCP sync. `hcp_sync.py`
3. **Schedule screen navigation** — `"schedule"` was missing from `AppScreen` type union in `App.tsx`. Screen was fully built but `onNavigate("schedule")` was silently dropped. Added to type, navigation handler, and TabManager initialTab mapping. `App.tsx`
4. **Lowe's receipt OCR** — `<style>` and `<script>` blocks survived both regex tag-strip and BS4 `get_text()`, leaking CSS text into parsed output. Added `_strip_html_to_text()` helper that `decompose()`s these blocks before extraction. Wired into all 3 paths: fallback LLM, regex parser, totals parser. `email_poller.py`
5. **Job completion digest** — New `job_digest.py` with 30-min cron. Queries HCP Jobs with status Completed/Invoiced/Paid modified in last 30 min, emails formatted table to office. Configurable via `enable_job_digest` + `job_digest_email` in HCP Integration Settings. `job_digest.py`, `hooks.py`, `hcp_integration_settings.json`
6. **Magic link migration** — MTM Login Invite doctype already existed in code. `bench migrate` on droplet created the table. Magic links should now work on self-hosted.

### Backend Deploy
- SCP to `/opt/hcp_replacement_app/hcp_replacement/hcp_replacement/core/` (correct nested path)
- `docker compose restart backend scheduler queue-long queue-short` from `/opt/hcp_replacement/docker/`
- `bench migrate` completed successfully

### Mobile Build
- Version bumped to v2.1.0 (versionCode 8)
- EAS build EPERM fix: `Alltec Exports/` and `catalog_data/` removed from git tracking (were causing Windows file locking on shallow clone cleanup). Permanent fix: build from `C:\temp\hcp_build` (off OneDrive).
- AAB building on EAS servers

### Root Causes Found
- **Login logout:** `validateToken()` on cold start returned `false` on any non-200 HTTP response (502, 503, maintenance window). Silently deleted all stored credentials. One bad response on app relaunch = forced re-login.
- **Customer/Tenant:** HCP has no tenant field. Office puts tenant info in description. Sync code was merging PM coordinator name into Customer name ("Person (Company)"). Company should be the Customer; tenant comes from description.
- **Schedule unreachable:** `AppScreen` type union didn't include `"schedule"`. `onNavigate` handler had no branch for it. Comment said "placeholder — handled in HomeScreen" but HomeScreen just dispatched `onNavigate("schedule")`.
- **Lowe's HTML junk:** CSS text from `<style>` blocks — both `re.sub(r"<[^>]+>", " ")` and `BeautifulSoup.get_text()` extract text nodes inside `<style>` tags. Need to remove the blocks entirely before extraction.

---

## 2026-06-17 — VEOE v5 (F2 exit engine) built, tested, awaiting Owner cutover go

### Summary
Kit built `veoe:v5-candidate` on droplet `104.131.176.130` — F2 (exit engine redesign) stacked on top of `veoe:v4b-0730638` (which carries F0+F3+F1). Build-only; live container untouched.

### 6 F2 changes applied
1. **F2.1 — hard_stop reachable under trail:** Moved ATR hard-stop block ABOVE the trail block in `_decide`. Was unreachable (trail block returned first). Capital-protection floor now always fires.
2. **F2.2 — DTE env-override + theta_firewall retired:** `dte <= 7` replaced with `self.dte_exit_threshold` (env: `DTE_EXIT_THRESHOLD`, default 7). `max_hold_days` default set to 0 (theta_firewall off; code path retained for override). Ghost-close in TEM updated in lockstep.
3. **F2.3 — Scale-out at +40%:** TEM `run()` sells half position when `pnl_pct >= 0.40` (env: `SCALE_OUT_PCT`). Persists `scaled_out` ONLY after confirmed broker fill. `"scale_out"` added to `RECON_PROTECTIVE_REASONS`.
4. **F2.4 — Tighter early trail:** `TRAIL_EARLY_PCT` default 0.25 → 0.13.
5. **F2.5 — Marketable-limit ladder with cancel-replace:** 3-rung ladder (bid → bid−1tick → mid/cross), 3s/rung, cancel-replace same order ID, then market fallback. Addresses 9,952 `not_filled` / 0 `filled` history.
6. **F2.6 — Faster monitor cooldown for hot positions:** `_FAST_COOLDOWN_SEC=30` when `pnl_pct >= 0.30` (vs 300s default).

### Test results
10/10 F2 tests green in candidate container. F3 regression (protective/discretionary taxonomy, ValueError on unknown) green. F1 (equity_resolver import) green.

### 41-tape capture ratio (offline simulation)
- v4b baseline: **43.4%** weighted (sum realized / sum peak, 36 trades with peak>5%)
- v5 candidate: **52.6%** (+9.2pp delta)
- Target >=40%: PASS
- Note: spec stated ~19% baseline — that reproduces only with a unit mismatch (realized_pnl_pct column uses pct-points; peak_pnl_pct in notes uses raw decimal). Correct same-basis method = 43.4% v4b. The +9.2pp improvement holds either way.

### Image provenance
- Base: `veoe:v4b-0730638` (F0+F3+F1, canonical)
- Build: `FROM veoe:v4b-0730638 + COPY src/` overlay
- Candidate: `veoe:v5-candidate`, SHA `sha256:c2e676a1825a7fe2f6aade47045d86be52bd3a14d1532b83da2d857c1fe32fa6`
- Build dir: `/app/veoe-v5-build/` on droplet

### Open Owner decisions (for cutover approval)
- DTE threshold: tape doesn't favor changing from 7; keep `DTE_EXIT_THRESHOLD=7` for cutover
- Breakeven-lock: confirmed OFF (0% WR on 6 real trades), default stays 0
- Runner trail width post scale-out: existing ratchet (peak>=0.30→0.08, peak>=0.60→0.05); leave as-is for first live cohort
- Scale-out: 40%/half defaults, env-tunable

### Rollback
`ssh root@104.131.176.130 "cd /app/veoe && docker compose down && docker tag veoe:v4b-0730638 veoe:current && docker compose up -d veoe-scheduler"`

---

## 2026-06-09 — VEOE: P&L Integrity + Execution Overhaul

### Context
Owner ran Monday readiness check. Discovered sandbox lost $1,390 while bot's internal balance showed +$1,281. Root cause: bot was recording P&L from estimated fill prices (mid * 0.98), not actual broker fills. Deep audit also found: illiquid options entering with no OI gate, limit orders spamming 1,198×/day and dumping at market close, no total exposure cap, orphaned legs invisible to duplicate guard.

### Fixes Deployed (6)
1. **P&L uses actual broker fills** — After fill confirmed, `get_order(order_id)` fetches `avg_fill_price`. exit_price, pnl, pnl_pct all recalculated from actual fills. Removed `* 0.98` fabricated haircut. `tradier_exit_manager.py:407-427, 1402-1424`
2. **Bid-aware exit pricing** — Fetches fresh bid/ask quote from `get_quote(occ_symbol)` before placing exit limit. Wide spread (>15% of mid) → limit at bid. Narrow spread → `bid + 0.7 * spread`. `tradier_exit_manager.py:354-398`
3. **Market escalation 50 → 2** — `_MARKET_ORDER_THRESHOLD` changed from 50 to 2. After 2 failed limit orders (10 min with 5-min cooldown), market order immediately. `tradier_exit_manager.py:122`
4. **Entry liquidity gate** — `MIN_OPEN_INTEREST` 0 → 100 per leg. `MAX_SPREAD_PCT` 0.40 → 0.20. Rejects illiquid options the bot can't exit cleanly. `tradier_validator.py:79-80`
5. **Duplicate ticker guard checks broker** — `open_tickers` now built from DB open trades + broker positions (via `get_positions()` API). Prevents re-entering tickers with orphaned legs from failed leg exits. `main.py:1507-1527`
6. **Total exposure cap 80%** — Before each entry, checks if total deployed + batch spend exceeds 80% of balance. Blocks new entries if over-allocated. `main.py:1672-1690`

### Root Causes Found
- **P&L drift:** Bot used `current_mid * 0.98` as exit_price and passed it to `db.close_trade()` and `record_trade()`. The broker fill price was never queried. On 06-08: bot said +$1,281, broker actually -$468 = $1,716 gap in ONE DAY. Compounds silently over time.
- **Exit execution failure:** Limit orders at `mid * 0.98` never fill on illiquid options because bid is much lower than mid. Bot spammed 1,198 canceled orders, then dumped at market at close for worst possible fills. KEY: mid showed +125% profit target, actual fill was below entry (-$20).
- **No option liquidity filter:** Scorer filtered stock ADV ($10M+) but had zero option-level checks. No min OI, spread gate at 40%. Bot entered positions it could never exit cleanly.
- **Orphaned legs invisible:** When one leg of a strangle trail-stopped, the DB closed the entire trade. Remaining orphan at broker disappeared from `open_tickers`. Bot re-entered same ticker, stacking positions. KEY went from 2 → 6 contracts this way.
- **181% over-allocation:** No total exposure cap. 45% max per trade × N trades = unlimited. DUOL alone was $6,090 on a $4,707 balance.

### Invariants Established
These are the new structural rules the bot must hold at all times:
1. P&L only from broker `avg_fill_price` — no estimates ever
2. Exit limit prices derived from fresh bid/ask quote — not mid
3. Market order after 2 failed limits — not 50
4. No entry on options with OI < 100 or spread > 20%
5. No entry on tickers the broker already holds (not just DB)
6. Total deployed never exceeds 80% of balance

### Actual P&L Reconciliation (06-08)
| Trade | Bot Said | Broker Actual | Delta |
|-------|----------|---------------|-------|
| EXE | +$926 | -$260 | $1,187 |
| KEY | +$350 | -$20 | $370 |
| AFRM | +$122 | +$75 | $48 |
| NOV | -$30 | -$50 | $20 |
| NVO | -$121 | -$213 | $92 |
| **Total** | **+$1,248** | **-$468** | **$1,716** |

### Current State (06-09 EOD)
- Balance: $4,707 (internal), sandbox equity $94,350
- Positions: DUOL straddle×3, HRI put×1, KEY put×6, HIMS call orphan×1, WULF call orphan×2
- Daily P&L: -$196 (actual broker fills now)
- Orphans blocked from re-entry by Fix 5

### P&L Baseline Decision
Internal balance $4,707 is inflated by ~$1,700 of pre-fix phantom gains. Owner decision: **do NOT reset — watch delta.** Compare internal P&L vs broker gain/loss on every close going forward. If they track together, the fix is working. If they drift, there's still a leak.

---

## 2026-06-03 → 06-06 — VEOE: Major Hardening Session

### Result
10 fixes deployed across 3 days. Bot went from 0 entries to active trading. EXE confirmed breakout hit +122% ($+880) on day one of Rule A. Balance $2,856 → $3,704.

### Fixes Deployed
1. **Rule A** — Confirmed breakouts bypass 12:30 PM CT timing window (PRE_BREAK still blocked). `main.py:1351`
2. **Learning fix** — Skip zombie_cleanup trades in nightly lesson recorder (CIFR NOT NULL crash). `main.py:3018`
3. **Exit Gate 1** — No close orders outside options hours (8:30a-3:00p CT) + US 2026 holiday calendar. `tradier_exit_manager.py:232`
4. **Exit Gate 2** — 5-min cooldown between close attempts per trade (kills 30-order spam). `tradier_exit_manager.py:241`
5. **Exit Gate 3** — Market orders in last 30 min before close (limits won't fill). `tradier_exit_manager.py:257`
6. **Exit monitor hours** — Uses `_options_market_is_open()` with holidays. `main.py:3385`
7. **Zombie Fix v2** — Allow re-entries for tickers with closed history; block only open duplicates. Ghost detection preserved. `tradier_exit_manager.py:504`
8. **Reconcile chain** — `reconcile_positions()` now runs `_reconcile_broker_positions()` first (creation before reporting). `tradier_exit_manager.py:782`
9. **Qty mismatch fix** — Single-leg = 1 leg per contract, not 2. `tradier_exit_manager.py:846`
10. **Scheduled reconcile** — Broker/DB check at 08:30 CT (open) + 14:00 CT (1hr pre-close). Replaces old 6-hour interval. `main.py:3539`

### Root Causes Found
- **EXE order flood:** Exit monitor spammed 30+ limit orders on illiquid option, each cycle: place → poll 11s → pending → cancel → repeat. Gates 1-3 kill this pattern.
- **NVO/MDLN invisible to exit manager:** Zombie fix (2026-04-19) blocked ALL re-entries for tickers with any history. Bot legitimately re-enters tickers. Fix: only block open duplicates.
- **Qty false positives:** Reconcile report assumed every trade is 2-leg, but single_leg trades only have 1.
- **Local config stale:** `VEOE/config/default.yaml` has `catalyst_mode: true` from May colab experiment. Droplet has correct blackout config. Needs local sync.

### Open Positions (as of 06-05 EOD)
NOV put $1.10×2 (+9%), AFRM put $5.55×1 (+49% trail active), NVO strangle $3.55×3, MDLN put $2.75×1

### Remaining
- EXE ghost: closed in DB but still at broker. Will resolve Monday when exit monitor runs during market hours.
- AFRM qty mismatch: broker shows 1, DB shows 1 — match, but reconcile flagged it previously. Now clean.

### Files changed (droplet 104.131.176.130, container veoe-scheduler)
- `/app/src/main.py` — Rule A, learning fix, exit monitor hours, scheduled reconcile
- `/app/src/tradier_exit_manager.py` — 3 exit gates, zombie v2, reconcile chain, qty fix, holiday calendar

---

## 2026-06-04 — MTP Prep: Internal Testing LIVE on Google Play

### Result
Production AAB built via EAS, uploaded to Google Play Console. Internal testing release live. Testers CSV uploaded.

### Details
- EAS build `d8523e90` completed (production profile, app-bundle, v1.0.0, versionCode 1)
- Had to clone repo to `C:/tmp/mtp-build/` to work around Windows/OneDrive EPERM on EAS CLI temp dirs
- Internal testing release created Jun 4 1:30 AM
- 14-day testing clock started — target promote to production: 2026-06-18
- Remaining: store listing graphics, content rating, data safety, then production

---

## 2026-06-04 — The Machine: Halt Cleared + 403/Fee Fixes (Rex)

### Result
Cleared stuck halt state, fixed two bugs, grid running in paper mode.

### Fixes
- Halt state was cached in running process memory (clearing JSON file wasn't enough — needed container restart)
- **Perps 403 fix:** Disabled FundingRateStrategy — API key lacks INTX permissions, only CDE works. `FUNDING_RATE_INSTRUMENTS: list = []`
- **Fee config fix:** CDE futures charge ~0.15%/trade (venue $0.10 + regulatory $0.02 + clearing $0.03 + client ~$0.12 per contract). Was incorrectly set to 0% ("Coinbase One"). Coinbase One only zeroes spot fees.
- Regime filter confirmed working: detected downtrend (ADX=45.3) and paused grid on first restart

### Grid status post-fix
ETP-20DEC30-CDE, instance_id=236, 4 levels, center=$1807.75, spacing=12.36 (ATR), alloc=$357.46. No errors in logs.

### Files: config.py (droplet + local)

---

## 2026-06-03 — The Machine: Equity Floor Hit → Paper Mode (Rex)

### Result
Equity hit $446.83 (floor $500). Grid halted automatically. Switched to paper mode.
Total drawdown: -$322 (-41.9%) from $768 over 10 days.

### Root causes: ZEC crash ($150), position accumulation ($80), distress leak ($40), margin-locked stops ($30)

### Fixes deployed this session
- Position size cap in replenish (don't grow beyond half)
- Balance trim every tick when flat (max 1 difference buy/sell)
- 12-min rebuild delay (backed by 34K candle study — lets overshoot revert)
- max_levels 6→4 for ETP (2 contracts/level instead of 1)
- Counter capacity counts unfilled + counter orders

### Decision: Paper mode until regime detection + position limits are solved
Don't put more real money in until June 8 review.

---

## 2026-06-01 — The Machine: ETP Switch + Counter Cap + Distress Fix (Rex)

### Instrument Switch
ZEC→ETP. ZEC contract ($567) exceeded budget ($438) at $544 equity. ETP contract $200 — full 6 levels.
ETP first 12h: 111 fills, 77 wins, +$38.68 rolling 24h.

### Bugs Fixed
- #20: check_fills counter-buy accumulation (no capacity cap → 9 buys, 0 sells). Always existed, ETP's 6 levels exposed it.
- Distress min loss threshold (-$5). Was leaking -$14/day on tiny dips during ranging.

### Files: grid_engine.py, position_manager.py, config.py

---

## 2026-05-30 — Colab v4 Protocol + Providence PM App (10T Claude+Grok, 23 rounds)

### Colab Process Overhaul
- Built v3 multi-instance system (session subdirectories, SESSIONS.md, watcher v3)
- Ran v1 colab session: 23 rounds, 47+ files exchanged
- Proved PENDING.md turn signal, Chris Prompts tracker (15+ entries), self-poller (first autonomous AI-to-AI response)
- Deployed Windows Task Scheduler persistence (30s polling, survives everything)
- Wrote v4 protocol into COLAB-OPERATING-NOTES.md with all lessons incorporated
- Both AIs appended lessons to COLAB-LESSONS.md

### Providence Buildium Replacement — App Scaffolded
- `providence_pm` Frappe app: 5 chunks, 47 files, 2,274+ lines
- Chunk 1: Core data model (Property, Unit, Tenant, Owner, Lease Agreement)
- Chunk 2: Lease lifecycle (Subscription billing, daily auto-expiry)
- Chunk 3: Rent collection (late fees, Owner Statement report, payment API)
- Chunk 4: Maintenance (PM Work Order, PM Vendor, tenant notifications)
- Chunk 5: Tenant + Owner self-service portals with API layer
- All reviewed by Grok, issues caught and fixed (triple nesting, autoname, company field, plan proliferation)
- Commits: d80f317, 5cfa88f, 9a2b014, 4cca5fb

### Providence Screening Module — Chunk 6 Built (2026-06-04)
- Tenant screening design doc written + Grok team review (5-expert panel) incorporated
- Provider research: 8 providers evaluated, CertnCentric primary ($9.50 credit + $18 criminal), Checkr backup
- 29 new files added to mtm_property app:
  - DocTypes: Rental Application, Screening Request, Screening Provider Settings
  - Child tables: Application Reference, Screening Check Item, Parish Search Item, Default Parish
  - Provider abstraction: base class, factory, MockProvider (fully functional), CertnCentric + Checkr (skeletons)
  - Webhook endpoint with HMAC verification, email invite template
  - Client scripts: "Order Screening" button on Rental Application, Approve/Deny/Conditional decision buttons on Screening Request
- Key decisions: non-submittable DocTypes, applicant-pays (no Sales Invoice), provider handles adverse action, Rental Application links Prospect→Tenant
- FCRA compliance: consent tracking (datetime + IP + user agent + URL), permissible purpose field, decision notes required for denials
- Louisiana-specific: parish search table, require_parish_search toggle, disaster hardship statement field (200 word limit per LA law)
- Design doc: `.tracking/specs/2026-06-03-tenant-screening-design.md`
- Next: email Certn for API access, apply Checkr Partner Program, deploy to ERPNext, Erica discovery meeting

### LA CC Surcharge Research
- Dual pricing recommended over surcharging (SB 254 debit ban, effective 2026-08-01)
- Research delivered to Owner's Inbox

---

## 2026-05-26 — The Machine: Surviving the Worst Day + Kill Switch (Rex/Kit)

### Market Event
ZEC dropped $680→$569 over 48h (-16%), worst single day in 88 days (-12.9%).
Causes: US strikes on Iran (risk-off), ZEC profit-taking after rally, whale liquidation ($1.48M on Hyperliquid).
BTC only -1%, ETH -1.9% — ZEC-specific, not broad crash. Institutional buyers (Multicoin) still in.

### Grid Survival
- Daily PnL: -$28.20 (29 stops triggered, 3 wins)
- Kill switch never triggered (20% threshold = ~$153, max unrealized was ~$35)
- All stops executed cleanly (cancel-before-close working)
- Grid remained flat and balanced through the drop
- 24h rolling DB PnL went from +$52 to -$21, but grid is intact
- **The grid survived its worst day.** Losses controlled, not catastrophic.

---

## 2026-05-26 — The Machine: Kill Switch + Stop-Loss Hardening (Rex/Kit)

### Results
- Stop-loss optimized from 2.0x to 2.5x (backtest: 83 days, same PnL, half the stops, PF 5.0→7.4)
- Emergency kill switch deployed (Gate 0 in safety_gates.py) — independent last defense
- Stop-loss execution path hardened after stuck position incident (-$33 loss)
- Cancel-before-close ensures stops always execute even at low margin

### Incident: Stuck Position
- LONG x2 @ $657, stop triggered at $646, Coinbase rejected close (insufficient funds)
- Open orders held all margin, blocking the market close for 30+ minutes
- Manually cancelled orders and closed at ~$641 (-$33 realized)
- Root cause: _close_position didn't cancel orders first

### Fixes
- position_manager: cancel orders before close, 500ms delay, 10s retry on failure
- safety_gates: emergency kill switch (20% equity loss → halt + close all + alert)
- Kill switch runs ALWAYS (even when halted), halts BEFORE closing (prevents race)
- coinbase_client: added cancel_all_orders() method
- Stop multiplier: 2.0x → 2.5x per backtest optimization

### Team Review
- Rex: traced stop-loss path for longs AND shorts, verified both directions work
- Kit: found cooldown-on-failure bug (120s lockout even when close rejected), cancel race condition, spacing=0 gap
- Both found cancel_all_orders() missing from client, halt-blocks-kill-switch re-entry

### Files Changed
- position_manager.py (cancel-before-close, retry cooldown, response check)
- safety_gates.py (kill switch, rate limiting)
- coinbase_client.py (cancel_all_orders)
- config.py (stop_spacing_mult 2.0→2.5)

---

## 2026-05-25 — The Machine: Structural Fixes + Instance Tagging (Rex)

### Results
- **+$49.70 daily PnL** (14 wins, 1 loss, 93% win rate)
- DB PnL (24h): +$117.04
- Grid cycling both directions (long and short) with auto-rebuild

### Bugs Fixed (continued from May 24)
7. **Stuck filled-pending** — filled levels with no counter_order_id never pruned → prune orphaned fills
8. **Orphans survive band filter** — orders from old instances stayed → instance-tagged client_order_ids (`tm_{instance}_{uuid}`)
9. **Wrong-instance orders persist** — cancel any `tm_` order with wrong instance prefix on adopt
10. **Phantom records v2** — `_close_position` checked exceptions only, not Coinbase response → check `success` field
11. **Email spam** — daily loss cap alert every 30s → rate-limited to 1 per 24h

### Key Findings
- **Capital constraint at $768**: can't hold orders on both sides while holding a position. One-sided with position is expected. Need ~$1,400 for full grid.
- **Coinbase PnL settlement**: `total_usd_balance` only updates at daily settlement. Unsettled PnL still counts for `available_margin` immediately.

### Files Changed
- grid_engine.py: stuck fill prune, instance-tagged orders, instance-based orphan cleanup
- position_manager.py: response-checked _close_position
- safety_gates.py: rate-limited alerts
- All deployed + local synced

---

## 2026-05-24 — The Machine: Grid Proven + 6 Bugs Fixed (Rex)

### Results
- **2 completed grid cycles**, 1 stop-loss, net +$16.00 daily realized PnL
- Grid is now BALANCED: 1 BUY @ $649.10 + 1 SELL @ $662.25
- ETP SHORT orphan is gone (closed prior to session)
- Equity: $768.40, Buying Power: $579.37

### Bugs Fixed
**grid_engine.py (5 replenish bugs):**
1. Filled+counter levels consumed grid slots → count only unfilled orders
2. Buy-first bias (buy always checked before sell) → balance guarantee, underrepresented side goes first
3. Spacing=0 with <2 orders → ATR-based spacing fallback
4. Per_level=$15 hardcoded default (ZEC costs $656/contract, qty=0) → compute from allocation
5. cfg_max_levels=4 unaffordable → cost-cap by leveraged_capital / contract_cost

**position_manager.py (phantom records):**
6. `_record_exit()` ran even when `_close_position()` failed → 34 phantom distress_close records wrote -$341 fake losses, triggered daily loss cap, blocked entire grid. Fix: gate record on close success (all 4 exit types).

### Activity
- 15:55 UTC — SELL fill @ $663.00, pnl=+$9.64
- ~16:21 UTC — BUY counter fill @ $656.05, pnl=+$6.95
- ~18:19 UTC — STOP-LOSS on SHORT, pnl=-$2.40
- Grid rebuilt balanced: BUY @ $654.80 + SELL @ $670.65

### Files Changed
- clawdbottrade/the-machine-rewrite/grid_engine.py (5 replenish fixes)
- clawdbottrade/the-machine-rewrite/position_manager.py (phantom record fix)
- Both deployed to droplet, balanced grid confirmed

---

## 2026-05-23 — The Machine: Per-Instrument Overrides + ZEC Deploy (Kit)

### Work Done
- Added `INSTRUMENT_PARAMS` dict to `/opt/the-machine/src/config.py` with per-instrument tuning for ZEC-20DEC30-CDE and ETP-20DEC30-CDE
- Updated `GRID_FORCED_INSTRUMENTS` from `["ETP-20DEC30-CDE", "LCP-20DEC30-CDE", "LC-29MAY26-CDE"]` to `["ZEC-20DEC30-CDE", "ETP-20DEC30-CDE"]`
- Wired override lookup into `grid_manager.py` tick_all build block (spacing_atr_mult)
- Wired override lookup into `grid_engine.py` build method (max_levels)
- Wired override lookups into `position_manager.py` check() (stop_spacing_mult, max_hold_hours, breakeven_hours)
- All overrides fall back to global config values for any instrument not in INSTRUMENT_PARAMS
- Syntax-checked all four files before restart
- Synced all four files to local repo at C:/Users/chris/OneDrive/Documentos/clawdbottrade/the-machine-rewrite/
- Restarted the-machine container, clean startup confirmed

### Startup Confirmation (logs)
- "Scanner: using forced instruments: ['ZEC-20DEC30-CDE', 'ETP-20DEC30-CDE']"
- "Created grid ZEC-20DEC30-CDE (instance_id=184, alloc=$307.36, weight=0.50)"
- "Created grid ETP-20DEC30-CDE (instance_id=185, alloc=$307.36, weight=0.50)"
- Mode: paper. Equity: $768.40

### Files Changed (droplet)
- /opt/the-machine/src/config.py
- /opt/the-machine/src/strategies/grid_manager.py
- /opt/the-machine/src/strategies/grid_engine.py
- /opt/the-machine/src/strategies/position_manager.py

### Backup
- /root/config.py.bak.zec_deploy

---

## 2026-05-20 — The Machine: Three-Fix Session (Kit)

Owner authorized three surgical fixes to The Machine grid bot on droplet root@104.131.176.130.

**Fix 1 — Starting Equity Baseline**
- Problem: `/api/v1/stats` showed `starting_equity: 338.47`, making it look like the bot was +$178 when account is actually down $176 from $950 funded.
- Root cause: `starting = 338.47` hardcoded in `main.py` line 785 inside the `/api/v1/stats` endpoint. No state file or DB constant — it was a leftover literal.
- Fix: Changed to `starting = 950.0`.
- Verified via API: `starting_equity: 950.0`, `current_equity: 950.43` (live exchange value).

**Fix 2 — ADX Regime Deadlock**
- Problem: Grid idle for 7 days. ETH ADX was 40-52, but grid paused at ADX > 25 (REGIME_ADX_TRENDING) and only resumed below ADX 20 (REGIME_ADX_RANGING). These thresholds are too tight for ETH's normal volatility.
- There are TWO sets of ADX constants in config.py plus the GRID_ADX_PAUSE/RESUME thresholds:
  - Lines 135-136: `GRID_REGIME_ADX_TRENDING/RANGING` (original grid section)
  - Lines 359-360: `REGIME_ADX_TRENDING/RANGING` (V2 module section)
  - Lines 202-203: `GRID_ADX_PAUSE_THRESHOLD / GRID_ADX_RESUME_THRESHOLD`
- Changes applied:
  - `GRID_REGIME_ADX_TRENDING`: 25 → 40
  - `GRID_REGIME_ADX_RANGING`: 20 → 30
  - `REGIME_ADX_TRENDING`: 25 → 40
  - `REGIME_ADX_RANGING`: 20 → 30
  - `GRID_ADX_PAUSE_THRESHOLD`: 30 → 45
  - `GRID_ADX_RESUME_THRESHOLD`: 25 → 35

**Fix 3 — Contract Rollover**
- Problem: `ET-29MAY26-CDE` expires May 29 (9 days). `GRID_FORCED_INSTRUMENTS` still listed it.
- Confirmed via `client.list_crypto_futures()`: next contracts are `ET-26JUN26-CDE` (Jun 26) and `ET-31JUL26-CDE` (Jul 31). Jun contract has volume ($3207 24h), Jul has none.
- Fix: `GRID_FORCED_INSTRUMENTS` updated from `["ETP-20DEC30-CDE", "ET-29MAY26-CDE"]` to `["ETP-20DEC30-CDE", "ET-26JUN26-CDE"]`.
- Note: `ET-26JUN26-CDE` shows `view_only: True` in the API response — this is normal for CDE contracts before they fully open. The bot accepted it and created the grid instance.

**Post-restart verification**
- Container restarted cleanly, no errors in startup logs.
- Scanner confirmed: `"using forced instruments: ['ETP-20DEC30-CDE', 'ET-26JUN26-CDE']"`
- Grid confirmed building: `"Grid ETP-20DEC30-CDE built: center=2128.75 spacing=5.34 levels=4 per_level=232.06"`

**Win Rate 100% issue (reported, not fixed)**
- The stats query filters `GridFill.status == "completed"` — only grid cycle completions write fills.
- Stop-loss exits and time-exits close positions via `position_manager.py` but do NOT write a GridFill record.
- Result: losses never appear in stats. Fixing requires writing a loss record to GridFill (or a separate loss_fills table) when stop/time exits fire. Flagged for Owner — separate task.

**Backups**: `/root/config.py.bak.20260520`, `/root/main.py.bak.20260520` on droplet.

---

## Session: 2026-05-19 — Nate B Jones Research + 10T System Upgrade

### What was done:

**1. Nate B Jones Deep Research (3 parallel DATA agents)**
- Researched Nate B Jones (@NateBJones) — former Head of Product at Amazon Prime Video, now independent AI strategist (291K YouTube, 152K+ Substack #2 in Technology)
- **Substack agent:** 20 articles deep-dived from last 30 days, 15+ from 6-month window, 5+ from 12-month window. 21 named frameworks indexed.
- **YouTube agent:** 25+ videos cataloged, 12 frameworks extracted, top 10 priority videos identified.
- **Web search agent:** 30+ sources cross-referenced. Background, business model, community reception, tool stack, OB1 project.

**4 deliverables in Owner's Inbox:**
- `nate-b-jones-research-brief.md` — who he is, credentials, business model
- `nate-b-jones-channel-research-brief.md` — YouTube themes, frameworks
- `nate-b-jones-substack-research-brief.md` — 20 articles, 21 frameworks
- `nate-b-jones-synthesis-and-recommendations.md` — action plan with priority matrix

**2. 10T System Upgrade — 3 Frameworks Implemented**

**Judge Protocol (GREEN/YELLOW/RED):**
- Added to `.10T/ORCHESTRATOR.md` and `CLAUDE.md`
- GREEN: read, research, draft, test → execute freely
- YELLOW: deploy to staging, modify configs, install packages, spend <$50 → 10T confirms
- RED: deploy to production, financial transactions, delete data, push to main, spend >$50 → Owner approval required
- Structural safety layer that complements the instructional 95% Rule

**Work-Shape Classification (BUILD/BUY/HIRE/WAIT):**
- Added to `.10T/ORCHESTRATOR.md` and `CLAUDE.md`
- Replaces automatic hiring pipeline trigger with 6-dimension scoring
- Dimensions: repetition, mistake cost, judgment, model trajectory, market maturity, specificity
- BUILD = new skill/MCP, BUY = existing tool, HIRE = new team member, WAIT = revisit later
- CLAUDE.md Rule #2 updated to reference this gate

**Two-Audience Rule + Callable Business Mandate:**
- Added to `.10T/ORCHESTRATOR.md` and `CLAUDE.md`
- All public-facing content must serve humans AND AI agents
- JSON-LD, structured data, machine-readable pricing required on new pages
- Long-term: AllTec service discovery API for programmatic booking
- Truth Layer: factual, verifiable claims over marketing copy

**3. Lido Document Processing Test**
- Tested on 2 supplier invoices (Coburn's + Wholesale Electric) from phone photos
- Successfully extracted all line items, PO#s, prices, quantities
- Ready for receipt automation pipeline integration

### Key decisions:
- Nate B Jones validated as credible source — subscribe to Substack
- Judge Protocol is structural, not instructional — both layers work together
- Work-Shape Classification prevents team bloat by filtering Build/Buy/Wait before Hire
- Two-Audience Rule applies to ALL new public-facing work going forward
- OB1 (Open Brain) evaluation queued for future session

### Files modified:
- MODIFIED: `.10T/ORCHESTRATOR.md` (Judge Protocol, Work-Shape Classification, Callable Business Mandate, updated workflow)
- MODIFIED: `CLAUDE.md` (Rule #2 updated, Judge Protocol summary, Two-Audience Rule, updated workflow)
- CREATED: `Owner's Inbox/nate-b-jones-research-brief.md`
- CREATED: `Owner's Inbox/nate-b-jones-channel-research-brief.md`
- CREATED: `Owner's Inbox/nate-b-jones-substack-research-brief.md`
- CREATED: `Owner's Inbox/nate-b-jones-synthesis-and-recommendations.md`
- MODIFIED: `.tracking/CURRENT.md`
- MODIFIED: `.tracking/PROGRESS.md`

### Resume Point (2026-05-19):
- **10T system upgrade COMPLETE** — Judge Protocol, Work-Shape Classification, Two-Audience Rule all live
- **Next from Nate research:** Evaluate OB1 against our state-persistence, audit MTM for JSON-LD, audit top skills for plugin upgrade
- **Play Store:** still in progress
- **Lido:** ready to integrate into receipt pipeline

---

## Session: 2026-05-18 — MTP Prep App: Bug Fixes + Play Store Submission

### Bug Fixes (deployed to Vercel)
1. **TTS reading arrows aloud** — Erica reported speaker button says "arrow"
   - Root cause: 28 cards had → characters in `back` field data
   - Fix: `speech.ts` — added `sanitizeForSpeech()` stripping Unicode arrows, bullets, dashes before `Speech.speak()`
   - All 3 speak functions (speakLatin, speakEnglish, speakAuto) go through sanitizer
2. **Flashcard content clipped/cut off** — Erica reported content not visible
   - Root cause: `cardContainer` had `overflow: hidden` + fixed `minHeight: 280`, clipping long translations
   - Fix: `FlashcardCard.tsx` — replaced `<View>` with `<ScrollView>` for both card faces, removed overflow:hidden, added maxHeight:340 scroll cap
3. Both fixes committed to master, pushed to GitHub, deployed to Vercel

### Vercel Deploy Fix
- Previous deploys failed because `.vercel/project.json` was only in `app/` subdirectory
- Vercel project "app" has `rootDirectory: app` configured — deploy must come from repo root
- Copied `.vercel/project.json` to repo root, added `.vercel/` to `.gitignore`
- GitHub auto-deploy already connected (manyTalents/ManyTalentsPrep)
- Future deploys: just `git push` and it auto-deploys

### Google Play Store Submission (in progress)
1. **Search Console verification** — DONE
   - HTML file method: `google20e8163a0dd7e380.html` in ManyTalentsMore `public/`
   - DNS TXT record: `google-site-verification=Vi_Tu9mgfDP8OfTFbOlDDNtHNYw18R2bkp6csmJed-s`
   - Ownership verified for `manytalentsmore.com`
2. **Developer account setup** — DONE
   - Account: ManyTalentMore.com (Personal), wit@manytalentsmore.com
   - Phone verified, identity verified
3. **App created** — `com.manytalents.testprep` / "ManyTalents Prep"
4. **Privacy policy** — deployed at https://manytalentsmore.com/privacy
5. **Data deletion page** — deployed at https://manytalentsmore.com/delete-data
6. **Content rating** — completed (all No — educational app, no violence/sharing/ads)
7. **Data safety** — in progress (email, app interactions, purchase history declared)
8. **Store settings** — Category: Education, email: wit@manytalentsmore.com, website: manytalentsmore.com
9. **Store listing text** — written (short: 79 chars, full: ~900 chars)

### GCP Access
- Granted wit@manytalentsmore.com Owner access to `alltec-receipt-ocr` GCP project
- Owner account: christoph3reverding@gmail.com (personal), alltecplumbing@gmail.com is company

### Still needed for Play Store:
- Store listing graphics (512x512 icon, 1024x500 feature graphic, phone/tablet screenshots)
- Upload production AAB (`npx eas-cli build --profile production --platform android`)
- Closed testing: 12 testers opted in for 14 days minimum
- Then apply for production access

### Files created/modified:
- MODIFIED: `test prep app ManyTalentsMore/app/src/services/speech.ts` (sanitizeForSpeech)
- MODIFIED: `test prep app ManyTalentsMore/app/src/components/FlashcardCard.tsx` (ScrollView, overflow fix)
- MODIFIED: `test prep app ManyTalentsMore/.gitignore` (added .vercel/)
- CREATED: `test prep app ManyTalentsMore/.vercel/project.json` (repo root link)
- CREATED: `ManyTalentsMore/public/google20e8163a0dd7e380.html` (Search Console verification)
- CREATED: `ManyTalentsMore/src/app/privacy/page.tsx` (privacy policy)
- CREATED: `ManyTalentsMore/src/app/delete-data/page.tsx` (data deletion request page)

### Resume Point (2026-05-18):
- **Play Store submission in progress** — finish data safety, store listing graphics, upload AAB
- **Closed testing gate:** 12 testers x 14 days before production access
- **Mobile Stripe still pending** — next feature session after Play Store setup

---

## Session: 2026-05-18 — Lido Doc Processing Test + Skill Review

### What was done:

**1. New Skills Review**
- Reviewed all newly installed skills from 2026-05-16/17 upgrade
- Notable additions: crypto analysis tools (batch-token-price-lookup, technical-analyzer, token-security-analyzer, trending-pools-analyzer), Expo/RN skills (expo-horizon, expo-ui-swiftui, expo-ui-jetpack-compose, rnrepo, radon-mcp), context-mode suite, Remotion video production, Lido document processing

**2. Lido Document Processing — TESTED SUCCESSFULLY**
- Tested `extract_file_data` on 2 real supplier invoices (phone photos, sideways orientation):
  1. **Coburn's Packing Slip** (05/14/2026) — PO 41035CE, 3 line items extracted perfectly
     - 7/8 x 50 LF Copper Refrig Tubing ($413.90), 3/8 x 50 LF ($122.74), Rubatex Insulation 48ft ($36.00)
     - Total: $635.63
  2. **Wholesale Electric Pick Ticket** (05/07/2026) — PO 41023CE, 1 line item
     - 16ea LED T8 4FT 18W 4000K ($6.512/ea = $104.20)
     - Total: $115.66
- Both extracted: supplier, ticket#, date, PO#, job name, item numbers, descriptions, quantities, units, unit prices, extended prices
- Handles rotated phone photos, multi-row invoices, mixed units (RL, FT, ea)
- Owner asked about automation — discussed 3 options: folder watch, mobile app button, batch end-of-day

### Key finding:
- Lido replaces need for custom OCR parsing in the AllTec receipt pipeline
- Currently using Google Cloud Vision OCR + custom receipt_parser.py
- Lido is higher-level: structured extraction with column definitions, not raw text OCR
- Could supplement or replace the existing OCR → LLM parser chain

### Resume Point (2026-05-19):
- **Lido proven** — ready to integrate into receipt pipeline
- **Decision needed:** supplement existing OCR chain or replace it with Lido
- **Play Store:** still in progress (data safety, graphics, AAB upload)
- **Mobile Stripe:** next feature session

---

## Session: 2026-05-17 — MTP Prep App: Flashcards + AI Intake System

### Flashcard System (completed)
- Generated weeks-06-10 flashcard batch (147 cards, was missing from crash)
- Merged all 6 batches into main JSON — 759 cards across 30 weeks
- Added "parsing" card type to FlashcardType, FlashcardCard, exam-config
- Fixed card flip toggle (was one-way only)
- Removed duplicate related-questions link overlapping card text
- All committed and pushed

### Vercel / Domain Fixes
- Fixed Vercel git builds for MTP app: Root Directory set to `app` in project settings
- Fixed www.manytalentsmore.com: moved from old `website` project to `manytalents-more` project
- All git-triggered builds now working

### APK Build + Distribution
- Built Android APK via EAS (preview profile) from non-OneDrive temp dir (OneDrive EPERM workaround)
- Uploaded to GitHub Releases: v1.0.0-preview
- Added "Download Android App" button on web auth screen

### Bitwarden Integration
- BW CLI already installed, used for secret retrieval
- Saved to BW: Supabase MTM Options Service Role, Supabase MTP Prep Service Role, Supabase Personal Access Token
- Pattern: pull keys from BW → set as Supabase Edge Function secrets

### AI Intake System (designed, built, deployed)
- **Design spec:** .tracking/specs/2026-05-17-ai-intake-system-design.md
- **Implementation plan:** .tracking/specs/2026-05-17-ai-intake-system.md (15 tasks)
- **Database:** trade_requests, trade_messages, trade_files tables + trade-uploads bucket
- **Edge functions:** ai-intake (Gemini 2.5 Flash-Lite conversation + phase gates) + charge-delivery
- **Client:** intakeApi service, useIntakeStore, IntakeAnimation, EmailVerifyGate, FileUploadButton, PaymentGate (Stripe.js web), request-trade.tsx rewrite
- **Stripe:** SetupIntent for charge-on-delivery ($79), card element on web
- **Email:** Design doc emailed to wit@manytalentsmore.com via Resend on intake completion
- **Secrets set in Supabase:** GEMINI_API_KEY, STRIPE_SECRET_KEY, RESEND_API_KEY
- **Legal brief:** Routed to Team Inbox for Legal hire
- **Tested live:** AI responded correctly to "Louisiana Master Plumber exam" test

### Pending
- Mobile Stripe card collection (web-only for now)
- Admin UI for delivery/charge workflow
- Feedback survey (Option C: end-of-intake + standalone)
- Legal disclaimer text from Legal team

### Resume Point (2026-05-18):
- **MTP intake system is LIVE** — monitor for first real customer
- **Legal disclaimers needed** — route through Berry hiring pipeline
- **Admin delivery UI** — Owner deciding approach (dashboard button vs DB webhook vs script)
- **Feedback survey** — next feature iteration

---

## Session Log — 2026-05-16/17 (Skill & MCP Upgrade)

### What was done:

**1. Full Skill Audit & Installation**
- Researched new Claude Code skills/MCPs since April 2026 (3 DATA agents in parallel)
- Installed 100 skills via `npx skills add` from 8 sources:
  - remotion-dev/skills (1) — video production
  - DojoCodingLabs/remotion-superpowers (2) — full video studio (5 MCPs, 13 commands)
  - software-mansion-labs/skills (5) — RN animations, gestures, architecture
  - expo/skills (13) — official Expo SDK 55/56 skills
  - callstackincubator/agent-skills (6) — RN perf, upgrading, GitHub
  - mksglu/claude-context-mode (7) — token management
  - coinpaprika/claude-marketplace (5) — free crypto data (no API key)
  - OpenAEC-Foundation/Frappe_Claude_Skill_Package (61) — Frappe v14-v16
- Git-cloned 6 reference libraries: video-use, video-toolkit, scientific-skills, health-tracking, openclaw-medical, healthcare-compliance

**2. MCP Server Buildout (37 total)**
- Wired 8 new local MCPs with Bitwarden bw-launch.sh pattern:
  - coinbase-trade (BW: 16a1e7d2) — direct Advanced Trade API
  - stripe (BW: ad1ab072) — payments via @stripe/mcp
  - elevenlabs (BW: b9ce0dc0) — TTS for video production
  - supabase-direct (BW: 110bd324) — direct DB access
  - google-maps (BW: 8ae9907e) — 18 tools (geocode, routes, places, distance matrix)
  - alphavantage (BW: 8336a217) — free market data
  - resend (BW: be1bd8c1) — transactional email
  - (coinbase-cdp via Composio remote)
- Added 4 project stdio MCPs: lido (document extraction), next-devtools (Vercel Next.js), postiz (social publishing), reap-video (video post-production)
- Added 22 remote MCPs (user config, zero tokens until invoked):
  - higgsfield, exa-search, deepwiki, manifold-markets, huggingface, aws-knowledge, pixa, stripe-remote, vercel, cloudflare-docs, neon, square, calendly, sentry, notion, canva, cloudinary, google-maps-remote, reap-video, zapier, linear, invideo
- Created 2 new BW entries: Google Maps API key, Alpha Vantage API key
- Created bw-launch wrappers (ready, no MCP package yet): Polygon (BW: 2959f28e), Tradier (BW: 6a9af359)

**3. Google Maps API Setup**
- Owner created Maps API key on GCP project alltec-receipt-ocr
- 7 APIs to enable: Routes, Geocoding, Places (New), Maps Static, Geolocation, Distance Matrix, Roads
- Maps Static API = HCP's address preview feature
- Geofencing runs on-device via expo-location (free, no Google API calls)

### Decisions made:
- Every secret in Bitwarden — no exceptions. bw-launch.sh wrapper pattern is standard.
- Skills installed via npx have activation guards — only load when file patterns match (~0.3% context overhead)
- Remote MCPs cost zero until invoked
- Google Maps covers: route optimization, address preview, geofencing support, travel time, nearest-tech dispatch

### Key ecosystem changes noted:
- obra/superpowers: 94K stars, in official Anthropic marketplace
- Skills format now cross-platform (Claude Code, Codex, Cursor, Gemini CLI, Windsurf)
- Expo SDK 55 shipped (New Architecture default, React 19.2)
- 15,134+ plugins indexed as of May 2026
- Claude Code Routines: scheduled cloud tasks (Pro: 15 runs/day)

### Files created/modified:
- CREATED: .10T/tools/stripe-mcp/bw-launch.sh
- CREATED: .10T/tools/elevenlabs-mcp/bw-launch.sh
- CREATED: .10T/tools/coinbase-mcp/bw-launch.sh
- CREATED: .10T/tools/supabase-mcp/bw-launch.sh
- CREATED: .10T/tools/google-maps-mcp/bw-launch.sh
- CREATED: .10T/tools/alphavantage-mcp/bw-launch.sh
- CREATED: .10T/tools/resend-mcp/bw-launch.sh
- CREATED: .10T/tools/polygon-mcp/bw-launch.sh (ready, no MCP pkg yet)
- CREATED: .10T/tools/tradier-mcp/bw-launch.sh (ready, no MCP pkg yet)
- MODIFIED: .mcp.json (3 → 11 servers)
- MODIFIED: .10T/SKILL_CATALOG.md (updated stats + Section 18: Installed & Active)
- CREATED: Owner's Inbox/skill-upgrade-report-2026-05-16.md
- BW CREATED: "Google Maps - API Key (AllTec)" (8ae9907e)
- BW CREATED: "Alpha Vantage - API Key (Free)" (8336a217)

### Resume Point (2026-05-17):
- **Skill/MCP upgrade COMPLETE — 37 MCPs, 100 skills, 6 reference libraries**
- **Google Maps APIs:** Owner needs to enable 7 APIs in GCP console, then restrict the key
- **Tabled:** ATTOM Property ($95/mo trial), Spike Health (paid API)
- **Next:** Resume project work

---

## Session Log — 2026-05-04 (The Machine Fix + Dashboard Wiring)

### What was done:

**1. The Machine — CDE Contract Sizing Bug FIXED**
- Root cause: grid computed fractional base sizes (e.g. "0.000297") but CDE products require integer contract counts (base_min_size=1, base_increment=1)
- Failed orders returned success=false without exception, storing empty order_ids
- `get_order("")` spammed 404 errors (40+ per tick, every 30 seconds)
- Additional: price rounding used wrong field (quote_increment vs price_increment)
- Additional: grid center used stale 24h VWAP instead of live mid-price

**Fixes applied (droplet + committed to GitHub):**
- `coinbase_client.py`: added `get_product_spec()` with 1hr cache (contract_size, base_increment, price_increment)
- `adaptive_grid.py`: `_compute_order_qty()` for integer contract counts, `_order_succeeded()` validates responses, `_round_price()` uses price_increment, grid centers on live mid-price
- `grid_scanner.py`: affordability filter rejects instruments where min contract cost > per-level budget
- `indicators.py`: `get_scanner_indicators()` returns min_contract_cost for filtering
- `main.py`: added `/api/v1/trades` endpoint (read-only, returns real grid fills)

**Results:**
- Bot running clean since 12:57 UTC — zero 404s, zero errors
- 32 real fills in first ~4 hours, +$16.92 realized PnL
- 5 real orders on Coinbase (ET-29MAY26-CDE + ETP-20DEC30-CDE)
- Grid auto-grew from 2 to 18 active levels per instrument

**2. Crypto Dashboard — WIRED TO LIVE DATA**
- `money-api.ts` rewritten to pull real data from Machine API:
  - stats: real PnL, trade count, win rate from /api/v1/trades
  - balance: includes unrealized PnL from grid
  - trades: shows recent real grid fills
  - strategies: rounded allocations, real win rates
  - risk: live equity with grid PnL
- Fixed pre-existing build error (kingdom-contact route crashing on missing RESEND_API_KEY)
- Deployed to Vercel

**3. Previous Session Error Identified**
- Last night's session told Owner "go sleep, bot is fine" based only on `grep "grid fill logged"`
- Never checked for errors — 404s were already happening alongside paper fills since 2:28 AM
- Bot was trading on paper (auto-promoted after 355K bogus paper fills) but failing silently on real orders

### Commits:
- `1125df0` on veoe-trade/main: "fix: CDE contract sizing, price precision, and order validation"
- `d7d7430` on manytalents-more/master: "fix: wire crypto dashboard to live Machine data"

### Key learnings (for CDE products):
- `price_increment` is the REAL tick size (not `quote_increment`)
- `base_increment=1`, `base_min_size=1` → orders must be integer contract counts
- BIT=0.01 BTC/contract (~$800), ET=0.1 ETH/contract (~$235), SOL=5 SOL/contract (~$420)
- Scanner must filter by affordability before selecting instruments
- Always validate order responses (`success: false` does NOT throw an exception)

### Resume Point (2026-05-04):
- **The Machine:** LIVE and trading, monitor for consistent fills over next few days
- **Dashboard:** Deployed, verify it renders correctly on next visit
- **Perps bug:** Still open (GitHub #125), check periodically
- **ET-31JUL26-CDE:** No 1H candle data yet (non-critical, skips gracefully)

---

---

## Session: 2026-05-19 → 2026-05-24 — 10T System Overhaul (Multi-Day)

### Research Phase (2026-05-19)
- 3 parallel DATA agents researched Nate B Jones (291K YouTube, 152K+ Substack)
- 40+ Substack articles, 25+ YouTube videos, 30+ web sources analyzed
- 4 deliverables: research brief, channel brief, substack brief, synthesis+recommendations
- OB1 evaluated → DEFERRED (our .tracking/ system works at current scale)
- MTM + AllTec websites audited for agent-readability (both invisible to AI agents)
- 12 Agentic Harness Primitives mapped: 6 COVERED, 5 PARTIAL, 1 MISSING
- Skill plugin audit: IDENTITY files are proto-plugins, need eval criteria + failure modes

### Round 1: Nate B Jones Frameworks Implemented (2026-05-19)
- **Judge Protocol** (GREEN/YELLOW/RED) — ORCHESTRATOR.md + CLAUDE.md
- **Work-Shape Classification** (BUILD/BUY/HIRE/WAIT gate) — replaces auto-hiring
- **Two-Audience Rule + Callable Business Mandate** — agent-era marketing

### Round 2: Self-Identified Improvements (2026-05-23)
- **3 Lifecycle Hooks** — judge_protocol.py (Bash), judge_write_guard.py (Write/Edit), audit_logger.py (PostToolUse)
- **All 30 IDENTITY files upgraded** — eval criteria + known failure modes (2 batch agents)
- **PROGRESS.md compressed** — 1,048 → 454 lines, archive at .tracking/archives/
- **MCP Profiles** — 37 MCPs scoped across 7 domains in .10T/MCP_PROFILES.md
- **Decision Audit Log** — .tracking/AUDIT.md, auto-logged by PostToolUse hook

### Grok Expert Panel Review (2026-05-23)
- 7-reviewer panel assembled (AI architect, security, org design, trading, ERP, product, SRE)
- Score: "Advanced for a 1-person operation. 6/12 primitives COVERED."
- Top finding: structural enforcement gap — hooks only caught Bash, not MCP/Write
- Full report provided by Owner from Grok project

### Round 3: Grok Review Response (2026-05-24)
- **Expanded hooks** — Write/Edit guard (blocks .env, prod paths, settings, REGISTRY) + auto audit logger
- **RED-A/RED-B split** — Owner-absent escalation path (RED-A waits forever, RED-B 10T approves after 2hr)
- **Trading kill switches DEPLOYED** to droplet 104.131.176.130:
  - safety_gates.py created, 7 config constants added, scheduler job every 30s
  - 5 gates: equity floor ($500), daily loss cap ($100), max positions (10), API circuit breaker, heartbeat kill
  - Pre-flight check wired into grid tick — blocks if halted/blocked
  - Backups: /root/config.py.bak.killswitch, /root/main.py.bak.killswitch
- **Relevant Lessons Injector** built — .10T/tools/lessons_injector.py
  - Keyword + recency search across LESSONS.md, STANDARDS.md, failure modes, SOLUTIONS_LOG
  - Auto-surfaces top 3-5 relevant lessons during task delegation
  - ORCHESTRATOR.md + CLAUDE.md updated to make this a formal delegation step
  - LESSONS_TEMPLATE.md created for standardizing member lesson files

### Other Work This Session
- Kraken portfolio spreadsheet .bat fixed (Coinbase auth → Kraken public API, WAXL token mapping fixed)
- Lido document processing tested on 2 supplier invoices
- Grok review instructions prepared (7 expert personas + file list)

### Files Created
- `.10T/hooks/judge_protocol.py` — PreToolUse Bash guard (7 RED triggers)
- `.10T/hooks/judge_write_guard.py` — PreToolUse Write/Edit guard (5 path patterns)
- `.10T/hooks/audit_logger.py` — PostToolUse auto-logger for AUDIT.md
- `.10T/hooks/INSTALL.md` — Hook installation guide
- `.10T/MCP_PROFILES.md` — Per-domain MCP access profiles
- `.10T/tools/safety_gates.py` — Trading kill switch design (local copy)
- `.10T/tools/lessons_injector.py` — Relevant Lessons Injector
- `.tracking/AUDIT.md` — Decision audit log
- `.tracking/archives/PROGRESS-archive-2026-Q1Q2.md` — Compressed old sessions
- `Team/LESSONS_TEMPLATE.md` — Standard template for member lessons
- `Owner's Inbox/nate-b-jones-*.md` (4 research briefs)
- `Owner's Inbox/ob1-vs-tracking-evaluation.md`
- `Owner's Inbox/12-primitives-gap-analysis.md`
- `Owner's Inbox/skill-plugin-upgrade-audit.md`
- `Owner's Inbox/alltecplumbing-ai-readability-audit.md`
- `Owner's Inbox/mtm-ai-agent-readability-audit.md`
- `Owner's Inbox/trading-kill-switches-design.md`
- `Owner's Inbox/grok-review-instructions.md`
- `Owner's Inbox/grok-review-file-list.md`
- Settings: `.claude/projects/.../settings.json` (3 hooks configured)

### Files Modified
- `CLAUDE.md` — Rule #2 (Work-Shape), Judge Protocol, Two-Audience Rule, AUDIT.md in tracking table, RED-A/RED-B, Lessons Injection
- `.10T/ORCHESTRATOR.md` — Judge Protocol, Work-Shape Classification, Callable Business, Structural Enforcement, Capability Modulation, Owner-Absent Escalation, PROGRESS Compression SOP, Lessons Injection
- `STANDARDS.md` — referenced but not directly modified this session
- All 30 `Team/*/IDENTITY.md` files — Eval Criteria + Known Failure Modes added
- `.tracking/PROGRESS.md` — compressed + this session log
- `.tracking/CURRENT.md` — updated with all active work
- Droplet: `/opt/the-machine/src/safety_gates.py` (created), `config.py` (safety constants), `main.py` (safety gates wired)

### Resume Point (2026-05-24)
- **10T system overhaul COMPLETE** — 3 rounds of improvements all live
- **Kill switches running** on droplet, verify no false halts over next 24h
- **VEOE kill switches** — design ready, deploy in separate session
- **AllTec website** — JSON-LD structured data ready to paste into Squarespace (or migrate to custom)
- **MTM website** — needs entity-correct structured data (platform, not plumber)
- **Remaining from Grok:** encode Shield's risk rules as hard gates in VEOE execution layer
- **Play Store:** still pending (graphics, AAB, closed testing)
- **FC worker cache:** still blocking receipt pipeline + invite system

---

## Session 2026-06-15 — Tracking enforcement + Machine regime-gate spec

### Context
Resumed interrupted Machine work. Owner reported auto-tracking updates weren't reliable; asked for better enforcement. Also surfaced the 06-03 regime-gate report (DATA research + Rex P&L) and wanted Rex's data-driven input turned into a deploy-ready spec.

### Work done
- **Tracking enforcement (BUILD):** Diagnosed the old Stop/PreCompact "enforcement" as toothless `echo` reminders (instructional, not structural). Owner chose AUTO-WRITE-ONLY mode + trigger = commits/deploys/code-edits.
  - Built + tested `.10T/hooks/tracking_autolog.py` (all 5 cases pass): parses the session transcript, detects real work without a CURRENT.md update, writes a detailed block to `sessions/YYYY-MM-DD.md` + an idempotent `<!-- AUTOLOG -->` pointer in CURRENT.md. Fail-silent, never blocks.
  - **Owner action pending:** register on Stop + PreCompact in settings.json (snippet delivered; guarded file).
- **Judge Protocol — droplet exemption (Owner decision):** Removed RED-TIER 4 host-gating of 104.131.176.130 in `judge_protocol.py`. Droplet SSH (read+write) now allowed; global destructive backstops (rm -rf, DROP TABLE, DELETE w/o WHERE, git push main, --force) still fire even inside `ssh '...'`. Verified with 6 test commands.
- **Permission unblock:** Added `Write/Edit(.10T/hooks/**)` to settings.local.json (Owner applied). Two prior subagent attempts blocked by permission-load-at-startup lag; Owner authorized 10T to make the hook edits inline this once.
- **Machine regime-gate spec (Rex, RED-A — awaiting approval):** Rex SSH-pulled live droplet data (`/app/data/machine.db`, `/app/src/config.py`).

### Key findings (Rex)
- **Gate identity was WRONG in memory:** live filter is **ADX 25 / BTC-MOM 2.5%**, not "ADX 35 / MOM 5%." Memory corrected.
- Gate net-positive but leaky: PRE 87.8% win → POST 79.9% (break-even 78.3%). Real value = trend→swing routing (+$188.64), not the grid pause (missed ETP −$55 bleed).
- Proposal: directional VWAP-drift entry gate (NEW), ADX pause 25→22, recheck 4h→1h, keep BTC-MOM 2.5%. Est ~+$60–100/18d. Spec: `.tracking/specs/2026-06-15-machine-regime-gates.md`.
- Data bugs B1–B4 filed (fake equity_snapshots, 355k backtest dump in live grid_fills, broken instance rollups, NULL adx_4h).

### Files Created/Modified
- `.10T/hooks/tracking_autolog.py` (NEW)
- `.10T/hooks/judge_protocol.py` (droplet RED-TIER 4 removed, docstring fixed, renumbered)
- `.tracking/specs/2026-06-15-machine-regime-gates.md` (NEW, Rex)
- `settings.local.json` (hooks-folder Write/Edit permission, Owner-applied)
- memory `project_machine_regime_filter.md` (corrected to ADX 25 / 2.5%)
- `.tracking/CURRENT.md`, `.tracking/PROGRESS.md`

### Resume Point (2026-06-15)
- **Owner decisions needed:** (1) register tracking_autolog.py in settings.json; (2) is the Machine paper or LIVE?; (3) approve the regime-gate validation path (backtest → 72h paper → Shield/Onyx review → sign-off) before any deploy (RED-A).
- Machine data bugs B1–B4 open (B3 dump purge is destructive, Owner-only).

---

## Session 2026-06-15 → 06-18 — Tracking enforcement, Machine fix sweep, alpha reckoning

### Arc
Started with "auto-tracking isn't enforcing → set up better enforcement." Expanded into a full Machine investigation + fix sweep, then an alpha reckoning that uncovered the bot had traded REAL money for weeks.

### Tracking / Judge Protocol
- Diagnosed old Stop/PreCompact "enforcement" as toothless echo reminders. Owner chose AUTO-WRITE-ONLY + trigger=commits/deploys/code-edits.
- Built+tested `.10T/hooks/tracking_autolog.py` (5/5 cases): parses transcript, auto-logs to sessions/ + CURRENT.md AUTOLOG region when real work happens without a tracking update. Owner registered it in settings.json (Stop + PreCompact auto+manual).
- **Droplet host-gate REMOVED** from judge_protocol.py (Owner decision): SSH read+write to 104.131.176.130 allowed; global destructive backstops (rm -rf, DROP TABLE, DELETE w/o WHERE, git push main, --force) still fire even inside ssh. Verified.
- Permission friction: subagents can't SSH / can't write hooks (perm-load-at-startup lag). Owner authorized 10T to do droplet edits/deploys inline; pattern used all session.

### The Machine — investigation (Rex/DATA/Kit/Shield)
- **Gate identity corrected:** live filter is ADX 25 / BTC-MOM 2.5% (NOT "35/5%" from old memory). Verified from /app/src/config.py.
- **Original regime-gate proposal KILLED by backtest** (Rex): trailing-VWAP gate net-negative; ADX 22 near-zero (ZEC bled at real ADX 30-37 but bot's recorded ADX was NULL). Directional A′ promising but N=2.
- **Real root cause (Kit, refuted own bypass hypothesis):** the live ADX gate works, but (a) the `if _eng.levels` close-guard skipped closing trending grids when levels were wiped (0/51 confirmed-trending closes ever — the actual bleed), (b) hysteresis state resets on grid rebuild. DATA (real Coinbase candles) confirmed bleed ADX was 30-46 (gate should've fired) and 86% of distress losses were in real ADX≥25 trends.
- Verdict (Rex+Kit): DROP A′; fix the existing gate. A′ adds +$0 over a working re-check gate.

### Deploys (all PAPER at time of deploy, reviewed Kit + Shield, logged in AUDIT.md)
1. **Fix A (06-16):** removed `.levels` close-guard + 120s cooldown. Confirmed working live (ETP ranging→trending 03:02 → 4 cancels same tick; first confirmed-trending close ever).
2. **Monitor cron (06-16):** `/opt/the-machine/regime_monitor.sh` → emails gate-fired signal + metrics to christoph3reverding@gmail.com every 12h; self-expires 06-19. Accuracy-fixed to read the signal from LOGS (DB end_reason unreliable — 266 NULL ended_at).
3. **Transient-403 retry (06-16):** bounded retry (3x, 0.5+1.0s) on futures reads in coinbase_client.py. The "perps 403" was TRANSIENT, not an access bug (CDE endpoints healthy 10/10; INTX 404/unavailable).
4. **Enforcement wire + blind-detection (06-17):** Shield found `new_entries_blocked` was a DEAD wire (phantom margin_gate.block_new_entries) — meaning daily_loss_cap + max_positions blocks were ALSO dead. Fixed at `MarginGate.check_order()` chokepoint (gates grid+swing; closes bypass) + main.py set/clear + blind-detection (Option B / N=3 / ~90s → CRITICAL+deduped alert+block, no halt). C3 smoke test PASSED (grid+swing rejected when blocked, closes unblockable, recovery works). REVIVED daily_loss/max_positions enforcement.
5. **Data bugs (06-17/18):** B1 (equity snapshot true-equity, query corrected mid-deploy to include loss cycles → ~$1,586 not frozen $1,088); B2 (orphan prevention + startup cleanup, 276→2); B4 (forced-path adx logging, dormant); B3 (PURGED 355,682-row backtest dump, VACUUM 60.8→4.5MB, backup .predelete_bak). Retired orphan /app/src/safety_gates.py.

### Alpha reckoning (the pivot)
- Owner asked: is the bot 100% paper-working and the best we can make it / no known alpha? Honest answer: mechanically working+safe, but NOT optimized for alpha (we did safety/measurement/de-risking). Grid is structurally short-vol, thin/negative-EV after fees.
- DATA alpha research + reconciliation (`Owner's Inbox/machine-alpha-research-and-reconciliation.md`): grid's whole P&L collapses onto the fee assumption (gross +$400 vs −$547 at 0.30% taker vs +$210 at low fee). "Fees kill grid EV" ✅, "grids bleed in trends" ✅ (86% of losses in real trends), barbell/swing = best contributor (N=1).
- **MAJOR FINDING (06-18): the bot ran LIVE with real money for weeks.** Coinbase get_fills shows 1,736 real fills, $919.37 real commissions, TAKER ~0.15%/side, through 2026-06-03 (zero after 06-04 → paper since). Owner confirmed "it ran live weeks." Our DB has no fees; Coinbase is source of truth.
- Exported real fills + contract specs to `clawdbottrade/data/machine_pull_20260618/`. **DATA reconstructing TRUE net-of-fee P&L of the live weeks** (multiplier-correct, round-trip matched) → `Owner's Inbox/machine-real-pnl-reconstruction.md`. Early signal points to net-negative (taker fees match −$547 case).

### Memory updated
project_the_machine (rewritten current), project_machine_regime_filter (corrected ADX 25/2.5% + paper-confirmed), feedback_bot_check_table (lead with P&L), feedback_check_includes_email (NEW: "check"→also check Gmail), feedback_veoe_separate (NEW: VEOE in own sessions).

### Resume Point (2026-06-18)
- **WAITING on DATA** real-P&L reconstruction → the definitive "did the Machine make or lose real money over its live weeks." Then decide: cost-first alpha track (maker orders / fee tier — free, decisive lever) vs run-tiny vs pivot to trend sleeve.
- Threshold tuning data-gated (≥8–10 trend events). Monitor cron self-expires 06-19 (remove line after, optional).
- VEOE idle/over-filtering — separate session.

---

## Session 2026-06-18 (cont.) — Real-money reckoning → Alpha Search Engine (M1 done)

### The real-money reckoning
- **Discovery:** The Machine ran LIVE with real money for weeks (Owner-confirmed), not pure paper. Coinbase get_fills: 1,736 real fills, $919.37 real commissions, through 2026-06-03 (zero after 06-04 → paper since). Bot's `grid_fills` DB had NO fee column (gross) and lied/drifted from the exchange.
- **DATA real-P&L reconstruction** (FIFO from real fills, `Owner's Inbox/machine-real-pnl-reconstruction.md`): the grid **LOST −$548.25 net** over the live window (gross −$147.30 + commissions −$400.95; 81% maker; fees = 272% of gross). Per-instrument: ZEC −$217, ETP −$182, AVP −$114, SOL +$17 (only winner, ranging). The bot's DB had reported +$364 gross — lied by ~$912. **Grid confirmed net-negative even pre-fees; the live window was 100% trending (a short-vol grid had no ranging to harvest).** "Fat-vol survives" REFUTED (ZEC worst). Lesson: **read P&L only from the exchange ledger, never the bot DB.**

### Alpha hunt (data-driven, rigorous)
- **Trend-hypothesis test** (Rex, `Owner's Inbox/machine-trend-hypothesis-test.md`): QUALIFIED YES — in the same window the grid lost −$548, ADX-1d long/short made +$303 (vs buy&hold −$553). But only 1 of ~24 configs survived OOS beta-stripping: **ADX-1d-LS** (modest, defensive — beats holding in chop, underperforms in bull runs). The +$5,357 naive OOS was a ZEC-beta mirage. Everything 6h/EMA/Donchian whipsawed.
- **Regime-classifier shootout** (Rex harness, 10T ran it): auto-verdict said "BUILD THE BARBELL" — but interrogation killed it. Q1 (smarter gate) illusory: Composite ~flat (+$74), the "+$853 edge" was just ADX failing the small TEST window. Q2 (barbell) rested on a too-optimistic grid model.
- **Grid-model calibration** (10T ran): "92% calibrated" aggregate was OFFSETTING errors — model too harsh on ZEC (−$474 vs −$217), too generous on ETP (+$106 vs −$182). Barbell's grid-in-range edge rested entirely on the model's optimistic instrument → **barbell UNPROVEN.** Trend-only stays the candidate.

### Strategic decision → Alpha Search Engine
- Owner's insight: switch weapons by regime (no grid in unfavorable regimes); fine-tune trend-regime tools; use the model's compute advantage to SEARCH for edge.
- 10T calibration: the edge isn't prediction (markets are efficient/adversarial) — it's rigorous large-scale SEARCH + TEST that no human quant can match, paired with a formal overfitting framework (Deflated Sharpe / PBO / CPCV) so aggressive search doesn't self-deceive. "Multiply the talents the careful way."
- **Stage 1 engine spec authored** (Rex, `clawdbottrade/.tracking/specs/2026-06-18-alpha-search-engine-design.md`): 5 layers (data / signal library / vectorized backtest engine / rigor framework spine / orchestration), M1–M7 milestones, team ownership, kill criteria. **Grok colab = MANDATORY independent review at M5 (overfitting math) + survivor-gate (adversarial kill)** — decorrelated skepticism = multi-model holdout discipline. NOT for plumbing.
- **✅ M1 DONE** (`clawdbottrade/alpha_engine/cost_truth.py`, 10T ran): real CDE-futures fees-only round-trip = **25.16 bps (0.25%)**, per-instrument cost table → `data/cost_truth.json` (M2 imports it). (Module has a Windows `→` print bug — needs PYTHONUTF8 or a 1-char fix.)

### Bot history context
clawdbottrade repo: first commit 2026-02-22, 197 commits, ~4 months. Real trading on account since 2024-10-30 (early = manual). 4 months of build → −$548 real loss, but produced the lessons + data + rigor engine.

### Resume Point (2026-06-18, end)
- **NEXT = M2:** engine core + PER-INSTRUMENT reconcile gate (must reproduce real −$548 or STOP — hard gate). Kit builds, Rex/Sage on reconcile math, 10T runs. Then M3 (data breadth) → M4 (signals) → M5 (rigor harness + Grok review) → M6 (orchestration) → M7 (survivor → paper-validation).
- Grid is DEAD as real-money strategy. ADX-1d-LS = the one honest candidate (paper-validate only). No live money until paper-validated survivors.
- 6 open spec questions (reconcile tolerance, cost-gate k, holdout policy, capacity, feed lags, liquidation source) bind at M3–M5.
- Say "continue the engine" to resume at M2.

---

## Session 2026-06-15→17 — ERPNext access restored + QuickBooks-replacement plan locked + migration toolkit built

### ERPNext server access restored (infra)
- Mapped erp.manytalentsmore.com: **Dockerized Frappe on 134.199.198.83** (root SSH via existing id_ed25519), bench site **dev.localhost**, backend container **hcp_dev-backend-1**, apps frappe/erpnext/hcp_replacement. Fronted by host **Caddy** (443) → frontend nginx (8080).
- Both BW-stored API keys were **DEAD** (one pointed at the now-inactive old Frappe Cloud site, manytalentsmore.v.frappe.cloud, HTTP 503). Regenerated christoph3reverding@gmail.com's API secret on the server via `bench console` (generate_keys); **live-tested HTTP 200**; updated BW item 462bb0fd (+fixed stale URIs).
- Web login was out (no pw / reset failing). Restored **wit@manytalentsmore.com** (= Chris's user "Chris Everding") as System Manager; verified login 200.
- **Broken/unstyled UI** diagnosed: frontend nginx image is STALE vs backend app build — serves baked 2023 assets (hash SC6JD32M) from /usr/share/nginx/html/assets, so current hashed bundles (CJDA34UL) 404'd. **TEMP fix:** copied current built assets into nginx's asset root → 200. Breaks on app rebuild/container recreate; permanent fix = align frontend image / point nginx at shared sites volume. Ref: `reference_erpnext_server` memory.

### QuickBooks→ERPNext accounting migration — plan locked
- Scope: replace QBO across ALL Everding entities (AllTec, Providence, holding LLCs, trusts, 501c3) on one ERPNext; part of the $40-70K/yr subscription cull. Prior DATA research (05-31) + Forge recon: ERPNext ~80% ready — needs DECISIONS not research.
- **Live ERPNext inventory:** only **1 Company (AllTec)**, stock US COA (84 accts), ~no real books (GL 16, AP 0, bank 0); but it IS the HCP app backend (1,024 customers, 14,799 items). Confirms **build-from-baseline**, not reconcile-existing.
- **Decisions:** (1) **UI = native ERPNext declutter** (role-restricted accounting-only view), NOT custom UI. (2) **QB = QuickBooks ONLINE** → full Intuit REST API (auto-pull COA/trial-balance, build reconciler). (3) **Payroll = QBO Payroll today → move to Gusto** + Gusto→ERPNext JE bridge (ERPNext not the payroll engine — no US tax tables); QBO Payroll is QBO-coupled so payroll move **gates AllTec cutover**; Gusto full-service "for now" (fully-DIY considered, rejected — TFRP personal-liability risk / false economy). (4) **Order = Option 3 phased** — no-payroll entities first (**All Boats Rise LLC** = first pilot), AllTec last; cancel each entity's QBO sub as validated (incremental savings); naturally times AllTec/payroll cutover near year-end (clean W-2 boundary).

### Built this session
- **Accounting-only login** (Forge): `accounting@manytalentsmore.com`, role profile "Accounting Only" (Accounts Manager + Accounts User, **NO System Manager**), Module Profile blocks 33/34 modules (only Accounts visible). Temp pw set; Chris to set the standard formula pw before Maddie uses it. For Maddie's daily use; migration setup uses Chris's wit@ System Manager login.
- **Migration toolkit** (Forge): `C:\Users\chris\OneDrive\Documentos\qb_migration\` — dry-run-first Python: bw_client, qbo_client (OAuth2 pull), coa_mapper (130-entry QBO→ERPNext type table, flags unknowns), erpnext_loader (Company/COA/opening-balance JE — HARD STOP if debits≠credits), reconcile (QB-vs-ERPNext trial-balance diff), run_migration orchestrator, RUNBOOK.md. **8 assumptions flagged to validate on first live run** (most fragile: QBO TrialBalance JSON column order).
- **Erica email drafted** (Chris's Gmail Drafts → `eeweller@yahoo.com`): her ONLY task = create Intuit Developer app + connect All Boats Rise via OAuth Playground + store 2 cred sets in Chris's BW (exact item names/types/fields specified in the email). She does NOT touch ERPNext.

### Side thread — XFRA opportunity (parked)
- NVIDIA/Span home-data-center play for Providence+AllTec: research + outreach letter + capability sheet in `Documentos\XFRA-Opportunity\`. Gates 1 (LA utility law) & 3 (AllTec full LSLBC license stack self-performs) GREEN; Gate 2 (Span landlord enrollment) timing-only ~2027. Parked. Memory: project_xfra_providence.

### Division of labor / open inputs
- **Erica = QuickBooks credential handoff only. Chris (via 10T) = all ERPNext work.**
- Parent group company = **"E Enterprise"** (PLACEHOLDER, family decision pending) — pass as `--group-company`.
- Set the standard formula password on accounting@ before Maddie uses it.

### Resume Point (2026-06-17, end)
- **EVERYTHING now GATED on Erica delivering the 2 QBO keys to Bitwarden** — send the drafted email (Drafts; delete the earlier placeholder draft addressed to self).
- When keys land: run `qb_migration` **dry-run** → validate the 8 assumptions (esp. TrialBalance shape) → pull COA+trial-balance → create All Boats Rise under "E Enterprise" → load COA → post opening balances (must tie to zero) → reconcile → **ARCHIVE QB data + short buffer → THEN cancel ABR's QBO sub** (don't rush the cancel; first live run).
- ABR migration plausibly same-day once keys arrive (tiny no-payroll books); cancellation = days not weeks, after verification.
- Say "continue accounting" or "All Boats" to resume.

---

## 2026-06-17 — VEOE F2 Re-cut + Proper Baked Image

### Context
F2 exit engine was built and tested (10/10) but existed only as an overlay image (`veoe:v5-candidate`) built `FROM veoe:v4b-0730638` + COPY — baked-image model forbids this because the image's BUILD_SHA label (0730638) wouldn't match the actual code version. Required re-cutting with proper git provenance.

### What was done (Kit)
1. **F2 commit on canonical branch.** Copied `exit_manager.py` and `tradier_exit_manager.py` from `/app/veoe-v5-build/src/` into canonical repo `/app/veoe/` (branch `live-snapshot-2026-06-16`). Also committed `tests/test_f2.py` and `scripts/f2_tape_replay.py`. Commit: `4e437aa830a839969bb4454e9a7413fbf1e5c54a` — feat(veoe/F2): exit engine — reachable hard_stop, DTE exit, scale-out, marketable-limit ladder. Chain: e7e4171(F0) → d59e417(F3) → e6a0b1c(F3-wire) → **4e437aa(F2)**.
2. **Proper baked image.** Built `veoe:v5-4e437aa` using `Dockerfile.baked` from the committed tree with `BUILD_SHA=4e437aa830a839969bb4454e9a7413fbf1e5c54a`. 3-way provenance verified: LABEL=FILE=ENV = `4e437aa830...` (NOT 0730638).
3. **Test results.** Full suite on new image: 160 pass, 10 fail. The 10 failures are pre-existing on `v4b-0730638` baseline (trail threshold tests, portfolio sizing, scorer screening — test spec drift, not code bugs). **Zero F2 regressions introduced.** F2 suite (10/10): ALL PASS.
4. **Tape replay (honest methodology).** 36 closed real trades with `peak_pnl_pct` and `exit_pnl_pct` populated in notes. Both fields are **decimal fractions per-option-premium basis** (same denominator). Weighted capture = sum(realized)/sum(peak). Simulation applies 3 rules: (a) hard_stop cap at -35% for adverse_fill/trail_stop losers, (b) scale-out half at +38% when peak≥40%, (c) tighter trail floor (peak-0.13) for sub-30% peaks. Result: v4b=43.4%, v5=52.6%, delta=+9.2pp. **Caveat:** simulation rules are estimates — independent recomputation with different assumptions spans 13-43% range. The primary justification for F2 is the reachable hard_stop capital-protection fix, not the headline capture number.
5. **Cleanup.** Deleted `veoe:v5-candidate` overlay image. Deleted `/app/veoe-v5-build/` workspace. Neither can be accidentally deployed.

### State at close
- Live containers still on `veoe:v4b-0730638` — no cutover performed.
- Candidate: `veoe:v5-4e437aa` on droplet, ready for 10T cutover on Owner go.
- Rollback: `veoe:v4b-0730638` (current live).

---

## 2026-06-19 — Machine Alpha Engine M5 corrected + structural scored + Grok review staged

### Context
M5 rigor harness had run (verdict: no signal survives) but with two open items: (1) resid_SR printed 0.000 for every signal — flagged as a likely harness bug; (2) the structural_funding_fade signal was SKIPPED because the deep BTC funding feed hadn't been ingested. Owner chose path "Grok review + score structural." Deep funding ingested prior turn (`funding_btc`: 3,223 rows, 2023-07..2026-06, BTC-only ~3y).

### What was done
1. **resid_SR bug — root cause + fix (Rex authored, 10T ran).** The harness reported `Sharpe(eps)` where `eps` = bare OLS residual. With an intercept, OLS normal equations force `sum(eps)=0` exactly → `mean(eps)=0` → `Sharpe(eps)=0.000` for EVERY signal regardless of skill (a placeholder, not a measurement). Fix: report Sharpe of the **alpha-only stream** `alpha+eps == y−β·r_bh` (strategy return with only the beta component removed; mean = exactly alpha). `rigor.py` `beta_strip()` both branches. Real numbers now (trend 0.48, regime 0.28, mean-rev −0.14, structural −0.65). Verdict UNCHANGED — every signal fails on DSR/holdout/PBO independently of resid_SR.
2. **Structural signal wired + scored (Rex authored, 10T ran).** `evaluate_signal()` gained `feed_by_inst` → binds the deep `funding_btc` feed to the strategy via `functools.partial`; point-in-time enforced inside the signal (`merge_asof backward` on `known_at`). Scored BTC-only through full ladder. DSR `--trials` now counts all 4.
3. **Corrected M5 re-run — VERDICT: NO SIGNAL SURVIVES (all 4).**
   - trend_ts_momentum: PASS G1/G2/G3 (net +$6,699; resid_SR 0.48 real alpha beyond beta; 100% folds+) → FAIL G4 (DSR 0.47<0.95, PBO 0.12) + G5 (sealed holdout net −$88). SOL +$6,651 carries the whole result (concentration risk).
   - regime_classifier: resid_SR 0.28 (<0.30 floor), DSR 0.30, holdout −$154 → FAIL.
   - mean_reversion_zscore: net −$354, PBO 0.94 (overfit) → FAIL.
   - structural_funding_fade: WORSE THAN NULL — net −$230, alpha_ann −0.055, resid_SR −0.65, DSR 0.005, fails every gate. Onyx funding-fade premium not present on BTC deep funding (arb'd into the basis). Single-instrument ~3y caveat noted.
   - JSON: `clawdbottrade/data/m5_rigor_verdicts.json`.
4. **Grok independent-review package STAGED:** `Owner's Inbox/machine-m5-grok-review-package.md`. Self-contained + skeptic-framed: asks Grok to attack the "no edge" verdict and rule on the 3 flagged constructs (resid_SR fix correctness, V=1/n DSR proxy conservatism, PBO C=#instruments scope), plus look-ahead/survivorship/cost-fallback/SOL-concentration checks, and give an independent M6-widen vs shelve read.

### State at close
- M1–M5 complete; engine validated; honest answer = **no durable beta-stripped edge in this signal set on our data.**
- Mandatory Grok review pending (run the colab from the staged package).
- **Decision gate after Grok:** M6 (widen — more signals/feeds, full config sweeps with proper PBO) vs shelve directional (fall back to the free cost-first lever: maker-only + fee-tier on a tiny grid). Owner call.
- Say "continue alpha" or "Machine" to resume.

---

## 2026-06-19 — CURRENT.md trim (detail archived here; CURRENT.md slimmed to its ≤20-line cap)

The Machine status narrative below was moved out of `CURRENT.md` (it had grown to ~13.9 KB / ~3,500 tok, violating the "Max 20 lines" rule and bloating every agent cold-start, incl. Grok). Preserved verbatim:

### Machine — full status snapshot (as of 06-19)
The Machine: **VERDICT IN — grid LOST −$548.25 net real money** over its live weeks (gross −$147 + fees −$401; FIFO from Coinbase fills). Grid confirmed net-negative & DEAD. **Trend test (Rex): QUALIFIED YES** — ADX-1d long/short made +$303 where grid lost −$548 same window; but only 1 of 24 configs survived OOS beta-strip (modest/defensive edge, not a printer). Candidate = ADX-1d-LS, paper-validate only. **Regime shootout (06-18):** auto-verdict said "BUILD BARBELL" but interrogation killed it — Q1 gate-improvement illusory (Composite ~flat, ADX just failed the small TEST), Q2 barbell rests on a too-optimistic grid model. **Grid-model calibration:** "92% calibrated" is OFFSETTING errors (ZEC −$474 vs −$217 too harsh; ETP +$106 vs −$182 too generous) — barbell UNPROVEN, trend-only stays the candidate. **Stage 1 Alpha Search Engine** (rigor: sealed holdout, Deflated-Sharpe/PBO, beta-strip, PER-INSTRUMENT reconcile-to-real-fills; Grok colab = mandatory independent review at M5 + survivor-gate). Spec: `clawdbottrade/.tracking/specs/2026-06-18-alpha-search-engine-design.md`. Code: `clawdbottrade/alpha_engine/`. **M1** (cost_truth.py): real CDE-futures fees-only round-trip = 25.16 bps. **M2** (backtest.py+reconcile.py): Check A PASS — engine FIFO reproduces real −$548.25 EXACT per-instrument (±$0.45). Engine core VALIDATED → trend/daily backtests trustworthy. Check B (candle grid model) out-of-tolerance as expected (grids can't be candle-backtested — moot, grid dead). **M3** (data_layer.py, store v=f123e459): 8 instruments 1h/6h/1d + 5 feeds (F&G/SOPR/funding/OI/basis), point-in-time. Open: liquidations no free source, Binance geo-blocked, deep-BTC-funding 429. **M4** (signals.py): 4 signals (regime_classifier, trend_ts_momentum, mean_reversion_zscore, structural_funding_fade) each w/ economic WHY, no look-ahead. **M5 + CORRECTED (rigor.py) — NO SIGNAL SURVIVES (all 4).** resid_SR=0.000 BUG FIXED (alpha-only stream y−β·r_bh). trend = closest: PASS G1/G2/G3 (net +$6,699, resid_SR 0.48, 100% folds+) but DIES G4 (DSR 0.47<0.95) + G5 (holdout −$88) — SOL +$6,651 carries it. regime resid_SR 0.28 (<0.30), holdout −$154. mean-rev PBO 0.94. structural_funding_fade WORSE THAN NULL (Onyx premium arb'd out). **GROK INDEPENDENT REVIEW (06-19) — CONFIRMS "NO SIGNAL SURVIVES."** 3 decorrelated reads agree. 25bps re-run: trend holdout −$88→−$249. SOL-concentration CONFIRMED (trend +$5,339 is SOL +$5,888 alone). Pkg: `Owner's Inbox/machine-m5-grok-review-package.md`. **COST-FIRST VERDICT (06-19) — DECISIVE: cost is NOT the bug, the grid is.** grid lost −$147.30 GROSS (before fees); even at ZERO fees negative → no break-even maker % exists. 100% maker = −$8 (flat fee, no maker/taker split); volume tiers DON'T EXIST on CDE futures (flat $/contract + $0.20/side floor, liq 80bps). Scripts: `alpha_engine/cost_lever.py`+`run_cost_lever.py`, `data/cost_lever_result.json`. **Both big questions converge: directional = no durable edge (M5+Grok); grid = gross-negative (cost-first). NO deployable edge in anything tested.** **SCOUTS (2 agents) → `Owner's Inbox/machine-strategy-scout-catalog.md`** (both ranked trend-ensemble, cross-sectional RV, seasonality up; rejected cash-and-carry, HFT, grid). **M6 DONE (Rex, 06-19) — ALL 3 FAIL. 7 directional signals now dead.** (1) trend_donchian_ensemble FAIL — cleanest in-sample (resid_SR 0.86) but DSR 0.615<0.95 + holdout −$425. (2) xs_relative_value (PANEL) FAIL — dollar-neutral but PBO 0.81 + holdout −$336. (3) funding_oi_divergence FAIL-but-UNTESTABLE — OKX funding too shallow (starts 2026-03-16), overlap inside sealed holdout, never fired. DATA on-chain netflow A4 NOT built. Result: `data/m5_new_signals_verdicts.json`. alpha_engine/ untracked (uncommitted). **DECISION GATE → if all fail: shelve directional, redeploy to AllTec/MTM/ERPNext/QuickBooks-cull. 2 of 3 clean kills; funding_oi_divergence the exception (untestable, not disproven) — option to ingest deep funding/OI feed first.** Bot history: ~4mo / 197 commits, lost −$548 real.

### Machine — operational detail
- **RAN LIVE WITH REAL MONEY.** Coinbase: 1,736 real fills, $919.37 real commissions (TAKER ~0.15%/side), through 2026-06-03; zero fills after 06-04 → PAPER since. `grid_fills` DB has NO fee column (cycle_pnl is GROSS); Coinbase is fee source of truth.
- **ALPHA VERDICT (06-18, DATA):** Grid LOST −$548.25 net (gross −$147 + fees −$401; 81% maker, fees=272% of gross). Per-instr: ZEC −$217, ETP −$182, AVP −$114; SOL +$17 only winner. 100% of live window trending (ADX≥25). +$188 swing was PAPER. Reports: `Owner's Inbox/machine-real-pnl-reconstruction.md` + `machine-alpha-research-and-reconciliation.md`.
- **Fixes deployed to paper 06-15→18 (Kit+Shield reviewed):** Fix A (regime close-guard removal + 120s cooldown); enforcement-wire (`new_entries_blocked` via `check_order` chokepoint — revived dead daily_loss/max_positions gates); blind-detection (N=3); transient-403 retry hardening; data bugs B1/B2/B4; B3 dump purge (DB 60→4.5MB). Fix B (state persistence) deferred.
- **Droplet 104.131.176.130, container the-machine.** Live code `/app/src/` authoritative (local `the-machine-rewrite/` STALE). Measure P&L from `grid_fills`+`swing_trades`, NEVER `equity_snapshots`. Monitor cron self-expired 06-19.

---

## 2026-06-19 — Alpha Search Campaign (19-agent workflow) — 0 survivors, 15/15 dead
Chris pushed to keep hunting ("gotta be a way, more tests more tries more research"). Launched a 19-agent multi-agent workflow (`wf_a72e4fa8-1ba`, ~1.47M tokens, 51min) that researched + rigor-tested 12 new avenues on top of the 7 directional signals + grid already dead.

**Result: 6 testable avenues ALL FAILED the 5-gate ladder; 6 needs-data (no verdict); 0 graduates, 0 confirmed survivors. Score now 15/15 dead.**

Core finding — **"the edge WAS the beta":** beta-neutral construction repeatedly succeeded (β≈0) but revealed ~zero residual alpha underneath. Everything that conditions on price direction is long-crypto beta in a 5y bull window; the rigor bar correctly refuses to pay for it. 5 of 6 died on sealed holdout (G5) and/or DSR deflation (G4). Near-misses: seasonality day-of-week (residSR 0.69 but DSR 0.042 after honest 174-bucket multiple-testing); trend_voltarget_persistence (residSR 1.02 in-sample but SOL 53% concentration + holdout −$50).

Kills: seasonality, vol_regime_breakout, stat_arb_pairs, trend_voltarget_persistence, decorrelated_ensemble, lit_practitioner xs-trend-rotation — all overfit / holdout-reversal / beta-in-disguise.

**The real frontier the campaign surfaced = PREMIUM HARVEST (untested, data not in store):**
1. `options_vrp` — crypto variance-risk-premium, prior 42% (highest in whole search), cleanest "premium not prediction," the SAME edge VEOE harvests in equity options. Unblocked by ONE free no-key fetcher: Deribit DVOL public API (get_volatility_index_data).
2/2/2. Bybit/Binance funding backfill (one fetcher) unblocks xs_carry + funding_carry_neutral + lit_academic_survivors. BUT literature itself reports crypto carry Sharpe went NEGATIVE in 2025 = exactly our holdout window → expect carry to die there (cheap to confirm).
5. deep_funding_oi (needs keyed OI source — Coinglass/CoinAPI). 6. onchain_netflow (prior 10%, lowest).

**10T recommendation:** shelve directional (15/15 = stop mining direction, neg-EV labor); pivot to premium — ingest Deribit DVOL + test options_vrp first, Bybit funding in parallel. Stays PAPER; even a VRP graduation = paper Deribit test only, never live capital. The discipline that killed 15 false edges is the asset — negatives saved real money.

Report: Owner's Inbox/machine-alpha-search-campaign-2026-06-19.md. Candidates: clawdbottrade/alpha_engine/candidates/. Verdicts: clawdbottrade/data/campaign/. Open Owner decision: run the premium-harvest campaign next, or shelve and redeploy.

---

## 2026-06-19 — Premium-Harvest Campaign — VRP + carry tested, 0 survivors, but failing for the RIGHT reasons
Chris said "yes" to pivot from prediction to premium harvest (paid to bear risk = durable). Ran workflow `wf_2a0998ec-df1`: ingested real data first (Deribit DVOL implied vol + deep funding), then rigor-tested VRP + 2 carry strategies. (Mid-run auth 401 killed 2 agents; resumed from cache, completed clean.)

**Result: 3 premiums tested, 0 graduate under realistic cost. Cumulative: 15 directional + 3 premium = 18 tested, 0 deployable.**

- **VRP (options_vrp)** — the headline, same edge VEOE harvests. Economically REAL: beta 0.006 (clean, NOT beta-in-disguise), PBO 0.00 (NOT overfit-by-search), residual Sharpe 2.0. PASSES G1/G2/G3. But FAILS G4 (DSR 0.00 — short-gamma fat tail, skew −5.04, kurt 40.1) + G5 (sealed holdout −$1.10). A trailing-RV variant nominally graduated (DSR 0.956) but REJECTED as a smoothing artifact (hides the kurt-40 tail that is the whole risk). DECISIVE: mandatory realistic re-run at −4 vol-pt haircut (Deribit wing bid/ask + hedge slippage) → every stream flips holdout −$83/−$86. The entire edge is the mid-implied premium the bid/ask spread eats.
- **funding_carry_neutral** — delta-neutral perp funding coupon. THE FIRST THING IN THE WHOLE ARC TO PASS ALL 5 GATES (at favorable 10bps: net $1,580, beta 0.001, residSR 8.16, holdout +$61). Then KILLED by the mandatory 30bps realistic re-run (DSR→0, holdout −$135). Coupon real + genuinely beta-neutral but too thin to survive both-leg bid/ask. Honest FAIL.
- **xs_carry** — cross-sectional funding L/S. Negative premium in-sample (net −$2,889, residSR −0.44). Dead, and name-concentrated (SOL vs LTC dominate) so even the sign is fragile.

**KEY DIAGNOSTIC SHIFT:** the first 15 died of FAKE edges (beta-in-disguise, holdout-reversal). These 3 died of REAL premiums eaten by fat tails (VRP) + execution cost (carry) — clean beta, zero PBO. Signal discovery is no longer the bottleneck; THE SPREAD IS. No amount of more signal-hunting fixes a cost-bound edge.

**New permanent infrastructure (valuable regardless of verdicts):** `dvol_btc`/`dvol_eth` feeds (Deribit DVOL, 5.25y daily implied vol, ~1,914 rows each) + `funding_deep` (Gate.io perp funding, 6.6y, 6 instruments, 41,250 rows @ 8h, 19% negative = real carry data). Both point-in-time honest, load via DataLayer.load_feed, dedupe on re-ingest. Geo note: Bybit (403) + Binance (451) hard-blocked from US IP; Gate.io + Deribit are the reliable US-accessible public sources.

**10T recommendation:** ONE honest loose end before shelving — both carry tests scored PRICE-ONLY, omitting the funding cash-flow that IS the carry premium. Rec #1 (cheap, high-info, decisive): re-run funding_carry_neutral CREDITING actual funding coupons from funding_deep vs true Coinbase CDE round-trip (~24-46bps) + spot-leg borrow. It already passed price-only @10bps; this is the one verdict we know is incomplete. If it survives WITH the coupon AND honest cost → first real candidate → PAPER only, never live. If not → directional + premium both exhausted; shelve and redeploy to AllTec/MTM/ERPNext/QuickBooks-cull. The deep feeds make a future re-test cheap. The Machine stays PAPER regardless. Report: Owner's Inbox/machine-premium-harvest-campaign-2026-06-19.md.

---

## 2026-06-20 — ALPHA SEARCH CLOSED: carry coupon re-test fails, 19/19, SHELVED
Owner chose the one cheap decisive test before shelving. Rex re-ran funding_carry_neutral with honest economics.

**Result: DIES. Joins the other 18. Alpha search closed at 19 strategies tested, 0 deployable.**

Key findings:
- The funding COUPON was already credited in the prior run (that was the original engine-gap fix). What flattered it was the two OMITTED terms: spot-leg borrow + realistic cost. With both added, every variant FAILS at 30bps AND 46bps. DSR=0.00 at every cost/borrow point — the honest 20-trial deflation kills it before borrow even bites. Holdout negative everywhere (−$213 to −$1,091).
- Reconciliation proof of correctness: harness at 30bps/zero-borrow reproduces the prior 30bps verdict to the dollar (net +$1,112 vs +$1,111.61; holdout −$135 vs −$135.34).
- carry_on_positive net$ by borrow: +1,112 (0%) → +484 (3%) → −144 (6%) → −981 (10%). Holdout negative at every level including zero.
- SOL is the structural killer: thin/negative Gate.io funding (mean −0.12 bps/8h, 29% negative) → −$324 drag the positive-carry names (DOGE/LINK/LTC) can't cover after borrow + rebalance cost.
- DECISIVE CAVEAT (moves verdict toward MORE death): funding_deep is Gate.io PERP 8h funding, but the live Machine trades Coinbase CDE DATED futures which pay NO 8h funding coupon — they carry a basis converging to expiry, structurally thinner. The entire gross coupon measured is a perp proxy that doesn't even apply to our instrument. No version of this caveat rescues the strategy.

**FINAL TALLY: 15 directional + 4 premium = 19 strategies tested across ~5 months, 0 survive honest rigor.** Clean diagnostic arc: the first 15 died of FAKE edges (beta-in-disguise, holdout-reversal); the last 4 died of REAL premiums eaten by execution cost / fat tails (clean beta, zero PBO). Signal discovery was never the bottleneck — the cost structure is. No retail-accessible directional OR premium edge clears the spread we'd actually pay at this size.

**DECISION (pre-committed path fired): SHELVE the alpha search. Redeploy effort to AllTec / MTM / ERPNext / QuickBooks-cull where ROI is proven.** What stays on disk and makes a future revisit cheap: validated FIFO rigor engine (reproduces real −$548.25 exact), 5-gate ladder (beta-strip/DSR/PBO/sealed-holdout), and two permanent multi-year feeds (dvol_btc/dvol_eth implied vol 5.25y; funding_deep 6.6y 6-instrument). Revisit triggers: a lower-cost execution venue, a real Coinbase fee-tier, or a narrower-wing/near-ATM VRP construction that leaves less premium in the expensive wings. The Machine stays PAPER and idle. The bot lost −$548 real over its ~4mo life; the engine's 19 honest negatives saved real money vs funding mirages. Verdict file: data/campaign/funding_carry_neutral_coupon_verdict.json. Closing reports: machine-alpha-search-campaign + machine-premium-harvest-campaign (Owner's Inbox).

---

## 2026-06-20 — Cheap-venue carry retest (filament #20) — most informative NO; mechanism proven, alpha search genuinely finished
Owner: "never give up, Edison style — excess compute, value in the no's." Re-tested funding carry on low-fee PERP venues where funding is real and fees are near-zero (the one edge proven cost-bound, not signal-bound). Workflow `wf_4b6a5f53-e9d`. Ingested Hyperliquid funding (~3.1y, feed funding_hl) + real Gate.io/HL fee schedules.

**Gate.io perp (consistent venue) — CLEAN FAIL, and corrected our own error.** The earlier "passed all 5 gates @10bps" was a VENUE ARTIFACT: it charged Coinbase CDE fees (24-46bps) on Gate.io funding. Scored honestly — Gate.io funding WITH Gate.io's real 4bps maker round-trip — carry_on_positive now fails G3 (walk-forward), G4 (DSR 0.046), G5 (holdout −$168.54, NEGATIVE). Every directional variant's 2025-26 holdout is negative (−$169 to −$268). carry_thresh comes closest (passes G1/G2/G3/G5 at 2bps) but fails G4 with PBO 0.75 (overfit) and its +$0.83 holdout is noise that flips negative at taker fees. Only all-5-gate pass is at an UNATTAINABLE VIP16 negative-fee tier — flagged + excluded. SOL the structural drain (31% negative-funding bars, standalone coupon −$21.91). 2025 funding decay: CONFIRMED.

**Hyperliquid — a FRAGILE graduation that did NOT survive adversarial review (confirmed survivors = 0).** carry_on_positive (w=3) touched all 5 gates (net $2,094, residSR 11.48, DSR 1.0, PBO 0.12, holdout +$28.74) BUT only at the −0.3bps maker-REBATE tier (top maker-volume tier, realistically unattainable for a retail/VIP0 account). At the realistic 1.5bps maker tier it FAILS G5 (holdout −$54); at taker −$184. Knife-edge: one fee-tier notch flips the best window from w=3 to w=30 and the holdout negative. Thin sample (HL only ~3.1y → 227 holdout bars; DSR=1.0 is from high in-sample residSR on a short series — not trustworthy). The 3 adversarial skeptics refuted it. Its own verdict: "FRAGILE — PAPER ONLY, never live."

**What this settles (the payoff of pushing):**
1. Cost WAS genuinely the binding wall — carry survives only at sub-zero effective fees. The diagnosis was right, not hand-waving.
2. Behind the wall, the premium is DECAYING in real time — search-window funding coupon ~+4.5-5.7bps/bar collapsed to ~+1.2bps/bar in the 2025-11..2026-06 holdout; SOL went outright negative; the parameter-free null (static_short_perp) is net-NEGATIVE in the holdout across ALL fee tiers including rebate. Even winning the fee battle, the edge is being arbitraged away.

**FINAL TALLY: 20 strategies tested, 0 deployable.** This is the cleanest shelve signal yet — not quitting, FINISHING: the only fee tier where carry lives is unreachable, and the premium is eroding regardless. The honest conclusion the Edison push earned: there is no retail-accessible automated edge — directional or premium — that clears the cost we'd actually pay AND persists. Decision stands: SHELVE; redeploy to AllTec/MTM/ERPNext/QuickBooks-cull. Engine + feeds (dvol_*, funding_deep, funding_hl) stay on disk; a future revisit (a real maker-rebate market-making variant, or a non-decaying premium) is cheap. Machine PAPER + idle. Verdicts: data/campaign/carry_gateio_perp_verdict.json + carry_hyperliquid_verdict.json. Report: Owner's Inbox/machine-carry-cheap-venue-2026-06-20.md.

---

## 2026-06-21 — MTM/AllTec mobile emulator testing UNBLOCKED (Radon abandoned on Windows)

Owner closed VS Code windows trying to get the MTM app running in an emulator; Radon kept failing with a "C:\c:\..." path error. Diagnosed and fixed:

- **Radon IDE is a dead end on Windows.** v1.3.0 has the doubled-drive-letter bug (#1274): it builds `C:\c:\temp\hcp_build\mobile` and throws ENOENT during *extension activation*, so it never registers "Open IDE Panel" (only the broken-state "Diagnostics" command shows). Confirmed there is **no newer Windows build** — Radon v1.4–1.18 are macOS-only (`@1.17.0` install = "not found"; `--pre-release` falls back to 1.3.0). Not fixable by updating. Also uninstalled **EasyCode AI** extension (crashing the shared extension host on port 49201; redundant with Claude Code).
- **Working path = standard Expo Go on the Pixel_8 AVD.** Boot emulator → `npx expo start --android --go` from `C:/temp/hcp_build/mobile`. App bundles in ~24s (1110 modules) and the **"Many Talents Manager" login screen renders** (verified via `adb exec-out screencap`). Stripe (`@stripe/stripe-react-native`) doesn't crash Expo Go — lazy / payments flag OFF. `expo-notifications` logs a harmless SDK-53 push warning. Left Metro running in hot-reload (non-CI) mode.
- Procedure docs updated: memory `reference_radon_testing.md` (rewritten), `MEMORY.md` index, and `SOLUTIONS_LOG.md` (new top entry). SDK 54, RN 0.81.5, managed (no `android/`).

---

## 2026-06-21 — AllTec full-week simulation & friction review (production app)

Ran a complete week of AllTec ops through the REAL stack as personas Zach (office/intake) + Adam (tech+dispatcher+invoice-reviewer). 9 ZZSIM intakes created via the real `create_job` office endpoint → dispatched to techs → worked → reviewed → invoiced → field-collected → one sent back with notes → estimate created+sent. All ZZSIM data deleted at end (verified 0 residue); live data/pricebook untouched; 2 demo emails (estimate + paid receipt) confirmed delivered to Owner inbox.

**Method milestone:** installed the actual **production AAB v2.2.4** on the Pixel_8 emulator (downloaded from EAS, converted AAB→universal APK via bundletool; the AAB ships x86_64 so it runs on the emulator) — Adam's login verified on the genuine build (answers "can Adam log in tomorrow": yes). Deep steps driven via the same API endpoints the buttons call (RN release build exposes no accessibility tree → blind tap-automation unreliable).

**Key findings (full report: `Owner's Inbox/2026-06-21-alltec-week-simulation-review.md`):**
- 🔴 Cash/custom part (chandelier) BROKEN twice: `add_custom_material` hardcodes nonexistent UOM "Ea" (fix→"Nos"); and custom material has no income account → invoice fails. Highest-impact fix.
- 🔴 Web intake sends `is_vacant`/`keycode` but backend `create_job` rejects them → vacant-property intake 500s.
- 🟠 Estimate/receipt PDFs render with unsupported CSS (box-shadow, var(), 8-digit hex, object-fit).
- 🟠 Tech collect: office `mark_paid` PermissionErrors for techs; field `record_payment` works (Adam collected $155 cash).
- 🟢 Working: production login, dispatch (assign_tech → renders on tech app, tenant 2nd-phone shows), part search+pricing, approve_for_invoice, invoice+collect, send-back-with-notes, customer emails.
- Also purged last Frappe Cloud ref from web (`next.config.ts`→droplet).

Background still up: Pixel_8 emulator + production app (Adam logged in — his phone may need re-login), Metro, bw serve (unlocked). Not yet live-driven: receipt OCR (Coburn's), web drag-drop scheduling (code-verified real).

## 2026-06-21 — AllTec sim fixes (same session)

- **✅ F1 chandelier/cash part FIXED + deployed live + verified.** Was 4 bugs in `add_custom_material` (UOM Ea→Nos; source Custom→Other; missing income account → company default via item_defaults; Item creation elevated to Administrator so nested Item Price insert works for techs). Test: Adam adds $385 chandelier → invoices $385. Live on droplet (`/opt/hcp_replacement_app/.../api/materials.py`, workers restarted), mirrored to `C:/temp/hcp_build/...`. The local OneDrive AllTecPro/hcp_replacement path differs (not mirrored there).
- **F3 PDF CSS — downgraded to benign.** Offending CSS (box-shadow/var/#hex) is Frappe core print bundle, not our templates; WeasyPrint warns but renders; emails sent fine. Only our `object-fit:cover` (web css L115). No clean app fix; eyeball one PDF if concerned.
- **F12 OCR re-diagnosed — NOT config.** Vision IS configured+routed correctly (valid SA JSON, enable_ocr=1, google-auth libs present, no tesseract fallback). Real cause = rotated/angled receipt photo scrambles Vision reading order → parser fails. Fix = image deskew/auto-orient + parser robustness (dedicated task).
- **F2 vacant/keycode — needs decision.** HCP Job has no is_vacant/keycode fields → add doctype fields (live migration) OR strip client-side in web.
- Remaining: F4 collect-permission (decision), F5 dated≠Scheduled (decision), F14 schedule time-of-day, F15 endpoint dedup, F11 testIDs. Report: `Owner's Inbox/2026-06-21-alltec-week-simulation-review.md`.

## 2026-06-21 — Fixes pushed + Monday login readiness

- **All sim fixes PUSHED to git + live:** backend `manyTalents/hcp_replacement@596a7cd` (chandelier/custom-part, vacant-intake is_vacant/keycode, OCR orientation, Coburn parser); web `manyTalents/manytalents-more@31007d3` (next.config FC→droplet purge). All already deployed live on droplet via worker restarts. Web fix goes live on next Vercel auto-deploy (confirm Vercel env `NEXT_PUBLIC_FRAPPE_SITE`=droplet, not FC).
- **Monday logins verified (real app endpoint):** Office/Zach = `alltecplumbing@gmail.com` / `AllTecOffice2026!` (password SET + saved to BW + verified; AllTec Office acct, System Mgr + Accounts Mgr). Adam = `adam@manytalentsmore.com` / `Adam123!` (verified). Backup office: `wit@manytalentsmore.com` / `ptrW1N8WcxrzwGYR!aQ7`.
- NOTE: is_vacant/keycode are Custom Fields in the droplet DB (live); would need re-creation on a fresh-site deploy (not in app code).

## 2026-06-22 (eve) — MTM Showcase video recovered + finished

- **Crash recovery:** A features-walkthrough video for ManyTalents Manager (for testers Zach+Adam) was in progress when the PC crashed. Found the lost project — a 15-scene Remotion build — sitting uncommitted in a temp Claude scratchpad (`...5d4c20b5.../scratchpad/mtm-showcase`). **Preserved to `Documentos\mtm-showcase`, git-init'd + committed** before it could be cleaned up. (Note: the existing `mtm-video` project is the separate 10T/AI-team explainer, NOT this.)
- **Fidelity audit (Owner rule: "actual markup from code"):** dispatched code-audit agents to diff every scene vs the real web (`ManyTalentsMore/manager`) + mobile (`AllTecPro/hcp_replacement/mobile`) source. Fixed ~15 inaccuracies — Login (fake tab bar→real email/QR + SHOW/Forgot), Home (Hey greeting + missing Schedule tile), My Jobs (real trade icons 💧⚡❄️), Job Detail (ACCEPT/Notes/Materials Total), Scanner (real save text + job# context), Inventory (ACCEPT ALL PULLED (n)), Dashboard/Invoices (real AR buckets 0-30…91+), Pricebook (real pricing-source badges).
- **Owner decisions:** web nav → **full 10-tab platform**; roadmap (Scene 14) → **fixed to genuinely-future only** (Equipment, GPS auto-clock-out, Route Optimization, Built-In Accounting; dropped already-built Estimates/Service Plans/Events) → **re-recorded the Scene-14 VO** (ElevenLabs George) + updated timing.
- **Rendered:** `out\mtm-showcase.mp4` — 2:44, 1920×1080 H.264, AAC (VO+music verified present end-to-end, mean ~−27 dB). Feature flags are server-side (`get_feature_flags`), so nav/roadmap were Owner judgment calls, not code-derivable.
- Memory added: `project_mtm_showcase_video`. Project tracking at `mtm-showcase/.tracking/`.

## 2026-06-22 (night) — AllTec test-week UI automation: pipeline proven, AUTH-01 green

Session recovered from a VS Code/session restart that wiped CURRENT.md + in-flight context (Monday's testing day work survived in commits). Reconstructed from 06-22 spec files.

- **Monday (06-22) testing day recap (already committed pre-restart):** 13 issues from Adam (tech) + Zach (office) as `Mtm`-prefixed HCP Job Notes + screenshots. ALL fixed — W1 web action buttons (Vercel `38e4a50`), M1–M11 mobile (queue jam/70-stuck-uploads, tab explosion, notes-disappear, labor override, sticky total, checklist, receipt UX) → AAB v2.2.5/code19 + canonical `fcb8be6`. Service-account JSON leak purged from git history.
- **Test-week automation built tonight:**
  - Swift instrumented 42 Tier-1+2 testIDs (`12551aa`) — fixes empty a11y tree (RN 0.81 Fabric flattening, not release build). Manifest at `hcp_replacement/.tracking/specs/2026-06-22-testid-manifest.md`.
  - Debug build w/ M1-M11+testIDs installed on `emulator-5554` (v2.2.5/code19). **Root cause of 30-min Gradle hang: OneDrive locks the Gradle daemon IPC sockets** → built off-OneDrive at `C:\Dev\AllTecPro\mobile_src`, compiled clean ~10min. Env: JAVA_HOME→Android Studio JBR (Java 21); `local.properties` needs sdk.dir+ndk.dir.
  - Maestro 2.6.1 + 11 Regression-Core flows authored (Kit). Metro on 8081 + adb reverse.
  - **AUTH-01 (login) PASSES 1/1.** Debugged from main loop: `clearText`→`eraseText`, `hideKeyboard` before Sign In (keyboard absorbed the tap — proven via manual adb tap landing home), text-assert `Hey, Adam` instead of `tabbar-home-button` (initial home has no TabBar), 45s post-submit wait (droplet round-trip > 20s), clearState:true. Committed `1b32e77`.
  - Forge seeded 5 ZZTEST jobs assigned to Adam (names 11–15, today's board); teardown staged in container (`/tmp/teardown_zztest.py`).
- **Security note:** Kit (subagent) refused a credential relayed through the coordinator — correct per CLAUDE.md (relayed consent ≠ Owner authority, and creds shouldn't flow through subagent channels). Resolution: main loop (talks to Owner directly) holds the password as an env var only (never written/committed) and owns AUTH-01; subagents run credential-free post-login flows against the established session.
- **In progress:** Kit running TAB-01/NOT-01/LAB-01/CHK-02/PRT-02. **Next:** Tier-3 testIDs (Scanner/Queue/Invoice/AddPart) → RCP-01/QUE-01/PRT-05/COL-01/PRT-03; then full Regression-Core run. Change-log email to alltecplumbing@ held for Owner trigger. NO production EAS channel (own-emulator testing only).

## 2026-06-23 (night) — AllTec v2.2.7 SHIPPED to internal; Adam's 3 issues fixed + proven

Adam re-tested on his Play-Store build (v2.2.5/code19, confirmed current on internal via Play API) and left 3 Mtm notes on Job#16: can't finish checklist, can't add part+price, receipt scan broken. Root-caused all three as DEEPER bugs Monday's v2.2.5 never reached, fixed + shipped v2.2.7/code21.

- **Finish-job (note #3) — root cause + fix, PROVEN.** `client.ts getHeaders()` forced `Content-Type: application/json` on the photo-upload FormData body → "Network request failed"; checklist photo items gate on upload success → FINISH JOB permanently locked. New `getUploadHeaders()` (no Content-Type) → multipart works (`[uploadFile] SUCCESS`). Plus robustness: optimistic checklist completion (photo queues, item completes locally — flaky signal can't trap a tech), un-greyed Take/Upload buttons, N/A skip for model/serial. Swift `d4ff1d3`. **Drove the full flow on emulator: job#15 In Progress→Completed, backend-confirmed.** Same bug = root of M2 (70 stuck uploads).
- **Custom part + price (note #2).** v2.2.5 had no price field on the custom-part modal (added today, Tier-3 `48adf3a`). Verified: added Brass shutoff valve @ $45, invoiced clean (PRT-05 PASS, NO "Income Account None" — F1.2 confirmed fixed).
- **Receipt scan (note #1).** Vision OCR was actually FINE (F12 wrong). Real bugs: scanner dup-crash (DuplicateEntryError discarded all OCR) + 57 receipts stuck Pending (poller saved before file attached → OCR never enqueued). Fixed live + canonical `b6d2113`; backlog drained 57→15. Remaining: Coburn's packing-slip column parser (deferred, logged).
- **Labor rate+hours edit-is-truth (Owner req, supersedes Mon "rate stays office-set").** Both editable; once edited, timer stops syncing (manual wins, persists through tick+refetch; old code used a ref that never re-rendered); manual shows orange; flows to invoice. Swift `f9f3948` + backend `update_labor_rate` deployed/verified.
- **Full Regression Core: 11/12 PASS** (Kit). Only fail PRT-03 = server doctype `HCPPricebookRequest` missing `naming_series` → Forge `5df98f2` + migrate, now PASS (effectively 12/12). PRT-05 invoice ✓, COL-01 cash collect→Paid ✓.
- **Release.** Bumped 2.2.7/code21 (`033086d`). BUILD LESSON: off-OneDrive build copy had a leftover `android/` dir from Swift's local `expo run:android` → EAS did a BARE build with stale build.gradle (code19) that failed in cloud; fix = `rm -rf android ios` so EAS does a clean MANAGED prebuild from app.json. Build `01344be8` → `eas submit` internal → **Play API verified: internal track name=2.2.7 status=completed versionCodes=['21'].** Adam updates → gets everything.
- Backend changes all mirrored to canonical (survive redeploy). ZZTEST jobs 11-15 left for now; teardown staged at container `/tmp/teardown_zztest.py`.

## 2026-06-23 (eve) — Video delivered + 38 biz skills + Composio key + audio fix
- **MTM showcase delivered:** rendered video uploaded to Owner's Google Drive (My Drive, anyone-with-link), shareable link for Zach+Adam. Root-caused & fixed the failed "question-everything" link to Aunt Yvonne (it was a Shared-Drive `/open?id=` copy → gave My-Drive `/view` public link). Lesson saved: `reference_drive_sharing`. Text+email drafts written for all three recipients.
- **38 net-new business skills installed** to `PKA/.agents/skills/` (Owner: "install the top set"): 22 from `anthropics/financial-services` (gl-recon/accrual/roll-forward/variance/nav-tieout for QB→ERPNext; 3-statement/dcf/comps/lbo/merger/dd/ic/value-creation for IPO/M&A; unit-economics for MTM SaaS; kyc for Providence; tax-loss-harvesting/financial-plan personal) + 16 `alirezarezvani` pods (general-counsel/cfo/coo/ma-playbook/board-deck, compliance-os/soc2, process-mapper/vendor/procurement/capacity, contract-writer/CS/deal-desk, youtube-full/content-humanizer). Install method: clone repo + `npx skills add <local-skill-dir>` per skill (the CLI `-s` multi-select rejects whole batch on duplicate names in plugin-marketplace repos). Memory: `reference_business_skills_installed`.
- **Composio API key → Bitwarden** (item `Composio API Key`, id afcd38f6-3082-4083-9840-b47201863f92). Tested live: v3 API 200 (v1 deprecated 410). Wiring the MCP next.
- **Owner audio fixed (pending reboot):** HP EliteBook 655 G10 — Realtek ALC236 codec phantom (driver dropped) was the real cause of "no sound" on all videos. Cleared phantom + restarted Realtek service via elevated PS (2× UAC); driver pkg confirmed in store → reboot re-detects & reinstalls. Logged to AUDIT.md.

## 2026-06-24 — Team IDENTITY upgrade DONE + Watchtower Phase 0 BUILD COMPLETE

**Team IDENTITY upgrade (DONE).** All 30 member `IDENTITY.md` files rebuilt to a new gold-standard template (thin persona / thick structure / boundaries table / tools-with-triggers / key-standards / pre-flight / failure-modes). Driven by DATA deep-research → Berry-architect rebuild (Berry+Forge by hand, 28 via workflow `wf_9927c3f2-b68`, 56 agents). Research-backed principle: persona≠capability (Wharton/arXiv) → lean prose, calibrated intensity. **Onyx #6 + Edge #11 MERGED** → Onyx now "Crypto Microstructure & Execution Specialist"; **Edge reversibly retired** (folder kept+bannered, registry→29 active, 6 identities repointed). Spec/tracker: `specs/2026-06-24-team-identity-upgrade-design.md`. NOT committed yet — Owner reviewing diffs. Open (deferred per Owner): seam-reconciliation pass — a few cross-member boundaries one-sided (parallel rebuilds saw stale neighbors). Memory: `project_team_identity_upgrade`.

**Watchtower Phase 0 — BUILD COMPLETE.** Alternative data observatory: 4 signal scrapers (insider cluster buys, job posting velocity, prediction market divergence, Philly Fed benchmark revision) + confluence engine + accuracy tracker; Docker on droplet, email alerts, paper/observation mode, $0/mo. **All 8 tasks done, 31/31 tests**, via SDD (Kit implementer + per-task spec/quality review + fix loops + opus whole-branch review). Final review caught 3 SILENT integration blockers — config keys not read by code (wrong thresholds + monthly report never sent); compose volume shadowed baked config (crash-loop); unexpanded `${ENV}` in email From/To (alerts silently fail) — **ALL FIXED `a58ad6f` + integration smoke-checked.** Code: `Documentos/watchtower/` (own git repo, head `96d5d9a`). Ledger: `watchtower/.superpowers/sdd/progress.md`. **🔴 DEPLOY TO DROPLET = RED, NOT RUN — awaiting Owner go.** Pre-deploy open (GREEN to run, needs live/network): one-shot live smoke of all 4 scrapers (esp. EDGAR insider — untested vs live SEC, may return 0) + real end-to-end test alert email; BW app-password for `WATCHTOWER_EMAIL_PASS`. Phase-1 backlog: insider clusters set sector (enable sector-overlap), SPY baseline at detection, SIGTERM handler. Spec: `specs/2026-06-23-watchtower-phase0-design.md`. Plan: `specs/2026-06-23-watchtower-phase0-plan.md`. Research (6 agents): `Owner's Inbox/alternative-data-synthesis-2026-06-23.md`.

**AllTec v2.2.7 closeout (06-23 night, recorded here for completeness).** v2.2.7/code21 LIVE on Play internal (Play API verified: name=2.2.7 status=completed versionCodes=['21']). Prod AAB installed on emulator (bundletool universal APK → adb install), **Adam login VERIFIED** (lands "Hey, Adam"); **ZZTEST teardown DONE** (all 9 jobs + 9 customers deleted, zero residue); v2.2.7 update email SENT to alltecplumbing@ (thread 19ef77e32e36870d). Remaining non-blocking: Coburn's packing-slip parser (logged 2026-06-23-mtm-notes.md); QUE-01 offline-drain harness (future).

---

## 2026-06-26 — Watchtower Phase 0: ACTUAL first deploy to droplet (LIVE + verified)

**Session:** Owner asked "is the watchtower done?" → discovered it was BUILT but NEVER deployed (tracking said "DEPLOYING now" but `/app/` on 104.131.176.130 held only `data/` + `veoe/`; no `watchtower` container in `docker ps -a`). Owner approved verify + close-out. Routed to Kit, but Kit (subagent) correctly refused the relayed BW master password per coordinator-disclaimer (the documented subagent-authorization-loop). Per `feedback_subagent_authorization`, ran the credentialed deploy from the **main loop** with Owner's direct password.

**Deploy (10T main loop):**
- BW unlocked via `bw serve` REST (localhost:8087); ACTIVE bot Gmail app-pw = item `c863e928` ("Gmail - Bot Notifications ACTIVE (christoph3reverding)"), creds in notes field. Same credential family VEOE uses. Vault locked + `bw serve` killed after.
- Code (head `aef0c1a`) tar-over-ssh → `root@104.131.176.130:/app/watchtower/` (no rsync available). `.env` written chmod 600 (`WATCHTOWER_EMAIL_USER` + `WATCHTOWER_EMAIL_PASS`, app-pw whitespace-stripped to 16 chars). `docker compose up -d --build`.
- Container `watchtower` Up (health: starting→); logs show `db_initialized` + `scheduler_running` with all 7 jobs (insider_buys_daily, pred_markets_daily, job_postings_daily, confluence_daily, philly_fed_weekly, job_velocity_weekly, accuracy_monthly).
- **End-to-end SMTP alert VERIFIED:** `send_alert(...)` returned True, `email_sent` logged, `[WATCHTOWER] Deploy smoke test` landed in christoph3reverding@gmail.com inbox (msg 19f01f9653e81023).

**State:** LIVE on droplet, paper/observation mode, $0/mo. Caveat: jobs watchlist sector labels loose (approx ticker map). Not git-committed (Owner reviews diffs). Next: observe first scheduled scrape cycle (daily 06:00–08:30 UTC) + first real/confluence alerts; Phase-1 backlog unchanged (insider sector tagging, SPY baseline, SIGTERM handler).

## 2026-06-28 — Watchtower Phase-1 hardening DEPLOYED LIVE (before Monday open)
Owner-authorized RED deploy to droplet 104.131.176.130. Pattern honored: Kit (subagent) reviewed/tested/committed the code; 10T main-loop ran the credentialed deploy.
- **Kit:** finalized 6 Phase-1 items, **47/47 tests** (+16 new), HEAD `893644e`. Items: (1) per-cycle run-summary logging across all scrapers; (2) weekly liveness digest (`engine/digest.py`, Sun 11:00 UTC); (3) SIGTERM graceful shutdown (`main.py`); (4) insider yield fix + Yahoo-assetProfile sector tagging (`insider_buys.py`, FTS pagination + direct XML); (5) SPY baseline stored at detection (`db.py` migration + tracker); (6) nightly SQLite→gdrive backup (`engine/backup.py`, 02:00 UTC, keep last 14). No new pip deps; no new env vars.
- **10T deploy:** added rclone install to Dockerfile + mounted authorized `gdrive` remote (copied local `rclone.conf`→droplet `/root/.config/rclone`, chmod 600; dir-mount so rclone persists refreshed OAuth token). Infra commits `e78a2a7` + dir-mount fix. tar-over-ssh of code (excluded live `data/`+`logs/`+`.env` — all intact). `docker compose up -d --build` (rclone via apt).
- **VERIFIED LIVE:** container healthy; scheduler shows 9 jobs incl `liveness_digest_weekly` + `db_backup_daily`; rclone `gdrive:` remote in container; **backup end-to-end → `wt-2026-06-28.db` in `gdrive:Watchtower-Backups`**; **insider live yield 2→12** (under-collecting bug fixed). Caveat: sector-overlap engages only on clusters detected after this deploy (existing live clusters sector=NULL; not a regression).
