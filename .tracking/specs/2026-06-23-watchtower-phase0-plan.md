# Watchtower Phase 0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an alternative data observatory that runs 4 signal scrapers on schedule, detects notable events and cross-signal confluence, emails alerts, and tracks prediction accuracy — all in paper/observation mode.

**Architecture:** Python Docker container on existing droplet (104.131.176.130). APScheduler drives 4 scrapers (EDGAR Form 4, career pages, Polymarket/Kalshi, Philly Fed PDF). SQLite stores all data. Gmail SMTP sends alerts. Confluence engine detects cross-domain signal alignment.

**Tech Stack:** Python 3.11+, requests, beautifulsoup4, pdfplumber, apscheduler, structlog, sqlite3 (stdlib), Docker.

## Global Constraints

- All data sources must be FREE ($0/month). No paid APIs.
- No auto-trading. Paper/observation only.
- Email via Gmail SMTP to christoph3reverding@gmail.com (credentials via env vars).
- Same subject line deduped within 24 hours.
- All times UTC in scheduler. Comments note CT equivalent.
- SEC EDGAR requires User-Agent header with contact email per their fair access policy.
- Project lives at `/app/watchtower/` on droplet. Separate compose file from VEOE.
- Design spec: `.tracking/specs/2026-06-23-watchtower-phase0-design.md`

---

### Task 1: Foundation — Database, Email, Config, Project Structure

**Files:**
- Create: `watchtower/db.py`
- Create: `watchtower/alerts/email.py`
- Create: `watchtower/config.py`
- Create: `watchtower/config.yaml`
- Create: `watchtower/requirements.txt`
- Create: `watchtower/__init__.py`
- Create: `watchtower/alerts/__init__.py`
- Create: `tests/__init__.py`
- Create: `tests/test_db.py`
- Create: `tests/test_email.py`
- Create: `tests/test_config.py`

**Interfaces:**
- Produces: `db.get_connection() -> sqlite3.Connection`
- Produces: `db.init_db(db_path: str) -> None` — creates all tables
- Produces: `alerts.email.send_alert(subject: str, body: str, config: dict) -> bool`
- Produces: `config.load_config(path: str) -> dict`

- [ ] **Step 1: Create project structure + requirements.txt**

```
watchtower/
├── watchtower/
│   ├── __init__.py
│   ├── alerts/
│   │   └── __init__.py
│   ├── scrapers/
│   │   └── __init__.py
│   └── engine/
│       └── __init__.py
├── tests/
│   └── __init__.py
├── requirements.txt
└── config.yaml
```

Create `watchtower/requirements.txt`:
```
requests>=2.31.0
beautifulsoup4>=4.12.0
pdfplumber>=0.10.0
apscheduler>=3.10.0
structlog>=23.1.0
pyyaml>=6.0
```

All `__init__.py` files are empty.

- [ ] **Step 2: Write failing tests for database**

Create `tests/test_db.py`:
```python
import os
import sqlite3
import tempfile
import pytest
from watchtower.db import init_db, get_connection


@pytest.fixture
def db_path():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    yield path
    os.unlink(path)


def test_init_db_creates_tables(db_path):
    init_db(db_path)
    conn = sqlite3.connect(db_path)
    cursor = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
    )
    tables = [row[0] for row in cursor.fetchall()]
    conn.close()
    assert "insider_filings" in tables
    assert "insider_clusters" in tables
    assert "job_postings" in tables
    assert "job_velocity" in tables
    assert "pred_market_events" in tables
    assert "philly_fed_revisions" in tables
    assert "confluences" in tables
    assert "accuracy_tracking" in tables
    assert "email_dedup" in tables


def test_get_connection_returns_connection(db_path):
    init_db(db_path)
    conn = get_connection(db_path)
    assert isinstance(conn, sqlite3.Connection)
    conn.close()


def test_init_db_is_idempotent(db_path):
    init_db(db_path)
    init_db(db_path)  # should not raise
    conn = sqlite3.connect(db_path)
    cursor = conn.execute(
        "SELECT count(name) FROM sqlite_master WHERE type='table'"
    )
    count = cursor.fetchone()[0]
    conn.close()
    assert count >= 9
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd watchtower && python -m pytest tests/test_db.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'watchtower.db'`

- [ ] **Step 4: Implement database module**

Create `watchtower/db.py`:
```python
import sqlite3
from pathlib import Path

SCHEMA = """
CREATE TABLE IF NOT EXISTS insider_filings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filing_date TEXT NOT NULL,
    issuer_cik TEXT NOT NULL,
    issuer_name TEXT,
    issuer_ticker TEXT,
    filer_name TEXT NOT NULL,
    filer_relationship TEXT,
    transaction_code TEXT NOT NULL,
    shares REAL,
    price_per_share REAL,
    total_value REAL,
    is_10b5_1 INTEGER DEFAULT 0,
    raw_url TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS insider_clusters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    issuer_ticker TEXT NOT NULL,
    issuer_name TEXT,
    issuer_cik TEXT,
    market_cap REAL,
    sector TEXT,
    num_insiders INTEGER NOT NULL,
    total_dollar_value REAL,
    first_filing_date TEXT NOT NULL,
    last_filing_date TEXT NOT NULL,
    insider_names TEXT,
    price_at_detection REAL,
    date_detected TEXT DEFAULT (datetime('now')),
    alerted INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS job_postings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scrape_date TEXT NOT NULL,
    company_ticker TEXT NOT NULL,
    company_name TEXT,
    sector TEXT,
    total_postings INTEGER,
    senior_postings INTEGER DEFAULT 0,
    mid_postings INTEGER DEFAULT 0,
    junior_postings INTEGER DEFAULT 0,
    scrape_source TEXT,
    scrape_status TEXT DEFAULT 'ok',
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS job_velocity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    week_ending TEXT NOT NULL,
    company_ticker TEXT NOT NULL,
    postings_7d_ago INTEGER,
    postings_now INTEGER,
    velocity_7d_pct REAL,
    velocity_14d_pct REAL,
    seniority_shift REAL,
    alert_fired INTEGER DEFAULT 0,
    alert_direction TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS pred_market_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scrape_date TEXT NOT NULL,
    event_name TEXT NOT NULL,
    event_date TEXT,
    category TEXT,
    polymarket_prob REAL,
    kalshi_prob REAL,
    consensus_prob REAL,
    consensus_source TEXT,
    divergence_pct REAL,
    resolved INTEGER DEFAULT 0,
    actual_outcome TEXT,
    pred_market_correct INTEGER,
    consensus_correct INTEGER,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS philly_fed_revisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    publication_date TEXT NOT NULL,
    quarter TEXT NOT NULL,
    predicted_direction TEXT,
    predicted_magnitude REAL,
    current_bls_number REAL,
    pdf_url TEXT,
    actual_revision_direction TEXT,
    actual_revision_magnitude REAL,
    accuracy_checked INTEGER DEFAULT 0,
    alerted INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    UNIQUE(quarter)
);

CREATE TABLE IF NOT EXISTS confluences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date_detected TEXT DEFAULT (datetime('now')),
    signals_json TEXT NOT NULL,
    sector TEXT,
    ticker TEXT,
    score TEXT NOT NULL,
    description TEXT,
    alerted INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS accuracy_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    signal_type TEXT NOT NULL,
    signal_id INTEGER NOT NULL,
    ticker TEXT,
    detection_date TEXT NOT NULL,
    detection_price REAL,
    check_date TEXT,
    check_days INTEGER,
    check_price REAL,
    stock_return REAL,
    benchmark_return REAL,
    alpha REAL,
    hit INTEGER,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS email_dedup (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_hash TEXT NOT NULL,
    sent_at TEXT DEFAULT (datetime('now'))
);
"""


def init_db(db_path: str) -> None:
    conn = sqlite3.connect(db_path)
    conn.executescript(SCHEMA)
    conn.commit()
    conn.close()


def get_connection(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd watchtower && python -m pytest tests/test_db.py -v`
Expected: 3 PASSED

