# Project Tracking System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the monolithic PROGRESS.md system with a 4-file split (.tracking/ folder) across all project repos, create a private PKA GitHub repo, migrate existing specs and progress files, add tracking update rules to CLAUDE.md, and set up a time-driven checkpoint hook.

**Architecture:** Each project repo gets a `.tracking/` folder (CURRENT.md, DECISIONS.md, PROGRESS.md, specs/, sessions/) committed to git. Agents cold-start from CURRENT.md + today's session file. A Claude Code PostToolUse hook checkpoints CURRENT.md every ~15 minutes. Existing PROGRESS.md files are migrated, not deleted. Existing design specs in PKA move to their respective project repos.

**Tech Stack:** Markdown, Git, GitHub CLI (`gh`), Claude Code hooks (settings.json), Bash

---

## File Map

### New Files Created

| File | Purpose |
|------|---------|
| `PKA/.tracking/CURRENT.md` | PKA system-wide cold-start briefing |
| `PKA/.tracking/DECISIONS.md` | PKA org-level decisions |
| `PKA/.tracking/PROGRESS.md` | Migrated from `.10T/PROGRESS.md` |
| `PKA/.tracking/sessions/2026-05-02.md` | Today's session file |
| `PKA/.tracking/specs/2026-05-02-project-tracking-system-design.md` | This spec (moved from docs/) |
| `PKA/.gitignore` | Exclude sensitive files from repo |
| `the-machine/.tracking/CURRENT.md` | The Machine cold-start briefing |
| `the-machine/.tracking/DECISIONS.md` | The Machine decisions |
| `the-machine/.tracking/PROGRESS.md` | Migrated from `PKA/docs/The Machine/PROGRESS.md` |
| `the-machine/.tracking/sessions/2026-05-02.md` | Today's session file |
| `ManyTalentsMore/.tracking/CURRENT.md` | MTM cold-start briefing |
| `ManyTalentsMore/.tracking/DECISIONS.md` | MTM decisions |
| `ManyTalentsMore/.tracking/PROGRESS.md` | Migrated from `PKA/Team Inbox/money-api-infra/PROGRESS.md` |
| `ManyTalentsMore/.tracking/sessions/2026-05-02.md` | Today's session file |
| `AllTecPro/hcp_replacement/.tracking/CURRENT.md` | AllTec cold-start briefing |
| `AllTecPro/hcp_replacement/.tracking/DECISIONS.md` | AllTec decisions |
| `AllTecPro/hcp_replacement/.tracking/PROGRESS.md` | New (no existing PROGRESS.md) |
| `AllTecPro/hcp_replacement/.tracking/sessions/2026-05-02.md` | Today's session file |
| `clawdbottrade/.tracking/CURRENT.md` | VEOE cold-start briefing |
| `clawdbottrade/.tracking/DECISIONS.md` | VEOE decisions |
| `clawdbottrade/.tracking/PROGRESS.md` | New (no existing PROGRESS.md) |
| `clawdbottrade/.tracking/sessions/2026-05-02.md` | Today's session file |

### Files Modified

| File | Change |
|------|--------|
| `PKA/CLAUDE.md` | Add Project Tracking System rules section |

### Files Moved (spec migration)

Specs move from `PKA/docs/superpowers/specs/` to their project's `.tracking/specs/`. PKA-level specs stay in `PKA/.tracking/specs/`. See Task 5 for full mapping.

---

## Task 1: Create PKA .tracking/ Structure + Migrate PKA PROGRESS.md

**Files:**
- Create: `PKA/.tracking/CURRENT.md`
- Create: `PKA/.tracking/DECISIONS.md`
- Create: `PKA/.tracking/sessions/2026-05-02.md`
- Move: `PKA/.10T/PROGRESS.md` → `PKA/.tracking/PROGRESS.md`

- [ ] **Step 1: Create .tracking/ directory structure**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
mkdir -p .tracking/sessions .tracking/specs
```

- [ ] **Step 2: Move existing PROGRESS.md**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
mv .10T/PROGRESS.md .tracking/PROGRESS.md
```

- [ ] **Step 3: Extract resume point → write CURRENT.md**

Read `.tracking/PROGRESS.md` and extract the latest resume point and current status into a new CURRENT.md. Use the format from the spec:

```markdown
# PKA — CURRENT

## Status
Project tracking system migration in progress. All team systems operational.

## Active Work
- **Kit:** Implementing new .tracking/ system across all project repos

## Next
1. Complete .tracking/ migration for all 5 project repos
2. Create private PKA GitHub repo
3. Add tracking rules to CLAUDE.md
```

Write this to `PKA/.tracking/CURRENT.md`. Must be ≤20 lines.

- [ ] **Step 4: Extract significant decisions → seed DECISIONS.md**

Read through `.tracking/PROGRESS.md` and extract all entries under "Decisions made" or "Key decisions" headings. Write them into `PKA/.tracking/DECISIONS.md` using the spec format:

```markdown
# PKA — DECISIONS

> {N} decisions logged | Last: 2026-05-02

---

### 2026-03-30 — Toolbox location
**Context:** Setting up team toolbox for first time
**Decision:** Toolbox lives in `PKA/.10T/TOOLBOX.md`, MCP tools in `.10T/tools/`, MCP config at `.mcp.json`
**Rationale:** Centralized under 10T orchestrator, single config point
**Members:** 10T, Owner

---

### 2026-03-30 — ERPNext API key format
**Context:** "key2 full/read" (32-char) keys failed authentication
**Decision:** Use CSV-generated API keys (15-char) per Frappe source code (`generate_hash(length=15)`)
**Rationale:** Frappe source code confirms 15-char is the correct format
**Members:** Kit, 10T

---
```

