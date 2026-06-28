# Watchtower Congress-Trades + TA Confirmation Layer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new inputs to the live Watchtower confluence engine — a `congress_trades` fundamental domain (House/Senate disclosed buys) and a technical-analysis confirmation layer that scores price/timing on any candidate ticker — built on one branch to avoid conflicts in the shared confluence/schema/scoring files.

**Architecture:** Both features extend the existing scraper→table→confluence pipeline on droplet `104.131.176.130`. Congress trades land in a new `political_trades` table and feed confluence as a fundamental domain. The TA layer is a pure on-demand function the confluence engine calls per candidate ticker to boost/veto the score. One schema migration adds both `political_trades`/`member_performance` and `ta_snapshots`. No new external service, no execution, $0.

**Tech Stack:** Python 3.11, SQLite (WAL), APScheduler, `requests`, smtplib; Polygon REST (primary price), Yahoo Finance chart API (fallback); House Clerk bulk ZIP/XML + PTR PDFs; pytest.

## Global Constraints

- **Repo:** `Documentos/watchtower` (own git repo). Branch off current `master` HEAD; ONE branch `feat/congress-trades-ta` for both phases.
- **No new pip deps unless unavoidable** — prefer stdlib + existing `requests`. If PDF parsing needs a lib, use `pdfplumber` only if not already vendored; flag it in the deploy manifest.
- **Secrets via env only** — `POLYGON_API_KEY` from BW `2959f28e-643f-454f-9aa2-b42f001fc64c` (notes field). Never hardcode. Added to droplet `/app/watchtower/.env` (chmod 600) at deploy.
- **Polite scraping** — real User-Agent, ≤1 req/sec to gov sources, cache the daily House ZIP, dedup on unseen DocIDs only.
- **Accuracy anchored at DISCLOSURE date** for congress (never trade date). TA never vetoes on missing data.
- **Tests must stay green** — current suite is 47/47; every task adds tests and keeps the whole suite green.
- **Deploy = RED** — Owner approval at deploy time; 10T runs the credentialed deploy, Kit code/commit only (per VEOE/Phase-1 pattern).
- **TDD** — failing test first, minimal impl, green, commit. Frequent commits.

---

## File Structure

**Phase A — congress_trades (fundamental domain):**
- Create `watchtower/scrapers/political_trades.py` — fetch House (Senate Phase 1b), parse, store, threshold-alert, hand to confluence.
- Create `watchtower/engine/member_ranking.py` — compute trailing-12m dollar-weighted alpha vs SPY, build watchlist.
- Modify `watchtower/db.py` — add `political_trades` + `member_performance` tables (one migration with Phase B tables).
- Modify `watchtower/engine/confluence.py` — register `congress_trades` domain.
- Modify `watchtower/engine/scheduler.py` — `political_trades_daily` 06:30 UTC; monthly member-alpha recompute on existing accuracy job.
- Modify `config.yaml` — `political_trades:` block.
- Create `tests/test_political_trades.py`, `tests/test_member_ranking.py`.

**Phase B — TA confirmation layer:**
- Create `watchtower/engine/technicals.py` — `analyze_ticker()` + indicator helpers + Polygon/Yahoo fetch.
- Modify `watchtower/db.py` — add `ta_snapshots` table (same migration as Phase A).
- Modify `watchtower/engine/confluence.py` — call `analyze_ticker` per candidate, apply confirm/veto delta.
- Modify `watchtower/engine/tracker.py` — log TA verdict + forward return.
- Modify `config.yaml` — `technicals:` block.
- Create `tests/test_technicals.py`.

**Phase C — integration + deploy.**

---

## PHASE A — congress_trades domain

### Task A1: Schema migration (both phases' tables)

**Files:**
- Modify: `watchtower/db.py` (add `_migrate` entries)
- Test: `tests/test_db.py` (extend)

**Interfaces:**
- Produces: tables `political_trades`, `member_performance`, `ta_snapshots` (DDL from design spec §5 and TA spec §5). Idempotent `CREATE TABLE IF NOT EXISTS` + `PRAGMA user_version` bump.

- [ ] **Step 1: Write failing test** — assert the three tables exist after `init_db` and have the expected columns.

```python
def test_new_tables_exist(tmp_path):
    db = str(tmp_path / "t.db"); init_db(db)
    import sqlite3; c = sqlite3.connect(db)
    cols = {t: {r[1] for r in c.execute(f"PRAGMA table_info({t})")} for t in
            ["political_trades", "member_performance", "ta_snapshots"]}
    assert "disclosure_date" in cols["political_trades"]
    assert "alpha_disclosure_dw" in cols["member_performance"]
    assert "score_delta" in cols["ta_snapshots"]
```

