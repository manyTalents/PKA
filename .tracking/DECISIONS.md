# PKA — DECISIONS

> 16 decisions logged | Last: 2026-05-02

---

### 2026-03-30 — Toolbox lives in PKA/.10T/TOOLBOX.md
**Context:** Needed a central reference for all 90+ tools available to the team across MCP, CLI, Python packages, and system tools.
**Decision:** Toolbox master reference lives at `PKA/.10T/TOOLBOX.md` with 12 categories.
**Rationale:** Keeps all 10T orchestration files co-located under `.10T/`, single place to look up any tool.
**Members:** 10T, Kit

---

### 2026-03-30 — MCP tools installed under PKA/.10T/tools/
**Context:** Needed a consistent install location for MCP server binaries and cloned tool repos.
**Decision:** All MCP tools installed in `PKA/.10T/tools/`.
**Rationale:** Co-located with the toolbox reference; clean separation from project source code.
**Members:** 10T, Kit

---

### 2026-03-30 — MCP config at PKA/.mcp.json
**Context:** Claude Code needs an `.mcp.json` to register MCP servers with credentials.
**Decision:** MCP config lives at `PKA/.mcp.json` (repo root).
**Rationale:** Standard location Claude Code expects; accessible to all team sessions.
**Members:** Kit

---

### 2026-03-30 — CSV API keys for ERPNext (15-char format)
**Context:** Two key formats existed: "key2 full/read" (32-char) and CSV-exported keys (15-char). Needed to determine which was valid for Frappe API auth.
**Decision:** Use CSV-exported API keys (15-char format) for ERPNext MCP. Key stored in Bitwarden.
**Rationale:** Frappe source code uses `generate_hash(length=15)` — the 32-char keys are NOT valid Frappe API keys. CSV format is the correct one per source.
**Members:** Kit

---

### 2026-03-30 — HCP tools installed in DATA's recommended priority order
**Context:** 12 HCP tools identified. Owner wanted to walk through them one at a time.
**Decision:** Follow DATA's priority ordering: ERPNext MCP → Stripe → Twilio → signature canvas → OR-Tools → Mapbox → Frappe Insights → n8n → DocuSeal → Hookdeck → Veryfi/Mindee → Photo-to-Estimate.
**Rationale:** DATA's research ranked by impact and dependency order; ERPNext MCP is the foundation all others build on.
**Members:** DATA, 10T

---

### 2026-03-30 — Payment processor: Stripe (not Stax/Helcim)
**Context:** DATA analyzed 6 payment processors for AllTec Plumbing ($2M/yr revenue). Stax cheapest (~$30K/yr) but requires $8K-$23K custom dev. Stripe costs ~$42K/yr but has native ERPNext integration.
**Decision:** Stripe now; evaluate Stax in 12-18 months.
**Rationale:** Stripe has native ERPNext via Stripe2 app and best Expo React Native SDK. Zero dev cost. Still saves $11K/yr vs. current HCP (2.99%). Square rejected for Expo compatibility issues. Braintree rejected for high per-transaction fees.
**Members:** DATA, 10T, Ace

---

### 2026-04-02 — Crypto bot sweep runs with code defaults (not CLI overrides)
**Context:** Massive parameter sweep (303/303 configs) completely failed — timed out at 600s or crashed with exit code 3221226091. Root cause: CLI overrides (100 pairs, 21-month period) were far too aggressive.
**Decision:** Sweep runs with code defaults: 15 pairs, 6 months, 900s timeout. No CLI overrides.
**Rationale:** Code defaults were the correct values the system was designed around. CLI overrides caused timeouts and Windows crashes.
**Members:** Kit, Rex

---

### 2026-04-02 — Hire alpha team (Rex, Sage, Onyx, Shield, Ace) for crypto strategy
**Context:** Early sweep results all negative. Current strategies needed new alpha sources and expert review.
**Decision:** Hired 5 specialist team members: Rex (Quant Trader), Sage (Mathematician), Onyx (Microstructure), Shield (Risk Manager), Ace (Business Strategist). Team grew from 3 to 8 (later 12 with Pulse, Echo, Edge, Macro).
**Rationale:** Each member brings a specific discipline; current 10T/Kit/DATA generalists lacked deep quant expertise for crypto strategy validation.
**Members:** 10T, Berry

