# Multi-Instrument Dynamic Grid — Design Spec

**Date:** 2026-05-02
**Status:** Approved
**Owner:** Rex (Strategy Lead)
**Project:** The Machine
**Code:** `C:/Users/chris/OneDrive/Documentos/the-machine/`
**Droplet:** `104.131.176.130` container `the-machine` port `8100`

---

## 1. Problem Statement

The grid strategy currently runs on a single instrument (SOL-29MAY26-CDE). When that asset enters a low-volatility regime (BBW percentile drops below threshold), the entire grid pauses and earns nothing. Meanwhile, other crypto assets may have sufficient volatility to run profitable grids.

Additionally, instrument selection — choosing *which* asset to grid — is likely the highest-alpha decision the grid makes. Spacing and level count are mechanical; predicting which asset is about to move enough to fill both sides of a grid is a prediction problem where ML can provide significant edge.

## 2. Goals

1. Run grids on multiple crypto assets simultaneously (starting at 3, scaling with equity)
2. Dynamically scan all available CDE crypto futures and select the best candidates every 4 hours
3. Volatility-weighted capital allocation, evolving into ML-driven allocation
4. Support both CDE dated futures (now) and perpetual futures (when available) seamlessly
5. Full DB persistence for scanner decisions, fill data, and ML feature collection
6. Rock-solid error handling — one grid's failure never affects another

## 3. Non-Goals

- Non-crypto instruments (commodities, indices) — excluded due to trading hours limitations
- Changing the core grid mechanics (ATR spacing, VWAP centering, counter-order logic)
- Replacing the existing single-grid deployment — this extends it

---

## 4. Architecture Overview

```
Scanner (new)
  |-- Every 4h: rank all CDE crypto assets by volatility score
  |-- Pick top N (equity-dependent, starting at 3)
  |-- Respect protection rule (no mid-cycle rotation)
  |-- Log decisions to scanner_snapshots table
  |-- Pass selected instruments to Grid Manager
  v
Grid Manager (new)
  |-- Maintains N AdaptiveGridStrategy instances
  |-- Creates/destroys instances on rotation
  |-- Splits capital via volatility-weighted allocation
  |-- Feeds per-grid allocation_usd to each instance
  |-- Tracks all instances in grid_instances table
  v
AdaptiveGridStrategy (existing, minor changes)
  |-- Already accepts instrument parameter
  |-- Add: product_type tag (dated vs perp)
  |-- Add: sizing dispatcher (CDE contracts vs perp base_size)
  |-- Log fills to grid_fills table
  |-- Everything else unchanged
  v
ML Pipeline (new, passive at first)
  |-- Feature logger: snapshots market state + scanner decisions
  |-- Outcome logger: fill rates, cycle P&L, time-to-fill per asset
  |-- Phase 1: pure data collection (no influence on decisions)
  |-- Phase 2: instrument selector model (once threshold met)
  |-- Phase 3: capital allocator model (refines volatility weighting)
```

---

## 5. Scanner — Instrument Selection

### 5.1 Scan Cycle (every 4 hours)

1. Fetch list of all CDE crypto products from Coinbase API
2. For each product, fetch 4h and 1h candle data
3. Compute volatility score per asset:
   - BBW percentile (Bollinger Band Width vs 90-day lookback)
   - ATR as percentage of price (normalized volatility)
   - 24h USD volume
   - Bid-ask spread in basis points
4. Filter out ineligible assets:
   - BBW percentile < `GRID_BBW_PAUSE_PERCENTILE` (currently 10)
   - 24h volume below minimum threshold (configurable)
   - Spread > max threshold in basis points (configurable)
   - Candle data older than 30 minutes (stale data guard)
5. Rank eligible assets by composite volatility score
6. Select top N (see Section 8 for equity-based scaling)

### 5.2 Composite Volatility Score

```
score = (bbw_percentile_normalized * 0.35)
      + (atr_pct_normalized * 0.35)
      + (volume_normalized * 0.20)
      + (inverse_spread_normalized * 0.10)
```

