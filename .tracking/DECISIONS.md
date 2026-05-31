# PKA — DECISIONS

> 24 decisions logged | Last: 2026-05-30

---

### 2026-05-30 — Colab v4 protocol: PENDING.md as primary turn signal
**Context:** v1 colab session (23 rounds) surfaced recurring detection failures. Filename-pattern watchers broke 4+ times. Chris had to prompt "check" 15+ times.
**Decision:** PENDING.md replaces filename-based detection as the single source of truth for whose turn it is. All detection protocols (both AIs) check PENDING.md first.
**Rationale:** Every filename pattern broke (*grok* missed 10t-*, regex 1[3-9] missed round 12, overwrites invisible to -newer). PENDING.md content is unambiguous.
**Members:** 10T (Claude + Grok), Owner

---

### 2026-05-30 — Grok persistence: 3-layer stack (Task Scheduler + self-poller + protocol)
**Context:** Grok goes silent after handing the turn because his agent only wakes on Owner messages. 15+ "check" prompts in v1.
**Decision:** Three mandatory layers: (1) Windows Task Scheduler polling every 30s (external, survives everything), (2) Self-poller counting task (in-agent, Chris's design), (3) Auto-Detection Protocol on every engagement (5-step signal check).
**Rationale:** No single layer was reliable. Task Scheduler survived agent death but had a broken regex for hours. Self-poller caught the first autonomous handoff but dies at 5 minutes. Protocol is reactive but reliable when triggered. All three together reduced relay burden significantly.
**Members:** 10T (Claude + Grok), Owner

---

### 2026-05-30 — Providence PM app: ERPNext + custom Frappe app (providence_pm)
**Context:** Buildium replacement for Providence Real Estate. Platform already decided (ERPNext). Needed an app name.
**Decision:** App name `providence_pm`. Specific to Providence for now, extractable later for multi-business reuse.
**Rationale:** Avoids generic name collision if other businesses want PM customizations on the same ERPNext instance. Start specific, refactor to generic if needed.
**Members:** 10T (Claude + Grok)

---

### 2026-05-30 — LA CC surcharges: use dual pricing / cash discount, not surcharges
**Context:** AllTec field invoice system needs to handle CC processing fees (2.7% + $0.15 Stripe).
**Decision:** Use cash discount / dual pricing instead of credit card surcharges.
**Rationale:** Surcharging requires debit card detection (federal law prohibits debit surcharges), Stripe notification 30 days in advance, and separate line items. LA SB 254 adds $500/violation state penalties for debit surcharges effective 2026-08-01. Cash discount avoids all of this — same economics, better customer perception, no debit card detection needed.
**Members:** Writ (research), 10T

---

### 2026-05-27 — server_script_enabled must go in common_site_config.json
**Context:** AllTec receipt pipeline setup on self-hosted ERPNext. Server Scripts kept throwing "disabled" despite site_config.json having the flag set.
**Decision:** Frappe's `is_safe_exec_enabled()` reads ONLY from `common_site_config.json` via `frappe.get_common_site_config()`, not from per-site `site_config.json`. `bench set-config` writes to the wrong file. Must edit `sites/common_site_config.json` directly.
**Rationale:** Source confirmed in `frappe/utils/safe_exec.py:81` — comment says "server scripts can only be enabled via common_site_config.json".
**Members:** Forge

---

### 2026-05-27 — FC encryption keys don't survive site restore to self-hosted
**Context:** Restored FC backup to self-hosted droplet. All Password fields (imap_password, llm_api_key) encrypted with FC's Fernet key, unreadable on new site.
**Decision:** On any site restore to a new instance, Password fields MUST be re-entered. Procedure: (1) delete old `__Auth` record via `frappe.db.delete("__Auth", {...})`, (2) re-set via `set_encrypted_password()`. Google Vision service account was Code field — NOT affected.
**Rationale:** Frappe uses per-site encryption_key in site_config.json; FC has its own key that doesn't transfer.
**Members:** Forge

---

### 2026-05-27 — LLM disabled until Anthropic key re-entered; OCR-only mode
**Context:** llm_api_key encrypted with old FC key, stale record deleted. `get_password` raises exception on missing record (not None), so llm_parser would crash even with `if not api_key:` guard.
**Decision:** Set llm_enabled=0 in HCP Replacement Settings. Pipeline runs OCR + regex/template parse only. Re-enable once Chris re-enters Anthropic key via the UI. Reset 4 failed receipts (which had successful OCR text) back to Processed status.
**Rationale:** Safest option without modifying parser code. OCR pipeline is fully functional without LLM.
**Members:** Forge

---

### 2026-05-27 — Receipt email pipeline fully live on self-hosted (with noted gaps)
**Context:** Pipeline stood up on 134.199.198.83 Docker instance.
**Decision:** Confirmed working: IMAP ghost mode (readonly=True, BODY.PEEK[]), date-based SINCE search, dedup Server Script, scheduler hourly event, custom fields, Google Vision OCR. Known gap: 50 email-path receipts show Pending (file attached after insert so after_insert OCR enqueue misses them — pre-existing FC-era design gap, not introduced by this setup).
**Rationale:** Design gap documented, not a regression. Pipeline creating and processing new receipts correctly.
**Members:** Forge

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
