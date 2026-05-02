# 10T Toolbox Buildout — PROGRESS

## Project Description
Building a comprehensive toolbox for the 10T team across all 3 active projects (VEOE trading bot, ManyTalents prep app, AllTec HCP replacement). Walking through HCP tools first, one at a time.

## Current Status
**Tool #1 (ERPNext MCP Server) — INSTALLED, awaiting restart to activate.**
**Tool #2 (Stripe) — RESEARCH COMPLETE. Full payment processor analysis delivered to Owner's Inbox.**

## Resume Point
1. **ACTIVE: AllTec Pro mobile app** — full HCP replacement, not just receipt scanner
   - Phase 1: Test receipt scanner end-to-end on phone (need API key first)
   - Phase 2: Job list with color-coded cards + tab navigation
   - Phase 3: Job detail page with address/customer history
   - Full plan in: `AllTecPro/hcp_replacement/progress.txt` (Session 8)
2. **TABLED: Payments** — Owner says "lets get payments set up" to resume Stripe walkthrough
   - Report ready: `Owner's Inbox/AllTec-Payment-Processor-Analysis.md`
   - Recommendation: Stripe (native ERPNext via Stripe2 app + best Expo SDK)
   - Setup links:
     - Stripe account signup: https://dashboard.stripe.com/register
     - Frappe Payments app: https://github.com/frappe/payments (`bench get-app payments` or install via Frappe Cloud Marketplace)
     - Stripe2 Frappe Cloud app: https://cloud.frappe.io/marketplace/apps/stripe2
     - Stripe React Native SDK: https://github.com/stripe/stripe-react-native (`expo install @stripe/stripe-react-native`)
     - Stripe Terminal readers: https://stripe.com/terminal/devices (Reader M2 ~$59)
     - Frappe Stripe integration docs: https://docs.frappe.io/erpnext/stripe-integration
   - Need from Owner: AllTec EIN, business bank account, decision from other owners
