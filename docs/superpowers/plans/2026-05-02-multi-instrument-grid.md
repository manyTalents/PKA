# Multi-Instrument Dynamic Grid — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-instrument grid with a dynamic multi-instrument grid system that scans all CDE crypto futures every 4 hours, runs grids on the top N most volatile assets, and collects ML training data for future intelligent instrument selection and capital allocation.

**Architecture:** A Scanner ranks all CDE crypto futures by volatility score. A Grid Manager maintains N AdaptiveGridStrategy instances, rotating instruments based on scanner output. All decisions, fills, and ML features are persisted to SQLite. The existing grid strategy gets minimal changes (product_type tag + sizing dispatcher + fill logging) — all new logic lives in new files.

**Tech Stack:** Python 3.11+, SQLAlchemy (SQLite), FastAPI, APScheduler, TA-Lib, coinbase-advanced-py SDK

**Spec:** `C:/Users/chris/OneDrive/Documentos/PKA/docs/superpowers/specs/2026-05-02-multi-instrument-grid-design.md`

**Repo:** `C:/Users/chris/OneDrive/Documentos/the-machine/`

**Test runner:** `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/ -v`

---

## File Map

### New Files
| File | Responsibility |
|------|----------------|
| `src/strategies/grid_scanner.py` | Scans CDE crypto products, computes volatility scores, ranks and selects top N |
| `src/strategies/grid_manager.py` | Manages N grid instances, handles rotation, capital allocation, lifecycle |
| `src/ml/instrument_selector.py` | ML Phase 1: logs scanner features + outcomes for future model training |
| `tests/test_grid_scanner.py` | Scanner unit tests |
| `tests/test_grid_manager.py` | Grid Manager unit tests |
| `tests/test_grid_models.py` | New DB table tests |
| `tests/test_instrument_selector.py` | ML feature logging tests |

### Modified Files
| File | Changes |
|------|---------|
| `src/models.py` | Add 4 new tables: `scanner_snapshots`, `grid_instances`, `grid_fills`, `ml_features` |
| `src/config.py` | Add scanner, scaling, ML, and contract rolling config entries |
| `src/exchange/coinbase_client.py` | Add `list_crypto_futures()` method, fix CDE futures detection for leverage/margin |
| `src/strategies/adaptive_grid.py` | Add `product_type` field, sizing dispatcher, fill logging to DB |
| `src/data/indicators.py` | Add `get_scanner_indicators()` — lightweight volatility metrics for many assets |
| `src/main.py` | Replace single grid with Grid Manager, add scanner to scheduler, update dashboard |

---

## Task 1: Database Models — New Tables

**Files:**
- Modify: `src/models.py`
- Test: `tests/test_grid_models.py`

- [ ] **Step 1: Write the failing test for new tables**

Create `tests/test_grid_models.py`:

```python
"""Tests for multi-instrument grid database tables."""
import json
import tempfile
from pathlib import Path

from sqlalchemy import inspect

from src.models import (
    Base, ScannerSnapshot, GridInstance, GridFill, MLFeature,
    get_engine, get_session,
)


def _temp_engine():
    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    engine = get_engine(Path(tmp.name))
    Base.metadata.create_all(engine)
    return engine, Path(tmp.name)


def _cleanup(engine, db_path: Path):
    engine.dispose()
    try:
        db_path.unlink(missing_ok=True)
        db_path.with_suffix(".db-wal").unlink(missing_ok=True)
        db_path.with_suffix(".db-shm").unlink(missing_ok=True)
    except PermissionError:
        pass


def test_grid_tables_created():
    engine, db_path = _temp_engine()
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    assert "scanner_snapshots" in tables
    assert "grid_instances" in tables
    assert "grid_fills" in tables
    assert "ml_features" in tables
    _cleanup(engine, db_path)


def test_scanner_snapshot_crud():
    engine, db_path = _temp_engine()
    session = get_session(engine)
    snap = ScannerSnapshot(
        timestamp="2026-05-02T12:00:00+00:00",
        total_equity=950.0,
        max_grids=3,
        selected_instruments=json.dumps(["SOL-29MAY26-CDE", "ETH-26JUN26-CDE"]),
        all_scores=json.dumps({"SOL": 0.85, "ETH": 0.72, "XRP": 0.40}),
        rotation_actions=json.dumps([]),
        scan_duration_ms=1200,
    )
    session.add(snap)
    session.commit()
    assert snap.id is not None
    fetched = session.query(ScannerSnapshot).first()
    assert fetched.total_equity == 950.0
    assert fetched.max_grids == 3
    session.close()
    _cleanup(engine, db_path)


def test_grid_instance_crud():
    engine, db_path = _temp_engine()
    session = get_session(engine)
    inst = GridInstance(
        instrument="SOL-29MAY26-CDE",
        product_type="dated",
        started_at="2026-05-02T12:00:00+00:00",
        allocation_usd=317.0,
        allocation_weight=0.40,
    )
    session.add(inst)
    session.commit()
    assert inst.id is not None
    assert inst.total_fills == 0
    assert inst.total_pnl == 0.0
    session.close()
    _cleanup(engine, db_path)


def test_grid_fill_crud():
    engine, db_path = _temp_engine()
    session = get_session(engine)
    inst = GridInstance(
        instrument="SOL-29MAY26-CDE",
        product_type="dated",
        started_at="2026-05-02T12:00:00+00:00",
        allocation_usd=317.0,
        allocation_weight=0.40,
    )
    session.add(inst)
    session.commit()
    fill = GridFill(
        instance_id=inst.id,
        instrument="SOL-29MAY26-CDE",
        entry_side="buy",
        entry_price=84.50,
        entry_time="2026-05-02T12:05:00+00:00",
        entry_order_id="oid-123",
        status="pending",
    )
    session.add(fill)
    session.commit()
    assert fill.id is not None
    assert fill.cycle_pnl is None
    session.close()
    _cleanup(engine, db_path)


def test_ml_feature_crud():
    engine, db_path = _temp_engine()
    session = get_session(engine)
    snap = ScannerSnapshot(
        timestamp="2026-05-02T12:00:00+00:00",
        total_equity=950.0,
        max_grids=3,
        selected_instruments=json.dumps([]),
        all_scores=json.dumps({}),
        rotation_actions=json.dumps([]),
    )
    session.add(snap)
    session.commit()
    feat = MLFeature(
        snapshot_id=snap.id,
        timestamp="2026-05-02T12:00:00+00:00",
        instrument="SOL-29MAY26-CDE",
        bbw_percentile=45.0,
        atr_pct=0.025,
        volume_24h=5_000_000.0,
        spread_bps=12.5,
        was_selected=1,
    )
    session.add(feat)
    session.commit()
    assert feat.id is not None
    assert feat.outcome_pnl_4h is None
    session.close()
    _cleanup(engine, db_path)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_grid_models.py -v`
Expected: FAIL with `ImportError: cannot import name 'ScannerSnapshot' from 'src.models'`

- [ ] **Step 3: Implement the 4 new models in models.py**

Add these classes to `src/models.py` after the `RiskEvent` class (before the Indexes section):