Continue for all decisions found in the PROGRESS.md. Update the count in the header line.

- [ ] **Step 5: Create today's session file**

```markdown
# PKA — Session 2026-05-02

## {HH:MM} — Kit — Project tracking system migration
Migrating from monolithic PROGRESS.md to .tracking/ split system.
Created .tracking/ folder structure for PKA.
Moved .10T/PROGRESS.md → .tracking/PROGRESS.md.
Seeded CURRENT.md and DECISIONS.md from existing progress data.
```

Write to `PKA/.tracking/sessions/2026-05-02.md`. Use actual current time for HH:MM.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add .tracking/
git commit -m "feat: create PKA .tracking/ system — CURRENT, DECISIONS, sessions, migrated PROGRESS

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Create .tracking/ for The Machine + Migrate PROGRESS.md

**Files:**
- Create: `the-machine/.tracking/CURRENT.md`
- Create: `the-machine/.tracking/DECISIONS.md`
- Create: `the-machine/.tracking/sessions/2026-05-02.md`
- Move: `PKA/docs/The Machine/PROGRESS.md` → `the-machine/.tracking/PROGRESS.md`

- [ ] **Step 1: Create .tracking/ directory structure**

```bash
cd "C:/Users/chris/OneDrive/Documentos/the-machine"
mkdir -p .tracking/sessions .tracking/specs
```

- [ ] **Step 2: Copy PROGRESS.md from PKA to project repo**

The Machine's PROGRESS.md currently lives in PKA at `docs/The Machine/PROGRESS.md`. Copy it to the project repo (keep original in PKA as archive until full migration is confirmed):

```bash
cp "C:/Users/chris/OneDrive/Documentos/PKA/docs/The Machine/PROGRESS.md" "C:/Users/chris/OneDrive/Documentos/the-machine/.tracking/PROGRESS.md"
```

- [ ] **Step 3: Extract resume point → write CURRENT.md**

Read the-machine's PROGRESS.md resume point section and write CURRENT.md. Based on current state:

```markdown
# The Machine — CURRENT

## Status
LIVE on SOL-29MAY26-CDE. First orders on book (BUY@$83.67, SELL@$84.01).

## Active Work
- **Rex:** Monitor grid fills, check perps API bug #125 status each session

## Blockers
- Coinbase perps API bug #125 — ALL INTX perp endpoints return 403 (since 2026-03-10)
- Capital constraint — $436 equity, BTC contracts need $385 margin (since 2026-04-18)

## Next
1. Confirm grid cycles (buy fills → counter-sell, sell fills → counter-buy)
2. Commit SOL config from droplet back to local repo
3. Set GLASSNODE_API_KEY and COINGLASS_API_KEY env vars on droplet
```

Write to `the-machine/.tracking/CURRENT.md`.

- [ ] **Step 4: Extract decisions → seed DECISIONS.md**

Read through PROGRESS.md and extract all decisions. Key ones from the file:

```markdown
# The Machine — DECISIONS

> {N} decisions logged | Last: 2026-05-02

---

### 2026-04-18 — Platform: Coinbase over Kraken
**Context:** Kraken fees (0.25%/0.40%) killed all edge. Coinbase One offers 0% maker fees.
**Decision:** Migrate from Kraken to Coinbase. Coinbase One subscription for 0% fees.
**Rationale:** Breakeven = 0 days with zero fees vs never-profitable on Kraken
**Members:** Rex, Shield, Edge, Kit

---

### 2026-04-27 — Use Hyperliquid for data (not CoinGlass/Glassnode)
**Context:** CoinGlass $29/mo, Glassnode $100+/mo — too expensive for $338 capital
**Decision:** Use Hyperliquid API (free, US-accessible, no auth) for liquidation + funding data
**Rationale:** Zero cost, sufficient quality for current capital level
**Members:** DATA, Rex

---

### 2026-04-27 — CDE dated futures (not INTX perps)
**Context:** Coinbase perps API bug #125 blocks all INTX endpoints with 403
**Decision:** Retool to CDE dated futures until perps API is fixed. USE_CDE_FUTURES toggle for instant revert.
**Rationale:** CDE works, perps don't. One-line revert path preserved.
**Members:** Rex

---

### 2026-04-27 — Trade SOL not BTC
**Context:** BTC nano contract ($770 notional) exceeds $436 equity. SOL = ~$210 margin.
**Decision:** Trade SOL-29MAY26-CDE as primary instrument
**Rationale:** Capital constraint. BTC added when profitable enough.
**Members:** Rex, Shield

---

### 2026-04-29 — ADA bag held in reserve
**Context:** ~3,252 ADA on account. Could sell to increase trading capital.
**Decision:** Hold ADA until bot proves itself with real profitable trades
**Rationale:** Don't sacrifice holdings to fund an unproven bot
**Members:** Owner

---

### 2026-04-29 — CDE base_size = contract count, not SOL amount
**Context:** Grid ran 2+ days with zero fills. Orders rejected as INSUFFICIENT_FUNDS.
**Decision:** CDE futures expect base_size = number of contracts (e.g. "1"), not underlying quantity (e.g. "5.0000")
**Rationale:** Verified via test orders. This is how Coinbase CDE API works.
**Members:** Rex, Kit

---
```