- [ ] **Step 6: Write failing tests for config**

Create `tests/test_config.py`:
```python
import tempfile
import os
import pytest
from watchtower.config import load_config


def test_load_config_returns_dict():
    cfg = load_config(os.path.join(os.path.dirname(__file__), "..", "config.yaml"))
    assert isinstance(cfg, dict)
    assert "email" in cfg
    assert "insider_buys" in cfg
    assert "job_postings" in cfg
    assert "pred_markets" in cfg
    assert "confluence" in cfg


def test_config_has_thresholds():
    cfg = load_config(os.path.join(os.path.dirname(__file__), "..", "config.yaml"))
    assert cfg["insider_buys"]["min_cluster_size"] == 3
    assert cfg["insider_buys"]["cluster_window_days"] == 15
    assert cfg["pred_markets"]["divergence_threshold_pct"] == 15
    assert cfg["confluence"]["window_days"] == 7
```

- [ ] **Step 7: Implement config module + config.yaml**

Create `watchtower/config.py`:
```python
import yaml
from pathlib import Path


def load_config(path: str = None) -> dict:
    if path is None:
        path = str(Path(__file__).parent.parent / "config.yaml")
    with open(path, "r") as f:
        return yaml.safe_load(f)
```

Create `config.yaml` with the full config from the spec (see design doc section "Config File").

- [ ] **Step 8: Run config tests**

Run: `python -m pytest tests/test_config.py -v`
Expected: 2 PASSED

- [ ] **Step 9: Write failing test for email + dedup**

Create `tests/test_email.py`:
```python
import os
import tempfile
import pytest
from unittest.mock import patch, MagicMock
from watchtower.alerts.email import send_alert, _is_deduped, _record_sent
from watchtower.db import init_db


@pytest.fixture
def db_path():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    init_db(path)
    yield path
    os.unlink(path)


def test_dedup_blocks_repeat_within_24h(db_path):
    subject = "[WATCHTOWER] Test Alert"
    assert _is_deduped(subject, db_path) is False
    _record_sent(subject, db_path)
    assert _is_deduped(subject, db_path) is True


def test_dedup_allows_different_subject(db_path):
    _record_sent("[WATCHTOWER] Alert A", db_path)
    assert _is_deduped("[WATCHTOWER] Alert B", db_path) is False


@patch("watchtower.alerts.email.smtplib.SMTP")
def test_send_alert_calls_smtp(mock_smtp_class, db_path):
    mock_smtp = MagicMock()
    mock_smtp_class.return_value.__enter__ = MagicMock(return_value=mock_smtp)
    mock_smtp_class.return_value.__exit__ = MagicMock(return_value=False)

    config = {
        "email": {
            "smtp_server": "smtp.gmail.com",
            "smtp_port": 587,
            "from_address": "test@test.com",
            "to_address": "test@test.com",
        }
    }
    with patch.dict(os.environ, {
        "WATCHTOWER_EMAIL_USER": "user",
        "WATCHTOWER_EMAIL_PASS": "pass",
    }):
        result = send_alert("[WATCHTOWER] Test", "body", config, db_path)
    assert result is True
```

- [ ] **Step 10: Implement email module**

Create `watchtower/alerts/email.py`:
```python
import hashlib
import os
import smtplib
import sqlite3
from email.mime.text import MIMEText
from datetime import datetime, timedelta

import structlog

log = structlog.get_logger()


def _subject_hash(subject: str) -> str:
    return hashlib.sha256(subject.encode()).hexdigest()[:16]


def _is_deduped(subject: str, db_path: str) -> bool:
    conn = sqlite3.connect(db_path)
    cutoff = (datetime.utcnow() - timedelta(hours=24)).isoformat()
    row = conn.execute(
        "SELECT 1 FROM email_dedup WHERE subject_hash = ? AND sent_at > ?",
        (_subject_hash(subject), cutoff),
    ).fetchone()
    conn.close()
    return row is not None


def _record_sent(subject: str, db_path: str) -> None:
    conn = sqlite3.connect(db_path)
    conn.execute(
        "INSERT INTO email_dedup (subject_hash) VALUES (?)",
        (_subject_hash(subject),),
    )
    conn.commit()
    conn.close()


def send_alert(subject: str, body: str, config: dict, db_path: str) -> bool:
    if _is_deduped(subject, db_path):
        log.info("email_deduped", subject=subject)
        return False

    email_cfg = config["email"]
    user = os.environ.get("WATCHTOWER_EMAIL_USER", email_cfg.get("from_address"))
    password = os.environ.get("WATCHTOWER_EMAIL_PASS", "")

    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = email_cfg["from_address"]
    msg["To"] = email_cfg["to_address"]

    try:
        with smtplib.SMTP(email_cfg["smtp_server"], email_cfg["smtp_port"]) as server:
            server.starttls()
            server.login(user, password)
            server.sendmail(
                email_cfg["from_address"],
                email_cfg["to_address"],
                msg.as_string(),
            )
        _record_sent(subject, db_path)
        log.info("email_sent", subject=subject)
        return True
    except Exception as e:
        log.error("email_failed", subject=subject, error=str(e))
        return False
```