All components normalized to 0-1 range across the candidate pool. Weights are initial heuristic — ML Phase 2 replaces this with a learned model.

### 5.3 Rotation Logic

After ranking, compare selected assets to currently running grids:

- **Asset already running, still in top N:** Keep. No action.
- **Asset already running, fell out of top N, has open counter-orders:** Keep until cycle completes (protection rule). Mark as "draining".
- **Asset already running, fell out of top N, no open position:** Rotate out. Cancel all orders, destroy grid instance, record in DB.
- **New asset entered top N, slot available:** Create new grid instance, allocate capital, build grid.
- **New asset entered top N, no slot (all slots occupied by protected grids):** Queue. Will be created when a draining grid completes.

### 5.4 Force-Rotate on Pause

If an active grid gets BBW-paused mid-cycle, its orders are already cancelled by the existing filter logic. This makes it immediately swap-eligible — no protection rule needed since there are no open orders.

### 5.5 Scanner Failure Mode

If the scanner itself fails (API error, timeout):
- All existing grids keep running on their current instruments unchanged
- No rotation actions taken
- Error logged, alert sent
- Retry on next 4h cycle

---

## 6. Grid Manager

### 6.1 Responsibilities

- Maintains a registry of active `AdaptiveGridStrategy` instances
- Creates new instances when scanner selects new instruments
- Destroys instances when scanner rotates out instruments
- Computes per-grid capital allocation (volatility-weighted)
- Wires each instance into the APScheduler tick loop
- Exposes all instances to the dashboard endpoint

### 6.2 Capital Allocation — Phase 1 (Volatility-Weighted)

Total grid capital = `equity * allocations["grid"]`

Each selected asset receives capital proportional to its volatility score:

```
weight_i = score_i / sum(all_selected_scores)
allocation_i = total_grid_capital * weight_i
```

Constraints:
- **Floor:** No asset gets less than 15% of grid allocation (prevents dust positions)
- **Ceiling:** No asset gets more than 50% of grid allocation (prevents over-concentration)
- After applying floor/ceiling, remaining capital redistributed proportionally

### 6.3 Capital Allocation — Phase 2 (ML-Refined)

Once ML model is active (see Section 9):

```
ml_weight_i = volatility_weight_i * ml_confidence_multiplier_i
allocation_i = total_grid_capital * (ml_weight_i / sum(all_ml_weights))
```

Same floor/ceiling constraints apply. ML can shift weights within bounds but never override protection rules or risk limits.

### 6.4 Pre-Order Capital Verification

Before every order placement across any grid instance:
1. Sum total notional exposure across all active grids
2. Verify total does not exceed `equity * MAX_LEVERAGE_GRID`
3. If it would exceed, reject the order, log warning
4. This is a hard stop — no exceptions

---

## 7. AdaptiveGridStrategy Changes

### 7.1 Product Type Tag

Each grid instance carries a `product_type` field:
- `"dated"` — CDE dated futures (e.g., `SOL-29MAY26-CDE`)
- `"perp"` — Perpetual futures (e.g., `SOL-PERP-INTX`)

### 7.2 Sizing Dispatcher

Order sizing branches on product type:
- `dated`: Use existing `cde_contracts_to_base_size()` — returns contract count
- `perp`: Use base_size calculation — returns asset quantity

This is the only behavioral difference. All other grid logic (construction, fill detection, counter-orders, filters) is identical for both types.

### 7.3 Fill Logging

On every fill, write a record to `grid_fills` table:
- Entry side, price, time
- Counter-order price
- Counter fill time and cycle P&L (backfilled when counter fills)
- Cycle duration in seconds

### 7.4 Backward Compatibility

If `GridManager` is not present (e.g., existing single-instrument deployment on droplet), the grid behaves exactly as it does today. The `instrument` parameter defaults to `cfg.GRID_INSTRUMENT`. Zero breaking changes.

---

## 8. Equity-Based Scaling