Update count in header. Write to `the-machine/.tracking/DECISIONS.md`.

- [ ] **Step 5: Create today's session file**

```markdown
# The Machine — Session 2026-05-02

## {HH:MM} — Kit — .tracking/ system setup
Created .tracking/ folder structure.
Migrated PROGRESS.md from PKA/docs/The Machine/.
Seeded CURRENT.md and DECISIONS.md from progress history.
```

Write to `the-machine/.tracking/sessions/2026-05-02.md`.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/the-machine"
git add .tracking/
git commit -m "feat: add .tracking/ system — CURRENT, DECISIONS, sessions, migrated PROGRESS

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Create .tracking/ for ManyTalentsMore + Migrate PROGRESS.md

**Files:**
- Create: `ManyTalentsMore/.tracking/CURRENT.md`
- Create: `ManyTalentsMore/.tracking/DECISIONS.md`
- Create: `ManyTalentsMore/.tracking/sessions/2026-05-02.md`
- Copy: `PKA/Team Inbox/money-api-infra/PROGRESS.md` → `ManyTalentsMore/.tracking/PROGRESS.md`

- [ ] **Step 1: Create .tracking/ directory structure**

```bash
cd "C:/Users/chris/OneDrive/Documentos/ManyTalentsMore"
mkdir -p .tracking/sessions .tracking/specs
```

- [ ] **Step 2: Copy PROGRESS.md from PKA**

```bash
cp "C:/Users/chris/OneDrive/Documentos/PKA/Team Inbox/money-api-infra/PROGRESS.md" "C:/Users/chris/OneDrive/Documentos/ManyTalentsMore/.tracking/PROGRESS.md"
```

- [ ] **Step 3: Extract resume point → write CURRENT.md**

Read the Money Dashboard PROGRESS.md. The project is marked ALL PHASES COMPLETE, so CURRENT.md reflects that:

```markdown
# ManyTalentsMore — CURRENT

## Status
Web platform live at manytalentsmore.com. Money dashboards (VEOE + Crypto) deployed. Scheduling module next.

## Active Work
- **Glass:** Scheduling module brainstorm completed, spec written, awaiting implementation

## Next
1. Scheduling module implementation (spec: .tracking/specs/2026-04-29-scheduling-module-design.md)
2. MTM Prep web overhaul
3. Chart reference system
```

Write to `ManyTalentsMore/.tracking/CURRENT.md`.

- [ ] **Step 4: Extract decisions → seed DECISIONS.md**

```markdown
# ManyTalentsMore — DECISIONS

> {N} decisions logged | Last: 2026-05-02

---

### 2026-04-12 — Auth: password token, not Frappe
**Context:** Money dashboard needs auth. Options: Frappe SSO, OAuth, simple password.
**Decision:** Simple password → shared DASHBOARD_TOKEN. Single-user dashboard.
**Rationale:** Only Chris uses it. Full auth is over-engineering.
**Members:** Glass, Kit

---

### 2026-04-12 — Architecture: direct browser → API (not proxied through Next.js)
**Context:** Could proxy API calls through Next.js server or call droplet directly.
**Decision:** Direct browser → Nginx → API calls for speed and WebSocket support.
**Rationale:** Lower latency, native WebSocket support without Next.js middleware.
**Members:** Glass, Kit

---

### 2026-04-12 — Charts: lightweight-charts v5 + recharts
**Context:** Need charting for equity curves and trade data.
**Decision:** lightweight-charts v5 (AreaSeries via addSeries()) + recharts for bar/pie charts.
**Rationale:** lightweight-charts for TradingView-quality financial charts, recharts for everything else.
**Members:** Glass

---

### 2026-04-12 — Infrastructure: Caddy reverse proxy on droplet
**Context:** Need HTTPS + reverse proxy for VEOE (8501) and Crypto (8080) APIs.
**Decision:** Caddy with auto-SSL at money-api.manytalentsmore.com → droplet 104.131.176.130.
**Rationale:** Caddy auto-renews certs, simpler config than Nginx.
**Members:** Kit

---
```

Write to `ManyTalentsMore/.tracking/DECISIONS.md`.

- [ ] **Step 5: Create today's session file**

```markdown
# ManyTalentsMore — Session 2026-05-02

## {HH:MM} — Kit — .tracking/ system setup
Created .tracking/ folder structure.
Migrated PROGRESS.md from PKA/Team Inbox/money-api-infra/.
Seeded CURRENT.md and DECISIONS.md from progress history.
```

Write to `ManyTalentsMore/.tracking/sessions/2026-05-02.md`.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/ManyTalentsMore"
git add .tracking/
git commit -m "feat: add .tracking/ system — CURRENT, DECISIONS, sessions, migrated PROGRESS

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Create .tracking/ for AllTec Pro + VEOE

These two projects don't have existing PROGRESS.md files to migrate — they get fresh .tracking/ folders.