- [ ] **Step 11: Run all tests**

Run: `python -m pytest tests/ -v`
Expected: 8 PASSED

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "feat(watchtower): foundation — db schema, email alerts, config loader"
```

---

### Task 2: Insider Cluster Buys Scraper

**Files:**
- Create: `watchtower/scrapers/insider_buys.py`
- Create: `tests/test_insider_buys.py`

**Interfaces:**
- Consumes: `db.get_connection(db_path)`, `db.init_db(db_path)`, `alerts.email.send_alert(...)`
- Produces: `insider_buys.scrape_form4_filings(db_path: str, config: dict) -> int` — returns count of new filings stored
- Produces: `insider_buys.detect_clusters(db_path: str, config: dict) -> list[dict]` — returns list of new clusters detected
- Produces: `insider_buys.run(db_path: str, config: dict) -> None` — full cycle: scrape + detect + alert

- [ ] **Step 1: Write failing tests**

Create `tests/test_insider_buys.py`:
```python
import os
import tempfile
import json
import pytest
from unittest.mock import patch, MagicMock
from watchtower.db import init_db, get_connection
from watchtower.scrapers.insider_buys import (
    parse_form4_xml,
    detect_clusters,
    _is_open_market_purchase,
)


@pytest.fixture
def db_path():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    init_db(path)
    yield path
    os.unlink(path)


SAMPLE_FORM4_XML = """<?xml version="1.0"?>
<ownershipDocument>
  <issuer>
    <issuerCik>0001234567</issuerCik>
    <issuerName>Test Corp</issuerName>
    <issuerTradingSymbol>TSTC</issuerTradingSymbol>
  </issuer>
  <reportingOwner>
    <reportingOwnerId>
      <rptOwnerName>John Smith</rptOwnerName>
    </reportingOwnerId>
    <reportingOwnerRelationship>
      <isDirector>1</isDirector>
      <isOfficer>1</isOfficer>
      <officerTitle>CEO</officerTitle>
    </reportingOwnerRelationship>
  </reportingOwner>
  <nonDerivativeTable>
    <nonDerivativeTransaction>
      <transactionDate><value>2026-06-20</value></transactionDate>
      <transactionCoding>
        <transactionCode>P</transactionCode>
      </transactionCoding>
      <transactionAmounts>
        <transactionShares><value>10000</value></transactionShares>
        <transactionPricePerShare><value>25.50</value></transactionPricePerShare>
      </transactionAmounts>
    </nonDerivativeTransaction>
  </nonDerivativeTable>
</ownershipDocument>"""


def test_parse_form4_xml_extracts_fields():
    result = parse_form4_xml(SAMPLE_FORM4_XML)
    assert result is not None
    assert result["issuer_cik"] == "0001234567"
    assert result["issuer_ticker"] == "TSTC"
    assert result["filer_name"] == "John Smith"
    assert result["transaction_code"] == "P"
    assert result["shares"] == 10000.0
    assert result["price_per_share"] == 25.50
    assert result["filer_relationship"] == "CEO"


def test_is_open_market_purchase():
    assert _is_open_market_purchase("P") is True
    assert _is_open_market_purchase("S") is False
    assert _is_open_market_purchase("A") is False
    assert _is_open_market_purchase("M") is False


def test_detect_clusters_finds_cluster(db_path):
    conn = get_connection(db_path)
    # Insert 3 filings from different insiders at same company within 15 days
    for i, name in enumerate(["Alice CEO", "Bob CFO", "Carol Director"]):
        conn.execute(
            """INSERT INTO insider_filings
            (filing_date, issuer_cik, issuer_name, issuer_ticker,
             filer_name, filer_relationship, transaction_code,
             shares, price_per_share, total_value)
            VALUES (?, ?, ?, ?, ?, ?, 'P', ?, ?, ?)""",
            (f"2026-06-{20+i}", "0001234567", "Test Corp", "TSTC",
             name, "Officer", 1000*(i+1), 25.0, 25000*(i+1)),
        )
    conn.commit()
    conn.close()

    config = {"insider_buys": {"min_cluster_size": 3, "cluster_window_days": 15, "max_market_cap": 5_000_000_000}}
    clusters = detect_clusters(db_path, config)
    assert len(clusters) == 1
    assert clusters[0]["num_insiders"] == 3
    assert clusters[0]["issuer_ticker"] == "TSTC"


def test_detect_clusters_ignores_spread_filings(db_path):
    conn = get_connection(db_path)
    # Insert 3 filings spread over 30 days (outside 15-day window)
    for i, name in enumerate(["Alice", "Bob", "Carol"]):
        conn.execute(
            """INSERT INTO insider_filings
            (filing_date, issuer_cik, issuer_name, issuer_ticker,
             filer_name, filer_relationship, transaction_code,
             shares, price_per_share, total_value)
            VALUES (?, ?, ?, ?, ?, ?, 'P', 1000, 25.0, 25000)""",
            (f"2026-06-{1 + i*12}", "0001234567", "Test Corp", "TSTC",
             name, "Officer"),
        )
    conn.commit()
    conn.close()

    config = {"insider_buys": {"min_cluster_size": 3, "cluster_window_days": 15, "max_market_cap": 5_000_000_000}}
    clusters = detect_clusters(db_path, config)
    assert len(clusters) == 0
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/test_insider_buys.py -v`
Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Implement insider_buys scraper**

Create `watchtower/scrapers/insider_buys.py`. Key functions:

- `parse_form4_xml(xml_text: str) -> dict | None` — parse a single Form 4 XML filing into a flat dict
- `_is_open_market_purchase(code: str) -> bool` — True only for transactionCode "P"
- `_get_relationship(owner_element) -> str` — extract officer title or "Director"/"10% Owner"
- `scrape_form4_filings(db_path: str, config: dict) -> int` — fetch recent Form 4 filings from EDGAR full-text search RSS feed (`https://efts.sec.gov/LATEST/search-index?q=%224%22&dateRange=custom&startdt=YYYY-MM-DD&enddt=YYYY-MM-DD&forms=4`), parse each, store new ones, return count
- `detect_clusters(db_path: str, config: dict) -> list[dict]` — query insider_filings grouped by issuer_cik, find groups with 3+ distinct filer_names where max(filing_date) - min(filing_date) <= 15 days, not already in insider_clusters table
- `_format_cluster_email(cluster: dict) -> tuple[str, str]` — returns (subject, body)
- `run(db_path: str, config: dict) -> None` — scrape + detect + alert