3. Continue toolbox queue (Tool #3: Twilio SMS) after payments is settled

## Session Log — 2026-03-30

### What was done:
- Audited all 90+ tools available to the team (MCP, CLI, Python packages, system tools)
- Created `PKA/.10T/TOOLBOX.md` — master toolbox reference (12 categories)
- DATA researched tools for all 3 projects (3 reports in Owner's Inbox)
- Owner chose to walk through HCP tools first, one at a time
- Installed ERPNext MCP Server at `PKA/.10T/tools/erpnext-mcp-server/`
- Created `PKA/.mcp.json` with correct Frappe API credentials
- Key discovery: "key2 full/read" (32-char) are NOT Frappe API keys. CSV keys (15-char) are the correct format per Frappe source code (`generate_hash(length=15)`)

### Decisions made:
- Toolbox lives in `PKA/.10T/TOOLBOX.md`
- MCP tools installed in `PKA/.10T/tools/`
- MCP config at `PKA/.mcp.json`
- Using CSV API keys for ERPNext (api_key: [redacted — stored in Bitwarden])
- HCP tools installed in DATA's recommended priority order

### HCP Tool Queue:
1. ERPNext MCP Server — DONE
2. Stripe (Frappe Payments + React Native SDK) — NEXT
3. Twilio SMS (official Frappe app)
4. react-native-signature-canvas
5. Google OR-Tools + OSRM (route optimization)
6. Mapbox React Native SDK
7. Frappe Insights (dashboards)
8. n8n QuickBooks workflow
9. DocuSeal (e-signatures)
10. Hookdeck (webhook reliability)
11. Veryfi/Mindee (better OCR)
12. Photo-to-Estimate (Vision AI)

### Files created/modified:
- CREATED: `PKA/.10T/TOOLBOX.md`
- CREATED: `PKA/.10T/tools/erpnext-mcp-server/` (cloned + built)
- CREATED: `PKA/.mcp.json`
- CREATED: `PKA/.10T/PROGRESS.md` (this file)
- CREATED: `Owner's Inbox/VEOE-Tools-Research-Report.md`
- CREATED: `Owner's Inbox/ManyTalents-Tools-Research-Report.md`
- CREATED: `Owner's Inbox/AllTec-HCP-Tools-Research.md`

---

## Session Log — 2026-03-30 (Session 2: DATA Payment Processor Research)

### What was done:
- DATA conducted deep research on 6 payment processors for AllTec Plumbing ($2M/yr revenue)
- Processors analyzed: Stripe, Stax, Helcim, Square, PayPal/Braintree, Payment Depot
- For each: pricing model, annual cost estimate, React Native/Expo SDK, ERPNext integration, in-person capability, ACH rates
- Built comprehensive cost comparison at $2M with 70% card / 20% ACH / 10% cash split
- Calculated annual savings vs. current HCP (2.99%) for each processor
- Delivered presentation-ready report to Owner's Inbox for AllTec ownership review

### Key findings:
- HCP currently costs AllTec ~$53,820/year in processing fees (card + ACH at 2.99%)
- Stax is cheapest at ~$30,102/year (saves ~$23,718) but requires $8K-$23K custom dev
- Helcim is second at ~$32,722/year (saves ~$21,098) but also needs custom dev
- Stripe costs ~$42,540/year (saves ~$11,280) but has native ERPNext + best Expo SDK
- Square and Braintree are roughly same cost as Stripe with worse integration fit

### Recommendation:
- **Stripe now** (native integration, zero dev cost, still saves $11K/year)
- **Evaluate Stax in 12-18 months** when system is stable and volume may justify custom build
- Square rejected due to Expo compatibility issues
- Braintree rejected due to high per-txn fees and weaker mobile field solution

### Files created/modified:
- CREATED: `Owner's Inbox/AllTec-Payment-Processor-Analysis.md`
- MODIFIED: `PKA/.10T/PROGRESS.md` (this file — updated status and resume point)

---

## Session Log — 2026-04-02 (Crypto Bot Alpha Team Buildout)

### What was done:
- Diagnosed why massive parameter sweep completely failed (303/303 configs, 0 completions)
  - Mar 31: 100 pairs / 21-month period → timed out at 600s each
  - Apr 2: Validation on failed configs → Windows crash (exit code 3221226091)
  - Root cause: CLI overrides too aggressive. Code defaults (15 pairs, 6 months) are correct.
- Backed up failed results, re-launched sweep with correct parameters
- Sweep now running successfully: 100 configs at ~50s each
- Early results all negative — confirms current strategies need new alpha sources
- Hired 5 new team members for crypto alpha research:
  - **Rex** — Quantitative Trader & Strategy Validation Lead
  - **Sage** — Mathematician & Statistician
  - **Onyx** — Crypto Market Microstructure Specialist
  - **Shield** — Risk & Portfolio Manager
  - **Ace** — Business Strategist & Capital Allocator
- Team Registry updated: 3 → 8 members

### Decisions made:
- Sweep runs with code defaults (15 pairs, 6 months, 900s timeout) — no CLI overrides
- Alpha team hired to bring fresh perspectives for sweep round 2
- Current sweep establishes baseline; new team designs next-gen theories

### Files created/modified:
- CREATED: `PKA/Team/Rex/IDENTITY.md`
- CREATED: `PKA/Team/Sage/IDENTITY.md`
- CREATED: `PKA/Team/Onyx/IDENTITY.md`
- CREATED: `PKA/Team/Shield/IDENTITY.md`
- CREATED: `PKA/Team/Ace/IDENTITY.md`
- MODIFIED: `PKA/Team/REGISTRY.md` (3 → 8 members)
- MODIFIED: `crypto_bot/PROGRESS.txt` (v8.1 session log)
- MODIFIED: `PKA/.10T/PROGRESS.md` (this file)
- CREATED: `PKA/Team/Pulse/IDENTITY.md`
- CREATED: `PKA/Team/Echo/IDENTITY.md`
- CREATED: `PKA/Team/Edge/IDENTITY.md`
- CREATED: `PKA/Team/Macro/IDENTITY.md`
- MODIFIED: `PKA/Team/REGISTRY.md` (8 → 12 members)
- CREATED: `crypto_bot/data_harvest.py` (bulk data download script)
- CREATED: `crypto_bot/data/alternative/` (14 files, 47,879 rows of alt data)
- INSTALLED: chaindl, pytrends, tradingview-datafeed
- CryptoQuant API: $99/mo — used chaindl as free alternative
- TradingView Pro: tvdatafeed tested, webhooks parked for Phase 5

### Resume Point (updated):
- **Phase 2:** Echo builds feature engine with 14 alt data sources + OHLCV
- **Phase 3:** Expanded sweep — 50 pairs, 12mo, new features, macro filter
- **Phase 4:** Sage validates — purged walk-forward, deflated Sharpe, p<0.05
- **Phase 5:** Paper trading → TradingView webhooks on validated signals

---

## Session Log — 2026-04-05 (Conference V2 + Live API Audit)

### What was done:
- Full team conference review of V1 findings → identified 5 priority gaps (Addendum A)
- Live Kraken API balance check: **$357.27** (was $224 → +59.5% return)
- **CRITICAL: Discovered fee schedule was WRONG in V1**
  - Actual: 0.25% maker / 0.40% taker (Tier 0)
  - V1 stated: 0.16% / 0.26% (Tier 2, requires $50K+ volume)
  - Thin pairs get 0.23% maker (rebate schedule, 317 pairs)
- Scanned 645 USD pairs live for spread/volume → 55 Strategy C candidates
- Tested triangular arb (BTC-ETH-USD): NOT viable (-0.75% after fees)
- Tested stablecoin arb (USDC/USDT/DAI): NOT viable (0.01% spread vs 0.40% fee)
- Tested Kraken Futures access: NOT available to US customers (auth error on futures.kraken.com)
- Checked Kraken Earn: ATOM 19.37% APR but price risk unhedgeable
- Researched grid trading, DCA timing effects, cross-exchange arb
- Produced CONFERENCE_FINDINGS_V2_2026-04-05.txt (full updated spec)

### Key decisions:
- Strategy B (Vol Compression Breakout) SHELVED — fees kill the thin edge
- Strategy D (Grid Trading) ADDED — complements market-making
- Strategy E (Cointegration Pairs Trading) ADDED — academic validated, Sharpe 1.5-2.5
- Strategy F (CVD Order Flow) ADDED — lower priority, Phase 4
- Monday Timing KILLED — academic proof calendar effects don't persist post-2015
- USDC Earn + free conversion for idle capital ($177 → ~3% APY)
- No new hires needed — current 18-member team sufficient
- Echo reassigned to pair_scanner.py + cointegration scanner
- Pulse reassigned to SOPR monitoring + narrative tracking

### Files created/modified:
- CREATED: `crypto_bot/CONFERENCE_FINDINGS_V2_2026-04-05.txt`
- MODIFIED: `crypto_bot/CONFERENCE_FINDINGS_2026-04-04.txt` (Addendum A added)
- MODIFIED: `PKA/.10T/PROGRESS.md` (this file)

### Completed (2026-04-05):
- **Kit: Phase 1 DONE** — 5,081 lines of production code, all 5 modules verified:
  - config.py (correct fees, all strategy params, quit criteria, weekend/holiday schedule)
  - exchange_kraken.py (full API wrapper, WebSocket, post-only orders, rate limiting)
  - pair_scanner.py (spread/volume scanner, Johansen cointegration for Strategy E)
  - risk_manager.py (drawdown ladder, API failure protocol, heartbeat watchdog, Kelly sizing)
  - portfolio.py (SQLite tracking, equity snapshots, fee tracking, monthly summaries)
- **Sage: Bootstrap CI DONE** — Strategy A VALIDATED (CI: +2.60% to +7.83%, p=0.00015)
  - Deflated Sharpe: 1.135 (survives multiple comparison)
  - Strategy B CONFIRMED DEAD (PF CI includes 1.0)
- **DATA: GitHub search DONE** — 30+ repos evaluated, key finding: use Hummingbot for MM, not custom

### Completed (2026-04-05 session 2):
- **Kit: Phase 2 DONE** — 3 production modules built:
  - strategy_pairs.py (1,544 lines — cointegration pairs trading, z-score, hedge-ratio sizing)
  - strategy_grid.py (1,243 lines — grid trading, ADX filter, weekend rules)
  - main.py (1,021 lines — central orchestrator, 30s/5m/15m/1h/4h/12h schedule)
- **Import class mismatch fixed** — GridStrategy/PairsStrategy aliases
- **SQLite schema migrated** — equity_snapshots recreated, trades table columns added
- **SIM MODE VERIFIED RUNNING** — `python main.py --sim` starts all 4 strategies:
  - A=ON C=ON D=ON E=ON, crash recovery works, equity snapshots work
  - Strategy C cycles every 30s, D every 5m, E every 15m, A hourly

### Completed (2026-04-05 session 3 — team code review + bug fixes):
- **Full Alpha Team code review** — all 10 production files reviewed
- **4 CRITICAL BUGS FOUND AND FIXED:**
  1. main.py called async strategy D/E methods without await → strategies never executed
  2. risk_manager alert callback was sync but wrapped in ensure_future → alerts silently failed
  3. strategy_grid.py _last_adx dict never initialized → would crash on ADX query
  4. alerts.py wellness report queried non-existent `positions` table → fixed with fallback
- **alerts.py upgraded** — wellness check at 7am + 7pm CDT (not just "alive" pulse)
  - Reports: heartbeat freshness, balance, equity trend, risk state, open positions, last trade
- **Email verified working** — test email sent successfully via Gmail

### Completed (2026-04-05 session 4 — FULL TEAM TRIPLE-CHECK):
- **5 specialist reviews in parallel:** Edge, Shield, Rex, Kit, Ace
- **Total findings: 9 HIGH/CRITICAL fixed, 12 MEDIUM noted, 8 LOW logged**
- **HIGH/CRITICAL bugs fixed this session:**
  1. main.py: sim mode was placing REAL Kraken orders for Strategy C → now skips execute_cycle
  2. main.py: Strategy A sync methods blocking event loop → wrapped in asyncio.to_thread()
  3. strategy_sopr.py: place_limit_buy called instead of place_limit_sell → fixed
  4. config.py: QUIT_HARD_BALANCE_FLOOR was $150 (stale) → corrected to $240 (-33% from $357)
  5. portfolio.py: fee fallback calculated fees on P&L instead of trade volume → fixed
  6. risk_manager.py: API recovery/halt clear lost drawdown state → added _check_drawdown_ladder()
  7. risk_manager.py: datetime.now() without timezone → added timezone.utc (2 locations)
  8. alerts.py: wellness report queried non-existent 'status' column → fixed to exit_price IS NULL
  9. strategy_mm.py: double market sell (stop + timeout) → added continue after stop block
- **99/99 tests pass after all fixes**
- **SIM verified clean** — no more real order errors, all 4 strategies cycle correctly

### REMAINING (MEDIUM, not blocking sim):
- strategy_mm.py: still uses old kraken_orders.py (BLOCKING for live, safe in sim)
- strategy_pairs.py: stuck closing-state retries forever (add market fallback after N retries)
- strategy_grid.py: partial fills use original volume not vol_exec for counter-orders
- main.py: no capital reallocation when Strategy A triggers (V2 spec steps 1-3)
- main.py: no log rotation (RotatingFileHandler needed for 24/7 operation)
- risk_manager.py: async alert silently dropped when no event loop running
- capital_manager.py: USDC Earn not implemented ($177 idle earns 0%)

### Completed (2026-04-05 session 5 — ROUND 3 TRIPLE-CHECK):
- **4 specialist reviews:** Edge, Shield, Kit, Rex+Ace (combined)
- **Round 3 findings: 2 P0 + 6 P1 + 5 P2 fixed**
- **P0 CRITICAL fixes:**
  1. strategy_sopr.py: place_limit_sell not imported → NameError on every exit (ADDED TO IMPORT)
  2. main.py: Strategy A check_exits ran in sim mode placing REAL orders (GUARDED)
  3. strategy_mm.py: double sell on profitable+timed inventory (RESTRUCTURED if/elif/else)
- **P1 HIGH fixes:**
  4. strategy_sopr.py: ALLOCATION_PCT=0.70 double-discounted → changed to 1.0
  5. strategy_sopr.py: no SOPR data staleness check → added 3-day guard
  6. strategy_pairs.py: negative hedge ratio inverts z-score → added guard + NaN returns
  7. strategy_pairs.py: z=0.0 on insufficient data triggers false exits → returns NaN now
  8. risk_manager.py: weekly loss limit (10%) never enforced → added WEEKLY_HALTED trigger
  9. risk_manager.py: weekly halt clear missing legacy flag reset → added
  10. strategy_grid.py: sell orders placed before buys fill → removed, now counter-order only
- **99/99 tests pass. SIM verified: zero real orders, zero errors**

### REMAINING (P2/LOW — not blocking sim or initial live):
- strategy_pairs.py: short leg needs margin_sell for actual short selling
- strategy_pairs.py: exit legs have no market fallback (stuck in closing forever)
- strategy_grid.py: grid level price collision on low-price coins (dedup needed)
- strategy_mm.py: fee constants still wrong (0.16%/0.26% — BLOCKING for live)
- config.py: MAX_DEPLOYED_PCT never enforced (no total deployment cap)
- main.py: static allocation doesn't scale with actual balance
- main.py: no Strategy A capital reallocation to other strategies
- main.py: no log rotation for 24/7 operation
- portfolio.py: save_daily_summary uses fragile t[8] index
- risk_manager.py: async alert dropped when no event loop
- capital_manager.py: USDC Earn not implemented

### Completed (2026-04-05 session 6 — ROUND 4 with Sage):
- **5 specialist reviews:** Edge, Shield, Kit, Rex+Ace, **Sage (first code review)**
- **Round 4 findings: 8 HIGH fixed across all files**
- **HIGH fixes this round:**
  1. strategy_pairs.py: zero-std z-score returned 0.0 → now returns NaN (prevented false exits)
  2. risk_manager.py: Kelly +1.0 offset inflated all position sizes → removed, proper half-Kelly
  3. main.py: get_balance=0 from API error → false HARD_QUIT. Now guarded, skips snapshot
  4. risk_manager.py: position_size() called can_trade() internally → double state mutation. Fixed
  5. risk_manager.py: min floor overrode max cap on small portfolios. Now returns 0 if too small
  6. main.py: heartbeat didn't record API failures + recorded equity=0 on error. Both fixed
  7. strategy_sopr.py: empty fg_data DataFrame caused IndexError. Added .empty guard
  8. risk_manager.py: zero balance bypassed HARD_QUIT silently. Now triggers it
- **99/99 tests pass. SIM verified clean.**

### CUMULATIVE BUG COUNT (4 rounds):
- Round 1: 4 CRITICAL → fixed
- Round 2: 9 HIGH/CRITICAL → fixed
- Round 3: 10 P0/P1 → fixed
- Round 4: 8 HIGH → fixed
- **Total: 31 bugs found and fixed across 4 review rounds**

### REMAINING (P2/LOW — logged for future, not blocking sim):
- strategy_mm.py: full rewrite needed (old API, wrong fees) — BLOCKING for LIVE
- strategy_pairs.py: short leg needs margin_sell for actual shorting
- strategy_pairs.py: exit legs no market fallback; orphaned long leg on failed short
- strategy_grid.py: level price collision on low-price coins; P&L overestimates by (1+s)
- config.py: MAX_DEPLOYED_PCT unenforced; grid spacing at exact fee minimum
- main.py: static allocation, no reallocation, no log rotation, Windows shutdown
- portfolio.py: fragile t[8] index; expected fee *2 approximation
- risk_manager.py: thread safety; API recovery wipes pre-outage halt; async alert edge case
- capital_manager.py: USDC Earn not implemented

### Completed (2026-04-05 session 7 — ROUND 5 with fresh Sage review):
- **5 specialist reviews:** Edge, Shield, Kit, Rex+Ace, Sage
- **Sage SIGN-OFFS:** z-score math, Kelly formula, ADX, drawdown cascade, P&L calculation
- **Round 5 fixes (7 HIGH/MEDIUM + 3 LOW):**
  1. strategy_pairs.py: NaN z-score no longer skips time stop (trades can't stay open forever)
  2. strategy_pairs.py: NaN no longer stored in watched pair state (clean JSON serialization)
  3. risk_manager.py: short_position_size 3 bugs fixed (can_trade, floor, drawdown/weekend scaling)
  4. risk_manager.py: Decimal vs float comparison cleaned up
  5. main.py: _tick_report now calls record_api_failure on error
  6. alerts.py: SMTP timeout=30s added (can't hang bot forever)
  7. portfolio.py: breakeven trades no longer counted as losses
- **99/99 tests pass. SIM verified clean.**

### Completed (2026-04-06 session 8 — FULL DE NOVO TOP-TO-BOTTOM REVIEW):
- **3 team panels:** Rex+Sage (strategy), Shield+Ace (risk/business), Kit+Edge (infra/execution)
- **CRITICAL fixes this session:**
  1. strategy_sopr.py REWRITTEN — migrated from kraken_orders to exchange_kraken + correct fees
  2. main.py: SOPRStrategy now receives client parameter
  3. risk_manager.py: PAUSED no longer blocks Strategy A in position_size()
  4. main.py: Peak balance restored from equity_snapshots DB on restart
  5. main.py: Daily P&L restored from today's trades on restart (loss limits survive crash)
  6. main.py: Orphaned orders from previous sessions cancelled on startup
  7. main.py: Portfolio quit criteria field name mismatch fixed ("type" vs "severity")
- **SIGN-OFFS RECEIVED:**
  - Strategy C (MM): **APPROVED** — Rex, Sage, Kit, Edge all sign off
  - Strategy D (Grid): **APPROVED WITH ADVISORY** — increase spacing to 1.5% for live
  - Strategy A (SOPR): **APPROVED** — now on V2 API with correct fees
  - Drawdown ladder: **APPROVED** — Shield confirms triple redundancy
  - Kelly criterion: **APPROVED** — Sage confirms math
  - Daily/Weekly loss limits: **APPROVED** — Shield confirms enforcement
  - API failure protocol: **APPROVED** — Kit confirms all paths
  - Async correctness: **APPROVED** — Kit confirms all sync/async boundaries
  - Error handling: **APPROVED** — Kit confirms all try/except blocks
  - Execution layer: **APPROVED** — Edge confirms place_order, cancel_all
  - Email system: **APPROVED** — Kit confirms schedule, SMTP timeout
  - Config validation: **APPROVED** — Shield confirms 5 critical checks
  - Fee calculations: **APPROVED** — Sage confirms all from config, no hardcoded

### STRATEGY E — REDESIGNED AS RELATIVE VALUE ROTATION (2026-04-06):
- DATA confirmed: Kraken US requires $10M ECP certification for margin/shorting. DEAD.
- No inverse tokens, no futures for pairs, no workarounds.
- **SOLUTION: Restructured from long/short pairs to relative value rotation.**
  - Buy BOTH assets in baseline amounts ($20/$20)
  - When z-score signals: TILT allocation ($30 underperformer / $10 overperformer)
  - When mean reversion: rebalance to 50/50 baseline
  - On exit: sell BOTH back to USD
  - Same z-score math, same cointegration scanner, same thresholds
  - No short selling needed — all trades are sells of assets we HOLD
- strategy_pairs.py rewritten: 2,186 lines (was 1,571)
- Expected Sharpe: 0.8-1.5 (vs 1.5-2.5 for true market-neutral) — still profitable
- **NOW FULLY EXECUTABLE on Kraken spot with no margin**

### Completed (2026-04-06 session 9 — FINAL REVIEW + SIM LAUNCH):
- **strategy_sopr.py REWRITTEN** — migrated to exchange_kraken, correct fees, _run_async bridge
- **strategy_pairs.py REDESIGNED** — long/short → relative value rotation (2,186 lines)
  - No short selling needed. Buys both assets, tilts allocation on z-score signals.
  - Same cointegration math, z-scores, thresholds — all Sage-approved
  - 100% executable on Kraken US spot with no margin
- **main.py integration fixes** — SOPRStrategy(client), peak/P&L restoration, orphan cleanup
- **FINAL TEAM REVIEW: ALL 5 FILES APPROVED, ZERO BLOCKING ISSUES**
- **SIM LAUNCHED** — PID 38111, log: sim_overnight_20260405_011318.log
  - A=ON C=ON D=ON E=ON, cycling every 30s/5m/15m/1h
  - 7am + 7pm CDT wellness emails configured

### CUMULATIVE STATS:
- **7 review rounds** (4 targeted + 1 full de novo + 1 strategy redesign + 1 final)
- **45+ bugs found and fixed** (including 1 fundamental design flaw)
- **3 full file rewrites** (strategy_mm, strategy_sopr, strategy_pairs)
- **ALL strategies on V2 API** — zero kraken_orders imports in active files
- **ALL strategies executable on Kraken US spot** — zero margin/shorting required

### TEAM SIGN-OFFS:
| File | Status | Reviewers |
|------|--------|-----------|
| strategy_pairs.py | APPROVED | Architecture Lead |
| strategy_sopr.py | APPROVED | Exchange Integration Lead |
| strategy_mm.py | APPROVED | Market-Making Lead |
| main.py | APPROVED | Integration Lead |
| risk_manager.py | APPROVED | Risk Lead |
| config.py | APPROVED | Shield, Sage, Ace |
| portfolio.py | APPROVED | Shield, Sage |
| alerts.py | APPROVED | Kit |
| exchange_kraken.py | APPROVED | Edge |

### REMAINING (LOW priority, not blocking sim or live):
- No Bonferroni correction for multiple pair testing in Strategy E
- macro_filter.py not yet built (DXY/VIX/Nasdaq gate)
- capital_manager.py not yet built (USDC Earn for idle capital)
- Grid spacing default at exact fee minimum (use 1.5% for live)
- No log rotation (add RotatingFileHandler before extended live)
- 3 inactive files still import kraken_orders (dashboard_api, strategy_breakout, trading_engine)
- ML integration deferred — need 3+ months live data first

### ML ASSESSMENT (Rex + Echo):
- Not useful yet at current data volume (58 SOPR signals, 0 live trades)
- After 3+ months: pair selection, fill rate prediction, regime detection
- Existing ml_trainer.py and neural_trainer.py ready when data accumulates
- Strategy edges are structural/statistical, not predictive — ML is Phase 4+

### Resume Point (2026-04-06 ~09:00 UTC):
- **SIM ran 903 cycles (~7.5 hours) with ZERO errors before PC shutdown**
- PC shutting down. Sim will need restart on next session: `cd crypto_bot && venv/Scripts/python.exe main.py --sim`
- Crash recovery will restore state from DB automatically on restart

**Next steps:**
1. **Restart sim** — verify wellness emails arrived at 7am/7pm CDT
2. **Run sim for 7 days total** — review daily logs for any issues
3. **Go live** — Strategy C ($100) + D ($40) first, then A + E
4. **Phase 3** — macro_filter.py, capital_manager.py, log rotation, dashboard
5. **Phase 4** — ML integration after 3+ months live data

---

## Session Log — 2026-04-18 (MTM Inventory Phase 1 + Event Tracker)

### What was done:
- **MTM Inventory Phase 1 — DEPLOYED & VERIFIED**
  - All inventory code deployed to Frappe Cloud (receipts, OCR, dispatch, warehouses)
  - Mobile app tested on phone — INVENTORY section loads, 10 receipts visible
  - Per-item SEND button, truck picker, Limbo destination, SYNC button added
  - Default destination = Limbo (tech picks where each item goes)
  - Google Cloud Vision OCR confirmed configured and working

- **MTM Event Tracker — BUILT & DEPLOYED**
  - New MTM Event Log doctype with Socket.IO real-time push
  - Central event_logger.py wired into 8 existing hook points
  - Events REST API with full filters (category, type, severity, tech, job, date, search)
  - Web dashboard: EventBadge (gold bell) + EventPanel (side panel) + full events page
  - 10 event types: job_status, clock, receipt, ocr, dispatch, hcp_sync, material, cron, api_error, login
  - 90-day auto-cleanup via daily scheduler

- **Web Dashboard Improvements**
  - Fixed Vercel build failure (TS errors in money-api.ts)
  - Job intake form: Vacant checkbox, Keycode/K@O fields
  - Dashboard: prominent "+ New Job" button, Dashboard link on intake page

### Decisions made:
- Deploy inventory to production (no staging needed)
- Limbo = post-job unused parts only (Owner confirmed)
- Event data in Frappe backend (not Supabase)
- Real-time via polling (Socket.IO on Frappe Cloud shared hosting is unreliable)
- All events tracked from day one except GPS

### Files created/modified:
- BACKEND (AllTecPro/hcp_replacement):
  - CREATED: doctype/mtm_event_log/ (JSON + Python + tests)
  - CREATED: core/event_logger.py
  - CREATED: api/events.py
  - MODIFIED: hooks.py, core/hcp_sync.py, core/ocr_engine.py, core/limbo_processor.py
  - MODIFIED: api/tech_utils.py, core/stock_processor.py, doctype/hcp_receipt/hcp_receipt.py
  - MODIFIED: api/auth_utils.py
  - MODIFIED: mobile/src/components/inventory/DispatchItemCard.tsx (SEND, truck picker, Limbo)
  - MODIFIED: mobile/src/components/inventory/ReceiptDetailScreen.tsx (SYNC, Limbo default)
  - MODIFIED: mobile/src/components/inventory/ReceiptCard.tsx (unicode fix)

- FRONTEND (ManyTalentsMore):
  - CREATED: src/lib/events.ts
  - CREATED: src/app/manager/components/EventBadge.tsx
  - CREATED: src/app/manager/components/EventPanel.tsx
  - CREATED: src/app/manager/events/page.tsx
  - MODIFIED: src/app/manager/dashboard/page.tsx (badge, panel, +New Job, content shift)
  - MODIFIED: src/app/manager/jobs/new/page.tsx (vacant, keycode, nav links)
  - MODIFIED: src/lib/frappe.ts (createJob type)
  - MODIFIED: src/lib/money-api.ts (TS fix)
  - MODIFIED: src/app/money/crypto/page.tsx (TS fix)

### Resume Point (2026-04-18):
- **Inventory Phase 1:** DONE — all verified on phone + web
- **Event Tracker:** DONE — live, events flowing from hooks

---

## Session Log — 2026-04-19 (Web Inventory + Restock + Smart Matching)

### What was done:

- **Web Inventory Dashboard — BUILT & DEPLOYED**
  - /manager/inventory with 5 tabs: Receipts, Warehouses, Limbo, Restock, Matches
  - Table-view dispatch with inline destination buttons (not dropdowns)
  - Truck picker popup, per-row SEND, bulk SYNC
  - Browser back button support (history.pushState)
  - Nav shows "← Receipts" when in dispatch view

- **Daily Restock Pull List — BUILT & DEPLOYED**
  - MTM Pull List Item doctype with full lifecycle (Pending→Pulled→Accepted/Rejected/Ignored)
  - 9 API endpoints: generate, pull, accept, reject, resolve, ignore, add, summary
  - Auto-generates every 15 min from truck stock consumption (scheduler)
  - Accept creates Stock Entry (Material Transfer: Office → Truck)
  - RESTOCK tab on web inventory with collapsible truck sections, PULL ALL, rejections

- **Smart Matching System — BUILT & DEPLOYED**
  - Item Classifier (core/item_classifier.py) — structured attribute parser
    - Understands nipple diameter x length, bushing two-diameter, street vs regular
    - Valve subtypes: T&P ≠ gas ≠ ball ≠ angle stop (will never cross-match)
    - PEX systems: crimp ≠ expansion ≠ SharkBite
    - Press: ProPress ≠ MegaPress
    - Synonym table for supplier abbreviations
  - match_count tracking on Item Supplier (increments on every confirmed match)
  - Confidence tiers: unmatched (white) → first_match (sky blue) → locked_in (dark cobalt)
  - Locked-in items collapse to single-line rows on both web and mobile
  - HCP Pricebook Request doctype — techs submit new parts, office reviews
  - MATCHES tab enhanced: confidence colors, "+ New Part" amber button, pending parts queue, keyboard shortcuts (J/K/Enter/S/N)
  - Mobile: PricebookSearchModal (bottom sheet), AddNewPartModal (amber), DISPATCH MATCHED button

- **Bulk Matcher — RAN 3 VERSIONS**
  - v1: basic word overlap (too many false positives)
  - v2: size + material + fitting type aware
  - v3: plumbing-convention aware (nipple length, bushing diameters, valve subtypes, PEX systems)
  - Results: 3,317 GOOD / 6,152 WEAK / 5,329 NONE out of 14,798 items
  - Excel workbook: AllTecPro/bulk_match_review.xlsx with pricebook dropdown + status dropdown
  - Receipt batch scanned: AllTecPro/recepts/2165_001.pdf (15 pages, 8 receipts, 5 suppliers, ~65 items)

- **Other Fixes**
  - get_global_limbo endpoint for web limbo tab
  - OCR parser: filters AMOUNT/DISCOUNT/TOTAL junk lines from Coburn's
  - receipt_file URL added to receipt list API
  - Dedup: exact supplier+total+date fallback matching
  - Back button fix (browser history for dispatch view)
  - Event panel no-overlay fix
  - Vercel TS build fix (CryptoStrategy fields)
  - Dashboard content shifts when event panel open
  - Intake form: vacant checkbox, keycode/K@O, Dashboard link on new job page
  - Auto key rotation via generate_keys API (never ask Chris to go to web UI)

### Team Review Conducted:
- Pixel (UI/UX): 3 tiers not 4, collapse locked-in to single line, amber for "Add New Part"
- Stocky (Inventory): unit reconciliation flags, "dispatch matched hold unmatched", job-type search ranking
- Glass (Frontend): shared search modal (not per-card), cache 975 pricebook locally, fixed card heights
- Forge (Backend): match_count on Item Supplier, remove ignore_permissions, fix bulk_approve learning, HCP Pricebook Request doctype

### Files created/modified:
- BACKEND:
  - CREATED: core/item_classifier.py (449 lines — structured attribute parser)
  - CREATED: api/restock.py (9 endpoints for daily pull lists)
  - CREATED: doctype/mtm_pull_list_item/ (pull list tracking)
  - CREATED: doctype/hcp_pricebook_request/ (new part requests)
  - CREATED: fixtures/custom_field.json (match_count, unit_conversion on Item Supplier)
  - CREATED: api/events.py — get_global_limbo endpoint added to limbo.py
  - MODIFIED: core/sku_matcher.py (match_count increment, unit conversion)
  - MODIFIED: api/match_review.py (bulk_approve learning, unit conversion, 4 new part endpoints)
  - MODIFIED: hooks.py (fixtures, restock scheduler)
  - MODIFIED: core/receipt_parser.py (filter junk OCR lines)
  - MODIFIED: api/inventory.py (receipt_file in list API)
  - MODIFIED: core/receipt_dedup.py (exact match fallback)
  - MODIFIED: mobile — PricebookSearchModal, AddNewPartModal, confidence colors, DISPATCH MATCHED

- FRONTEND (ManyTalentsMore):
  - CREATED: src/lib/inventory-api.ts (typed API layer for all inventory endpoints)
  - CREATED: src/app/manager/inventory/page.tsx (~2500 lines — full inventory dashboard)
  - MODIFIED: src/lib/inventory-api.ts (restock, match review, confidence APIs)
  - MODIFIED: src/app/manager/inventory/page.tsx (RESTOCK + MATCHES tabs, confidence colors)
  - MODIFIED: src/app/manager/dashboard/page.tsx (Inventory nav link, event panel shift)

### Design Specs Written:
- docs/superpowers/specs/2026-04-18-daily-restock-pull-list-design.md
- docs/superpowers/specs/2026-04-19-smart-matching-system-design.md

### Resume Point (2026-04-19):
- **Everything built is deployed and live**
- **Next priorities:**
  1. Review bulk match results (AllTecPro/bulk_match_review.xlsx)
  2. Match 65 receipt items from scan batch (AllTecPro/recepts/2165_001.pdf)
  3. Parts usage tracker + recommended stock levels
  4. Supplier ordering system (reorder + job-specific + routing)
  5. Fix Gmail SMTP (alltecplumbing@gmail.com password)
  6. Phase 2 flow adjustment (receipt → job parts → finish → limbo)
  7. Tech onboarding flow (web QR page + email invites)
  8. Providence Buildium replacement

---

## Session Log — 2026-04-29 (Emergency Frappe Fixes)

### What was done:

**1. Email Auto-Read Fix — DEPLOYED & LIVE**
- Problem: Frappe IMAP sync was marking ALL emails in alltecplumbing@gmail.com as read
- Fix: Created Server Script "Mark Emails Unread After Sync" (Scheduler Event, runs every ~5 min)
  - Connects to Gmail IMAP using Email Account credentials
  - Finds all SEEN emails from today, marks them back as UNSEEN
  - Safe: Frappe uses UID tracking (uidnext), won't re-process emails it's already handled
  - No error logs generated — running clean since first execution
- Deployed via Frappe REST API using BW credentials

**2. HCP Pull "Source" Error — FIXED LIVE**
- Problem: `_pull_line_items()` set `source: "HCP"` on materials child table, but "HCP" wasn't a valid Select option
- Error: "Row #1: Source cannot be 'HCP'" — firing every 15 minutes since deploy
- Fix: Created Property Setter via API adding "HCP" to HCP Job Material source field options
- Also fixed local JSON: `AllTecPro/.../doctype/hcp_job_material/hcp_job_material.json`
- VERIFIED: Error stopped immediately after Property Setter was created

**3. HCP Pull "Customer Group" Error — FIXED LIVE**
- Problem: `_get_or_create_customer()` used `customer_group: "All Customer Groups"` (a group node, not leaf)
- Fix: Created Server Script "Fix Customer Group for HCP Sync" (Before Insert on Customer)
  - Changes "All Customer Groups" → "Individual" before validation
- Also fixed local code: `hcp_sync.py` line 1021 → `"Individual"`
- VERIFIED: Customer Group error stopped after Server Script deployed

**4. HCP Pull "str.get" Error — LOCAL FIX ONLY (needs deploy)**
- Problem: HCP API sometimes returns `customer` as a string instead of dict object
- Code calls `customer_data.get("first_name")` on a string → crash
- Fix: Added `isinstance(customer_data, str)` guard in `_upsert_hcp_job()`
- LOCAL ONLY — needs git push + Frappe Cloud deploy to go live

### Live fixes deployed (no code deploy needed):
| Fix | Method | Status |
|-----|--------|--------|
| Email unread | Server Script (Scheduler) | RUNNING |
| Source field | Property Setter | LIVE |
| Customer Group | Server Script (Before Insert) | LIVE |

### Code changes needing deploy:
- `hcp_replacement/core/hcp_sync.py` — customer_group + string guard
- `hcp_replacement/doctype/hcp_job_material/hcp_job_material.json` — "HCP" in options

### Resume Point (2026-04-29):
- **Deploy code changes** to Frappe Cloud (git push + deploy)
- **Monitor** email unread script for 24 hours
- **Note:** HCP Pull Error still fires every 15 min for the string customer edge case until code deploys