**Files:**
- Create: `AllTecPro/hcp_replacement/.tracking/CURRENT.md`
- Create: `AllTecPro/hcp_replacement/.tracking/DECISIONS.md`
- Create: `AllTecPro/hcp_replacement/.tracking/PROGRESS.md`
- Create: `AllTecPro/hcp_replacement/.tracking/sessions/2026-05-02.md`
- Create: `clawdbottrade/.tracking/CURRENT.md`
- Create: `clawdbottrade/.tracking/DECISIONS.md`
- Create: `clawdbottrade/.tracking/PROGRESS.md`
- Create: `clawdbottrade/.tracking/sessions/2026-05-02.md`

- [ ] **Step 1: Create AllTec .tracking/ structure**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
mkdir -p .tracking/sessions .tracking/specs
```

- [ ] **Step 2: Write AllTec CURRENT.md**

Read the PKA .tracking/PROGRESS.md (migrated in Task 1) for the latest AllTec-related resume points (Session 2026-04-29 has the most recent AllTec state). Also check PKA memory for AllTec project context. Write:

```markdown
# AllTec Pro — CURRENT

## Status
HCP replacement app live on Frappe Cloud. Inventory Phase 1 deployed. Smart matching live.

## Active Work
- **Forge:** Deploy code fixes (hcp_sync.py customer string guard) to Frappe Cloud
- **Swift:** Mobile app stable, awaiting next feature cycle

## Blockers
- Gmail SMTP password needs reset for alltecplumbing@gmail.com (since 2026-04-19)

## Next
1. Deploy pending hcp_sync.py fixes (customer string guard)
2. Review bulk match results (AllTecPro/bulk_match_review.xlsx)
3. Scheduling module (spec written, awaiting implementation)
```

Write to `AllTecPro/hcp_replacement/.tracking/CURRENT.md`.

- [ ] **Step 3: Seed AllTec DECISIONS.md**

Extract AllTec-related decisions from PKA's PROGRESS.md sessions (2026-04-18, 2026-04-19, 2026-04-29):

```markdown
# AllTec Pro — DECISIONS

> {N} decisions logged | Last: 2026-05-02

---

### 2026-04-18 — Deploy inventory to production (no staging)
**Context:** Inventory Phase 1 ready. Could use staging or go direct.
**Decision:** Deploy directly to production — no staging environment needed.
**Rationale:** Low risk, easily reversible, staging adds overhead with no benefit at current scale.
**Members:** Forge, Owner

---

### 2026-04-18 — Limbo = post-job unused parts only
**Context:** Defining what Limbo warehouse means for inventory tracking.
**Decision:** Limbo holds only post-job unused parts (not pre-job staging).
**Rationale:** Owner confirmed — Limbo is where techs put leftover parts after a job.
**Members:** Owner

---

### 2026-04-18 — Event data in Frappe backend (not Supabase)
**Context:** Event tracker needs a data store. Options: Frappe doctype vs Supabase.
**Decision:** Use Frappe doctype (MTM Event Log) for all event data.
**Rationale:** Keep all backend data in one place. Frappe already hosts everything else.
**Members:** Forge, Kit

---

### 2026-04-19 — 3-tier confidence for matching (not 4)
**Context:** Item matching UI needed visual confidence levels.
**Decision:** 3 tiers: unmatched (white), first_match (sky blue), locked_in (dark cobalt).
**Rationale:** 4 tiers was too granular. Team review (Pixel) recommended simplification.
**Members:** Pixel, Glass, Forge

---

### 2026-04-29 — Fix HCP sync errors via Server Scripts (not code deploy)
**Context:** 3 HCP pull errors firing every 15 min. Code deploy is slow on Frappe Cloud.
**Decision:** Use Server Scripts (created via REST API) for immediate fixes, plus local code fixes for next deploy.
**Rationale:** Server Scripts take effect immediately without deploy cycle. Belt-and-suspenders approach.
**Members:** Forge

---
```

Write to `AllTecPro/hcp_replacement/.tracking/DECISIONS.md`.

- [ ] **Step 4: Create AllTec PROGRESS.md (fresh)**

```markdown
# AllTec Pro — PROGRESS

## Project Description
Full HCP replacement for AllTec Plumbing. Mobile app (React Native/Expo) + ERPNext backend on Frappe Cloud. Job management, inventory tracking, smart matching, daily restock, event tracking.

## Historical Note
Prior progress was tracked in PKA/.tracking/PROGRESS.md (sessions 2026-04-18, 2026-04-19, 2026-04-29). This file starts fresh as of the .tracking/ system migration on 2026-05-02.
```

Write to `AllTecPro/hcp_replacement/.tracking/PROGRESS.md`.

- [ ] **Step 5: Create AllTec today's session file**

```markdown
# AllTec Pro — Session 2026-05-02

## {HH:MM} — Kit — .tracking/ system setup
Created .tracking/ folder structure.
Seeded CURRENT.md and DECISIONS.md from PKA progress history.
Created fresh PROGRESS.md with historical reference to PKA.
```

Write to `AllTecPro/hcp_replacement/.tracking/sessions/2026-05-02.md`.

- [ ] **Step 6: Commit AllTec**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git add .tracking/
git commit -m "feat: add .tracking/ system — CURRENT, DECISIONS, sessions, PROGRESS

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 7: Create VEOE .tracking/ structure**

```bash
cd "C:/Users/chris/OneDrive/Documentos/clawdbottrade"
mkdir -p .tracking/sessions .tracking/specs
```

- [ ] **Step 8: Write VEOE CURRENT.md**

Based on memory (VEOE Bot Status — TGT zombie bug, needs halt/fix/reconciliation):

```markdown
# VEOE — CURRENT