EDGAR requests must include `User-Agent: Watchtower/1.0 (christoph3reverding@gmail.com)` header and respect 10 requests/second rate limit (0.1s sleep between requests).

For market cap enrichment, use SEC company tickers JSON (`https://www.sec.gov/files/company_tickers.json`) for ticker resolution. Market cap lookup via free Yahoo Finance scrape or Financial Modeling Prep free tier — if lookup fails, still detect the cluster but mark market_cap as NULL.

- [ ] **Step 4: Run tests to verify they pass**

Run: `python -m pytest tests/test_insider_buys.py -v`
Expected: 4 PASSED

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(watchtower): insider cluster buys scraper — EDGAR Form 4 parsing + cluster detection"
```

---

### Task 3: Job Posting Velocity Scraper

**Files:**
- Create: `watchtower/scrapers/job_postings.py`
- Create: `watchtower/watchlist.yaml`
- Create: `tests/test_job_postings.py`

**Interfaces:**
- Consumes: `db.get_connection(db_path)`, `alerts.email.send_alert(...)`
- Produces: `job_postings.scrape_company(ticker: str, company: dict, db_path: str) -> dict` — scrape one company, return {ticker, total, senior, mid, junior, status}
- Produces: `job_postings.scrape_all(db_path: str, config: dict, watchlist: dict) -> int` — scrape all companies, return count
- Produces: `job_postings.analyze_velocity(db_path: str, config: dict) -> list[dict]` — weekly analysis, return alerts
- Produces: `job_postings.run_scrape(db_path: str, config: dict) -> None` — daily scrape cycle
- Produces: `job_postings.run_analysis(db_path: str, config: dict) -> None` — weekly analysis cycle

- [ ] **Step 1: Write failing tests**

Create `tests/test_job_postings.py`:
```python
import os
import tempfile
import pytest
from watchtower.db import init_db, get_connection
from watchtower.scrapers.job_postings import (
    classify_seniority,
    analyze_velocity,
    _velocity_pct,
)


@pytest.fixture
def db_path():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    init_db(path)
    yield path
    os.unlink(path)


def test_classify_seniority():
    assert classify_seniority("VP of Engineering") == "senior"
    assert classify_seniority("Director of Sales") == "senior"
    assert classify_seniority("Senior Software Engineer") == "mid"
    assert classify_seniority("Software Engineer") == "mid"
    assert classify_seniority("Junior Analyst") == "junior"
    assert classify_seniority("Intern") == "junior"
    assert classify_seniority("Warehouse Associate") == "junior"


def test_velocity_pct():
    assert _velocity_pct(100, 70) == -30.0
    assert _velocity_pct(100, 150) == 50.0
    assert _velocity_pct(0, 10) == 100.0  # from zero = 100% surge
    assert _velocity_pct(0, 0) == 0.0


def test_analyze_velocity_detects_drop(db_path):
    conn = get_connection(db_path)
    # Insert postings 14 days ago: 100
    conn.execute(
        "INSERT INTO job_postings (scrape_date, company_ticker, company_name, sector, total_postings) VALUES (date('now', '-14 days'), 'TSTC', 'Test Corp', 'biotech', 100)"
    )
    # Insert postings 7 days ago: 80
    conn.execute(
        "INSERT INTO job_postings (scrape_date, company_ticker, company_name, sector, total_postings) VALUES (date('now', '-7 days'), 'TSTC', 'Test Corp', 'biotech', 80)"
    )
    # Insert postings today: 60 (40% drop in 14d)
    conn.execute(
        "INSERT INTO job_postings (scrape_date, company_ticker, company_name, sector, total_postings) VALUES (date('now'), 'TSTC', 'Test Corp', 'biotech', 60)"
    )
    conn.commit()
    conn.close()

    config = {"job_postings": {"alert_drop_threshold_pct": -30, "alert_surge_threshold_pct": 50, "seniority_shift_threshold_pct": 20}}
    alerts = analyze_velocity(db_path, config)
    assert len(alerts) >= 1
    assert alerts[0]["company_ticker"] == "TSTC"
    assert alerts[0]["alert_direction"] == "distress"


def test_analyze_velocity_no_alert_on_small_change(db_path):
    conn = get_connection(db_path)
    conn.execute(
        "INSERT INTO job_postings (scrape_date, company_ticker, company_name, sector, total_postings) VALUES (date('now', '-14 days'), 'TSTC', 'Test Corp', 'biotech', 100)"
    )
    conn.execute(
        "INSERT INTO job_postings (scrape_date, company_ticker, company_name, sector, total_postings) VALUES (date('now'), 'TSTC', 'Test Corp', 'biotech', 90)"
    )
    conn.commit()
    conn.close()

    config = {"job_postings": {"alert_drop_threshold_pct": -30, "alert_surge_threshold_pct": 50, "seniority_shift_threshold_pct": 20}}
    alerts = analyze_velocity(db_path, config)
    assert len(alerts) == 0
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python -m pytest tests/test_job_postings.py -v`
Expected: FAIL

- [ ] **Step 3: Create watchlist.yaml**

Create `watchtower/watchlist.yaml` with initial company lists for the 3 priority sectors + back-burner. Each entry has: ticker, name, sector, careers_url (the company's job board URL). Populate ~20 per priority sector at build time by researching each company's career page URL. Start with well-known names in each sector whose career pages are publicly accessible.

- [ ] **Step 4: Implement job_postings scraper**

Create `watchtower/scrapers/job_postings.py`. Key functions:

- `classify_seniority(title: str) -> str` — returns "senior", "mid", or "junior" based on title keywords (VP/Director/Chief/President → senior; Senior/Lead/Manager/Engineer/Analyst → mid; Junior/Intern/Associate/Coordinator/Warehouse → junior)
- `_velocity_pct(old: int, new: int) -> float` — percentage change, handles zero denominator
- `scrape_company(ticker: str, company: dict, db_path: str) -> dict` — HTTP GET to careers_url, parse page for job listing count + titles, classify seniority, store in job_postings table
- `scrape_all(db_path: str, config: dict, watchlist: dict) -> int` — iterate watchlist, call scrape_company for each, 1s delay between requests, return count of successful scrapes
- `analyze_velocity(db_path: str, config: dict) -> list[dict]` — for each ticker with data, compare latest posting count to 7d and 14d ago, check thresholds, insert into job_velocity, return list of alerts
- `_format_job_alert(alert: dict) -> tuple[str, str]` — returns (subject, body)
- `run_scrape(db_path: str, config: dict) -> None` — daily scrape
- `run_analysis(db_path: str, config: dict) -> None` — weekly analysis + alerts

Scraping approach: most career pages return HTML with job cards. Use BeautifulSoup to count elements. Different companies have different HTML structures — handle failures gracefully (log warning, set scrape_status='error', move to next company). The watchlist.yaml can include a `selector` field per company for the CSS selector that identifies job cards, defaulting to common patterns.

- [ ] **Step 5: Run tests**

Run: `python -m pytest tests/test_job_postings.py -v`
Expected: 4 PASSED

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(watchtower): job posting velocity scraper — career page scraping + velocity analysis"
```