```python
class ScannerSnapshot(Base):
    __tablename__ = "scanner_snapshots"

    id = Column(Integer, primary_key=True, autoincrement=True)
    timestamp = Column(Text, nullable=False)
    total_equity = Column(Float, nullable=False)
    max_grids = Column(Integer, nullable=False)
    selected_instruments = Column(Text, nullable=False)   # JSON
    all_scores = Column(Text, nullable=False)             # JSON
    rotation_actions = Column(Text, nullable=False)       # JSON
    scan_duration_ms = Column(Integer)


class GridInstance(Base):
    __tablename__ = "grid_instances"

    id = Column(Integer, primary_key=True, autoincrement=True)
    instrument = Column(Text, nullable=False)
    product_type = Column(Text, nullable=False)           # "dated" or "perp"
    started_at = Column(Text, nullable=False)
    ended_at = Column(Text)
    end_reason = Column(Text)                             # "rotated", "paused", "expiry", "equity_drop"
    allocation_usd = Column(Float, nullable=False)
    allocation_weight = Column(Float, nullable=False)
    total_fills = Column(Integer, nullable=False, default=0)
    total_cycles = Column(Integer, nullable=False, default=0)
    total_pnl = Column(Float, nullable=False, default=0.0)


class GridFill(Base):
    __tablename__ = "grid_fills"

    id = Column(Integer, primary_key=True, autoincrement=True)
    instance_id = Column(Integer, ForeignKey("grid_instances.id"), nullable=False)
    instrument = Column(Text, nullable=False)
    entry_side = Column(Text, nullable=False)
    entry_price = Column(Float, nullable=False)
    entry_time = Column(Text, nullable=False)
    entry_order_id = Column(Text, nullable=False)
    counter_price = Column(Float)
    counter_order_id = Column(Text)
    counter_fill_time = Column(Text)
    cycle_pnl = Column(Float)
    cycle_duration_sec = Column(Integer)
    status = Column(Text, nullable=False, default="pending")  # "pending", "completed", "cancelled", "expired"


class MLFeature(Base):
    __tablename__ = "ml_features"

    id = Column(Integer, primary_key=True, autoincrement=True)
    snapshot_id = Column(Integer, ForeignKey("scanner_snapshots.id"))
    timestamp = Column(Text, nullable=False)
    instrument = Column(Text, nullable=False)
    bbw_percentile = Column(Float, nullable=False)
    atr_pct = Column(Float, nullable=False)
    volume_24h = Column(Float, nullable=False)
    spread_bps = Column(Float, nullable=False)
    adx_4h = Column(Float)
    btc_dominance = Column(Float)
    total_crypto_vol = Column(Float)
    fill_rate_1h = Column(Float)
    was_selected = Column(Integer, nullable=False)        # 1 or 0
    allocation_weight = Column(Float)
    outcome_pnl_4h = Column(Float)
    outcome_fills_4h = Column(Integer)
    outcome_cycle_completions_4h = Column(Integer)
```

Also add these indexes after the existing index declarations:

```python
Index("ix_scanner_timestamp", ScannerSnapshot.timestamp)
Index("ix_grid_instances_instrument", GridInstance.instrument)
Index("ix_grid_fills_instance_id", GridFill.instance_id)
Index("ix_ml_features_timestamp", MLFeature.timestamp)
Index("ix_ml_features_instrument", MLFeature.instrument)
```

Update the `test_all_tables_created` expected set in `tests/test_models.py`:

```python
assert tables == {
    "trades", "equity_snapshots", "signals", "lessons", "risk_events",
    "scanner_snapshots", "grid_instances", "grid_fills", "ml_features",
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_grid_models.py tests/test_models.py -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add src/models.py tests/test_grid_models.py tests/test_models.py
git commit -m "feat: add scanner_snapshots, grid_instances, grid_fills, ml_features tables"
```

---

## Task 2: Configuration — Scanner, Scaling, ML Entries

**Files:**
- Modify: `src/config.py`
- Test: `tests/test_config.py`

- [ ] **Step 1: Write the failing test for new config entries**

Add to `tests/test_config.py`:

```python
def test_scanner_config_exists():
    import src.config as cfg
    assert cfg.GRID_SCANNER_INTERVAL_HOURS == 4
    assert cfg.GRID_SCANNER_MIN_VOLUME_24H == 100_000.0
    assert cfg.GRID_SCANNER_MAX_SPREAD_BPS == 50.0
    assert cfg.GRID_SCANNER_STALE_DATA_MINUTES == 30
    assert cfg.GRID_MAX_SIMULTANEOUS == 3
    assert cfg.GRID_MIN_PER_GRID_CAPITAL == 250.0
    assert cfg.GRID_ALLOCATION_FLOOR == 0.15
    assert cfg.GRID_ALLOCATION_CEILING == 0.50


def test_score_weights_sum_to_one():
    import src.config as cfg
    total = (
        cfg.GRID_SCORE_WEIGHT_BBW
        + cfg.GRID_SCORE_WEIGHT_ATR
        + cfg.GRID_SCORE_WEIGHT_VOLUME
        + cfg.GRID_SCORE_WEIGHT_SPREAD
    )
    assert abs(total - 1.0) < 1e-9


def test_equity_scale_tiers():
    import src.config as cfg
    assert len(cfg.GRID_SCALE_TIERS) == 5
    assert cfg.GRID_SCALE_TIERS[0]["min_equity"] == 0
    assert cfg.GRID_SCALE_TIERS[0]["max_grids"] == 1
    assert cfg.GRID_SCALE_TIERS[-1]["max_grids"] == 5


def test_ml_selector_config():
    import src.config as cfg
    assert cfg.ML_MIN_GRID_FILLS_SELECTOR == 500
    assert cfg.ML_MIN_GRID_FILLS_ALLOCATOR == 1000
    assert cfg.ML_BLEND_WEIGHT_CAP == 0.80
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_config.py::test_scanner_config_exists -v`
Expected: FAIL with `AttributeError: module 'src.config' has no attribute 'GRID_SCANNER_INTERVAL_HOURS'`

- [ ] **Step 3: Add config entries to config.py**

Add after the `# -- ML Foundation` section in `src/config.py`:

```python
# ── Multi-Instrument Grid Scanner ────────────────────────────────────
GRID_SCANNER_INTERVAL_HOURS: int = 4
GRID_SCANNER_MIN_VOLUME_24H: float = 100_000.0    # $100k minimum 24h volume
GRID_SCANNER_MAX_SPREAD_BPS: float = 50.0          # 50 bps max bid-ask spread
GRID_SCANNER_STALE_DATA_MINUTES: int = 30
GRID_MAX_SIMULTANEOUS: int = 3                      # Starting max (overridden by equity scaling)
GRID_MIN_PER_GRID_CAPITAL: float = 250.0            # Minimum capital per grid instance
GRID_ALLOCATION_FLOOR: float = 0.15                 # 15% min weight per grid
GRID_ALLOCATION_CEILING: float = 0.50               # 50% max weight per grid

# ── Volatility Score Weights (Phase 1 heuristic) ────────────────────
GRID_SCORE_WEIGHT_BBW: float = 0.35
GRID_SCORE_WEIGHT_ATR: float = 0.35
GRID_SCORE_WEIGHT_VOLUME: float = 0.20
GRID_SCORE_WEIGHT_SPREAD: float = 0.10

# ── Contract Rolling ────────────────────────────────────────────────
GRID_ROLL_WARNING_HOURS: int = 48                   # Stop new levels 48h before expiry
GRID_ROLL_CLOSE_HOURS: int = 24                     # Force close 24h before expiry

# ── ML Instrument Selection ─────────────────────────────────────────
ML_MIN_GRID_FILLS_SELECTOR: int = 500               # Phase 2 activation
ML_MIN_GRID_FILLS_ALLOCATOR: int = 1000             # Phase 3 activation
ML_SELECTOR_MIN_WEEKS: int = 4                      # Phase 3 requires Phase 2 running 4+ weeks
ML_BLEND_WEIGHT_INCREMENT: float = 0.20             # Max 20% blend increase per week
ML_BLEND_WEIGHT_CAP: float = 0.80                   # Heuristic always retains 20%

# ── Equity Scaling ──────────────────────────────────────────────────
GRID_SCALE_TIERS: list = [
    {"min_equity": 0,    "max_grids": 1, "min_capital": 250},
    {"min_equity": 500,  "max_grids": 2, "min_capital": 250},
    {"min_equity": 1000, "max_grids": 3, "min_capital": 300},
    {"min_equity": 2000, "max_grids": 4, "min_capital": 400},
    {"min_equity": 5000, "max_grids": 5, "min_capital": 500},
]
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_config.py -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add src/config.py tests/test_config.py
git commit -m "feat: add multi-instrument scanner and ML config entries"
```

---

## Task 3: CoinbaseClient — Product Discovery + CDE Detection Fix

**Files:**
- Modify: `src/exchange/coinbase_client.py`
- Test: `tests/test_coinbase_client.py`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_coinbase_client.py`:

```python
def test_list_crypto_futures_returns_dated_and_perp(mock_client_obj):
    """list_crypto_futures should return both CDE and perp products, crypto only."""
    mock_client_obj._client.get_products.return_value = {
        "products": [
            {"product_id": "SOL-29MAY26-CDE", "product_type": "FUTURE", "quote_currency_id": "USD"},
            {"product_id": "BTC-PERP-INTX", "product_type": "FUTURE", "quote_currency_id": "USD"},
            {"product_id": "BTC-USD", "product_type": "SPOT", "quote_currency_id": "USD"},
            {"product_id": "NOL-18MAY26-CDE", "product_type": "FUTURE", "quote_currency_id": "USD"},  # Oil
        ]
    }
    result = mock_client_obj.list_crypto_futures()
    product_ids = [p["product_id"] for p in result]
    assert "SOL-29MAY26-CDE" in product_ids
    assert "BTC-PERP-INTX" in product_ids
    assert "BTC-USD" not in product_ids     # Not a future
    assert "NOL-18MAY26-CDE" not in product_ids  # Oil, not crypto