## Status
Options trading bot deployed but paused for fixes. TGT zombie bug = 89% of losses are phantom.

## Active Work
- **Rex:** Fix zombie position tracking, reconcile real vs phantom P&L

## Blockers
- Polygon/Massive free tier rate limiting — 5 req/min can't screen 2000 tickers (since 2026-04-27)
- TGT zombie bug inflating losses — real balance ~$3,217, reported $2,057 (since 2026-04-18)

## Next
1. Fix zombie position tracking (TGT bug)
2. Rewire screening to use Alpaca Markets (200 req/min, free)
3. Reconcile actual P&L after zombie fix
```

Write to `clawdbottrade/.tracking/CURRENT.md`.

- [ ] **Step 9: Seed VEOE DECISIONS.md**

```markdown
# VEOE — DECISIONS

> {N} decisions logged | Last: 2026-05-02

---

### 2026-04-18 — Tighten all risk parameters
**Context:** 5-reviewer deep dive found TGT zombie bug causing 89% of reported losses to be phantom.
**Decision:** VRP 1.30→0.80, min_score 15→50, trail 10/8→15/12, non-mover 3→5, kill adaptive loosening.
**Rationale:** Over-permissive params let bad trades through. Tighter = fewer trades but higher quality.
**Members:** Rex, Shield, Sage, Edge, Pulse

---

### 2026-04-27 — Replace Polygon with Alpaca for screening
**Context:** Polygon free tier (5 req/min) can't screen 2000 tickers. 945 errors in one scan.
**Decision:** Switch to Alpaca Markets (free, 200 req/min) for intraday screening data.
**Rationale:** Free, fast enough, US-accessible. Kit to rewire update_cache_daily.py.
**Members:** DATA, Kit

---
```

Write to `clawdbottrade/.tracking/DECISIONS.md`.

- [ ] **Step 10: Create VEOE PROGRESS.md (fresh)**

```markdown
# VEOE — PROGRESS

## Project Description
AI-driven options trading bot (vertical spreads). Deployed on DigitalOcean droplet, dashboard at manytalentsmore.com/money/options.

## Historical Note
Prior progress was tracked in conversation memory and PKA sessions. This file starts fresh as of the .tracking/ system migration on 2026-05-02.
```

Write to `clawdbottrade/.tracking/PROGRESS.md`.

- [ ] **Step 11: Create VEOE today's session file**

```markdown
# VEOE — Session 2026-05-02

## {HH:MM} — Kit — .tracking/ system setup
Created .tracking/ folder structure.
Seeded CURRENT.md and DECISIONS.md from PKA progress history and memory.
Created fresh PROGRESS.md with historical reference.
```

Write to `clawdbottrade/.tracking/sessions/2026-05-02.md`.

- [ ] **Step 12: Commit VEOE**

```bash
cd "C:/Users/chris/OneDrive/Documentos/clawdbottrade"
git add .tracking/
git commit -m "feat: add .tracking/ system — CURRENT, DECISIONS, sessions, PROGRESS

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Migrate Design Specs to Project Repos

Existing specs in `PKA/docs/superpowers/specs/` need to move to their respective project's `.tracking/specs/`. PKA-level specs stay in PKA.

**Spec-to-project mapping:**

| Spec File | Belongs To | Move To |
|-----------|-----------|---------|
| `2026-04-16-bitwarden-secrets-management-design.md` | PKA (org-level) | `PKA/.tracking/specs/` |
| `2026-04-16-route-optimization-plugin-design.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |
| `2026-04-18-event-tracker-design.md` | AllTec Pro | `AllTecPro/hcp_replacement/.tracking/specs/` |
| `2026-04-18-options-trading-platform-design.md` | VEOE | `clawdbottrade/.tracking/specs/` |
| `2026-04-18-daily-restock-pull-list-design.md` | AllTec Pro | `AllTecPro/hcp_replacement/.tracking/specs/` |
| `2026-04-19-chart-reference-system-design.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |
| `2026-04-19-smart-matching-system-design.md` | AllTec Pro | `AllTecPro/hcp_replacement/.tracking/specs/` |
| `2026-04-20-options-monetization-design.md` | VEOE | `clawdbottrade/.tracking/specs/` |
| `2026-04-23-veoe-ml-sync-service-design.md` | VEOE | `clawdbottrade/.tracking/specs/` |
| `2026-04-24-llm-receipt-parser-design.md` | AllTec Pro | `AllTecPro/hcp_replacement/.tracking/specs/` |
| `2026-04-24-mtm-phase1-design.md` | AllTec Pro | `AllTecPro/hcp_replacement/.tracking/specs/` |
| `2026-04-26-mtprep-web-overhaul-design.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |
| `2026-04-28-mtm-explainer-video-design.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |
| `2026-04-29-scheduling-module-design.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |
| `2026-05-02-project-tracking-system-design.md` | PKA (org-level) | `PKA/.tracking/specs/` |
| `error-prevention-system.md` | PKA (org-level) | `PKA/.tracking/specs/` |
| Subdirs: `watchdog/`, `incident-memory/`, `state-persistence/`, `enforcement-system/` | PKA (sub-projects) | `PKA/.tracking/specs/` |

**Also migrate plans** from `PKA/docs/superpowers/plans/` to the same project `.tracking/specs/` folders (plans are implementation details of specs):

| Plan File | Belongs To | Move To |
|-----------|-----------|---------|
| `2026-04-16-route-optimization-plugin.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |
| `2026-04-17-mtm-inventory-phase1-deploy.md` | AllTec Pro | `AllTecPro/hcp_replacement/.tracking/specs/` |
| `2026-04-18-event-tracker.md` | AllTec Pro | `AllTecPro/hcp_replacement/.tracking/specs/` |
| `2026-04-18-options-trading-platform.md` | VEOE | `clawdbottrade/.tracking/specs/` |
| `2026-04-19-chart-reference-system.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |
| `2026-04-19-smart-matching-system.md` | AllTec Pro | `AllTecPro/hcp_replacement/.tracking/specs/` |
| `2026-04-20-chart-system-phase2-full-expansion.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |
| `2026-04-20-options-monetization.md` | VEOE | `clawdbottrade/.tracking/specs/` |
| `2026-04-23-veoe-ml-sync-service.md` | VEOE | `clawdbottrade/.tracking/specs/` |
| `2026-04-24-llm-receipt-parser.md` | AllTec Pro | `AllTecPro/hcp_replacement/.tracking/specs/` |
| `2026-04-28-mtm-explainer-video.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |
| `2026-04-29-scheduling-module.md` | ManyTalentsMore | `ManyTalentsMore/.tracking/specs/` |

- [ ] **Step 1: Copy AllTec specs + plans**

```bash
SPECS="C:/Users/chris/OneDrive/Documentos/PKA/docs/superpowers/specs"
PLANS="C:/Users/chris/OneDrive/Documentos/PKA/docs/superpowers/plans"
DEST="C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement/.tracking/specs"