---

### Task 4: Prediction Market Divergence Scraper

**Files:**
- Create: `watchtower/scrapers/pred_markets.py`
- Create: `tests/test_pred_markets.py`

**Interfaces:**
- Consumes: `db.get_connection(db_path)`, `alerts.email.send_alert(...)`
- Produces: `pred_markets.fetch_polymarket_events(categories: list[str]) -> list[dict]`
- Produces: `pred_markets.fetch_kalshi_events(categories: list[str]) -> list[dict]`
- Produces: `pred_markets.calculate_divergence(pm_prob: float, consensus_prob: float) -> float`
- Produces: `pred_markets.run(db_path: str, config: dict) -> None`

- [ ] **Step 1: Write failing tests**

Create `tests/test_pred_markets.py`:
```python
import os
import tempfile
import pytest
from unittest.mock import patch
from watchtower.db import init_db
from watchtower.scrapers.pred_markets import (
    calculate_divergence,
    merge_events,
    _categorize_event,
)


def test_calculate_divergence():
    assert calculate_divergence(0.73, 0.52) == pytest.approx(21.0, abs=0.1)
    assert calculate_divergence(0.50, 0.50) == 0.0
    assert calculate_divergence(0.30, 0.80) == pytest.approx(50.0, abs=0.1)


def test_categorize_event():
    assert _categorize_event("Will the Fed cut rates in July 2026?") == "fed_rate"
    assert _categorize_event("US GDP growth above 2% Q3 2026") == "gdp"
    assert _categorize_event("Bitcoin above 100k by Dec 2026") == "other"
    assert _categorize_event("Unemployment rate below 4%") == "unemployment"


def test_merge_events_deduplicates():
    poly = [{"name": "Fed rate cut July", "prob": 0.65, "source": "polymarket"}]
    kalshi = [{"name": "Fed cuts in July 2026", "prob": 0.68, "source": "kalshi"}]
    merged = merge_events(poly, kalshi)
    # Should recognize these as the same event and merge
    assert len(merged) <= 2  # at most one per source, possibly merged
```

- [ ] **Step 2: Run tests to verify failure, then implement**

Create `watchtower/scrapers/pred_markets.py`. Key functions:

- `fetch_polymarket_events(categories: list[str]) -> list[dict]` — GET `https://clob.polymarket.com/markets` or the Gamma API endpoint. Filter for economic/market events. Return list of {name, prob, end_date, source, category}.
- `fetch_kalshi_events(categories: list[str]) -> list[dict]` — GET `https://trading-api.kalshi.com/trade-api/v2/markets`. Filter for relevant categories. Return same format.
- `_categorize_event(title: str) -> str` — keyword matching: "fed"/"rate" → fed_rate, "gdp"/"growth" → gdp, "inflation"/"cpi" → inflation, "unemploy"/"jobs"/"payroll" → unemployment, "election"/"president" → geopolitical. Default "other".
- `merge_events(poly: list, kalshi: list) -> list[dict]` — fuzzy match by event name to combine Polymarket + Kalshi odds for the same event.
- `calculate_divergence(pm_prob: float, consensus_prob: float) -> float` — absolute percentage difference.
- `_get_consensus(event: dict) -> tuple[float, str]` — for Fed events, scrape CME FedWatch implied probability. For others, return None (consensus_prob stored as NULL, no divergence alert).
- `run(db_path: str, config: dict) -> None` — fetch all events, store in pred_market_events, check divergence threshold, send alerts.

- [ ] **Step 3: Run tests, verify pass**

Run: `python -m pytest tests/test_pred_markets.py -v`
Expected: 3 PASSED

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(watchtower): prediction market divergence scraper — Polymarket + Kalshi + consensus comparison"
```

---

### Task 5: Philly Fed Scraper

**Files:**
- Create: `watchtower/scrapers/philly_fed.py`
- Create: `tests/test_philly_fed.py`

**Interfaces:**
- Consumes: `db.get_connection(db_path)`, `alerts.email.send_alert(...)`
- Produces: `philly_fed.check_for_new_revision(db_path: str, config: dict) -> dict | None`
- Produces: `philly_fed.run(db_path: str, config: dict) -> None`

- [ ] **Step 1: Write failing tests**

Create `tests/test_philly_fed.py`:
```python
import os
import tempfile
import pytest
from watchtower.db import init_db, get_connection
from watchtower.scrapers.philly_fed import (
    parse_revision_from_text,
    _is_new_quarter,
)


@pytest.fixture
def db_path():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    init_db(path)
    yield path
    os.unlink(path)


SAMPLE_PDF_TEXT = """
Early Benchmark Revisions of State Payroll Employment: 2026Q2

The early benchmark model predicts that March 2026 total nonfarm
payroll employment will be revised downward by 487,000.

The current published estimate shows 158,200,000 total nonfarm jobs.
"""


def test_parse_revision_from_text():
    result = parse_revision_from_text(SAMPLE_PDF_TEXT)
    assert result is not None
    assert result["quarter"] == "2026Q2"
    assert result["predicted_direction"] == "down"
    assert result["predicted_magnitude"] == 487000.0


def test_is_new_quarter_true(db_path):
    assert _is_new_quarter("2026Q2", db_path) is True


def test_is_new_quarter_false_when_exists(db_path):
    conn = get_connection(db_path)
    conn.execute(
        "INSERT INTO philly_fed_revisions (publication_date, quarter, predicted_direction) VALUES ('2026-06-01', '2026Q2', 'down')"
    )
    conn.commit()
    conn.close()
    assert _is_new_quarter("2026Q2", db_path) is False