- [ ] **Step 2: Run — expect FAIL** (`no such table`). `pytest tests/test_db.py::test_new_tables_exist -v`
- [ ] **Step 3: Implement** — add the three `CREATE TABLE IF NOT EXISTS` blocks (verbatim DDL from specs) to the migration path in `db.py`; bump `user_version`.
- [ ] **Step 4: Run — expect PASS.** Then run full suite: `pytest -q` → 48+ green.
- [ ] **Step 5: Commit** — `feat(watchtower): schema for political_trades, member_performance, ta_snapshots`

### Task A2: House PTR fetch + parse

**Files:**
- Create: `watchtower/scrapers/political_trades.py`
- Test: `tests/test_political_trades.py`

**Interfaces:**
- Produces: `fetch_house_ptrs(year:int, http=requests) -> list[dict]` returning rows with keys matching `political_trades` columns (`source='house'`, `doc_id`, `member_name`, `ticker`, `txn_type`, `txn_date`, `disclosure_date`, `amount_min/max/mid`, `owner`, `filing_url`). Network injected via `http` param for mocking.
- Consumes: nothing from other tasks.

- [ ] **Step 1: Write failing test** with a canned `2026FD.xml` fixture (3 filings) + a stub PTR table; mock `http.get` to return the fixture bytes. Assert parsing yields a buy row with correct `amount_mid` (bracket midpoint) and `disclosure_date`.

```python
def test_house_parse_amount_midpoint(monkeypatch):
    rows = fetch_house_ptrs(2026, http=FakeHTTP(FIXTURE_ZIP))
    buy = next(r for r in rows if r["txn_type"] == "P")
    assert buy["amount_min"] == 1001 and buy["amount_max"] == 15000
    assert buy["amount_mid"] == 8000
    assert buy["disclosure_date"]  # non-empty, ISO
```

- [ ] **Step 2: Run — expect FAIL** (function missing).
- [ ] **Step 3: Implement** `fetch_house_ptrs`: GET `disclosures-clerk.house.gov/public_disc/financial-pdfs/<YEAR>FD.zip`, unzip, parse `<YEAR>FD.xml` for DocIDs/FilingType/name/date, fetch PTR detail per new DocID, map STOCK Act brackets → `amount_mid`. Real UA, ≤1 req/sec. Bracket table from brief §3.
- [ ] **Step 4: Run — expect PASS.** Full suite green.
- [ ] **Step 5: Commit** — `feat(watchtower): House Clerk PTR fetch + bracket parsing`

### Task A3: Store with dedup

**Files:** Modify `political_trades.py`; Test `tests/test_political_trades.py`

**Interfaces:**
- Produces: `store_trades(conn, rows) -> list[dict]` (returns only newly-inserted rows; uses `INSERT OR IGNORE` on `UNIQUE(source,doc_id,ticker,txn_date,amount_min,owner)` + `raw_hash`).

- [ ] **Step 1: Failing test** — insert same row twice, assert second call returns `[]` and table count stays 1.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** `store_trades` with `raw_hash = sha256(repr(row))` secondary dedup.
- [ ] **Step 4: PASS** + suite green.
- [ ] **Step 5: Commit** — `feat(watchtower): political_trades idempotent store`

### Task A4: Member alpha ranking + watchlist

**Files:**
- Create: `watchtower/engine/member_ranking.py`
- Test: `tests/test_member_ranking.py`

**Interfaces:**
- Consumes: `tracker.price_on_date(ticker, date)` and `tracker.spy_return(start, end)` (existing Yahoo helpers).
- Produces: `recompute_member_performance(conn, price_on_date, spy_return, now_date) -> None` (writes `member_performance`, dollar-weighted disclosure-anchored alpha, ≥5-buy floor, top 15–20 `is_watchlist=1`); `load_watchlist(conn) -> set[str]` (bioguide_ids); `seed_watchlist(conn)` (the 5 seed members from brief §2, `is_seed=1`).

- [ ] **Step 1: Failing test** — seed 6 buys for one member with known prices (injected `price_on_date`/`spy_return` stubs), assert `alpha_disclosure_dw` equals the hand-computed dollar-weighted value and member is on the watchlist; a member with 4 buys is excluded by the floor.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** the per-trade alpha (disclosure-anchored) and dollar-weighted aggregation per brief §2; store both disclosure- and trade-anchored alpha.
- [ ] **Step 4: PASS** + suite green.
- [ ] **Step 5: Commit** — `feat(watchtower): member alpha ranking + watchlist (disclosure-anchored)`