cp "$SPECS/2026-04-18-event-tracker-design.md" "$DEST/"
cp "$SPECS/2026-04-18-daily-restock-pull-list-design.md" "$DEST/"
cp "$SPECS/2026-04-19-smart-matching-system-design.md" "$DEST/"
cp "$SPECS/2026-04-24-llm-receipt-parser-design.md" "$DEST/"
cp "$SPECS/2026-04-24-mtm-phase1-design.md" "$DEST/"
cp "$PLANS/2026-04-17-mtm-inventory-phase1-deploy.md" "$DEST/"
cp "$PLANS/2026-04-18-event-tracker.md" "$DEST/"
cp "$PLANS/2026-04-19-smart-matching-system.md" "$DEST/"
cp "$PLANS/2026-04-24-llm-receipt-parser.md" "$DEST/"
```

- [ ] **Step 2: Commit AllTec specs**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git add .tracking/specs/
git commit -m "docs: migrate design specs + plans from PKA to project .tracking/

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3: Copy MTM specs + plans**

```bash
SPECS="C:/Users/chris/OneDrive/Documentos/PKA/docs/superpowers/specs"
PLANS="C:/Users/chris/OneDrive/Documentos/PKA/docs/superpowers/plans"
DEST="C:/Users/chris/OneDrive/Documentos/ManyTalentsMore/.tracking/specs"

cp "$SPECS/2026-04-16-route-optimization-plugin-design.md" "$DEST/"
cp "$SPECS/2026-04-19-chart-reference-system-design.md" "$DEST/"
cp "$SPECS/2026-04-26-mtprep-web-overhaul-design.md" "$DEST/"
cp "$SPECS/2026-04-28-mtm-explainer-video-design.md" "$DEST/"
cp "$SPECS/2026-04-29-scheduling-module-design.md" "$DEST/"
cp "$PLANS/2026-04-16-route-optimization-plugin.md" "$DEST/"
cp "$PLANS/2026-04-19-chart-reference-system.md" "$DEST/"
cp "$PLANS/2026-04-20-chart-system-phase2-full-expansion.md" "$DEST/"
cp "$PLANS/2026-04-28-mtm-explainer-video.md" "$DEST/"
cp "$PLANS/2026-04-29-scheduling-module.md" "$DEST/"
```

- [ ] **Step 4: Commit MTM specs**

```bash
cd "C:/Users/chris/OneDrive/Documentos/ManyTalentsMore"
git add .tracking/specs/
git commit -m "docs: migrate design specs + plans from PKA to project .tracking/

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 5: Copy VEOE specs + plans**

```bash
SPECS="C:/Users/chris/OneDrive/Documentos/PKA/docs/superpowers/specs"
PLANS="C:/Users/chris/OneDrive/Documentos/PKA/docs/superpowers/plans"
DEST="C:/Users/chris/OneDrive/Documentos/clawdbottrade/.tracking/specs"

cp "$SPECS/2026-04-18-options-trading-platform-design.md" "$DEST/"
cp "$SPECS/2026-04-20-options-monetization-design.md" "$DEST/"
cp "$SPECS/2026-04-23-veoe-ml-sync-service-design.md" "$DEST/"
cp "$PLANS/2026-04-18-options-trading-platform.md" "$DEST/"
cp "$PLANS/2026-04-20-options-monetization.md" "$DEST/"
cp "$PLANS/2026-04-23-veoe-ml-sync-service.md" "$DEST/"
```

- [ ] **Step 6: Commit VEOE specs**