```

- [ ] **Step 2: Run tests to verify failure, then implement**

Create `watchtower/scrapers/philly_fed.py`. Key functions:

- `_download_latest_pdf() -> bytes | None` — GET the Philly Fed early benchmark page, find the latest PDF link, download it. Return raw bytes or None.
- `_extract_text_from_pdf(pdf_bytes: bytes) -> str` — use pdfplumber to extract text from all pages.
- `parse_revision_from_text(text: str) -> dict | None` — regex to find: quarter (e.g. "2026Q2"), direction ("upward"/"downward"), magnitude (number), current BLS number. Return dict or None if parsing fails.
- `_is_new_quarter(quarter: str, db_path: str) -> bool` — check philly_fed_revisions table for existing entry.
- `check_for_new_revision(db_path: str, config: dict) -> dict | None` — download PDF, parse, check if new quarter, store + alert if new. Return the revision dict or None.
- `run(db_path: str, config: dict) -> None` — wrapper for check_for_new_revision + error handling.

- [ ] **Step 3: Run tests, verify pass**

Run: `python -m pytest tests/test_philly_fed.py -v`
Expected: 3 PASSED

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(watchtower): Philly Fed early benchmark revision scraper — PDF parse + new quarter detection"
```

---

### Task 6: Confluence Engine

**Files:**
- Create: `watchtower/engine/confluence.py`
- Create: `tests/test_confluence.py`

**Interfaces:**
- Consumes: `db.get_connection(db_path)`, `alerts.email.send_alert(...)`
- Produces: `confluence.check_confluence(db_path: str, config: dict) -> list[dict]`
- Produces: `confluence.run(db_path: str, config: dict) -> None`

- [ ] **Step 1: Write failing tests**

Create `tests/test_confluence.py`:
```python
import os
import tempfile
import json
import pytest
from watchtower.db import init_db, get_connection
from watchtower.engine.confluence import check_confluence


@pytest.fixture
def db_path():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    init_db(path)
    yield path
    os.unlink(path)


def test_confluence_detects_ticker_overlap(db_path):
    conn = get_connection(db_path)
    # Insider cluster for TSTC detected today
    conn.execute(
        """INSERT INTO insider_clusters
        (issuer_ticker, issuer_name, num_insiders, total_dollar_value,
         first_filing_date, last_filing_date, date_detected, sector)
        VALUES ('TSTC', 'Test Corp', 3, 75000,
                date('now', '-5 days'), date('now', '-1 day'), date('now'), 'biotech')"""
    )
    # Job posting surge for TSTC within 7 days
    conn.execute(
        """INSERT INTO job_velocity
        (week_ending, company_ticker, postings_7d_ago, postings_now,
         velocity_7d_pct, velocity_14d_pct, alert_fired, alert_direction)
        VALUES (date('now'), 'TSTC', 50, 80, 60.0, 55.0, 1, 'expansion')"""
    )
    conn.commit()
    conn.close()

    config = {"confluence": {"window_days": 7, "min_signals": 2, "high_conviction_min": 3}}
    results = check_confluence(db_path, config)
    assert len(results) >= 1
    assert results[0]["ticker"] == "TSTC"
    assert results[0]["score"] in ("MODERATE", "HIGH")


def test_confluence_no_match_on_different_tickers(db_path):
    conn = get_connection(db_path)
    conn.execute(
        """INSERT INTO insider_clusters
        (issuer_ticker, issuer_name, num_insiders, total_dollar_value,
         first_filing_date, last_filing_date, date_detected, sector)
        VALUES ('AAA', 'Alpha Corp', 3, 75000,
                date('now', '-3 days'), date('now'), date('now'), 'energy')"""
    )
    conn.execute(
        """INSERT INTO job_velocity
        (week_ending, company_ticker, postings_7d_ago, postings_now,
         velocity_7d_pct, velocity_14d_pct, alert_fired, alert_direction)
        VALUES (date('now'), 'BBB', 50, 80, 60.0, 55.0, 1, 'expansion')"""
    )
    conn.commit()
    conn.close()

    config = {"confluence": {"window_days": 7, "min_signals": 2, "high_conviction_min": 3}}
    results = check_confluence(db_path, config)
    # No ticker overlap, but check for sector overlap
    ticker_matches = [r for r in results if r.get("ticker")]
    assert len(ticker_matches) == 0


def test_confluence_detects_sector_overlap(db_path):
    conn = get_connection(db_path)
    conn.execute(
        """INSERT INTO insider_clusters
        (issuer_ticker, issuer_name, num_insiders, total_dollar_value,
         first_filing_date, last_filing_date, date_detected, sector)
        VALUES ('AAA', 'Alpha Bio', 3, 75000,
                date('now', '-3 days'), date('now'), date('now'), 'biotech')"""
    )
    conn.execute(
        """INSERT INTO job_velocity
        (week_ending, company_ticker, postings_7d_ago, postings_now,
         velocity_7d_pct, velocity_14d_pct, alert_fired, alert_direction)
        VALUES (date('now'), 'BBB', 50, 80, 60.0, 55.0, 1, 'expansion')"""
    )
    # Need sector on job_velocity — check via job_postings table
    conn.execute(
        "INSERT INTO job_postings (scrape_date, company_ticker, company_name, sector, total_postings) VALUES (date('now'), 'BBB', 'Beta Bio', 'biotech', 80)"
    )
    conn.commit()
    conn.close()

    config = {"confluence": {"window_days": 7, "min_signals": 2, "high_conviction_min": 3}}
    results = check_confluence(db_path, config)
    sector_matches = [r for r in results if r.get("sector") == "biotech"]
    assert len(sector_matches) >= 1
```

- [ ] **Step 2: Run tests to verify failure, then implement**

Create `watchtower/engine/confluence.py`. Key functions:

- `_get_recent_signals(db_path: str, window_days: int) -> dict` — query all signal tables for events within window. Return dict with keys: insider_clusters (list of {ticker, sector, date, ...}), job_alerts (list), pred_market_alerts (list), philly_fed (list). Each signal tagged with its domain.
- `_find_ticker_overlaps(signals: dict) -> list[dict]` — find tickers appearing in 2+ different signal domains.
- `_find_sector_overlaps(signals: dict) -> list[dict]` — find sectors with signals from 2+ different domains (when no ticker match).
- `_score_confluence(num_signals: int, config: dict) -> str` — return "MODERATE" (2) or "HIGH" (3+).
- `check_confluence(db_path: str, config: dict) -> list[dict]` — orchestrate: get signals, find overlaps, score, deduplicate against existing confluences table, insert new ones, return list.
- `run(db_path: str, config: dict) -> None` — check_confluence + send email alerts for new confluences.

