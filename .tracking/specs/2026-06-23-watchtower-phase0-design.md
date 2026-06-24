# The Watchtower — Phase 0 Design Spec

## Overview

Alternative data observatory that monitors non-obvious signals predicting market-moving outcomes before official reports. Phase 0: 4 signal scrapers + email alerts + accuracy tracking. Paper/observation mode — no live trading.

**Home:** Docker container on droplet 104.131.176.130, alongside VEOE/Machine.
**Cost:** $0/month (all free data sources).
**Output:** Email alerts to christoph3reverding@gmail.com via Gmail SMTP (reuse VEOE pattern).

---

## Signals

### 1. Philly Fed Early Benchmark Revision

**Source:** Philadelphia Federal Reserve, quarterly PDF publication.
**URL:** https://www.philadelphiafed.org/surveys-and-data/real-time-data-research/early-benchmark-revisions
**Schedule:** Scrape weekly (Tuesday). Only fires alert when new quarterly revision detected.
**What it does:**
- Downloads latest PDF from Philly Fed early benchmark page
- Extracts the predicted revision direction and magnitude for nonfarm payrolls
- Compares to current BLS published number
- Stores: date, predicted_direction (up/down), predicted_magnitude, current_bls_number

**Alert trigger:** New quarterly revision published.
**Alert content:** Direction of predicted revision, magnitude, what it implies for next BLS release.
**Accuracy tracking:** After next BLS benchmark revision publishes, compare Philly Fed prediction to actual revision. Log hit/miss + magnitude accuracy.

### 2. Insider Cluster Buys (SEC EDGAR Form 4)

**Source:** SEC EDGAR full-text search + bulk Form 4 feed.
**URL:** https://efts.sec.gov/LATEST/search-index?q=%22Form+4%22 and https://www.sec.gov/cgi-bin/browse-edgar?action=getcurrent&type=4&dateb=&owner=include&count=100
**Schedule:** Daily at 06:00 UTC (after EDGAR overnight batch).
**What it does:**
- Pull latest Form 4 filings from EDGAR
- Parse each filing: filer name, issuer, transaction type, shares, price, date, relationship to issuer
- Filter: open-market purchases only (transactionCode = "P")
- Exclude: 10b5-1 planned transactions, option exercises (transactionCode = "A", "M"), gifts
- Detect clusters: 3+ distinct insiders at the same issuer CIK filing open-market purchases within 15 calendar days
- Enrich: market cap from free API (Financial Modeling Prep free tier or SEC company tickers JSON), sector
- Focus scoring: sub-$5B market cap scores higher, CEO/CFO purchases score higher than director/10% owner

**Data stored per filing:** filing_date, issuer_cik, issuer_name, issuer_ticker, filer_name, filer_relationship, transaction_type, shares, price_per_share, total_value, is_10b5_1
**Data stored per cluster:** cluster_id, issuer_ticker, issuer_name, market_cap, sector, num_insiders, total_dollar_value, first_filing_date, last_filing_date, insider_names, price_at_detection
**Alert trigger:** New cluster detected (3+ insiders, 15-day window, open-market purchase).
**Alert content:** Company name, ticker, number of insiders, aggregate dollar amount, each insider's name and role, current stock price, market cap, sector.
**Accuracy tracking:** Record stock price at detection. Check price at +30, +60, +90, +180 days. Calculate return vs. SPY benchmark over same period. Log alpha.

### 3. Job Posting Velocity

**Source:** Company career pages (direct scrape) + backup via free job APIs.
**Primary method:** HTTP GET to each company's careers/jobs page, parse job listing count and metadata.
**Backup method:** JobSpy Python library (aggregates Indeed, LinkedIn, Glassdoor, ZipRecruiter).
**Schedule:** Daily scrape at 08:00 UTC. Weekly analysis Sunday 10:00 UTC.

**Initial watchlist (~60 companies across 3 priority sectors + back-burner):**

Priority sectors (alert-enabled):
- **Biotech/Pharma (20):** Small/mid-cap biotechs with upcoming catalysts. Initial list seeded from companies with market cap $500M-$5B, at least 1 PDUFA date in next 12 months. Specific tickers determined at build time from FDA calendar + screener.
- **Energy/Industrials (20):** Mix of renewable, traditional, and infrastructure. Sub-$10B market cap preferred. Include companies overlapping with Carbon Monitor / electricity consumption signals.
- **Construction/RE (20):** Homebuilders, commercial RE, building materials, HVAC/electrical suppliers. Directly relevant to AllTec competitive landscape.

Back-burner sectors (tracked but no alerts unless extreme):
- Defense/Aerospace, Semiconductors, Retail — tracked passively, alert only on >50% swings.

**What it does:**
- Daily: scrape total job count per company, store with timestamp
- Parse seniority where possible (title keywords: VP, Director, Senior, Engineer, Analyst)
- Weekly: calculate 7-day and 14-day velocity (% change in total postings)
- Weekly: calculate seniority mix shift (ratio of senior to junior postings changing)