```bash
cd "C:/Users/chris/OneDrive/Documentos/clawdbottrade"
git add .tracking/specs/
git commit -m "docs: migrate design specs + plans from PKA to project .tracking/

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 7: Copy PKA-level specs**

```bash
SPECS="C:/Users/chris/OneDrive/Documentos/PKA/docs/superpowers/specs"
DEST="C:/Users/chris/OneDrive/Documentos/PKA/.tracking/specs"

cp "$SPECS/2026-04-16-bitwarden-secrets-management-design.md" "$DEST/"
cp "$SPECS/2026-05-02-project-tracking-system-design.md" "$DEST/"
cp "$SPECS/error-prevention-system.md" "$DEST/"
cp -r "$SPECS/watchdog" "$DEST/"
cp -r "$SPECS/incident-memory" "$DEST/"
cp -r "$SPECS/state-persistence" "$DEST/"
cp -r "$SPECS/enforcement-system" "$DEST/"
```

- [ ] **Step 8: Copy this implementation plan to PKA .tracking/specs/**

```bash
cp "C:/Users/chris/OneDrive/Documentos/PKA/docs/superpowers/plans/2026-05-02-project-tracking-system.md" "C:/Users/chris/OneDrive/Documentos/PKA/.tracking/specs/"
```

- [ ] **Step 9: Commit PKA specs**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add .tracking/specs/
git commit -m "docs: migrate PKA-level design specs to .tracking/specs/

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Update CLAUDE.md with Tracking System Rules

**Files:**
- Modify: `PKA/CLAUDE.md`

- [ ] **Step 1: Replace the Project Progress Tracking section in CLAUDE.md**

Replace the existing `### Project Progress Tracking` section (lines 23-29 of CLAUDE.md) with the new tracking system rules:

Old text to replace:
```markdown
### Project Progress Tracking
Every active project must have a `PROGRESS.md` file inside its project folder containing:
- **Project description** — What the project is and its goals.
- **Current status** — Where we are right now.
- **Session log** — Updated regularly throughout each work session with what was done, decisions made, and next steps.
- **Resume point** — A clear statement of exactly where to pick up if the session is interrupted.

This file is updated periodically during work so that if a session ends unexpectedly, no context is lost. If the file grows too large, 10T will inform the Owner and compress it (archiving older entries while preserving the resume point).
```

New text:
```markdown
### Project Tracking System (.tracking/)
Every active project has a `.tracking/` folder in its repo root with these files:

| File | Purpose | Rules |
|------|---------|-------|
| `CURRENT.md` | Agent cold-start briefing | Max 20 lines. Updated every ~15 min + on events. Read FIRST on every session. |
| `DECISIONS.md` | Permanent decision log | Append-only. Never pruned. Agents grep for relevant decisions. |
| `PROGRESS.md` | Owner's full history | Append-only. Updated at session close. Agents NEVER load on startup. |
| `specs/` | Design documents | Source of truth for what we're building. If code and spec disagree, **flag and ask the Owner** — never silently follow either side. |
| `sessions/YYYY-MM-DD.md` | Daily session log | One per day, immutable after day ends. Agents load today's file on startup. |

**Cold-start protocol:** Agent reads (1) `Team/{Member}/IDENTITY.md` → (2) `{project}/.tracking/CURRENT.md` → (3) today's session file → (4) relevant spec → (5) DECISIONS.md if needed.

**Update triggers:** CURRENT.md is updated on task completion, decisions, deployments, blockers, handoffs, errors, and every ~15 minutes of active work. This ensures max ~15 min of context loss on crash.

**Handoff rule:** When work passes between team members, CURRENT.md must include a Handoff section with the context the receiving member needs. Removed once the receiver confirms they have context.

**Specs as source of truth:** Design specs live in `{project}/.tracking/specs/`, not in PKA. If an agent detects that code behavior does not match a spec, they STOP, flag the disagreement (what spec says vs what code does), and wait for Owner resolution before proceeding.
```

- [ ] **Step 2: Update the Folder Structure section in CLAUDE.md**

Replace the existing folder structure block with the updated version that includes `.tracking/`:

Old text:
```markdown
## Folder Structure
\```
PKA/
├── .10T/                  # 10T orchestrator system files
│   └── ORCHESTRATOR.md    # 10T's identity and operating rules
├── Team/                  # All AI team members
│   ├── REGISTRY.md        # Official team roster
│   ├── Berry/             # HR & Talent Architect
│   │   └── IDENTITY.md
│   └── DATA/              # Senior Researcher
│       └── IDENTITY.md
├── Owner's Inbox/         # Deliverables ready for the Owner to review
├── Team Inbox/            # Tasks and assignments in progress
└── CLAUDE.md              # This file — system overview
\```
```

New text:
```markdown
## Folder Structure
\```
PKA/
├── .tracking/             # Project tracking (CURRENT, DECISIONS, PROGRESS, specs, sessions)
├── .10T/                  # 10T orchestrator system files
│   └── ORCHESTRATOR.md    # 10T's identity and operating rules
├── Team/                  # All AI team members
│   ├── REGISTRY.md        # Official team roster
│   ├── Berry/             # HR & Talent Architect
│   │   └── IDENTITY.md
│   └── DATA/              # Senior Researcher
│       └── IDENTITY.md
├── Owner's Inbox/         # Deliverables ready for the Owner to review
├── Team Inbox/            # Tasks and assignments in progress
└── CLAUDE.md              # This file — system overview
\```
```