| Equity Range | Max Simultaneous Grids | Min Per-Grid Capital |
|-------------|----------------------|---------------------|
| < $500 | 1 | $250 |
| $500 - $999 | 2 | $250 |
| $1,000 - $1,999 | 3 | $300 |
| $2,000 - $4,999 | 4 | $400 |
| $5,000+ | 5 | $500 |

The scanner reads current equity at each 4h cycle and determines `max_grids` from this table. If equity drops (drawdown), grid count reduces — the lowest-scoring grid is rotated out first.

Min per-grid capital ensures enough for meaningful grid levels (at least 4-5 levels per grid). If `total_grid_allocation / max_grids < min_per_grid`, reduce `max_grids` by 1.

---

## 9. ML Pipeline

### 9.1 Phase 1 — Data Collection (starts day one)

No influence on decisions. Pure logging.

**Features logged per scan cycle (`ml_features` table):**
- All asset volatility scores (BBW, ATR %, volume, spread)
- Which assets were selected and why (scanner decision)
- Current market regime indicators (overall crypto vol, BTC dominance)
- Correlation between selected assets
- Time of day / day of week

**Outcomes logged per grid cycle (`grid_fills` table):**
- Fill rate (fills per hour per asset)
- Average cycle time (entry fill to counter fill)
- Cycle P&L per asset
- Slippage on any emergency closes

**Outcome backfill:** After each 4h scan cycle, the previous cycle's `ml_features` rows get their `outcome_pnl_4h` and `outcome_fills_4h` columns filled in. This creates labeled training data: "given these features, this is what happened."

### 9.2 Phase 2 — Instrument Selector Model

**Activation threshold:** 500 total grid fills across all instruments (matches existing `ML_MIN_GRID_FILLS`)

**Model:** Learns to predict which assets will have the highest fill rate and cycle P&L in the next 4h window, given current market features.

**Integration:** Replaces the composite volatility score (Section 5.2) with ML predictions. Scanner still applies the same filters (BBW minimum, volume minimum, spread maximum) — ML only influences ranking among eligible assets.

**Guardrail:** ML predictions are blended with the heuristic score:
```
final_score = (ml_score * ml_blend_weight) + (heuristic_score * (1 - ml_blend_weight))
```
`ml_blend_weight` starts at 0.0 (pure heuristic) and ramps up weekly, capping at 0.80 — heuristic always retains 20% influence as a safety net.

**Ramp-up rules:**
- Each week, compare ML-selected instruments vs heuristic-selected instruments over the prior 7 days
- If ML selections produced higher total fill rate AND higher total cycle P&L than heuristic would have: increase `ml_blend_weight` by `ML_BLEND_WEIGHT_INCREMENT` (0.20)
- If ML selections underperformed heuristic: decrease `ml_blend_weight` by the same increment (floor at 0.0)
- If comparable (within 10%): no change
- This is evaluated once per week at the same time as the weekly grid rebuild (Sunday 00:10 UTC)

### 9.3 Phase 3 — Capital Allocator Model

**Activation threshold:** 1000 total grid fills + Phase 2 running for at least 4 weeks

**Model:** Given the selected instruments, predicts optimal capital weighting. Learns which assets convert volatility into actual completed grid cycles most efficiently.

**Integration:** Replaces equal-start volatility weighting (Section 6.2) with ML-driven weights. Same floor (15%) and ceiling (50%) constraints apply.

---

## 10. Contract Rolling (CDE Dated Futures)

CDE dated futures expire monthly. The Grid Manager handles rolling:

1. **T-48h before expiry:** Stop opening new grid levels on the expiring contract. Existing levels continue to operate.
2. **T-24h before expiry:** Cancel all remaining open orders on the expiring contract. Close any open positions at market.
3. **On expiry:** Scanner automatically discovers the next month's contract (e.g., `SOL-29MAY26-CDE` becomes `SOL-26JUN26-CDE`). If the asset is still in the top N, a new grid instance is created on the new contract.

Contract expiry dates are parsed from the product ID (format: `ASSET-DDMMMYY-CDE`).

