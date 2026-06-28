# Watchtower — Technical-Analysis Confirmation Layer (Design)

**Date:** 2026-06-28
**Status:** Design approved by Owner (2026-06-28). Folded into the queued `congress_trades` build (shared confluence/schema/scoring files → one branch).
**Owner of build:** Rex (signal + confluence logic) → Kit (deploy). 10T owns the credentialed droplet deploy.
**Tier:** GREEN (alerts only, no execution, $0 cost).

---

## 1. Context & Problem

Watchtower is a live alt-data observatory (insider Form-4 buys, job-posting velocity, prediction-market divergence, Philly-Fed revisions) running on droplet `104.131.176.130`, emitting confluence-based email alerts. Its signals answer **"what"** (a fundamental thesis on a ticker) but carry **no price/timing context**. The Owner wants a technical-analysis layer so alerts also answer **"when"** — i.e., does the tape confirm or contradict the fundamental thesis.

We have **no equity TA capability today** — the only `technical-analyzer` skill is crypto/DEX-only (DexPaprika). This spec adds equity TA as a first-class Watchtower confluence input.

## 2. Goal

Add TA as a **confirmation domain** that the confluence engine consults on-demand for any ticker already carrying a fundamental signal. TA **boosts** the confluence score when price action aligns with the thesis direction and **downgrades/holds** the alert when the tape clearly contradicts it ("fundamentals say buy, tape says wait"). Alerts only — no trade execution.

## 3. Decisions (locked in brainstorming)

| Decision | Choice | Rationale |
|---|---|---|
| Role | Confirmation domain in confluence engine; alerts only | Lowest risk; builds on what's live |
| Data source | **Polygon primary** (`POLYGON_API_KEY`, BW `2959f28e…`, free tier confirmed: 60 daily candles OK) → **Yahoo fallback** | Official, cleaner than Yahoo; both $0; Yahoo already a dep (sector tags) |
| Scoring | **Confirm + veto** | Makes alerts genuinely smarter |
| Cadence | Daily (runs inside `confluence_daily`) | Matches the slow alt-data cadence; no new scheduled job |
| Accuracy tracking | **Kept** | Prove TA adds edge before trusting it (honest-rigor bar) |
| Execution | **None** | GREEN tier; no broker, no webhooks, no TradingView |

## 4. Architecture & Data Flow

```
existing scrapers (insider / jobs / pred-market / congress)  →  their tables   [unchanged]
                          ↓
confluence_daily → candidate tickers (≥1 fundamental hit)
                          ↓  per candidate:
   technicals.analyze_ticker(TICKER) -> TAVerdict
     1. fetch ~1y daily OHLCV: Polygon (primary) → Yahoo (fallback)
     2. compute trend / momentum / breakout / volume
     3. classify direction (bullish/bearish/neutral) + strength + components
                          ↓
   confluence folds TAVerdict into score:
     aligned  → +boost   |  neutral → 0  |  contradicts → -penalty / HOLD-flag
                          ↓
   write ta_snapshot (audit + accuracy) → alert (now carries TA note)
```

No new scheduled job. No new external service. No new pip dependency (stdlib + existing `requests`).

## 5. Components (6, each small & bounded)

1. **`watchtower/engine/technicals.py`** *(new)* — the only file that knows indicator math.
   - `analyze_ticker(ticker, config) -> TAVerdict`
   - `_fetch_ohlcv(ticker)` → Polygon daily aggregates; on failure/empty → Yahoo chart fallback; returns list of `(date, o, h, l, c, v)` or `None`.
   - Pure indicator helpers: `_ema(series, n)`, `_rsi(series, 14)`, `_macd(series)`, `_recent_high(series, n)`, `_avg_volume(series, n)`.
   - `TAVerdict` = `{direction: 'bullish'|'bearish'|'neutral'|'unavailable', strength: 0..1, score_delta: float, components: {...}}`.
2. **`watchtower/engine/confluence.py`** *(modified)* — for each candidate ticker, call `analyze_ticker`, derive thesis direction from the fundamental signal(s), apply `score_delta`, attach the TA note + HOLD flag to the confluence record.
3. **`watchtower/db.py`** *(migration)* — new table `ta_snapshots`:
   `id, ticker, date_analyzed, source('polygon'|'yahoo'), direction, strength, rsi, ema50_state, ema200_state, macd_state, breakout, volume_confirm, score_delta, price_at_analysis, created_at`.
