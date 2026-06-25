# Onyx — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->

### 2026-04-27: Kraken US Has No Margin or Shorting
- **Category:** strategy / exchange-constraints
- **Lesson:** Kraken US accounts cannot margin trade or short; strategies requiring short exposure must be redesigned for long-only or relative-value rotation.
- **Context:** Strategy E (crypto portfolio) was designed with short legs for hedging. Kraken US regulatory restrictions block all margin and shorting. The strategy was redesigned to relative value rotation (overweight/underweight across long positions only). This constraint applies to ALL Kraken US strategies going forward.
- **Keywords:** kraken, margin, shorting, long-only, regulatory, strategy-e, rotation, us-restrictions

### 2026-05-04: CDE Product Specs — price_increment Is the Real Tick Size
- **Category:** execution / exchange-specs
- **Lesson:** On Coinbase CDE futures, `price_increment` is the actual minimum price step for orders; `quote_increment` is a different field and will cause rejections if used for order pricing.
- **Context:** Orders were rejected because prices were rounded to `quote_increment` instead of `price_increment`. These are different values on CDE products. The fix was to fetch the product spec via `get_product_spec()` (cached 1 hour) and use `price_increment` for all price rounding.
- **Keywords:** cde, price_increment, quote_increment, tick-size, product-spec, coinbase, futures

### 2026-05-04: CDE Orders Must Be Integer Contract Counts
- **Category:** execution / exchange-specs
- **Lesson:** CDE futures have `base_increment=1` and `base_min_size=1` — all order quantities must be whole integers; fractional sizes return `success:false` silently.
- **Context:** The grid computed fractional base sizes (e.g., "0.000297") because it divided dollar allocation by price. CDE products represent fixed-size contracts (BIT=0.01 BTC, ET=0.1 ETH, SOL=5 SOL). Orders must specify integer contract counts. Fractional sizes silently fail. Fix: `_compute_order_qty()` converts dollar allocation to integer contract count using `contract_size * price`.
- **Keywords:** cde, integer, contract-count, base_increment, base_min_size, fractional, silent-failure, contract-size

### 2026-04-27: Coinbase Perps API 403 Bug — CDE Workaround (GitHub #125)
- **Category:** exchange / api-bugs
- **Lesson:** Coinbase perpetual futures (INTX) endpoints return 403 PERMISSION_DENIED for all operations despite correct API key permissions; dated futures (CDE) work fine as a workaround.
- **Context:** All INTX perp endpoints (orders, portfolio, positions, balances) return 403 even with View+Trade+Transfer+Receive permissions. The user can trade perps through the web UI — only the API is broken. GitHub issue #125 (coinbase/coinbase-advanced-py) open since 2026-03-10, no fix as of 2026-05-24. The Machine was retooled to use CDE dated futures. Funding rate strategy disabled (requires perps). Check every session for resolution.
- **Keywords:** perps, intx, 403, permission-denied, coinbase, api-bug, cde-workaround, github-125

### 2026-05-04: CDE Contract Dollar Values for Position Sizing
- **Category:** exchange / position-sizing
- **Lesson:** Know the dollar value per contract for each CDE product to properly size positions at low equity levels.
- **Context:** At $950 equity, instrument affordability matters. BIT contract = 0.01 BTC (~$800), ET contract = 0.1 ETH (~$235), SOL contract = 5 SOL (~$420). The scanner must filter instruments by whether the minimum contract cost fits within the per-level budget. Without this filter, the grid selects instruments it cannot afford and produces zero fills.
- **Keywords:** contract-value, position-sizing, affordability, scanner, budget, cde, bit, et, sol

---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->

- **`get_product_spec()` with cache:** Single function that returns contract_size, base_increment, price_increment for any CDE product. 1-hour cache. Source of truth for all sizing and rounding.
- **Affordability filter in scanner:** Rejects instruments where `contract_size * price > per_level_budget` before selecting for the grid.
- **Contract rollover monitoring:** Check expiry dates on dated futures and roll to next month contract when <10 days remain. Verify volume exists on the new contract first.

---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->

- Auto-rollover script that checks CDE contract expiry dates daily and alerts when a position's contract is <14 days from expiry
- Exchange spec cache that refreshes product parameters (base_increment, price_increment, contract_size) daily and flags any changes

---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

- **Fetch and cache product specs before trading:** Never hardcode tick sizes, contract sizes, or minimum quantities. Always query the exchange for product specs and cache them. Seen in CDE sizing bug (2026-05-04) and price rounding bug (2026-05-04).