### Task A5: Threshold alerts + cluster detection

**Files:** Modify `political_trades.py`; add `run(db_path, config) -> None`; Test `tests/test_political_trades.py`

**Interfaces:**
- Consumes: `store_trades`, `load_watchlist`, `send_alert` (existing), `record_for_accuracy` (existing tracker hook), `price_on_date`.
- Produces: `run(db_path, config)`; `detect_political_clusters(conn, window_days, min_members) -> list[(ticker, members)]`.

- [ ] **Step 1: Failing tests** — (a) a top-performer buy ≥ `top_performer_min_usd` triggers exactly one `send_alert` (mock); (b) a ≥`large_notional_usd` buy by a non-watchlist member also alerts; (c) 2 members same ticker within 14d yields one cluster; a 15-day gap yields none.

```python
def test_top_performer_buy_alerts(monkeypatch):
    sent = []; monkeypatch.setattr(mod, "send_alert", lambda **k: sent.append(k))
    run(db_with_watchlist_and_new_buy, CFG)
    assert len(sent) == 1 and "Congress Buy" in sent[0]["subject"]
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** `run()` per brief §6 sketch: fetch→store→threshold (sale rows skipped)→cluster→leave new buys for confluence. Run-summary log line `run_summary scraper=political_trades new=N alerts=M`. Alert footer states the ≤45-day lag caveat.
- [ ] **Step 4: PASS** + suite green.
- [ ] **Step 5: Commit** — `feat(watchtower): congress threshold + cluster alerts`

### Task A6: Confluence domain + scheduler wiring

**Files:** Modify `engine/confluence.py`, `engine/scheduler.py`, `config.yaml`; Test `tests/test_confluence.py`, `tests/test_scheduler.py`

**Interfaces:**
- Produces: confluence treats `political_trades` rows (last 7d) as a domain keyed by ticker/sector; `scheduler` registers `political_trades_daily` CronTrigger hour=6 minute=30 mon-fri; monthly accuracy job also calls `recompute_member_performance`.

- [ ] **Step 1: Failing tests** — (a) a congress buy + an insider cluster on the same ticker within the window produces a confluence with both domains and HIGH; (b) scheduler job list includes `political_trades_daily`.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** domain registration + scheduler job + config block (`top_performer_min_usd: 50000`, `large_notional_usd: 250000`, `cluster_window_days: 14`, `cluster_min_members: 2`, `watchlist_size: 20`, `min_buys_floor: 5`).
- [ ] **Step 4: PASS** + suite green.
- [ ] **Step 5: Commit** — `feat(watchtower): congress_trades confluence domain + 06:30 job`

*(Senate eFD = Phase 1b, deferred — separate later task; House proves the pipeline first.)*

---

## PHASE B — TA confirmation layer

### Task B1: Price fetch (Polygon primary → Yahoo fallback)

**Files:**
- Create: `watchtower/engine/technicals.py`
- Test: `tests/test_technicals.py`

**Interfaces:**
- Produces: `fetch_ohlcv(ticker, http=requests, api_key=None) -> list[tuple]|None` — list of `(date, o, h, l, c, v)` newest-last, ≥1y daily; tries Polygon `v2/aggs/ticker/{t}/range/1/day/...`, on failure/empty falls back to Yahoo `v8/finance/chart`. Returns `None` if both fail.

- [ ] **Step 1: Failing test** — mock `http.get` to return a canned Polygon JSON (60 candles); assert 60 tuples parsed, ascending dates. Second test: Polygon returns empty → Yahoo fixture used.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** both fetch paths + parsing; throttle helper (sleep to respect ~5/min) applied by caller, not here.
- [ ] **Step 4: PASS** + suite green.
- [ ] **Step 5: Commit** — `feat(watchtower): TA OHLCV fetch (Polygon→Yahoo)`

### Task B2: Indicators + verdict

**Files:** Modify `technicals.py`; Test `tests/test_technicals.py`

**Interfaces:**
- Produces: `_ema(series,n)`, `_rsi(series,n)`, `_macd(series)`, `_recent_high(series,n)`, `_avg_volume(series,n)`; `analyze_ticker(ticker, config, http=requests, api_key=None) -> dict` = `{direction, strength, score_delta, components, source}` with `direction ∈ {bullish,bearish,neutral,unavailable}`.

- [ ] **Step 1: Failing tests** with deterministic fixtures: a clean uptrend (price>EMA50>EMA200, RSI~60) → `bullish`; clean downtrend → `bearish`; <50 candles → `unavailable` with `score_delta==0`; RSI>75 uptrend → bullish but boost capped at 0 (overbought guard).
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** indicator math + classification + delta per TA spec §6 (bounded by `max_boost`/`max_penalty`).
- [ ] **Step 4: PASS** + suite green.
- [ ] **Step 5: Commit** — `feat(watchtower): TA indicators + confirm/veto verdict`

### Task B3: Confluence integration (confirm + veto) + snapshot

**Files:** Modify `engine/confluence.py`, `db.py` (write helper), `config.yaml`; Test `tests/test_confluence.py`

**Interfaces:**
- Consumes: `analyze_ticker`; thesis direction derived from the candidate's fundamental domain(s).
- Produces: confluence applies `score_delta` (aligned→boost, contradicts→penalty/HOLD when score<`hold_threshold`), writes a `ta_snapshots` row, attaches a TA note to the confluence record. `technicals:` config block per TA spec §5.

- [ ] **Step 1: Failing tests** — (a) bullish thesis + bullish TA → score increased, no HOLD; (b) bullish thesis + bearish TA (clean downtrend) → HOLD flag + `"tape contradicts"` note; (c) `unavailable` TA → score unchanged, alert still fires (never suppressed on missing data); (d) a `ta_snapshots` row is written each case.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** the fold-in + snapshot write + throttling across the candidate batch.
- [ ] **Step 4: PASS** + suite green.
- [ ] **Step 5: Commit** — `feat(watchtower): TA confirm/veto in confluence + ta_snapshots`

### Task B4: TA accuracy tracking

**Files:** Modify `engine/tracker.py`; Test `tests/test_tracker.py`

**Interfaces:**
- Produces: monthly accuracy report gains a TA section — hit-rate of TA-confirmed vs TA-contradicted vs TA-neutral confluences, using +5d/+20d forward returns from `fetch_ohlcv`.

- [ ] **Step 1: Failing test** — seed snapshots with known forward prices (injected), assert the report buckets and computes hit-rate correctly.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** the TA section in the monthly report.
- [ ] **Step 4: PASS** + suite green.
- [ ] **Step 5: Commit** — `feat(watchtower): TA forward-return accuracy section`

---

## PHASE C — integration + deploy

### Task C1: Whole-branch review + integration smoke

- [ ] **Step 1:** Run full suite `pytest -q` — all green (target ~60+ tests).
- [ ] **Step 2:** Opus whole-branch review (per Phase-0 pattern) — config keys reconciled to code, no silent integration blockers, env-var expansion intact.
- [ ] **Step 3:** Local integration smoke: run `political_trades.run()` against live House ZIP (expect ≥1 parsed filing); run `analyze_ticker` live on a known uptrend + downtrend ticker via Polygon, then force Polygon failure to confirm Yahoo fallback.
- [ ] **Step 4:** Update SDD ledger + `config.yaml` documented. Commit.

### Task C2: Deploy (RED — Owner approval, 10T runs it)

- [ ] **Step 1:** Owner approval to deploy (RED, production droplet).
- [ ] **Step 2:** Add `POLYGON_API_KEY` to droplet `/app/watchtower/.env` (chmod 600) from BW. Verify `.env` + live `data/` untouched.
- [ ] **Step 3:** tar-over-ssh code → `/app/watchtower/` (exclude `data/`, `logs/`, `.env`, `.git`). `docker compose up -d --build`.
- [ ] **Step 4:** Verify: container healthy; scheduler shows `political_trades_daily`; one live cycle writes `political_trades` + a `ta_snapshots` row; run-summary logs present. Update CURRENT.md + PROGRESS.md.

---

## Self-Review

- **Spec coverage:** TA spec §§4–11 → Tasks B1–B4, C; congress brief §§2–6 → Tasks A1–A6, C. Senate eFD explicitly deferred to Phase 1b (noted). Both schema sets in A1. ✓
- **Placeholders:** none — DDL referenced from specs (§5 each), config values given, test code shown. Bracket midpoint table lives in brief §3 (single source). ✓
- **Type consistency:** `analyze_ticker` return shape consistent B2→B3→B4; `fetch_ohlcv` tuple shape consistent B1→B2→B4; `load_watchlist` returns bioguide set in A4 and consumed in A5. ✓
- **Caveats preserved:** disclosure-anchored accuracy (A4), ≤45-day lag in alert footer (A5), TA never vetoes on missing data (B3). ✓