4. **`watchtower/engine/tracker.py`** *(extended)* — record TA verdict + forward return alongside confluence accuracy, so we can later answer "did TA-confirmed signals outperform TA-contradicted ones?"
5. **`config.yaml`** — `technicals:` block: `ema_periods: [50,200]`, `rsi_period: 14`, `rsi_healthy: [45,70]`, `rsi_overbought: 75`, `rsi_oversold: 30`, `breakout_lookback: [20,50]`, `min_candles: 50`, `max_boost: 2`, `max_penalty: 2`, `hold_threshold`, `polygon_rate_limit_per_min: 5`.
6. **`tests/test_technicals.py`** *(new)* — canned OHLCV fixtures (clean uptrend, clean downtrend, breakout-on-volume, overbought, insufficient-data) → asserted verdicts; network mocked. Folds into the existing 47-test suite.

## 6. Scoring Logic (confirm + veto)

- **Thesis direction:** insider 'P' buy = bullish; hiring surge = bullish; hiring contraction = bearish; pred-market divergence / congress = per-domain sign.
- **TA direction** from components:
  - *Bullish:* price > EMA50 and > EMA200 (or reclaiming), RSI in healthy band, MACD bullish, near/above recent high with volume.
  - *Bearish:* price < EMA50 and < EMA200, lower highs, MACD bearish.
  - *Neutral:* mixed / chop.
- **Delta:**
  - aligned + strong → `+max_boost`; aligned + weak → `+1`.
  - neutral → `0`.
  - contradicts (clean trend opposing thesis) → `-penalty`; if resulting score < `hold_threshold` → mark **HOLD** with note `"tape contradicts: <reason>"`.
- **Overbought guard:** bullish thesis + RSI > overbought → cap boost at `0` (don't chase).

## 7. Error Handling (Polygon/Yahoo are best-effort)

- Polygon fail/empty → Yahoo fallback. Yahoo fail or `<min_candles` → `direction='unavailable'`, `score_delta=0`.
- **TA never vetoes on missing/insufficient data** — a fundamental alert is never suppressed because a chart didn't load.
- Polygon free tier ~5 calls/min → throttle the candidate batch (sleep between calls); candidates/day is small.
- All outcomes logged via the run-summary logging shipped in Phase-1 (`run_summary scraper=technicals analyzed=N unavailable=M`).

## 8. Accuracy Tracking

Extend `tracker.py` to capture, per confluence that included a TA verdict: TA direction, score_delta, and forward return at +5d/+20d (using the same Polygon source). Monthly accuracy report gains a TA section: hit-rate of TA-confirmed vs TA-contradicted vs TA-neutral signals. This is the gate before we ever trust TA as more than a tie-breaker. (Cf. the Machine — no signal trusted without honest forward-tested rigor.)

## 9. Integration with the `congress_trades` build

Both this layer and the green-lit congress-trades domain modify `confluence.py`, `db.py` (schema), `scheduler.py`/`config.yaml`, and the SPY-baseline/scoring paths. To avoid merge conflicts they are built on **one branch**, sequenced:
1. Congress-trades domain (new scraper + `congress_trades` table + confluence domain + daily 06:30 UTC job) — per DATA's brief `Owner's Inbox/watchtower-political-trading-signal-2026-06-27.md`.
2. TA confirmation layer (this spec) layered on top of the updated confluence engine.
3. Shared: confluence scoring refactor accommodates both new inputs cleanly; one schema migration adds both `congress_trades` and `ta_snapshots`.

## 10. Secrets / Deploy

- Add `POLYGON_API_KEY` to droplet `/app/watchtower/.env` (chmod 600) from BW item `2959f28e-643f-454f-9aa2-b42f001fc64c` (key is in the **notes** field). Never hardcoded.
- Deploy = RED (production droplet) → Owner approval at deploy time; 10T runs the credentialed deploy (Kit code/commit only), same pattern as Phase-1.

## 11. Testing & Acceptance

- Unit: `test_technicals.py` fixtures green; full suite stays green.
- Integration smoke (post-deploy): run `analyze_ticker` live against a known uptrend + downtrend ticker; confirm Polygon primary works and Yahoo fallback triggers when Polygon key is removed.
- Acceptance: a confluence with a fundamental hit shows a TA note; a contradicting-tape case produces a HOLD; `ta_snapshots` row written; run-summary logs the batch.

## 12. Risks / Caveats

- TA edge is **unproven** until the accuracy tracker accumulates forward returns — TA is a tie-breaker, not gospel, at launch.
- Polygon free tier: EOD/delayed, ~5 calls/min — acceptable for daily cadence; if candidate count grows, revisit a paid tier or Alpaca/Tradier (also in BW).
- Daily candles only — no intraday timing; matches the slow alt-data cadence by design.
- Yahoo fallback is unofficial and may break; that only degrades TA to `unavailable`, never blocks alerts.

## 13. YAGNI (explicitly out of scope)

No trade execution, no broker integration, no TradingView/webhooks, no intraday, no options-chain pricing (Tradier/Alpaca deferred), no per-ticker manual config.
