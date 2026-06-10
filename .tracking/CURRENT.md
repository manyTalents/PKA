# PKA — CURRENT

## Status
VEOE: 6 critical fixes deployed (2026-06-09). P&L now uses actual broker fills. Exit execution overhauled. Entry gates tightened.

## Active Work
- **VEOE — 6 FIXES DEPLOYED (2026-06-09):** Paper trading, 3 DB positions + 2 broker orphans, $4,707 balance.
  - **Fix 1: P&L uses actual broker fills** — `avg_fill_price` fetched from Tradier API after every fill. `exit_price`, `pnl`, `pnl_pct` recalculated from actual fills. Removed `* 0.98` fabricated haircut. No more estimated P&L.
  - **Fix 2: Bid-aware exit pricing** — Fetches fresh bid/ask quote before placing exit limit. Wide spread (>15%) = limit at bid. Narrow spread = `bid + 0.7 * spread`. Replaces blind `mid * 0.98`.
  - **Fix 3: Market escalation 50 → 2** — After 2 failed limit orders (10 min), switches to market immediately. Kills the 1,198 canceled orders / dump-at-close pattern.
  - **Fix 4: Entry liquidity gate** — `MIN_OPEN_INTEREST` 0 → 100 per leg. `MAX_SPREAD_PCT` 40% → 20%. Rejects illiquid options the bot can't exit.
  - **Fix 5: Duplicate ticker guard checks broker** — `open_tickers` now built from DB + broker positions. Prevents re-entering tickers with orphaned legs.
  - **Fix 6: Total exposure cap 80%** — New entries blocked if total deployed exceeds 80% of balance. Prevents 181% over-allocation.
  - **Known orphans:** HIMS call (put trail-stopped, call stranded), WULF call (put trail-stopped, call stranded). Both blocked from re-entry by Fix 5.
  - **Sandbox drift confirmed:** Bot internal P&L was +$1,281 on 06-08 while broker actually lost $468. Root cause was Fix 1 (estimated fills). Now fixed.
  - **INVARIANTS ESTABLISHED:** P&L from API only, bid-aware pricing, 2-retry market escalation, 100 OI + 20% spread entry gate, broker-aware duplicate guard, 80% exposure cap.
  - **P&L BASELINE NOTE:** Internal balance $4,707 is inflated by ~$1,700 of pre-fix phantom gains. NOT resetting — watching delta between internal and broker going forward. If they track together from here, the fix is working. If they drift, there's still a leak.
  - **Next monitor:** First real test of bid-aware exits on next trading day. Watch for `bid_aware_limit_price` and `pnl_from_actual_fills` log events. Compare internal P&L vs broker gain/loss on every close.
- **MTP Prep App — READY FOR TESTING (2026-06-07)**
  - Google Play Console: `com.manytalents.testprep`, "ManyTalents Prep"
  - Internal testing: LIVE (Jun 4). Closed testing: submitted, in Google review.
  - 18 testers invited via email with opt-in links (Jun 6)
  - **REMAINING for production:** Google closed testing review approval, 14-day testing period, content rating + data safety forms, store listing graphics
- **AllTec / MTM Manager — ALL 21 AUDIT ISSUES FIXED + INVOICE MVP (2026-05-31)**
  - Self-hosted ERPNext live at erp.manytalentsmore.com (134.199.198.83)
- **The Machine V2 — 11 FIXES DEPLOYED (2026-06-09):** Paper mode, **$1,088.64 equity**. Scanner free (was forced to ETH only). 2 grids: ETP-20DEC30-CDE + ET-26JUN26-CDE @ $435 each. ADX=31, regime=trending/down.
  - **Fix 10:** Scanner unforced — `GRID_FORCED_INSTRUMENTS` cleared, scanner picks from 75 futures
  - **Fix 11:** Re-scan on regime change — when instrument goes trending, immediate re-scan for ranging alternatives (10min cooldown)
  - Most futures too expensive at $408/grid budget. ZEC ($429) close — one more win unlocks it.
  - **NOTE:** Local code (`the-machine/src/`) is STALE — deployed code on droplet is authoritative
- **Providence Buildium Replacement — SCREENING MODULE BUILT (2026-06-04)**
- **Colab System — v5 protocol (2026-06-03)**

## Still Pending
- Native Stripe (`@stripe/stripe-react-native`) — future upgrade from browser handoff
- Admin delivery workflow (dashboard button or DB webhook)
- Feedback survey (Option C — end-of-intake + standalone)

## Known Issue (Minor)
cancel_all() silently swallows cancel errors then clears internal levels list.