---

### 2026-04-05 — Strategy B (Vol Compression Breakout) shelved
**Context:** Fee analysis at 0.25%/0.40% maker/taker (actual Tier 0) vs. incorrectly assumed 0.16%/0.26% (Tier 2). Thin edges in Strategy B no longer viable.
**Decision:** Strategy B SHELVED. Replaced pipeline with D (Grid Trading), E (Cointegration/Relative Value), F (CVD Order Flow).
**Rationale:** 0.40% taker fee kills any edge from vol compression breakouts at the pair spreads tested. Fees were wrong in V1 — recalculated with live Kraken data.
**Members:** Rex, Sage, Shield

---

### 2026-04-05 — Monday timing effect killed
**Context:** Considered using day-of-week timing (buy Monday, sell Friday) as an alpha signal.
**Decision:** Monday timing KILLED. Not used.
**Rationale:** Academic proof that calendar effects don't persist post-2015. No edge after 2015 in any backtested dataset.
**Members:** Rex, Sage

---

### 2026-04-05 — USDC Earn for idle capital
**Context:** $177 sitting idle in USD on Kraken earning 0%.
**Decision:** Use USDC Earn + free USDC/USD conversion for idle capital (~3% APY).
**Rationale:** No capital risk on stablecoin earn. Free conversion means no fee to enter/exit. capital_manager.py to implement when built.
**Members:** Shield, Ace

---

### 2026-04-06 — Strategy E redesigned as relative value rotation (no short selling)
**Context:** DATA confirmed Kraken US requires $10M ECP certification for margin/short selling. True market-neutral long/short pairs strategy was DEAD on Kraken US spot.
**Decision:** Restructured Strategy E from long/short pairs to relative value rotation. Buy BOTH assets at baseline ($20/$20). Tilt allocation on z-score signal ($30/$10). Rebalance on mean reversion. All trades are sells of assets held — no shorts needed.
**Rationale:** No margin required. Same cointegration math, z-scores, thresholds. Expected Sharpe 0.8-1.5 (vs 1.5-2.5 for true market-neutral) — still profitable and 100% executable on Kraken US spot.
**Members:** Rex, Sage, Kit, DATA

---

### 2026-04-06 — Grid spacing: use 1.5% for live (not exact fee minimum default)
**Context:** Strategy D (Grid Trading) default grid spacing was set at the exact fee minimum. This leaves no margin for spread slippage.
**Decision:** Use 1.5% grid spacing for live trading. Default in code is at fee minimum.
**Rationale:** Approved with advisory by team. Extra buffer above fee minimum prevents marginal-edge trades that lose to spread.
**Members:** Rex, Shield, Sage

---

### 2026-04-18 — MTM Inventory deployed to production (no staging)
**Context:** MTM Inventory Phase 1 was ready. Question was whether to stage-test first.
**Decision:** Deploy inventory to production directly — no staging environment needed.
**Rationale:** Frappe Cloud shared hosting; no staging available. System is additive (new doctypes, new APIs) with no risk of breaking existing data.
**Members:** Kit

---

### 2026-04-18 — Limbo = post-job unused parts only
**Context:** "Limbo" warehouse concept needed a precise definition.
**Decision:** Limbo is exclusively for post-job unused parts (parts that went on a job truck but weren't used).
**Rationale:** Owner confirmed. Keeps limbo semantically clean — not a general holding bin, specifically the orphaned-parts-from-jobs bucket.
**Members:** 10T, Owner

---

### 2026-04-18 — Event data stored in Frappe backend (not Supabase), real-time via polling
**Context:** MTM Event Tracker needed a storage and delivery mechanism. Options: Supabase, Frappe, Socket.IO push.
**Decision:** Event data in Frappe backend (new MTM Event Log doctype). Real-time via polling — not Socket.IO push.
**Rationale:** Frappe Cloud shared hosting makes Socket.IO unreliable. All data stays in the single source of truth (Frappe). Polling is simpler and reliable on shared hosting.
**Members:** Kit

---