**Data stored per scrape:** date, company_ticker, company_name, sector, total_postings, senior_postings, mid_postings, junior_postings, scrape_source, scrape_status
**Data stored per weekly analysis:** week_ending, company_ticker, postings_7d_ago, postings_now, velocity_7d_pct, velocity_14d_pct, seniority_shift

**Alert triggers:**
- Postings drop >30% in 14 days (distress signal)
- Postings surge >50% in 14 days (expansion signal)
- Seniority mix shifts dramatically (>20% change in senior/junior ratio)

**Alert content:** Company name, ticker, sector, posting count (before/after), velocity %, direction, seniority shift if notable, next earnings date if known.
**Accuracy tracking:** Record alert date + direction. After next earnings report, log: did earnings surprise match the posting signal direction? Calculate hit rate.

### 4. Prediction Market Divergence

**Source:** Polymarket API (https://clob.polymarket.com) + Kalshi API (https://trading-api.kalshi.com).
**Schedule:** Daily at 07:00 UTC.
**What it does:**
- Pull current odds for economic/market-relevant events from Polymarket and Kalshi
- Categories of interest: Fed rate decisions, inflation readings, GDP, unemployment, major elections, geopolitical events, specific company events (earnings beat/miss where available)
- Compare prediction market implied probability to consensus:
  - Fed funds futures (CME FedWatch — free from CME site)
  - Analyst consensus estimates (scraped from free sources: Yahoo Finance, Finviz)
  - Polling aggregates for political events
- Calculate divergence: |prediction_market_prob - consensus_prob|

**Data stored per event:** date, event_name, event_date, polymarket_prob, kalshi_prob, consensus_prob, consensus_source, divergence_pct, category
**Alert trigger:** Divergence >15% between prediction market and consensus on a tradeable event.
**Alert content:** Event name, event date, prediction market odds, consensus odds, divergence magnitude, which side is higher, category.
**Accuracy tracking:** After event resolves, log: which was right (prediction market or consensus)? Track cumulative accuracy of each source.

---

## Confluence Engine (v1)

Simple cross-signal correlation detector.

**Logic:**
- After each daily scrape cycle completes, check for temporal + sector overlap across signals
- Confluence defined as: 2+ signals from DIFFERENT domains firing on the same sector or ticker within 7 calendar days
- Domain mapping: insider_buys = microstructure, job_postings = behavioral, pred_markets = sentiment, philly_fed = macro

**Confluence scoring:**
- 2 signals aligned = MODERATE (included in weekly digest)
- 3+ signals aligned = HIGH (immediate standalone email)

**Example confluences:**
- Insider cluster buy at biotech ticker + job posting surge at same company = HIGH
- Insider cluster in energy sector + prediction market divergence on oil/energy event = MODERATE
- Philly Fed predicts downward revision + prediction market diverges bearish on employment = HIGH

**Data stored:** confluence_id, date_detected, signals_involved (JSON array), sector, ticker (if company-specific), score, description

---

## Architecture

```
watchtower/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── config.yaml              # watchlists, thresholds, email config, API URLs
├── scrapers/
│   ├── __init__.py
│   ├── philly_fed.py        # quarterly PDF scrape + parse
│   ├── insider_buys.py      # daily EDGAR Form 4 parse
│   ├── job_postings.py      # daily career page scrape
│   └── pred_markets.py      # daily Polymarket/Kalshi API
├── engine/
│   ├── __init__.py
│   ├── confluence.py        # cross-signal correlation detection
│   ├── tracker.py           # prediction accuracy tracking + price lookups
│   └── scheduler.py         # APScheduler setup (like VEOE)
├── alerts/
│   ├── __init__.py
│   └── email.py             # Gmail SMTP alerts (reuse VEOE pattern)
├── data/
│   └── watchtower.db        # SQLite — all signal data, alerts, accuracy
└── logs/
    └── watchtower.log       # rotating file log
```

### Docker Setup
- Single container: `watchtower`
- Python 3.11+ image
- SQLite for storage (volume-mounted at /app/data/)
- Logs volume-mounted at /app/logs/
- Config volume-mounted at /app/config/
- Uses APScheduler (same pattern as VEOE) for all scheduling
- Gmail SMTP credentials via env vars or secrets volume (same as VEOE)

### Compose Integration
- Add `watchtower` service to a new `docker-compose.yml` in its own directory on the droplet (e.g., `/app/watchtower/`)
- OR add to existing VEOE compose as an independent service (no shared network needed)
- Decision: separate compose file for clean isolation. Watchtower is not VEOE.

### Dependencies (Python)
- `requests` — HTTP scraping
- `beautifulsoup4` — HTML parsing
- `pdfplumber` or `PyPDF2` — PDF text extraction (Philly Fed)
- `apscheduler` — task scheduling
- `sqlite3` — stdlib, no extra dep
- `structlog` — logging (match VEOE pattern)
- No paid APIs. No API keys except Gmail SMTP (already have).

---

## Schedule Summary

| Time (UTC) | Frequency | Task |
|------------|-----------|------|
| 06:00 | Daily (Mon-Fri) | Insider buys scrape (EDGAR) |
| 07:00 | Daily | Prediction market scrape |
| 08:00 | Daily | Job posting scrape |
| 08:30 | Daily | Confluence check + fire alerts |
| 10:00 | Weekly (Sunday) | Job posting velocity analysis + weekly digest |
| 12:00 | Weekly (Tuesday) | Philly Fed PDF check |
| 00:00 | Monthly (1st) | Accuracy tracker: pull 30/60/90-day price checks for past signals |

---

## Email Formats

**Subject line patterns:**
- `[WATCHTOWER] Insider Cluster: 4 execs buying $MDTX ($2.1M)`
- `[WATCHTOWER] Job Alert: Vertex Pharma postings -42% in 14 days`
- `[WATCHTOWER] Prediction Divergence: Fed cut odds 73% vs consensus 52%`
- `[WATCHTOWER] CONFLUENCE: Biotech — insider cluster + job surge at $VRTX`
- `[WATCHTOWER] Weekly Digest: 14 signals tracked, 2 clusters, 1 confluence`
- `[WATCHTOWER] Accuracy Report: 78% hit rate on insider clusters (n=23)`

**Email body:** Plain text, structured sections (match VEOE email style). No HTML templates.

**Dedup rule:** Same subject line deduped within 24 hours (match VEOE pattern).

---

## Accuracy Tracking System

Every signal that fires is a prediction. Track it.

**For insider clusters:**
- Record: ticker, price_at_detection, date_detected
- At +30, +60, +90, +180 days: look up price, calculate return, compare to SPY return
- Score: alpha = stock_return - spy_return

**For job posting alerts:**
- Record: ticker, direction (distress/expansion), date_detected, next_earnings_date
- After earnings: did earnings surprise match direction? (posting collapse → earnings miss, posting surge → earnings beat)
- Score: binary hit/miss

**For prediction market divergence:**
- Record: event, pred_market_odds, consensus_odds, date_detected
- After event resolves: who was right?
- Score: binary hit/miss for each source

**For confluence alerts:**
- Record: confluence_id, signals_involved, sector/ticker, date_detected
- Track outcome same as component signals but also track: did confluence improve accuracy over individual signals?

**Monthly accuracy email:** Summary of all tracked predictions, hit rates by signal type, cumulative alpha for insider clusters.

---

## Config File (config.yaml)

```yaml
email:
  smtp_server: smtp.gmail.com
  smtp_port: 587
  from_address: christoph3reverding@gmail.com
  to_address: christoph3reverding@gmail.com
  # credentials via env vars: WATCHTOWER_EMAIL_USER, WATCHTOWER_EMAIL_PASS

insider_buys:
  min_cluster_size: 3
  cluster_window_days: 15
  max_market_cap: 5_000_000_000  # $5B
  exclude_10b5_1: true
  exclude_option_exercises: true

job_postings:
  alert_drop_threshold_pct: -30
  alert_surge_threshold_pct: 50
  seniority_shift_threshold_pct: 20
  scrape_interval_hours: 24
  analysis_day: sunday

pred_markets:
  divergence_threshold_pct: 15
  categories:
    - fed_rate
    - inflation
    - gdp
    - unemployment
    - geopolitical
    - company_events

confluence:
  window_days: 7
  min_signals: 2
  high_conviction_min: 3

accuracy:
  price_check_days: [30, 60, 90, 180]
  monthly_report_day: 1

watchlist:
  biotech: []    # populated at build time from FDA calendar
  energy: []     # populated at build time from screener
  construction: []  # populated at build time
  backburner:
    defense: []
    semiconductors: []
    retail: []
```

---

## What Phase 0 Does NOT Include

- No web dashboard (Phase 1: manytalentsmore.com/money/watchtower)
- No auto-trading or order placement
- No paid data feeds
- No backtesting engine (manual review of accuracy reports)
- No ML/NLP (simple rule-based detection only)
- No real-time streaming (batch/scheduled only)
- No Philly Fed NLP — just extract the key number from the PDF
- No earnings call linguistics (Phase 2 signal, not Phase 0)

---

## Success Criteria (after 90 days of observation)

1. All 4 scrapers running reliably with <5% failure rate
2. At least 10 insider cluster events detected and tracked
3. At least 20 job posting velocity alerts fired
4. At least 5 prediction market divergence events tracked to resolution
5. Accuracy data sufficient to determine: is each signal better than random?
6. At least 1 confluence event detected and tracked
7. Owner receives timely, actionable emails without spam (dedup working)