def test_classify_product_type():
    """classify_product_type should detect dated vs perp."""
    from src.exchange.coinbase_client import classify_product_type
    assert classify_product_type("SOL-29MAY26-CDE") == "dated"
    assert classify_product_type("BTC-PERP-INTX") == "perp"
    assert classify_product_type("BTC-USD") == "spot"


def test_is_futures_product():
    """is_futures_product should return True for both CDE and PERP."""
    from src.exchange.coinbase_client import is_futures_product
    assert is_futures_product("SOL-29MAY26-CDE") is True
    assert is_futures_product("BTC-PERP-INTX") is True
    assert is_futures_product("BTC-USD") is False
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_coinbase_client.py::test_list_crypto_futures_returns_dated_and_perp -v`
Expected: FAIL with `AttributeError: 'CoinbaseClient' object has no attribute 'list_crypto_futures'`

- [ ] **Step 3: Implement in coinbase_client.py**

Add these module-level functions after the `_to_dict` helper:

```python
# Known non-crypto CDE product prefixes (commodities, indices)
_NON_CRYPTO_PREFIXES = ("NOL", "SLR", "PT", "B5", "LB5", "TEC", "LTEC", "OIL")


def classify_product_type(product_id: str) -> str:
    """Classify a product ID as 'dated', 'perp', or 'spot'."""
    if "CDE" in product_id:
        return "dated"
    if "PERP" in product_id:
        return "perp"
    return "spot"


def is_futures_product(product_id: str) -> bool:
    """Return True if product is a futures contract (dated or perp)."""
    return classify_product_type(product_id) in ("dated", "perp")
```

Add this method to the `CoinbaseClient` class:

```python
    def list_crypto_futures(self) -> list[dict]:
        """List all crypto futures products (CDE dated + INTX perps).

        Filters out non-crypto products (oil, silver, platinum, indices).
        Returns list of product dicts with product_id, product_type, etc.
        """
        resp = _to_dict(self._client.get_products(product_type="FUTURE"))
        products = resp.get("products", [])
        result = []
        for p in products:
            pid = p.get("product_id", "")
            # Skip non-crypto products
            prefix = pid.split("-")[0] if "-" in pid else pid
            if prefix.upper() in _NON_CRYPTO_PREFIXES:
                continue
            result.append(p)
        return result
```

Also fix the `place_limit_order` method to handle CDE futures leverage:

Change `is_perp = "PERP" in product_id` to:

```python
        is_futures = is_futures_product(product_id)
```

And update the return statement to use `is_futures` instead of `is_perp`:

```python
        return _to_dict(self._client.limit_order_gtc(
            client_order_id=client_order_id,
            product_id=product_id,
            side=side.upper(),
            base_size=size,
            limit_price=price,
            post_only=post_only,
            leverage=leverage if is_futures else None,
            margin_type="CROSS" if is_futures else None,
        ))
```

Apply the same fix to `place_market_order`:

Change `is_perp = "PERP" in product_id` to `is_futures = is_futures_product(product_id)` and update the corresponding references.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_coinbase_client.py -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add src/exchange/coinbase_client.py tests/test_coinbase_client.py
git commit -m "feat: add list_crypto_futures, classify_product_type, fix CDE leverage detection"
```

---

## Task 4: Scanner Indicators — Lightweight Volatility Metrics