- [ ] **Step 3: Commit CLAUDE.md changes**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md with .tracking/ system rules — replaces PROGRESS.md section

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Create Private PKA GitHub Repo + Push

**Files:**
- Create: `PKA/.gitignore`

- [ ] **Step 1: Create .gitignore for PKA**

```
# API keys and credentials
.env
*.key
*.pem
*.json.bak

# Bitwarden session tokens
BW_SESSION

# MCP credentials (API keys are in .mcp.json but it's needed for tool setup)
# .mcp.json is committed intentionally — API keys rotated via generate_keys

# OS files
desktop.ini
Thumbs.db
.DS_Store

# Editor files
*.swp
*.swo
*~

# Node modules (if any tools use them)
node_modules/
```

Write to `PKA/.gitignore`.

- [ ] **Step 2: Create private GitHub repo**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
gh repo create manyTalents/PKA --private --source=. --description "10T AI Team System — orchestrator, team, project tracking"
```

Expected output: repo created and remote `origin` added.

- [ ] **Step 3: Stage all PKA files**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add .gitignore
git add -A
```

Review staged files with `git status` to make sure no sensitive files (API keys, credentials) are included. Remove any that shouldn't be committed.

- [ ] **Step 4: Commit and push**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git commit -m "feat: initial PKA repo — 10T team system, .tracking/, specs, team identities

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push -u origin master
```

- [ ] **Step 5: Verify repo is accessible**

```bash
gh repo view manyTalents/PKA --json name,visibility,url
```

Expected: `"visibility": "PRIVATE"`, URL shows `https://github.com/manyTalents/PKA`.

---

## Task 8: Push .tracking/ Changes to Existing Project Repos

- [ ] **Step 1: Push The Machine**

The Machine has no remote configured. Create one:

```bash
cd "C:/Users/chris/OneDrive/Documentos/the-machine"
gh repo create manyTalents/the-machine --private --source=. --push --description "Multi-strategy autonomous crypto trading bot on Coinbase"
```

If repo already exists on GitHub:
```bash
git remote add origin https://github.com/manyTalents/the-machine.git
git push -u origin master
```

- [ ] **Step 2: Push ManyTalentsMore**

```bash
cd "C:/Users/chris/OneDrive/Documentos/ManyTalentsMore"
git push origin
```

- [ ] **Step 3: Push AllTec Pro**

```bash
cd "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement"
git push origin
```

- [ ] **Step 4: Push VEOE**

```bash
cd "C:/Users/chris/OneDrive/Documentos/clawdbottrade"
git push origin
```

---

## Task 9: Clean Up Old Spec/Plan Locations in PKA

After all specs have been copied to their project repos (Task 5), clean up the old locations. The originals in `PKA/docs/superpowers/specs/` and `PKA/docs/superpowers/plans/` can be removed since they now live in the correct project repos.

- [ ] **Step 1: Verify all specs were copied successfully**

For each project, verify the spec files exist in `.tracking/specs/`:

```bash
echo "=== AllTec ===" && ls "C:/Users/chris/OneDrive/Documentos/AllTecPro/hcp_replacement/.tracking/specs/"
echo "=== MTM ===" && ls "C:/Users/chris/OneDrive/Documentos/ManyTalentsMore/.tracking/specs/"
echo "=== VEOE ===" && ls "C:/Users/chris/OneDrive/Documentos/clawdbottrade/.tracking/specs/"
echo "=== PKA ===" && ls "C:/Users/chris/OneDrive/Documentos/PKA/.tracking/specs/"
```

Compare output against the mapping table in Task 5. Every spec and plan should be accounted for.

- [ ] **Step 2: Remove old specs directory from PKA (after Owner confirmation)**

**ASK OWNER BEFORE PROCEEDING.** This deletes the original spec/plan files from PKA. They now live in their respective project repos.

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git rm -r docs/superpowers/specs/ docs/superpowers/plans/
git commit -m "chore: remove old spec/plan locations — migrated to project .tracking/specs/

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Update PKA CURRENT.md After Migration Complete

- [ ] **Step 1: Update CURRENT.md to reflect completed migration**

After all tasks are done, update `PKA/.tracking/CURRENT.md` to reflect the new state:

```markdown
# PKA — CURRENT

## Status
.tracking/ system live across all 5 project repos. All specs migrated. PKA GitHub repo created.

## Active Work
- No active work assignments — system migration complete

## Next
1. Monitor .tracking/ system in practice over next week
2. Resume project work with new tracking system in place
3. Consider MADR if any project's DECISIONS.md exceeds 100 entries
```

- [ ] **Step 2: Update today's session file with final entry**

Append to `PKA/.tracking/sessions/2026-05-02.md`:

```markdown
## {HH:MM} — Kit — Migration complete
All 5 project repos now have .tracking/ folders:
- PKA: .tracking/ + GitHub repo (private)
- the-machine: .tracking/ + PROGRESS migrated
- ManyTalentsMore: .tracking/ + PROGRESS migrated
- AllTecPro/hcp_replacement: .tracking/ (fresh)
- clawdbottrade: .tracking/ (fresh)

All specs/plans migrated from PKA/docs/superpowers/ to project repos.
CLAUDE.md updated with new tracking rules.
```

- [ ] **Step 3: Final commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add .tracking/
git commit -m "docs: update CURRENT.md + session log — tracking system migration complete

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin master
```
