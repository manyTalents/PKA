# Edge — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->

### 2026-05-04: Order Response success:false Does NOT Throw an Exception
- **Category:** execution / order-management
- **Lesson:** Coinbase order responses can return `success:false` without raising any exception; you must explicitly check the response field or orders will silently fail.
- **Context:** The grid placed orders with fractional CDE contract sizes. Every order returned `success:false` but the code never threw an error. The result: empty order_ids were stored, and `get_order("")` then spammed 404 errors 40+ times per tick. Fix: added `_order_succeeded()` method that explicitly validates the order response before storing the order_id. Any `success:false` is now logged and the order is treated as failed.
- **Keywords:** order-response, success-false, silent-failure, validation, coinbase, exception, order_succeeded

### 2026-05-20: Partial Fills — Use Executed Volume, Not Original
- **Category:** execution / order-management
- **Lesson:** When placing counter-orders (closing a position), always use the actually executed volume (`vol_exec`), not the original requested volume; partial fills mean the position size differs from what was ordered.
- **Context:** Grid exit orders were sized using the original entry volume, but some entries were partially filled. The exit order size exceeded the actual position, causing order rejections or unintended new positions on the other side. Fix: counter-orders now reference `vol_exec` from the fill record.
- **Keywords:** partial-fill, vol_exec, counter-order, position-size, exit-order, volume

### 2026-05-11: No Built-In Rate Limiter in Exchange Client
- **Category:** execution / api-safety
- **Lesson:** The Coinbase exchange client has no built-in rate limiter; without an external circuit breaker, a bug in retry logic can exhaust the daily API quota in minutes.
- **Context:** The self-DOS incident (10,000+ requests in minutes) proved that the exchange client will happily send unlimited requests. Rate limiting must be implemented externally — either as a circuit breaker wrapper around the client or as a request-counting gate. Fix: circuit breaker pattern with max retries (3), exponential backoff, and a 60-second cooldown persisted to disk.
- **Keywords:** rate-limiter, circuit-breaker, exchange-client, coinbase, api-quota, self-dos

### 2026-05-04: Price Rounding Must Use price_increment, Not quote_increment
- **Category:** execution / order-management
- **Lesson:** For CDE futures, `price_increment` is the real tick size for order prices; `quote_increment` is a different field that will cause orders to be rejected if used for rounding.
- **Context:** Orders were rejected because prices were rounded to `quote_increment` instead of `price_increment`. The two fields have different values on CDE products. Fix: `_round_price()` now fetches and uses `price_increment` from the product spec (cached 1 hour via `get_product_spec()`).
- **Keywords:** price_increment, quote_increment, tick-size, rounding, cde, order-rejection, product-spec

### 2026-05-12: Test Rewrites in Paper Mode Before Deploying to Production
- **Category:** execution / deployment
- **Lesson:** Any code change that touches order placement, margin checking, or strategy selection must be tested in paper mode before going live; deploying a rewrite directly to production caused a 15-hour stall with zero fills.
- **Context:** A 4-module grid rewrite replacing a 962-line monolith was deployed directly to production. Five cascading failures occurred: config mismatches, wrong margin math (notional vs margin cost), dashboard breakage, scanner-grid disconnect. All would have been caught in 48 hours of paper testing. Fix: the bot has `MODE=paper` — use it. Keep the old working code live while the new code proves itself in paper.
- **Keywords:** paper-mode, testing, rewrite, deploy, production, stall, margin, cascading-failure

---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->

- **`_order_succeeded()` explicit validator:** Check `response.success` field before storing order_id. Log full response body on failure.
- **`get_product_spec()` with 1hr cache:** Returns contract_size, base_increment, price_increment for any product. Single source of truth for order sizing and rounding.
- **Circuit breaker wrapper:** Track consecutive failures, enforce max retries (3), exponential backoff, cooldown timestamp on disk.

---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->

- Order-response audit log that captures every API response (success or failure) for post-session review
- Paper-mode smoke test script that places 5 orders across all active instruments and validates responses before switching to live

---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

- **Explicit order response validation required:** Never assume an order succeeded because no exception was thrown. Always check the response status field. Seen in CDE sizing bug (2026-05-04).
- **Paper mode before production for all trading code changes:** Any PR touching order logic must include paper-mode test results. Seen in grid rewrite stall (2026-05-12).