- [ ] **Step 3: Run tests, verify pass**

Run: `python -m pytest tests/test_confluence.py -v`
Expected: 3 PASSED

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(watchtower): confluence engine — cross-signal ticker + sector overlap detection"
```

---

### Task 7: Accuracy Tracker

**Files:**
- Create: `watchtower/engine/tracker.py`
- Create: `tests/test_tracker.py`

**Interfaces:**
- Consumes: `db.get_connection(db_path)`, `alerts.email.send_alert(...)`
- Produces: `tracker.check_insider_accuracy(db_path: str, config: dict) -> list[dict]`
- Produces: `tracker.generate_accuracy_report(db_path: str, config: dict) -> str`
- Produces: `tracker.run(db_path: str, config: dict) -> None`

- [ ] **Step 1: Write failing tests**

Create `tests/test_tracker.py`:
```python
import os
import tempfile
import pytest
from watchtower.db import init_db, get_connection
from watchtower.engine.tracker import (
    _calculate_alpha,
    generate_accuracy_report,
)


@pytest.fixture
def db_path():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    init_db(path)
    yield path
    os.unlink(path)


def test_calculate_alpha():
    # Stock went up 10%, SPY went up 3% => alpha = 7%
    assert _calculate_alpha(0.10, 0.03) == pytest.approx(0.07)
    # Stock went down 5%, SPY went up 2% => alpha = -7%
    assert _calculate_alpha(-0.05, 0.02) == pytest.approx(-0.07)


def test_generate_accuracy_report_empty_db(db_path):
    config = {"accuracy": {"price_check_days": [30, 60, 90, 180]}}
    report = generate_accuracy_report(db_path, config)
    assert "No accuracy data" in report or "0 signals" in report.lower()


def test_generate_accuracy_report_with_data(db_path):
    conn = get_connection(db_path)
    conn.execute(
        """INSERT INTO accuracy_tracking
        (signal_type, signal_id, ticker, detection_date, detection_price,
         check_date, check_days, check_price, stock_return, benchmark_return, alpha, hit)
        VALUES ('insider_cluster', 1, 'TSTC', '2026-03-01', 25.0,
                '2026-06-01', 90, 30.0, 0.20, 0.05, 0.15, 1)"""
    )
    conn.commit()
    conn.close()

    config = {"accuracy": {"price_check_days": [30, 60, 90, 180]}}
    report = generate_accuracy_report(db_path, config)
    assert "insider_cluster" in report.lower()
    assert "TSTC" in report
```

- [ ] **Step 2: Run tests to verify failure, then implement**

Create `watchtower/engine/tracker.py`. Key functions:

- `_get_stock_price(ticker: str) -> float | None` — free stock price lookup via Yahoo Finance scrape (`https://query1.finance.yahoo.com/v8/finance/chart/{ticker}?range=1d&interval=1d`). Return latest close or None on failure.
- `_get_spy_price() -> float | None` — same as above for SPY.
- `_calculate_alpha(stock_return: float, benchmark_return: float) -> float` — simple subtraction.
- `check_insider_accuracy(db_path: str, config: dict) -> list[dict]` — find insider_clusters that are due for a price check (detection_date + check_days <= today, not yet checked). Look up current prices, calculate returns, store in accuracy_tracking.
- `check_job_accuracy(db_path: str, config: dict) -> list[dict]` — find job_velocity alerts. For now, just mark them as pending manual review (earnings check requires knowing earnings dates, which is Phase 1 enrichment).
- `check_pred_market_accuracy(db_path: str, config: dict) -> list[dict]` — find resolved events in pred_market_events. Mark which side was correct.
- `generate_accuracy_report(db_path: str, config: dict) -> str` — aggregate accuracy_tracking by signal_type. Return formatted text: hit rates, average alpha, sample sizes.
- `run(db_path: str, config: dict) -> None` — run all accuracy checks + generate report + email if monthly.

- [ ] **Step 3: Run tests, verify pass**

Run: `python -m pytest tests/test_tracker.py -v`
Expected: 3 PASSED

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(watchtower): accuracy tracker — price lookups, alpha calculation, monthly reports"
```

---

### Task 8: Scheduler + Docker + Deploy

**Files:**
- Create: `watchtower/engine/scheduler.py`
- Create: `watchtower/main.py`
- Create: `Dockerfile`
- Create: `docker-compose.yml`
- Create: `.dockerignore`
- Create: `tests/test_scheduler.py`

**Interfaces:**
- Consumes: all scrapers' `run()` functions, confluence `run()`, tracker `run()`, config `load_config()`
- Produces: `main.main()` — entrypoint that initializes DB, loads config, starts scheduler

- [ ] **Step 1: Write failing test for scheduler**

Create `tests/test_scheduler.py`:
```python
from watchtower.engine.scheduler import build_scheduler


def test_build_scheduler_creates_jobs():
    config = {
        "email": {"smtp_server": "smtp.gmail.com", "smtp_port": 587,
                  "from_address": "test@test.com", "to_address": "test@test.com"},
        "insider_buys": {"min_cluster_size": 3, "cluster_window_days": 15, "max_market_cap": 5e9},
        "job_postings": {"alert_drop_threshold_pct": -30, "alert_surge_threshold_pct": 50,
                         "seniority_shift_threshold_pct": 20, "analysis_day": "sunday"},
        "pred_markets": {"divergence_threshold_pct": 15, "categories": ["fed_rate"]},
        "confluence": {"window_days": 7, "min_signals": 2, "high_conviction_min": 3},
        "accuracy": {"price_check_days": [30, 60, 90, 180], "monthly_report_day": 1},
    }
    sched = build_scheduler(config, db_path="/tmp/test.db")
    job_ids = [j.id for j in sched.get_jobs()]
    assert "insider_buys_daily" in job_ids
    assert "pred_markets_daily" in job_ids
    assert "job_postings_daily" in job_ids
    assert "confluence_daily" in job_ids
    assert "philly_fed_weekly" in job_ids
    assert "job_velocity_weekly" in job_ids
    assert "accuracy_monthly" in job_ids
    sched.shutdown(wait=False)
```

- [ ] **Step 2: Implement scheduler**

Create `watchtower/engine/scheduler.py`:
```python
from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger
import structlog