When perps become available, they have no expiry — no rolling needed. The scanner simply tags them as `product_type: "perp"` and they're always eligible.

---

## 11. Perps + CDE Unified Handling

The scanner treats both product types as eligible candidates in the same pool:

1. **Discovery:** Scanner queries Coinbase API for all crypto products with `product_type` in (`FUTURE`, `PERPETUAL`)
2. **Tagging:** Each product gets tagged as `dated` or `perp` based on its type
3. **Scoring:** Same volatility scoring applies to both. No preference for one type over the other.
4. **Selection:** Top N selected regardless of type. Could be all perps, all dated, or mixed.
5. **Instance creation:** Grid Manager passes `product_type` to `AdaptiveGridStrategy`, which uses the appropriate sizing dispatcher.

**Perps advantages when available:**
- No contract rolling needed
- No expiry risk
- Funding rate data available (could inform grid placement)

**Current state:** Perps API returns 403 (Coinbase bug #125, open since 2026-03-10). Perpetual-style futures announced for July 21, 2026. When either the bug is fixed or July launch happens, perps automatically enter the candidate pool — no code change needed.

---

## 12. Database Schema

All tables use the existing SQLAlchemy engine from `models.py`.

### 12.1 `scanner_snapshots`

Records every 4h scan cycle decision.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| id | INTEGER | PK, autoincrement | |
| timestamp | TEXT | NOT NULL, indexed | Scan time (UTC ISO 8601) |
| total_equity | REAL | NOT NULL | Equity at scan time |
| max_grids | INTEGER | NOT NULL | Allowed grid count (from scaling table) |
| selected_instruments | TEXT (JSON) | NOT NULL | Instruments picked + scores + reasons |
| all_scores | TEXT (JSON) | NOT NULL | Full ranking of every asset scanned |
| rotation_actions | TEXT (JSON) | NOT NULL | What was swapped in/out, with reasons |
| scan_duration_ms | INTEGER | | How long the scan took |

### 12.2 `grid_instances`

Tracks each grid instance lifecycle.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| id | INTEGER | PK, autoincrement | |
| instrument | TEXT | NOT NULL, indexed | Product ID |
| product_type | TEXT | NOT NULL | "dated" or "perp" |
| started_at | TEXT | NOT NULL | When this grid was created |
| ended_at | TEXT | nullable | When rotated out (null if active) |
| end_reason | TEXT | nullable | "rotated", "paused", "expiry", "equity_drop" |
| allocation_usd | REAL | NOT NULL | Capital assigned |
| allocation_weight | REAL | NOT NULL | Volatility weight (0.0-1.0) |
| total_fills | INTEGER | NOT NULL, default 0 | Lifetime fills for this instance |
| total_cycles | INTEGER | NOT NULL, default 0 | Completed buy-sell cycles |
| total_pnl | REAL | NOT NULL, default 0.0 | Lifetime P&L |

### 12.3 `grid_fills`

Every individual fill and cycle.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| id | INTEGER | PK, autoincrement | |
| instance_id | INTEGER | FK -> grid_instances, indexed | Which grid |
| instrument | TEXT | NOT NULL | Product ID |
| entry_side | TEXT | NOT NULL | "buy" or "sell" |
| entry_price | REAL | NOT NULL | Fill price |
| entry_time | TEXT | NOT NULL | When filled (UTC) |
| entry_order_id | TEXT | NOT NULL | Coinbase order ID |
| counter_price | REAL | nullable | Counter-order price |
| counter_order_id | TEXT | nullable | Counter-order Coinbase ID |
| counter_fill_time | TEXT | nullable | When counter filled |
| cycle_pnl | REAL | nullable | Profit from completed cycle |
| cycle_duration_sec | INTEGER | nullable | Seconds between entry and counter fill |
| status | TEXT | NOT NULL, default "pending" | "pending", "completed", "cancelled", "expired" |

### 12.4 `ml_features`

Feature snapshots for ML training. One row per asset per scan cycle.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| id | INTEGER | PK, autoincrement | |
| snapshot_id | INTEGER | FK -> scanner_snapshots | Links to scan cycle |
| timestamp | TEXT | NOT NULL, indexed | Snapshot time |
| instrument | TEXT | NOT NULL, indexed | Asset |
| bbw_percentile | REAL | NOT NULL | Bollinger Band Width percentile |
| atr_pct | REAL | NOT NULL | ATR as % of price |
| volume_24h | REAL | NOT NULL | 24h USD volume |
| spread_bps | REAL | NOT NULL | Bid-ask spread in basis points |
| adx_4h | REAL | | ADX value |
| btc_dominance | REAL | | BTC market dominance % |
| total_crypto_vol | REAL | | Overall crypto market vol proxy |
| fill_rate_1h | REAL | | Recent fills per hour for this asset |
| was_selected | INTEGER | NOT NULL | 1 if scanner picked this asset, 0 if not |
| allocation_weight | REAL | | Weight assigned (0 if not selected) |
| outcome_pnl_4h | REAL | nullable | P&L over next 4h (backfilled) |
| outcome_fills_4h | INTEGER | nullable | Fill count over next 4h (backfilled) |
| outcome_cycle_completions_4h | INTEGER | nullable | Completed cycles over next 4h (backfilled) |

---

## 13. Error Handling

### 13.1 Per-Grid Isolation

Each `AdaptiveGridStrategy` instance operates independently. Errors in one grid never propagate to others:
- API failures: retried per-instance with exponential backoff (3 retries, 2s/4s/8s)
- If all retries fail: grid pauses itself, logs error, sends alert. Other grids unaffected.
- Exception boundaries at Grid Manager level — each grid tick is wrapped in try/except

### 13.2 Sizing Validation

Before every order:
1. Validate contract size is positive and within expected bounds
2. Validate price is positive and within 10% of last known price (sanity check)
3. Validate total exposure across all grids does not exceed leverage limits
4. If any validation fails: skip this order, log error with full context, continue

### 13.3 Scanner Resilience

- If candle fetch fails for one asset: exclude from ranking, continue with others
- If candle fetch fails for all assets: abort scan, keep existing grids, retry next cycle
- If Coinbase product list API fails: use cached product list from last successful fetch
- Stale data guard: candle data older than 30 minutes marks asset as ineligible

### 13.4 Rotation Atomicity

Rotation is atomic per-asset:
1. Cancel all orders on outgoing asset
2. Verify cancellation (check order statuses)
3. Create new grid instance on incoming asset
4. If step 3 fails: log error, slot remains empty until next scan cycle
5. Never partially rotate — old is fully torn down before new is created

### 13.5 Capital Accounting

- Grid Manager maintains a running total of allocated capital across all instances
- Before any allocation change, verify: `sum(all_allocations) <= total_grid_capital`
- On mismatch: log error, recalculate from scratch, alert owner
- Daily reconciliation job: compare expected positions (from DB) against actual Coinbase positions

### 13.6 Dashboard Exposure

Grid Manager exposes all active instances to the existing `/api/v1/dashboard` endpoint:
- Each grid shows: instrument, product_type, allocation, daily P&L, active levels, paused status
- Scanner section shows: last scan time, all scores, rotation history
- ML section shows: current phase, data collection stats, model confidence (when active)

---

## 14. Configuration (new config.py entries)

```python
# -- Multi-Instrument Grid Scanner ---
GRID_SCANNER_INTERVAL_HOURS: int = 4
GRID_SCANNER_MIN_VOLUME_24H: float = 100_000.0    # $100k minimum volume
GRID_SCANNER_MAX_SPREAD_BPS: float = 50.0          # 50 bps max spread
GRID_SCANNER_STALE_DATA_MINUTES: int = 30
GRID_MAX_SIMULTANEOUS: int = 3                      # Starting max (overridden by equity scaling)
GRID_MIN_PER_GRID_CAPITAL: float = 250.0            # Minimum capital per grid instance
GRID_ALLOCATION_FLOOR: float = 0.15                 # 15% minimum weight per grid
GRID_ALLOCATION_CEILING: float = 0.50               # 50% maximum weight per grid

# -- Volatility Score Weights (Phase 1 heuristic) ---
GRID_SCORE_WEIGHT_BBW: float = 0.35
GRID_SCORE_WEIGHT_ATR: float = 0.35
GRID_SCORE_WEIGHT_VOLUME: float = 0.20
GRID_SCORE_WEIGHT_SPREAD: float = 0.10

# -- Contract Rolling ---
GRID_ROLL_WARNING_HOURS: int = 48                   # Stop new levels 48h before expiry
GRID_ROLL_CLOSE_HOURS: int = 24                     # Force close 24h before expiry

# -- ML Integration ---
ML_MIN_GRID_FILLS_SELECTOR: int = 500               # Phase 2 activation (instrument selector)
ML_MIN_GRID_FILLS_ALLOCATOR: int = 1000             # Phase 3 activation (capital allocator)
ML_SELECTOR_MIN_WEEKS: int = 4                      # Phase 3 requires Phase 2 running 4+ weeks
ML_BLEND_WEIGHT_INCREMENT: float = 0.20             # Max 20% blend increase per week
ML_BLEND_WEIGHT_CAP: float = 0.80                   # Heuristic always retains 20%

# -- Equity Scaling ---
GRID_SCALE_TIERS: list = [
    {"min_equity": 0,    "max_grids": 1, "min_capital": 250},
    {"min_equity": 500,  "max_grids": 2, "min_capital": 250},
    {"min_equity": 1000, "max_grids": 3, "min_capital": 300},
    {"min_equity": 2000, "max_grids": 4, "min_capital": 400},
    {"min_equity": 5000, "max_grids": 5, "min_capital": 500},
]
```

---

## 15. New Files

| File | Purpose |
|------|---------|
| `src/strategies/grid_scanner.py` | Scanner: fetches all CDE crypto products, computes scores, selects top N |
| `src/strategies/grid_manager.py` | Grid Manager: maintains N grid instances, handles rotation, capital allocation |
| `src/ml/instrument_selector.py` | ML Phase 2: instrument selection model (training + inference) |
| `src/ml/capital_allocator.py` | ML Phase 3: capital allocation model (training + inference) |

### Modified Files

| File | Changes |
|------|---------|
| `src/strategies/adaptive_grid.py` | Add `product_type` field, sizing dispatcher, fill logging to DB |
| `src/models.py` | Add 4 new tables (scanner_snapshots, grid_instances, grid_fills, ml_features) |
| `src/main.py` | Replace single grid instance with Grid Manager, add scanner to scheduler |
| `src/config.py` | Add new configuration entries (Section 14) |
| `src/monitoring/dashboard.py` or `main.py` dashboard route | Expose multi-grid data |
| `src/exchange/coinbase_client.py` | Add `list_crypto_futures()` method for scanner product discovery |

---

## 16. Testing Strategy

- **Unit tests:** Scanner scoring, rotation logic, capital allocation math, sizing dispatcher, equity scaling
- **Integration tests:** Grid Manager lifecycle (create, rotate, destroy instances), DB persistence, fill logging
- **Edge cases:** Scanner returns 0 eligible assets, equity drops mid-cycle forcing grid reduction, all grids BBW-paused simultaneously, contract expiry during active cycle, API failures during rotation
- **Paper mode:** Full system runs in paper mode before any live deployment. Paper mode uses the same scanner and Grid Manager but routes orders through the existing paper trading module.

---

## 17. Rollout Plan

1. **Deploy in paper mode** alongside existing live single-grid — verify scanner picks reasonable assets, rotation works, DB fills up
2. **Monitor for 48-72h** — review scanner decisions, check for error patterns
3. **Switch live** — replace single grid with Grid Manager on droplet
4. **ML Phase 1 begins automatically** — data collection from day one
5. **ML Phase 2 activates** — after 500 fills, instrument selector starts influencing
6. **ML Phase 3 activates** — after 1000 fills + 4 weeks, capital allocator joins