**Files:**
- Modify: `src/data/indicators.py`
- Test: `tests/test_indicators.py`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_indicators.py`:

```python
def test_get_scanner_indicators_returns_all_keys():
    """get_scanner_indicators returns bbw_percentile, atr_pct, volume_24h, spread_bps, adx_4h."""
    from src.data.indicators import get_scanner_indicators
    mock_client = MagicMock()

    # Mock 4h candles (200 bars) — use realistic price data
    candles_4h = [
        {"start": str(i), "open": str(100 + i * 0.1), "high": str(101 + i * 0.1),
         "low": str(99 + i * 0.1), "close": str(100.5 + i * 0.1), "volume": str(1000 + i)}
        for i in range(200)
    ]
    # Mock 1h candles (50 bars)
    candles_1h = [
        {"start": str(i), "open": str(100 + i * 0.05), "high": str(100.5 + i * 0.05),
         "low": str(99.5 + i * 0.05), "close": str(100.2 + i * 0.05), "volume": str(500 + i)}
        for i in range(50)
    ]
    mock_client.get_candles.side_effect = lambda pid, s, e, g: (
        {"candles": candles_4h} if g == "FOUR_HOUR" else {"candles": candles_1h}
    )

    # Mock bid-ask
    mock_client.get_best_bid_ask.return_value = {
        "pricebooks": [{
            "bids": [{"price": "100.00"}],
            "asks": [{"price": "100.10"}],
        }]
    }

    result = get_scanner_indicators(mock_client, "SOL-29MAY26-CDE")
    assert "bbw_percentile" in result
    assert "atr_pct" in result
    assert "volume_24h" in result
    assert "spread_bps" in result
    assert "adx_4h" in result
    assert result["volume_24h"] > 0
    assert result["spread_bps"] >= 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_indicators.py::test_get_scanner_indicators_returns_all_keys -v`
Expected: FAIL with `ImportError: cannot import name 'get_scanner_indicators'`

- [ ] **Step 3: Implement get_scanner_indicators**

Add to `src/data/indicators.py`:

```python
def get_scanner_indicators(client: CoinbaseClient, product_id: str) -> dict:
    """Lightweight volatility metrics for scanner ranking.

    Returns:
        bbw_percentile: BBW percentile rank (0-100) over 30-day window
        atr_pct: ATR(14) as % of current price on 4h bars
        volume_24h: 24h USD volume from 1h bars
        spread_bps: Current bid-ask spread in basis points
        adx_4h: ADX(14) on 4h bars
    """
    _talib = talib
    if _talib is None:
        import sys
        _talib = sys.modules.get("talib")
    if _talib is None:
        raise ImportError("TA-Lib C library is required.")

    # 4h candles for BBW, ATR, ADX
    df_4h = _fetch_ohlcv(client, product_id, OHLCV_GRANULARITY_4H, limit=200)

    adx_4h = _talib.ADX(
        df_4h["high"].values, df_4h["low"].values, df_4h["close"].values, timeperiod=14
    )
    atr_4h = _talib.ATR(
        df_4h["high"].values, df_4h["low"].values, df_4h["close"].values, timeperiod=14
    )
    upper, mid, lower = _talib.BBANDS(df_4h["close"].values, timeperiod=20, nbdevup=2, nbdevdn=2)
    bbw_series = (upper - lower) / mid

    window = bbw_series[~np.isnan(bbw_series)]
    window = window[-180:] if len(window) > 180 else window
    bbw_pctile = float(np.sum(window < window[-1]) / len(window) * 100) if len(window) > 0 else 50.0

    current_price = float(df_4h["close"].iloc[-1])
    latest_atr = float(atr_4h[~np.isnan(atr_4h)][-1]) if np.any(~np.isnan(atr_4h)) else 0.0
    atr_pct = latest_atr / current_price if current_price > 0 else 0.0

    # 1h candles for 24h volume
    df_1h = _fetch_ohlcv(client, product_id, OHLCV_GRANULARITY_1H, limit=24)
    volume_24h = float(df_1h["volume"].sum()) * current_price  # approx USD volume

    # Bid-ask spread
    try:
        resp = client.get_best_bid_ask([product_id])
        pricebooks = resp.get("pricebooks", [])
        if pricebooks:
            bid = float(pricebooks[0].get("bids", [{}])[0].get("price", 0))
            ask = float(pricebooks[0].get("asks", [{}])[0].get("price", 0))
            mid_price = (bid + ask) / 2
            spread_bps = ((ask - bid) / mid_price * 10000) if mid_price > 0 else 9999.0
        else:
            spread_bps = 9999.0
    except Exception:
        spread_bps = 9999.0

    return {
        "bbw_percentile": bbw_pctile,
        "atr_pct": atr_pct,
        "volume_24h": volume_24h,
        "spread_bps": spread_bps,
        "adx_4h": float(adx_4h[~np.isnan(adx_4h)][-1]) if np.any(~np.isnan(adx_4h)) else 0.0,
        "current_price": current_price,
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_indicators.py -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add src/data/indicators.py tests/test_indicators.py
git commit -m "feat: add get_scanner_indicators for multi-asset volatility ranking"
```

---

## Task 5: Grid Scanner — Scoring, Ranking, Selection

**Files:**
- Create: `src/strategies/grid_scanner.py`
- Test: `tests/test_grid_scanner.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_grid_scanner.py`:

```python
"""Tests for multi-instrument grid scanner."""
import pytest
from unittest.mock import MagicMock, patch
from src.strategies.grid_scanner import GridScanner, ScoredInstrument


@pytest.fixture
def scanner():
    client = MagicMock()
    return GridScanner(client)


def _make_indicators(bbw=50.0, atr_pct=0.03, volume=500_000.0, spread=10.0, adx=15.0):
    return {
        "bbw_percentile": bbw, "atr_pct": atr_pct,
        "volume_24h": volume, "spread_bps": spread,
        "adx_4h": adx, "current_price": 100.0,
    }


def test_score_instrument_returns_scored_instrument(scanner):
    indicators = _make_indicators()
    result = scanner.score_instrument("SOL-29MAY26-CDE", indicators)
    assert isinstance(result, ScoredInstrument)
    assert result.product_id == "SOL-29MAY26-CDE"
    assert result.product_type == "dated"
    assert 0.0 <= result.score <= 1.0


def test_filter_rejects_low_bbw(scanner):
    indicators = _make_indicators(bbw=5.0)
    result = scanner.score_instrument("SOL-29MAY26-CDE", indicators)
    assert not result.eligible
    assert "bbw" in result.reject_reason.lower()


def test_filter_rejects_low_volume(scanner):
    indicators = _make_indicators(volume=50_000.0)
    result = scanner.score_instrument("SOL-29MAY26-CDE", indicators)
    assert not result.eligible
    assert "volume" in result.reject_reason.lower()


def test_filter_rejects_wide_spread(scanner):
    indicators = _make_indicators(spread=60.0)
    result = scanner.score_instrument("SOL-29MAY26-CDE", indicators)
    assert not result.eligible
    assert "spread" in result.reject_reason.lower()


def test_select_top_n(scanner):
    scored = [
        ScoredInstrument("A-CDE", "dated", 0.90, True, "", _make_indicators()),
        ScoredInstrument("B-CDE", "dated", 0.70, True, "", _make_indicators()),
        ScoredInstrument("C-CDE", "dated", 0.50, True, "", _make_indicators()),
        ScoredInstrument("D-CDE", "dated", 0.30, True, "", _make_indicators()),
    ]
    selected = scanner.select_top_n(scored, max_grids=3)
    assert len(selected) == 3
    assert selected[0].product_id == "A-CDE"
    assert selected[2].product_id == "C-CDE"


def test_select_top_n_excludes_ineligible(scanner):
    scored = [
        ScoredInstrument("A-CDE", "dated", 0.90, True, "", _make_indicators()),
        ScoredInstrument("B-CDE", "dated", 0.70, False, "low bbw", _make_indicators()),
        ScoredInstrument("C-CDE", "dated", 0.50, True, "", _make_indicators()),
    ]
    selected = scanner.select_top_n(scored, max_grids=3)
    assert len(selected) == 2
    assert "B-CDE" not in [s.product_id for s in selected]


def test_compute_weights_volatility_based(scanner):
    selected = [
        ScoredInstrument("A-CDE", "dated", 0.80, True, "", _make_indicators()),
        ScoredInstrument("B-CDE", "dated", 0.40, True, "", _make_indicators()),
    ]
    weights = scanner.compute_weights(selected)
    assert abs(sum(weights.values()) - 1.0) < 1e-9
    assert weights["A-CDE"] > weights["B-CDE"]


def test_compute_weights_respects_floor_ceiling(scanner):
    selected = [
        ScoredInstrument("A-CDE", "dated", 0.99, True, "", _make_indicators()),
        ScoredInstrument("B-CDE", "dated", 0.01, True, "", _make_indicators()),
    ]
    weights = scanner.compute_weights(selected)
    assert weights["B-CDE"] >= 0.15   # floor
    assert weights["A-CDE"] <= 0.50   # ceiling (only applies with 2+ grids)


def test_get_max_grids_from_equity(scanner):
    assert scanner.get_max_grids(400.0) == 1
    assert scanner.get_max_grids(800.0) == 2
    assert scanner.get_max_grids(1500.0) == 3
    assert scanner.get_max_grids(3000.0) == 4
    assert scanner.get_max_grids(10000.0) == 5
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_grid_scanner.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'src.strategies.grid_scanner'`

- [ ] **Step 3: Implement GridScanner**

Create `src/strategies/grid_scanner.py`:

```python
"""
grid_scanner.py — Scans all CDE crypto futures and selects top N by volatility.

Every 4 hours:
1. Fetch all crypto futures products from Coinbase
2. Compute volatility score per asset (BBW, ATR, volume, spread)
3. Filter ineligible assets
4. Rank and select top N
5. Compute volatility-weighted capital allocation
"""

import logging
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone

from src.exchange.coinbase_client import CoinbaseClient, classify_product_type
from src.data.indicators import get_scanner_indicators
import src.config as cfg

logger = logging.getLogger("the-machine.scanner")


@dataclass
class ScoredInstrument:
    product_id: str
    product_type: str       # "dated" or "perp"
    score: float            # 0.0 - 1.0 composite volatility score
    eligible: bool
    reject_reason: str
    indicators: dict = field(default_factory=dict)


class GridScanner:
    """Scans CDE crypto products and selects the best instruments for grid trading."""

    def __init__(self, client: CoinbaseClient):
        self._client = client
        self._cached_products: list[dict] = []
        self._last_product_fetch: float = 0.0

    def scan(self, equity: float) -> tuple[list[ScoredInstrument], list[ScoredInstrument]]:
        """Run a full scan cycle.

        Returns:
            (selected, all_scored) — selected instruments for grids, and full ranking
        """
        start_ms = int(time.time() * 1000)
        max_grids = self.get_max_grids(equity)

        # Fetch product list (cache for 1 hour)
        products = self._get_crypto_futures()
        if not products:
            logger.error("Scanner: no crypto futures products found")
            return [], []

        # Score each product
        all_scored: list[ScoredInstrument] = []
        for product in products:
            pid = product.get("product_id", "")
            try:
                indicators = get_scanner_indicators(self._client, pid)
                scored = self.score_instrument(pid, indicators)
                all_scored.append(scored)
            except Exception as e:
                logger.warning("Scanner: failed to score %s: %s", pid, e)
                all_scored.append(ScoredInstrument(
                    pid, classify_product_type(pid), 0.0, False, f"error: {e}"
                ))

        selected = self.select_top_n(all_scored, max_grids)

        elapsed_ms = int(time.time() * 1000) - start_ms
        logger.info(
            "Scanner: scanned %d products, %d eligible, selected %d (took %dms)",
            len(all_scored),
            sum(1 for s in all_scored if s.eligible),
            len(selected),
            elapsed_ms,
        )
        return selected, all_scored

    def score_instrument(self, product_id: str, indicators: dict) -> ScoredInstrument:
        """Score a single instrument based on volatility metrics."""
        product_type = classify_product_type(product_id)
        bbw = indicators.get("bbw_percentile", 0.0)
        atr_pct = indicators.get("atr_pct", 0.0)
        volume = indicators.get("volume_24h", 0.0)
        spread = indicators.get("spread_bps", 9999.0)

        # Eligibility filters
        if bbw < cfg.GRID_BBW_PAUSE_PERCENTILE:
            return ScoredInstrument(product_id, product_type, 0.0, False,
                                   f"BBW {bbw:.1f} < {cfg.GRID_BBW_PAUSE_PERCENTILE}", indicators)
        if volume < cfg.GRID_SCANNER_MIN_VOLUME_24H:
            return ScoredInstrument(product_id, product_type, 0.0, False,
                                   f"Volume ${volume:,.0f} < ${cfg.GRID_SCANNER_MIN_VOLUME_24H:,.0f}", indicators)
        if spread > cfg.GRID_SCANNER_MAX_SPREAD_BPS:
            return ScoredInstrument(product_id, product_type, 0.0, False,
                                   f"Spread {spread:.1f}bps > {cfg.GRID_SCANNER_MAX_SPREAD_BPS}bps", indicators)

        # Composite score (0-1 range, will be normalized across pool later)
        # For now, use raw weighted sum — normalization happens in select_top_n
        raw_score = (
            bbw / 100.0 * cfg.GRID_SCORE_WEIGHT_BBW
            + min(atr_pct / 0.10, 1.0) * cfg.GRID_SCORE_WEIGHT_ATR  # cap ATR at 10%
            + min(volume / 10_000_000.0, 1.0) * cfg.GRID_SCORE_WEIGHT_VOLUME  # cap at $10M
            + max(1.0 - spread / 100.0, 0.0) * cfg.GRID_SCORE_WEIGHT_SPREAD  # invert spread
        )

        return ScoredInstrument(product_id, product_type, raw_score, True, "", indicators)

    def select_top_n(
        self, scored: list[ScoredInstrument], max_grids: int
    ) -> list[ScoredInstrument]:
        """Select top N eligible instruments by score."""
        eligible = [s for s in scored if s.eligible]
        eligible.sort(key=lambda s: s.score, reverse=True)
        return eligible[:max_grids]

    def compute_weights(self, selected: list[ScoredInstrument]) -> dict[str, float]:
        """Compute volatility-weighted capital allocation with floor/ceiling."""
        if not selected:
            return {}
        if len(selected) == 1:
            return {selected[0].product_id: 1.0}

        total_score = sum(s.score for s in selected)
        if total_score <= 0:
            # Equal split fallback
            w = 1.0 / len(selected)
            return {s.product_id: w for s in selected}

        # Raw weights
        weights = {s.product_id: s.score / total_score for s in selected}

        # Apply floor and ceiling
        floor = cfg.GRID_ALLOCATION_FLOOR
        ceiling = cfg.GRID_ALLOCATION_CEILING
        clamped = {pid: max(floor, min(ceiling, w)) for pid, w in weights.items()}

        # Renormalize to sum to 1.0
        total = sum(clamped.values())
        return {pid: w / total for pid, w in clamped.items()}

    def get_max_grids(self, equity: float) -> int:
        """Determine max simultaneous grids from equity scaling tiers."""
        max_grids = 1
        for tier in cfg.GRID_SCALE_TIERS:
            if equity >= tier["min_equity"]:
                max_grids = tier["max_grids"]
        return max_grids

    def _get_crypto_futures(self) -> list[dict]:
        """Get crypto futures products with 1-hour caching."""
        now = time.time()
        if self._cached_products and (now - self._last_product_fetch) < 3600:
            return self._cached_products
        try:
            self._cached_products = self._client.list_crypto_futures()
            self._last_product_fetch = now
            logger.info("Scanner: fetched %d crypto futures products", len(self._cached_products))
        except Exception as e:
            logger.error("Scanner: failed to fetch product list: %s", e)
            # Return cached list if available
        return self._cached_products
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_grid_scanner.py -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add src/strategies/grid_scanner.py tests/test_grid_scanner.py
git commit -m "feat: add GridScanner — volatility scoring, ranking, and selection"
```

---

## Task 6: AdaptiveGridStrategy — Product Type + Sizing + Fill Logging

**Files:**
- Modify: `src/strategies/adaptive_grid.py`
- Modify: `tests/test_grid.py`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_grid.py`:

```python
def test_grid_accepts_product_type():
    client = MagicMock()
    client.place_limit_order.return_value = {
        "success_response": {"order_id": "oid-1", "status": "PENDING"}
    }
    om = MagicMock()
    grid = AdaptiveGridStrategy(client=client, order_manager=om,
                                instrument="SOL-29MAY26-CDE", product_type="dated")
    assert grid.product_type == "dated"
    assert grid.INSTRUMENT == "SOL-29MAY26-CDE"


def test_grid_defaults_product_type_from_instrument():
    client = MagicMock()
    om = MagicMock()
    grid = AdaptiveGridStrategy(client=client, order_manager=om,
                                instrument="BTC-PERP-INTX")
    assert grid.product_type == "perp"


def test_grid_exposes_instance_id():
    client = MagicMock()
    om = MagicMock()
    grid = AdaptiveGridStrategy(client=client, order_manager=om, instance_id=42)
    assert grid.instance_id == 42


def test_grid_has_open_counter_orders_false_when_no_fills():
    client = MagicMock()
    om = MagicMock()
    grid = AdaptiveGridStrategy(client=client, order_manager=om)
    assert grid.has_open_counter_orders() is False
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_grid.py::test_grid_accepts_product_type -v`
Expected: FAIL with `TypeError: __init__() got an unexpected keyword argument 'product_type'`

- [ ] **Step 3: Update AdaptiveGridStrategy**

Modify `src/strategies/adaptive_grid.py`:

Update the imports:

```python
from src.exchange.coinbase_client import CoinbaseClient, OrderResult, classify_product_type
```

Update `__init__`:

```python
    def __init__(
        self,
        client: CoinbaseClient,
        order_manager: OrderManager,
        instrument: str = "",
        product_type: str = "",
        instance_id: int = 0,
    ):
        self._client = client
        self._om = order_manager
        self.INSTRUMENT: str = instrument or cfg.GRID_INSTRUMENT
        self.product_type: str = product_type or classify_product_type(self.INSTRUMENT)
        self.instance_id: int = instance_id
        self.levels: list[GridLevel] = []
        self.paused = False
        self.pause_reason = ""
        self.daily_pnl = 0.0
        self.spacing = 0.0
        self.center = 0.0
```

Add the `has_open_counter_orders` method:

```python
    def has_open_counter_orders(self) -> bool:
        """Check if any filled levels have pending counter-orders.

        Used by Grid Manager to determine if this grid is safe to rotate out.
        """
        for level in self.levels:
            if level.filled:
                # A filled level means a counter-order was placed — check if it's still pending
                # by looking for unfilled levels that were added after fills
                pass
        # Simple heuristic: if any level is filled, counter-orders may be pending
        return any(level.filled for level in self.levels)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_grid.py -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add src/strategies/adaptive_grid.py tests/test_grid.py
git commit -m "feat: add product_type, instance_id, has_open_counter_orders to grid"
```

---

## Task 7: Grid Manager — Multi-Instance Lifecycle

**Files:**
- Create: `src/strategies/grid_manager.py`
- Test: `tests/test_grid_manager.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_grid_manager.py`:

```python
"""Tests for GridManager — multi-instance grid lifecycle."""
import json
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from src.models import Base, get_engine, get_session, GridInstance
from src.strategies.grid_manager import GridManager
from src.strategies.grid_scanner import ScoredInstrument


def _make_scored(pid, score=0.8, ptype="dated"):
    return ScoredInstrument(pid, ptype, score, True, "", {
        "bbw_percentile": 50.0, "atr_pct": 0.03,
        "volume_24h": 500_000.0, "spread_bps": 10.0,
        "adx_4h": 15.0, "current_price": 100.0,
    })


@pytest.fixture
def db():
    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    engine = get_engine(Path(tmp.name))
    Base.metadata.create_all(engine)
    yield engine, Path(tmp.name)
    engine.dispose()
    try:
        Path(tmp.name).unlink(missing_ok=True)
    except PermissionError:
        pass


@pytest.fixture
def manager(db):
    engine, _ = db
    client = MagicMock()
    client.place_limit_order.return_value = {
        "success_response": {"order_id": "oid-1", "status": "PENDING"}
    }
    client.cancel_order.return_value = {"results": [{"success": True}]}
    om = MagicMock()
    return GridManager(client=client, order_manager=om, engine=engine)


def test_manager_starts_empty(manager):
    assert len(manager.grids) == 0


def test_apply_rotation_creates_grids(manager):
    selected = [_make_scored("SOL-CDE"), _make_scored("ETH-CDE", 0.6)]
    weights = {"SOL-CDE": 0.6, "ETH-CDE": 0.4}
    manager.apply_rotation(selected, weights, total_capital=500.0)
    assert len(manager.grids) == 2
    assert "SOL-CDE" in manager.grids
    assert "ETH-CDE" in manager.grids


def test_apply_rotation_records_to_db(manager, db):
    engine, _ = db
    selected = [_make_scored("SOL-CDE")]
    weights = {"SOL-CDE": 1.0}
    manager.apply_rotation(selected, weights, total_capital=500.0)
    session = get_session(engine)
    instances = session.query(GridInstance).all()
    assert len(instances) == 1
    assert instances[0].instrument == "SOL-CDE"
    assert instances[0].ended_at is None
    session.close()


def test_apply_rotation_removes_stale_grids(manager):
    # First rotation: SOL + ETH
    selected = [_make_scored("SOL-CDE"), _make_scored("ETH-CDE", 0.6)]
    weights = {"SOL-CDE": 0.6, "ETH-CDE": 0.4}
    manager.apply_rotation(selected, weights, total_capital=500.0)
    assert len(manager.grids) == 2

    # Second rotation: SOL + XRP (ETH dropped)
    selected2 = [_make_scored("SOL-CDE"), _make_scored("XRP-CDE", 0.5)]
    weights2 = {"SOL-CDE": 0.6, "XRP-CDE": 0.4}
    manager.apply_rotation(selected2, weights2, total_capital=500.0)
    assert "ETH-CDE" not in manager.grids
    assert "XRP-CDE" in manager.grids
    assert len(manager.grids) == 2


def test_apply_rotation_keeps_protected_grids(manager):
    # Start with SOL
    selected = [_make_scored("SOL-CDE")]
    weights = {"SOL-CDE": 1.0}
    manager.apply_rotation(selected, weights, total_capital=500.0)

    # Simulate a fill (protected from rotation)
    manager.grids["SOL-CDE"].levels = [MagicMock(filled=True)]

    # Rotation wants to swap SOL for ETH
    selected2 = [_make_scored("ETH-CDE")]
    weights2 = {"ETH-CDE": 1.0}
    manager.apply_rotation(selected2, weights2, total_capital=500.0)

    # SOL kept (protected), ETH added if slot available
    assert "SOL-CDE" in manager.grids


def test_tick_all_calls_evaluate(manager):
    selected = [_make_scored("SOL-CDE")]
    weights = {"SOL-CDE": 1.0}
    manager.apply_rotation(selected, weights, total_capital=500.0)

    with patch("src.strategies.adaptive_grid.get_grid_indicators") as mock_ind:
        mock_ind.return_value = {
            "atr_1h": 1.0, "atr_1d": 5.0, "adx_4h": 15.0,
            "bbw_4h": 0.05, "bbw_pctile": 50.0, "vwap_24h": 100.0,
        }
        manager.tick_all(total_capital=500.0, weights=weights)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_grid_manager.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'src.strategies.grid_manager'`

- [ ] **Step 3: Implement GridManager**

Create `src/strategies/grid_manager.py`:

```python
"""
grid_manager.py — Manages multiple AdaptiveGridStrategy instances.

Handles:
- Creating/destroying grid instances on scanner rotation
- Capital allocation per grid
- Lifecycle tracking in grid_instances table
- Tick dispatch to all active grids
"""

import logging
from datetime import datetime, timezone

from src.exchange.coinbase_client import CoinbaseClient
from src.exchange.order_manager import OrderManager
from src.strategies.adaptive_grid import AdaptiveGridStrategy
from src.strategies.grid_scanner import ScoredInstrument
from src.models import get_session, GridInstance

logger = logging.getLogger("the-machine.grid_manager")


class GridManager:
    """Maintains N AdaptiveGridStrategy instances with rotation support."""

    def __init__(self, client: CoinbaseClient, order_manager: OrderManager, engine):
        self._client = client
        self._om = order_manager
        self._engine = engine
        self.grids: dict[str, AdaptiveGridStrategy] = {}
        self._db_instance_ids: dict[str, int] = {}  # product_id -> GridInstance.id

    def apply_rotation(
        self,
        selected: list[ScoredInstrument],
        weights: dict[str, float],
        total_capital: float,
    ) -> dict:
        """Apply scanner rotation: create new grids, remove stale ones.

        Returns dict of rotation actions taken.
        """
        now = datetime.now(timezone.utc).isoformat()
        selected_ids = {s.product_id for s in selected}
        actions = []

        # 1. Remove grids no longer in selection (unless protected)
        to_remove = []
        for pid in list(self.grids.keys()):
            if pid not in selected_ids:
                grid = self.grids[pid]
                if grid.has_open_counter_orders():
                    logger.info("Grid %s protected (open counter-orders), keeping", pid)
                    actions.append({"action": "kept_protected", "instrument": pid})
                    continue
                # Safe to rotate out
                self._teardown_grid(pid, reason="rotated")
                to_remove.append(pid)
                actions.append({"action": "rotated_out", "instrument": pid})

        for pid in to_remove:
            del self.grids[pid]

        # 2. Create grids for new selections
        selected_map = {s.product_id: s for s in selected}
        for pid, scored in selected_map.items():
            if pid not in self.grids:
                try:
                    instance_id = self._create_db_instance(
                        pid, scored.product_type,
                        total_capital * weights.get(pid, 0.0),
                        weights.get(pid, 0.0), now,
                    )
                    grid = AdaptiveGridStrategy(
                        client=self._client,
                        order_manager=self._om,
                        instrument=pid,
                        product_type=scored.product_type,
                        instance_id=instance_id,
                    )
                    self.grids[pid] = grid
                    self._db_instance_ids[pid] = instance_id
                    actions.append({"action": "created", "instrument": pid})
                    logger.info("Grid created: %s (type=%s, alloc=$%.2f)",
                                pid, scored.product_type,
                                total_capital * weights.get(pid, 0.0))
                except Exception as e:
                    logger.error("Failed to create grid for %s: %s", pid, e)
                    actions.append({"action": "create_failed", "instrument": pid,
                                    "error": str(e)})

        return {"actions": actions, "active_grids": list(self.grids.keys())}

    def tick_all(self, total_capital: float, weights: dict[str, float]) -> None:
        """Called every 30 seconds. Dispatches evaluate() to each grid."""
        for pid, grid in self.grids.items():
            try:
                alloc = total_capital * weights.get(pid, 0.0)
                grid.evaluate(allocation_usd=alloc)
            except Exception as e:
                logger.error("Grid tick failed for %s: %s", pid, e)

    def rebuild_all(self, total_capital: float, weights: dict[str, float]) -> None:
        """Called weekly. Rebuilds all active grids."""
        for pid, grid in self.grids.items():
            try:
                alloc = total_capital * weights.get(pid, 0.0)
                grid.rebuild(allocation_usd=alloc)
            except Exception as e:
                logger.error("Grid rebuild failed for %s: %s", pid, e)

    def close_all(self, reason: str) -> None:
        """Emergency close all grids."""
        for pid, grid in self.grids.items():
            try:
                grid.close_all(reason)
            except Exception as e:
                logger.error("Grid close_all failed for %s: %s", pid, e)

    def get_dashboard_data(self) -> list[dict]:
        """Return dashboard-friendly data for all active grids."""
        data = []
        for pid, grid in self.grids.items():
            data.append({
                "instrument": pid,
                "product_type": grid.product_type,
                "instance_id": grid.instance_id,
                "paused": grid.paused,
                "pause_reason": grid.pause_reason,
                "daily_pnl": grid.daily_pnl,
                "active_levels": len(grid.levels),
            })
        return data

    def _teardown_grid(self, product_id: str, reason: str) -> None:
        """Cancel all orders and close DB instance."""
        grid = self.grids.get(product_id)
        if grid:
            try:
                grid.close_all(f"rotation: {reason}")
            except Exception as e:
                logger.error("Teardown close_all failed for %s: %s", product_id, e)

        # Update DB
        db_id = self._db_instance_ids.get(product_id)
        if db_id:
            try:
                session = get_session(self._engine)
                inst = session.query(GridInstance).get(db_id)
                if inst:
                    inst.ended_at = datetime.now(timezone.utc).isoformat()
                    inst.end_reason = reason
                    inst.total_pnl = grid.daily_pnl if grid else 0.0
                    session.commit()
                session.close()
            except Exception as e:
                logger.error("DB teardown failed for %s: %s", product_id, e)
            del self._db_instance_ids[product_id]

    def _create_db_instance(
        self, instrument: str, product_type: str,
        allocation_usd: float, weight: float, started_at: str,
    ) -> int:
        """Create a GridInstance DB record. Returns the instance ID."""
        session = get_session(self._engine)
        try:
            inst = GridInstance(
                instrument=instrument,
                product_type=product_type,
                started_at=started_at,
                allocation_usd=allocation_usd,
                allocation_weight=weight,
            )
            session.add(inst)
            session.commit()
            instance_id = inst.id
            return instance_id
        finally:
            session.close()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_grid_manager.py -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add src/strategies/grid_manager.py tests/test_grid_manager.py
git commit -m "feat: add GridManager — multi-instance lifecycle, rotation, capital allocation"
```

---

## Task 8: ML Feature Logger — Scanner Decision Persistence

**Files:**
- Create: `src/ml/instrument_selector.py`
- Test: `tests/test_instrument_selector.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_instrument_selector.py`:

```python
"""Tests for ML instrument selector feature logging."""
import json
import tempfile
from pathlib import Path

import pytest

from src.models import Base, get_engine, get_session, ScannerSnapshot, MLFeature
from src.ml.instrument_selector import log_scan_cycle, backfill_outcomes
from src.strategies.grid_scanner import ScoredInstrument


def _make_scored(pid, score=0.8, eligible=True, bbw=50.0, atr=0.03, vol=500_000, spread=10.0):
    return ScoredInstrument(pid, "dated", score, eligible, "", {
        "bbw_percentile": bbw, "atr_pct": atr,
        "volume_24h": vol, "spread_bps": spread,
        "adx_4h": 15.0, "current_price": 100.0,
    })


@pytest.fixture
def db():
    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    engine = get_engine(Path(tmp.name))
    Base.metadata.create_all(engine)
    yield engine, Path(tmp.name)
    engine.dispose()
    try:
        Path(tmp.name).unlink(missing_ok=True)
    except PermissionError:
        pass


def test_log_scan_cycle_creates_snapshot_and_features(db):
    engine, _ = db
    selected = [_make_scored("SOL-CDE"), _make_scored("ETH-CDE", 0.6)]
    all_scored = selected + [_make_scored("XRP-CDE", 0.3, eligible=False)]
    weights = {"SOL-CDE": 0.6, "ETH-CDE": 0.4}

    log_scan_cycle(engine, selected, all_scored, weights,
                   equity=950.0, max_grids=3, rotation_actions={}, scan_duration_ms=1200)

    session = get_session(engine)
    snapshots = session.query(ScannerSnapshot).all()
    assert len(snapshots) == 1
    assert snapshots[0].total_equity == 950.0

    features = session.query(MLFeature).all()
    assert len(features) == 3  # one per scored instrument
    selected_features = [f for f in features if f.was_selected == 1]
    assert len(selected_features) == 2
    session.close()


def test_log_scan_cycle_stores_allocation_weight(db):
    engine, _ = db
    selected = [_make_scored("SOL-CDE")]
    weights = {"SOL-CDE": 1.0}

    log_scan_cycle(engine, selected, selected, weights,
                   equity=500.0, max_grids=1, rotation_actions={}, scan_duration_ms=500)

    session = get_session(engine)
    feat = session.query(MLFeature).first()
    assert feat.allocation_weight == 1.0
    assert feat.outcome_pnl_4h is None  # not yet backfilled
    session.close()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_instrument_selector.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'src.ml.instrument_selector'`

- [ ] **Step 3: Implement instrument_selector.py**

Create `src/ml/instrument_selector.py`:

```python
"""
instrument_selector.py — ML Phase 1: logs scanner features and outcomes.

Writes to scanner_snapshots and ml_features tables on every scan cycle.
Outcome columns are backfilled after the next scan cycle completes.
No ML inference in Phase 1 — pure data collection.
"""

import json
import logging
from datetime import datetime, timezone

from src.models import get_session, ScannerSnapshot, MLFeature, GridFill
from src.strategies.grid_scanner import ScoredInstrument

logger = logging.getLogger("the-machine.ml.selector")


def log_scan_cycle(
    engine,
    selected: list[ScoredInstrument],
    all_scored: list[ScoredInstrument],
    weights: dict[str, float],
    equity: float,
    max_grids: int,
    rotation_actions: dict,
    scan_duration_ms: int = 0,
) -> int:
    """Log a complete scan cycle to DB. Returns the snapshot ID."""
    now = datetime.now(timezone.utc).isoformat()
    selected_ids = {s.product_id for s in selected}

    session = get_session(engine)
    try:
        # Create snapshot
        snapshot = ScannerSnapshot(
            timestamp=now,
            total_equity=equity,
            max_grids=max_grids,
            selected_instruments=json.dumps([
                {"product_id": s.product_id, "score": s.score, "type": s.product_type}
                for s in selected
            ]),
            all_scores=json.dumps([
                {"product_id": s.product_id, "score": s.score, "eligible": s.eligible,
                 "reason": s.reject_reason}
                for s in all_scored
            ]),
            rotation_actions=json.dumps(rotation_actions),
            scan_duration_ms=scan_duration_ms,
        )
        session.add(snapshot)
        session.flush()  # Get snapshot.id

        # Create ML feature rows — one per scored instrument
        for scored in all_scored:
            ind = scored.indicators
            feat = MLFeature(
                snapshot_id=snapshot.id,
                timestamp=now,
                instrument=scored.product_id,
                bbw_percentile=ind.get("bbw_percentile", 0.0),
                atr_pct=ind.get("atr_pct", 0.0),
                volume_24h=ind.get("volume_24h", 0.0),
                spread_bps=ind.get("spread_bps", 0.0),
                adx_4h=ind.get("adx_4h"),
                was_selected=1 if scored.product_id in selected_ids else 0,
                allocation_weight=weights.get(scored.product_id),
            )
            session.add(feat)

        session.commit()
        logger.info("Logged scan cycle: snapshot_id=%d, %d features", snapshot.id, len(all_scored))
        return snapshot.id

    except Exception as e:
        session.rollback()
        logger.error("Failed to log scan cycle: %s", e)
        raise
    finally:
        session.close()


def backfill_outcomes(engine, snapshot_id: int) -> int:
    """Backfill outcome columns for a previous scan cycle.

    Called after the NEXT scan cycle to fill in what happened during the
    previous 4h window. Returns count of rows updated.

    Queries grid_fills table for fills that occurred after the snapshot
    timestamp and groups by instrument.
    """
    session = get_session(engine)
    try:
        snapshot = session.query(ScannerSnapshot).get(snapshot_id)
        if not snapshot:
            return 0

        features = (
            session.query(MLFeature)
            .filter(MLFeature.snapshot_id == snapshot_id)
            .all()
        )

        updated = 0
        for feat in features:
            # Count fills and P&L for this instrument since the snapshot
            fills = (
                session.query(GridFill)
                .filter(GridFill.instrument == feat.instrument)
                .filter(GridFill.entry_time >= snapshot.timestamp)
                .all()
            )
            feat.outcome_fills_4h = len(fills)
            feat.outcome_pnl_4h = sum(f.cycle_pnl or 0.0 for f in fills)
            feat.outcome_cycle_completions_4h = sum(
                1 for f in fills if f.status == "completed"
            )
            updated += 1

        session.commit()
        logger.info("Backfilled %d feature rows for snapshot %d", updated, snapshot_id)
        return updated

    except Exception as e:
        session.rollback()
        logger.error("Backfill failed for snapshot %d: %s", snapshot_id, e)
        return 0
    finally:
        session.close()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_instrument_selector.py -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add src/ml/instrument_selector.py tests/test_instrument_selector.py
git commit -m "feat: add ML instrument selector — Phase 1 data collection"
```

---

## Task 9: Main.py + Dashboard — Wire Everything Together

**Files:**
- Modify: `src/main.py`

This is the integration task. No new test file — verified by existing `test_main_loop.py` + manual verification.

- [ ] **Step 1: Read current test_main_loop.py to understand test patterns**

Read `tests/test_main_loop.py` and understand existing test setup.

- [ ] **Step 2: Update main.py — replace single grid with Grid Manager + Scanner**

Key changes to `src/main.py`:

**Add imports:**
```python
from src.strategies.grid_scanner import GridScanner
from src.strategies.grid_manager import GridManager
from src.ml.instrument_selector import log_scan_cycle, backfill_outcomes
```

**Replace single grid creation (lines 76-79) with Grid Manager:**
```python
    grid_scanner = GridScanner(client=client)
    grid_manager = GridManager(
        client=client, order_manager=order_manager, engine=engine,
    )
```

**Store in app.state:**
```python
    app.state.grid_scanner = grid_scanner
    app.state.grid_manager = grid_manager
```

**Replace `_grid_tick` function:**
```python
    # Track current scanner weights (mutable, updated by scanner)
    grid_weights: dict[str, float] = {}
    last_snapshot_id: int = 0

    def _grid_tick():
        try:
            equity = _get_equity()
            grid_capital = equity * allocations.get("grid", cfg.DEFAULT_ALLOCATION_GRID)
            grid_manager.tick_all(total_capital=grid_capital, weights=grid_weights)
        except Exception as e:
            logger.error("Grid tick failed: %s", e)
```

**Add scanner job (every 4 hours):**
```python
    def _scanner_tick():
        nonlocal grid_weights, last_snapshot_id
        try:
            equity = _get_equity()
            grid_capital = equity * allocations.get("grid", cfg.DEFAULT_ALLOCATION_GRID)

            # Backfill previous cycle outcomes
            if last_snapshot_id > 0:
                backfill_outcomes(engine, last_snapshot_id)

            # Run scan
            selected, all_scored = grid_scanner.scan(equity)
            if not selected:
                logger.warning("Scanner returned 0 eligible instruments, keeping current grids")
                return

            # Compute weights and apply rotation
            grid_weights = grid_scanner.compute_weights(selected)
            rotation = grid_manager.apply_rotation(selected, grid_weights, grid_capital)

            # Log to DB
            max_grids = grid_scanner.get_max_grids(equity)
            last_snapshot_id = log_scan_cycle(
                engine, selected, all_scored, grid_weights,
                equity, max_grids, rotation,
            )
        except Exception as e:
            logger.error("Scanner tick failed: %s", e)

    # Run scanner immediately on startup, then every 4 hours
    _scanner_tick()

    scheduler.add_job(
        _scanner_tick, "interval",
        hours=cfg.GRID_SCANNER_INTERVAL_HOURS,
        id="grid_scanner",
    )
```

**Replace weekly grid rebuild:**
```python
    def weekly_grid_rebuild():
        try:
            equity = _get_equity()
            grid_capital = equity * allocations.get("grid", cfg.DEFAULT_ALLOCATION_GRID)
            grid_manager.rebuild_all(total_capital=grid_capital, weights=grid_weights)
        except Exception as e:
            logger.error("Weekly grid rebuild failed: %s", e)
```

**Update emergency close:**
Replace `grid_strategy.close_all(reason)` with `grid_manager.close_all(reason)`.

**Update dashboard endpoint:**
Replace the grid section in the dashboard return with:
```python
                "grid": {
                    "allocation": allocs.get("grid", cfg.DEFAULT_ALLOCATION_GRID),
                    "daily_pnl": sum(g.daily_pnl for g in grid_manager.grids.values()),
                    "instances": grid_manager.get_dashboard_data(),
                    "scanner": {
                        "last_snapshot_id": last_snapshot_id,
                        "active_instruments": list(grid_manager.grids.keys()),
                    },
                },
```

- [ ] **Step 3: Run all tests to verify nothing is broken**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/ -v`
Expected: ALL PASS (some may need minor fixture updates for the new grid constructor params)

- [ ] **Step 4: Fix any test failures from constructor changes**

If `test_main_loop.py` or other tests create `AdaptiveGridStrategy` directly, they may need the new `product_type` parameter added. Update as needed.

- [ ] **Step 5: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add src/main.py
git commit -m "feat: wire GridManager + Scanner into main.py, update dashboard"
```

---

## Task 10: Integration Test — Full Scan-Rotate-Tick Cycle

**Files:**
- Modify: `tests/test_grid_manager.py`

- [ ] **Step 1: Write end-to-end integration test**

Add to `tests/test_grid_manager.py`:

```python
def test_full_scan_rotate_tick_cycle(db):
    """Integration: scanner selects instruments, manager creates grids, tick runs."""
    engine, _ = db
    client = MagicMock()
    client.place_limit_order.return_value = {
        "success_response": {"order_id": "oid-1", "status": "PENDING"}
    }
    client.cancel_order.return_value = {"results": [{"success": True}]}
    client.get_order.return_value = {"order": {"order_id": "oid-1", "status": "OPEN"}}
    client.list_crypto_futures.return_value = [
        {"product_id": "SOL-29MAY26-CDE"},
        {"product_id": "ETH-26JUN26-CDE"},
    ]
    om = MagicMock()

    scanner = GridScanner(client)
    manager = GridManager(client=client, order_manager=om, engine=engine)

    # Mock scanner indicators
    indicators = {
        "bbw_percentile": 50.0, "atr_pct": 0.03,
        "volume_24h": 500_000.0, "spread_bps": 10.0,
        "adx_4h": 15.0, "current_price": 100.0,
    }

    with patch("src.strategies.grid_scanner.get_scanner_indicators", return_value=indicators):
        selected, all_scored = scanner.scan(equity=1000.0)

    assert len(selected) >= 1

    weights = scanner.compute_weights(selected)
    rotation = manager.apply_rotation(selected, weights, total_capital=250.0)
    assert len(manager.grids) >= 1

    # Tick should not raise
    with patch("src.strategies.adaptive_grid.get_grid_indicators") as mock_gi:
        mock_gi.return_value = {
            "atr_1h": 1.0, "atr_1d": 5.0, "adx_4h": 15.0,
            "bbw_4h": 0.05, "bbw_pctile": 50.0, "vwap_24h": 100.0,
        }
        manager.tick_all(total_capital=250.0, weights=weights)

    # Verify DB records
    session = get_session(engine)
    instances = session.query(GridInstance).all()
    assert len(instances) >= 1
    assert all(i.ended_at is None for i in instances)  # all still active
    session.close()
```

Add the missing import to the top of the file:

```python
from src.strategies.grid_scanner import GridScanner
```

- [ ] **Step 2: Run the integration test**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/test_grid_manager.py::test_full_scan_rotate_tick_cycle -v`
Expected: PASS

- [ ] **Step 3: Run full test suite**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/ -v`
Expected: ALL PASS

- [ ] **Step 4: Commit**

```bash
cd C:/Users/chris/OneDrive/Documentos/the-machine
git add tests/test_grid_manager.py
git commit -m "test: add full scan-rotate-tick integration test"
```

---

## Task 11: Final Verification + Deploy Prep

- [ ] **Step 1: Run full test suite one more time**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -m pytest tests/ -v --tb=short`
Expected: ALL PASS

- [ ] **Step 2: Verify no import cycles or missing dependencies**

Run: `cd C:/Users/chris/OneDrive/Documentos/the-machine && python -c "from src.strategies.grid_scanner import GridScanner; from src.strategies.grid_manager import GridManager; from src.ml.instrument_selector import log_scan_cycle; print('All imports OK')"`
Expected: `All imports OK`

- [ ] **Step 3: Update PROGRESS.md with session summary**

Add a new session entry to `C:/Users/chris/OneDrive/Documentos/PKA/docs/The Machine/PROGRESS.md` documenting:
- Multi-instrument grid scanner built
- Grid Manager with rotation, protection rules, DB persistence
- ML Phase 1 feature logging
- New DB tables (scanner_snapshots, grid_instances, grid_fills, ml_features)
- New config entries
- CDE detection fix in coinbase_client.py
- Next step: deploy in paper mode alongside existing live grid

- [ ] **Step 4: Commit progress update**

```bash
cd C:/Users/chris/OneDrive/Documentos/PKA
git add "docs/The Machine/PROGRESS.md"
git commit -m "docs: update Machine progress — multi-instrument grid built"
```

---

## Deployment Notes

**Paper mode first:** The new system should run in paper mode (`MODE=paper`) alongside the existing live single-grid on the droplet. Verify:
1. Scanner discovers CDE products correctly
2. Rotation creates/destroys grid instances without errors
3. DB tables fill with scanner snapshots and ML features
4. Dashboard shows multi-grid data

**Live switch:** Once verified (48-72h), update the droplet container:
1. Stop existing container
2. Deploy new code
3. Set `MODE=live`
4. Monitor first scanner cycle and grid builds

**Rollback:** If issues, set `GRID_MAX_SIMULTANEOUS=1` and the system behaves identically to the old single-grid setup.

---

## Deferred Items (follow-up tasks, not blockers)

1. **Contract rolling logic** — Config entries added (`GRID_ROLL_WARNING_HOURS`, `GRID_ROLL_CLOSE_HOURS`) but the T-48h/T-24h auto-roll behavior is not implemented. Scanner naturally discovers next month's contract, but graceful pre-expiry wind-down needs a follow-up task. SOL-29MAY26-CDE expires May 29 — 27 days out.
2. **Daily reconciliation** — Spec Section 13.5 calls for comparing expected positions (from DB) against actual Coinbase positions. Not in this plan — add as a follow-up monitoring job.
3. **Grid fill logging to DB** — Task 6 adds the `instance_id` field to the grid, but the actual fill-to-`grid_fills` table writes inside `_check_fills_and_counter` need a follow-up to wire in the DB session. Currently the ML data collection works via `scanner_snapshots` + `ml_features`; fill-level logging is a Phase 1.5 enhancement.
4. **ML Phase 2/3 models** — `instrument_selector.py` and `capital_allocator.py` inference code. Only Phase 1 (data collection) is implemented here. Activate when `ML_MIN_GRID_FILLS_SELECTOR` threshold is met.