from watchtower.scrapers.insider_buys import run as run_insider
from watchtower.scrapers.job_postings import run_scrape as run_jobs_scrape
from watchtower.scrapers.job_postings import run_analysis as run_jobs_analysis
from watchtower.scrapers.pred_markets import run as run_pred
from watchtower.scrapers.philly_fed import run as run_philly
from watchtower.engine.confluence import run as run_confluence
from watchtower.engine.tracker import run as run_tracker

log = structlog.get_logger()


def build_scheduler(config: dict, db_path: str) -> BlockingScheduler:
    sched = BlockingScheduler(timezone="UTC")

    # Daily Mon-Fri 06:00 UTC: Insider buys
    sched.add_job(run_insider, CronTrigger(hour=6, minute=0, day_of_week="mon-fri"),
                  args=[db_path, config], id="insider_buys_daily", misfire_grace_time=3600)

    # Daily 07:00 UTC: Prediction markets
    sched.add_job(run_pred, CronTrigger(hour=7, minute=0),
                  args=[db_path, config], id="pred_markets_daily", misfire_grace_time=3600)

    # Daily 08:00 UTC: Job postings scrape
    sched.add_job(run_jobs_scrape, CronTrigger(hour=8, minute=0),
                  args=[db_path, config], id="job_postings_daily", misfire_grace_time=3600)

    # Daily 08:30 UTC: Confluence check
    sched.add_job(run_confluence, CronTrigger(hour=8, minute=30),
                  args=[db_path, config], id="confluence_daily", misfire_grace_time=3600)

    # Weekly Tuesday 12:00 UTC: Philly Fed check
    sched.add_job(run_philly, CronTrigger(hour=12, minute=0, day_of_week="tue"),
                  args=[db_path, config], id="philly_fed_weekly", misfire_grace_time=3600)

    # Weekly Sunday 10:00 UTC: Job velocity analysis
    sched.add_job(run_jobs_analysis, CronTrigger(hour=10, minute=0, day_of_week="sun"),
                  args=[db_path, config], id="job_velocity_weekly", misfire_grace_time=3600)

    # Monthly 1st 00:00 UTC: Accuracy report
    sched.add_job(run_tracker, CronTrigger(day=1, hour=0, minute=0),
                  args=[db_path, config], id="accuracy_monthly", misfire_grace_time=3600)

    return sched
```

- [ ] **Step 3: Create main.py entrypoint**

Create `watchtower/main.py`:
```python
import os
import sys
import structlog
from watchtower.db import init_db
from watchtower.config import load_config
from watchtower.engine.scheduler import build_scheduler

log = structlog.get_logger()

def main():
    config_path = os.environ.get("WATCHTOWER_CONFIG", "/app/config/config.yaml")
    db_path = os.environ.get("WATCHTOWER_DB", "/app/data/watchtower.db")

    log.info("watchtower_starting", config=config_path, db=db_path)

    config = load_config(config_path)
    init_db(db_path)

    log.info("db_initialized", path=db_path)

    scheduler = build_scheduler(config, db_path)
    log.info("scheduler_built", jobs=[j.id for j in scheduler.get_jobs()])

    try:
        scheduler.start()
    except (KeyboardInterrupt, SystemExit):
        log.info("watchtower_shutdown")
        sys.exit(0)

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Create Dockerfile**

Create `Dockerfile`:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY watchtower/ /app/watchtower/
COPY config.yaml /app/config/config.yaml
COPY watchlist.yaml /app/config/watchlist.yaml

ENV PYTHONUNBUFFERED=1
ENV WATCHTOWER_CONFIG=/app/config/config.yaml
ENV WATCHTOWER_DB=/app/data/watchtower.db

CMD ["python", "-m", "watchtower.main"]
```

Create `.dockerignore`:
```
__pycache__
*.pyc
tests/
.git
.pytest_cache
data/
logs/
```

- [ ] **Step 5: Create docker-compose.yml**

Create `docker-compose.yml`:
```yaml
version: "3.8"

services:
  watchtower:
    build: .
    container_name: watchtower
    restart: unless-stopped
    environment:
      - WATCHTOWER_EMAIL_USER=${WATCHTOWER_EMAIL_USER}
      - WATCHTOWER_EMAIL_PASS=${WATCHTOWER_EMAIL_PASS}
      - WATCHTOWER_CONFIG=/app/config/config.yaml
      - WATCHTOWER_DB=/app/data/watchtower.db
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
      - ./config:/app/config
    healthcheck:
      test: ["CMD", "python", "-c", "import watchtower.db; print('ok')"]
      interval: 60s
      timeout: 10s
      retries: 3
```

- [ ] **Step 6: Run all tests**

Run: `python -m pytest tests/ -v`
Expected: ALL PASSED (at least 20 tests across all test files)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(watchtower): scheduler + Docker + compose — deployment-ready"
```

- [ ] **Step 8: Deploy to droplet**

This is a RED action — requires Owner approval.

```bash
# On local: copy project to droplet
scp -r watchtower/ root@104.131.176.130:/app/watchtower/

# On droplet: set up data + logs dirs, env vars
ssh root@104.131.176.130 "cd /app/watchtower && mkdir -p data logs config"

# Set email credentials (same as VEOE bot uses)
ssh root@104.131.176.130 "cat > /app/watchtower/.env << 'EOF'
WATCHTOWER_EMAIL_USER=christoph3reverding@gmail.com
WATCHTOWER_EMAIL_PASS=<app-password-from-bitwarden>
EOF"

# Build and start
ssh root@104.131.176.130 "cd /app/watchtower && docker compose up -d --build"

# Verify
ssh root@104.131.176.130 "docker ps --filter name=watchtower --format '{{.Names}} {{.Status}}'"
# Expected: watchtower Up X seconds (healthy)
```

- [ ] **Step 9: Smoke test — trigger one scrape manually**

```bash
ssh root@104.131.176.130 "docker exec watchtower python -c \"
from watchtower.db import init_db
from watchtower.config import load_config
init_db('/app/data/watchtower.db')
cfg = load_config('/app/config/config.yaml')
print('DB + Config OK')
\""
# Expected: DB + Config OK
```

- [ ] **Step 10: Commit deploy state + update tracking**

Update `.tracking/CURRENT.md` and `.tracking/PROGRESS.md` with deployment status.

```bash
git add -A
git commit -m "deploy: Watchtower Phase 0 live on droplet — paper/observation mode"
```
