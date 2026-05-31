# 10T Toolbox Buildout — PROGRESS

## Project Description
Building a comprehensive toolbox for the 10T team across all 3 active projects (VEOE trading bot, ManyTalents prep app, AllTec HCP replacement). Walking through HCP tools first, one at a time.

> **Archived sessions:** `.tracking/archives/PROGRESS-archive-2026-Q1Q2.md` (March-April 2026)

---

## 2026-05-30 — Colab v4 Protocol + Providence PM App (10T Claude+Grok, 23 rounds)

### Colab Process Overhaul
- Built v3 multi-instance system (session subdirectories, SESSIONS.md, watcher v3)
- Ran v1 colab session: 23 rounds, 47+ files exchanged
- Proved PENDING.md turn signal, Chris Prompts tracker (15+ entries), self-poller (first autonomous AI-to-AI response)
- Deployed Windows Task Scheduler persistence (30s polling, survives everything)
- Wrote v4 protocol into COLAB-OPERATING-NOTES.md with all lessons incorporated
- Both AIs appended lessons to COLAB-LESSONS.md

### Providence Buildium Replacement — App Scaffolded
- `providence_pm` Frappe app: 5 chunks, 47 files, 2,274+ lines
- Chunk 1: Core data model (Property, Unit, Tenant, Owner, Lease Agreement)
- Chunk 2: Lease lifecycle (Subscription billing, daily auto-expiry)
- Chunk 3: Rent collection (late fees, Owner Statement report, payment API)
- Chunk 4: Maintenance (PM Work Order, PM Vendor, tenant notifications)
- Chunk 5: Tenant + Owner self-service portals with API layer
- All reviewed by Grok, issues caught and fixed (triple nesting, autoname, company field, plan proliferation)
- Commits: d80f317, 5cfa88f, 9a2b014, 4cca5fb

### LA CC Surcharge Research
- Dual pricing recommended over surcharging (SB 254 debit ban, effective 2026-08-01)
- Research delivered to Owner's Inbox

---

## 2026-05-26 — The Machine: Surviving the Worst Day + Kill Switch (Rex/Kit)

### Market Event
ZEC dropped $680→$569 over 48h (-16%), worst single day in 88 days (-12.9%).
Causes: US strikes on Iran (risk-off), ZEC profit-taking after rally, whale liquidation ($1.48M on Hyperliquid).
BTC only -1%, ETH -1.9% — ZEC-specific, not broad crash. Institutional buyers (Multicoin) still in.

### Grid Survival
- Daily PnL: -$28.20 (29 stops triggered, 3 wins)
- Kill switch never triggered (20% threshold = ~$153, max unrealized was ~$35)
- All stops executed cleanly (cancel-before-close working)
- Grid remained flat and balanced through the drop
- 24h rolling DB PnL went from +$52 to -$21, but grid is intact
- **The grid survived its worst day.** Losses controlled, not catastrophic.

---

## 2026-05-26 — The Machine: Kill Switch + Stop-Loss Hardening (Rex/Kit)

### Results
- Stop-loss optimized from 2.0x to 2.5x (backtest: 83 days, same PnL, half the stops, PF 5.0→7.4)
- Emergency kill switch deployed (Gate 0 in safety_gates.py) — independent last defense
- Stop-loss execution path hardened after stuck position incident (-$33 loss)
- Cancel-before-close ensures stops always execute even at low margin

### Incident: Stuck Position
- LONG x2 @ $657, stop triggered at $646, Coinbase rejected close (insufficient funds)
- Open orders held all margin, blocking the market close for 30+ minutes
- Manually cancelled orders and closed at ~$641 (-$33 realized)
- Root cause: _close_position didn't cancel orders first

### Fixes
- position_manager: cancel orders before close, 500ms delay, 10s retry on failure
- safety_gates: emergency kill switch (20% equity loss → halt + close all + alert)
- Kill switch runs ALWAYS (even when halted), halts BEFORE closing (prevents race)
- coinbase_client: added cancel_all_orders() method
- Stop multiplier: 2.0x → 2.5x per backtest optimization

### Team Review
- Rex: traced stop-loss path for longs AND shorts, verified both directions work
- Kit: found cooldown-on-failure bug (120s lockout even when close rejected), cancel race condition, spacing=0 gap
- Both found cancel_all_orders() missing from client, halt-blocks-kill-switch re-entry

### Files Changed
- position_manager.py (cancel-before-close, retry cooldown, response check)
- safety_gates.py (kill switch, rate limiting)
- coinbase_client.py (cancel_all_orders)
- config.py (stop_spacing_mult 2.0→2.5)

---

## 2026-05-25 — The Machine: Structural Fixes + Instance Tagging (Rex)

### Results
- **+$49.70 daily PnL** (14 wins, 1 loss, 93% win rate)
- DB PnL (24h): +$117.04
- Grid cycling both directions (long and short) with auto-rebuild

### Bugs Fixed (continued from May 24)
7. **Stuck filled-pending** — filled levels with no counter_order_id never pruned → prune orphaned fills
8. **Orphans survive band filter** — orders from old instances stayed → instance-tagged client_order_ids (`tm_{instance}_{uuid}`)
9. **Wrong-instance orders persist** — cancel any `tm_` order with wrong instance prefix on adopt
10. **Phantom records v2** — `_close_position` checked exceptions only, not Coinbase response → check `success` field
11. **Email spam** — daily loss cap alert every 30s → rate-limited to 1 per 24h

### Key Findings
- **Capital constraint at $768**: can't hold orders on both sides while holding a position. One-sided with position is expected. Need ~$1,400 for full grid.
- **Coinbase PnL settlement**: `total_usd_balance` only updates at daily settlement. Unsettled PnL still counts for `available_margin` immediately.

### Files Changed
- grid_engine.py: stuck fill prune, instance-tagged orders, instance-based orphan cleanup
- position_manager.py: response-checked _close_position
- safety_gates.py: rate-limited alerts
- All deployed + local synced

---

## 2026-05-24 — The Machine: Grid Proven + 6 Bugs Fixed (Rex)

### Results
- **2 completed grid cycles**, 1 stop-loss, net +$16.00 daily realized PnL
- Grid is now BALANCED: 1 BUY @ $649.10 + 1 SELL @ $662.25
- ETP SHORT orphan is gone (closed prior to session)
- Equity: $768.40, Buying Power: $579.37

### Bugs Fixed
**grid_engine.py (5 replenish bugs):**
1. Filled+counter levels consumed grid slots → count only unfilled orders
2. Buy-first bias (buy always checked before sell) → balance guarantee, underrepresented side goes first
3. Spacing=0 with <2 orders → ATR-based spacing fallback
4. Per_level=$15 hardcoded default (ZEC costs $656/contract, qty=0) → compute from allocation
5. cfg_max_levels=4 unaffordable → cost-cap by leveraged_capital / contract_cost

**position_manager.py (phantom records):**
6. `_record_exit()` ran even when `_close_position()` failed → 34 phantom distress_close records wrote -$341 fake losses, triggered daily loss cap, blocked entire grid. Fix: gate record on close success (all 4 exit types).

### Activity
- 15:55 UTC — SELL fill @ $663.00, pnl=+$9.64
- ~16:21 UTC — BUY counter fill @ $656.05, pnl=+$6.95
- ~18:19 UTC — STOP-LOSS on SHORT, pnl=-$2.40
- Grid rebuilt balanced: BUY @ $654.80 + SELL @ $670.65

### Files Changed
- clawdbottrade/the-machine-rewrite/grid_engine.py (5 replenish fixes)
- clawdbottrade/the-machine-rewrite/position_manager.py (phantom record fix)
- Both deployed to droplet, balanced grid confirmed

---

## 2026-05-23 — The Machine: Per-Instrument Overrides + ZEC Deploy (Kit)

### Work Done
- Added `INSTRUMENT_PARAMS` dict to `/opt/the-machine/src/config.py` with per-instrument tuning for ZEC-20DEC30-CDE and ETP-20DEC30-CDE
- Updated `GRID_FORCED_INSTRUMENTS` from `["ETP-20DEC30-CDE", "LCP-20DEC30-CDE", "LC-29MAY26-CDE"]` to `["ZEC-20DEC30-CDE", "ETP-20DEC30-CDE"]`
- Wired override lookup into `grid_manager.py` tick_all build block (spacing_atr_mult)
- Wired override lookup into `grid_engine.py` build method (max_levels)
- Wired override lookups into `position_manager.py` check() (stop_spacing_mult, max_hold_hours, breakeven_hours)
- All overrides fall back to global config values for any instrument not in INSTRUMENT_PARAMS
- Syntax-checked all four files before restart
- Synced all four files to local repo at C:/Users/chris/OneDrive/Documentos/clawdbottrade/the-machine-rewrite/
- Restarted the-machine container, clean startup confirmed

### Startup Confirmation (logs)
- "Scanner: using forced instruments: ['ZEC-20DEC30-CDE', 'ETP-20DEC30-CDE']"
- "Created grid ZEC-20DEC30-CDE (instance_id=184, alloc=$307.36, weight=0.50)"
- "Created grid ETP-20DEC30-CDE (instance_id=185, alloc=$307.36, weight=0.50)"
- Mode: paper. Equity: $768.40

### Files Changed (droplet)
- /opt/the-machine/src/config.py
- /opt/the-machine/src/strategies/grid_manager.py
- /opt/the-machine/src/strategies/grid_engine.py
- /opt/the-machine/src/strategies/position_manager.py

### Backup
- /root/config.py.bak.zec_deploy

---

## 2026-05-20 — The Machine: Three-Fix Session (Kit)

Owner authorized three surgical fixes to The Machine grid bot on droplet root@104.131.176.130.

**Fix 1 — Starting Equity Baseline**
- Problem: `/api/v1/stats` showed `starting_equity: 338.47`, making it look like the bot was +$178 when account is actually down $176 from $950 funded.
- Root cause: `starting = 338.47` hardcoded in `main.py` line 785 inside the `/api/v1/stats` endpoint. No state file or DB constant — it was a leftover literal.
- Fix: Changed to `starting = 950.0`.
- Verified via API: `starting_equity: 950.0`, `current_equity: 950.43` (live exchange value).

**Fix 2 — ADX Regime Deadlock**
- Problem: Grid idle for 7 days. ETH ADX was 40-52, but grid paused at ADX > 25 (REGIME_ADX_TRENDING) and only resumed below ADX 20 (REGIME_ADX_RANGING). These thresholds are too tight for ETH's normal volatility.
- There are TWO sets of ADX constants in config.py plus the GRID_ADX_PAUSE/RESUME thresholds:
  - Lines 135-136: `GRID_REGIME_ADX_TRENDING/RANGING` (original grid section)
  - Lines 359-360: `REGIME_ADX_TRENDING/RANGING` (V2 module section)
  - Lines 202-203: `GRID_ADX_PAUSE_THRESHOLD / GRID_ADX_RESUME_THRESHOLD`
- Changes applied:
  - `GRID_REGIME_ADX_TRENDING`: 25 → 40
  - `GRID_REGIME_ADX_RANGING`: 20 → 30
  - `REGIME_ADX_TRENDING`: 25 → 40
  - `REGIME_ADX_RANGING`: 20 → 30
  - `GRID_ADX_PAUSE_THRESHOLD`: 30 → 45
  - `GRID_ADX_RESUME_THRESHOLD`: 25 → 35

**Fix 3 — Contract Rollover**
- Problem: `ET-29MAY26-CDE` expires May 29 (9 days). `GRID_FORCED_INSTRUMENTS` still listed it.
- Confirmed via `client.list_crypto_futures()`: next contracts are `ET-26JUN26-CDE` (Jun 26) and `ET-31JUL26-CDE` (Jul 31). Jun contract has volume ($3207 24h), Jul has none.
- Fix: `GRID_FORCED_INSTRUMENTS` updated from `["ETP-20DEC30-CDE", "ET-29MAY26-CDE"]` to `["ETP-20DEC30-CDE", "ET-26JUN26-CDE"]`.
- Note: `ET-26JUN26-CDE` shows `view_only: True` in the API response — this is normal for CDE contracts before they fully open. The bot accepted it and created the grid instance.

**Post-restart verification**
- Container restarted cleanly, no errors in startup logs.
- Scanner confirmed: `"using forced instruments: ['ETP-20DEC30-CDE', 'ET-26JUN26-CDE']"`
- Grid confirmed building: `"Grid ETP-20DEC30-CDE built: center=2128.75 spacing=5.34 levels=4 per_level=232.06"`

**Win Rate 100% issue (reported, not fixed)**
- The stats query filters `GridFill.status == "completed"` — only grid cycle completions write fills.
- Stop-loss exits and time-exits close positions via `position_manager.py` but do NOT write a GridFill record.
- Result: losses never appear in stats. Fixing requires writing a loss record to GridFill (or a separate loss_fills table) when stop/time exits fire. Flagged for Owner — separate task.

**Backups**: `/root/config.py.bak.20260520`, `/root/main.py.bak.20260520` on droplet.

---

## Session: 2026-05-19 — Nate B Jones Research + 10T System Upgrade

### What was done:

**1. Nate B Jones Deep Research (3 parallel DATA agents)**
- Researched Nate B Jones (@NateBJones) — former Head of Product at Amazon Prime Video, now independent AI strategist (291K YouTube, 152K+ Substack #2 in Technology)
- **Substack agent:** 20 articles deep-dived from last 30 days, 15+ from 6-month window, 5+ from 12-month window. 21 named frameworks indexed.
- **YouTube agent:** 25+ videos cataloged, 12 frameworks extracted, top 10 priority videos identified.
- **Web search agent:** 30+ sources cross-referenced. Background, business model, community reception, tool stack, OB1 project.

**4 deliverables in Owner's Inbox:**
- `nate-b-jones-research-brief.md` — who he is, credentials, business model
- `nate-b-jones-channel-research-brief.md` — YouTube themes, frameworks
- `nate-b-jones-substack-research-brief.md` — 20 articles, 21 frameworks
- `nate-b-jones-synthesis-and-recommendations.md` — action plan with priority matrix

**2. 10T System Upgrade — 3 Frameworks Implemented**

**Judge Protocol (GREEN/YELLOW/RED):**
- Added to `.10T/ORCHESTRATOR.md` and `CLAUDE.md`
- GREEN: read, research, draft, test → execute freely
- YELLOW: deploy to staging, modify configs, install packages, spend <$50 → 10T confirms
- RED: deploy to production, financial transactions, delete data, push to main, spend >$50 → Owner approval required
- Structural safety layer that complements the instructional 95% Rule

**Work-Shape Classification (BUILD/BUY/HIRE/WAIT):**
- Added to `.10T/ORCHESTRATOR.md` and `CLAUDE.md`
- Replaces automatic hiring pipeline trigger with 6-dimension scoring
- Dimensions: repetition, mistake cost, judgment, model trajectory, market maturity, specificity
- BUILD = new skill/MCP, BUY = existing tool, HIRE = new team member, WAIT = revisit later
- CLAUDE.md Rule #2 updated to reference this gate

**Two-Audience Rule + Callable Business Mandate:**
- Added to `.10T/ORCHESTRATOR.md` and `CLAUDE.md`
- All public-facing content must serve humans AND AI agents
- JSON-LD, structured data, machine-readable pricing required on new pages
- Long-term: AllTec service discovery API for programmatic booking
- Truth Layer: factual, verifiable claims over marketing copy

**3. Lido Document Processing Test**
- Tested on 2 supplier invoices (Coburn's + Wholesale Electric) from phone photos
- Successfully extracted all line items, PO#s, prices, quantities
- Ready for receipt automation pipeline integration

### Key decisions:
- Nate B Jones validated as credible source — subscribe to Substack
- Judge Protocol is structural, not instructional — both layers work together
- Work-Shape Classification prevents team bloat by filtering Build/Buy/Wait before Hire
- Two-Audience Rule applies to ALL new public-facing work going forward
- OB1 (Open Brain) evaluation queued for future session

### Files modified:
- MODIFIED: `.10T/ORCHESTRATOR.md` (Judge Protocol, Work-Shape Classification, Callable Business Mandate, updated workflow)
- MODIFIED: `CLAUDE.md` (Rule #2 updated, Judge Protocol summary, Two-Audience Rule, updated workflow)
- CREATED: `Owner's Inbox/nate-b-jones-research-brief.md`
- CREATED: `Owner's Inbox/nate-b-jones-channel-research-brief.md`
- CREATED: `Owner's Inbox/nate-b-jones-substack-research-brief.md`
- CREATED: `Owner's Inbox/nate-b-jones-synthesis-and-recommendations.md`
- MODIFIED: `.tracking/CURRENT.md`
- MODIFIED: `.tracking/PROGRESS.md`

### Resume Point (2026-05-19):
- **10T system upgrade COMPLETE** — Judge Protocol, Work-Shape Classification, Two-Audience Rule all live
- **Next from Nate research:** Evaluate OB1 against our state-persistence, audit MTM for JSON-LD, audit top skills for plugin upgrade
- **Play Store:** still in progress
- **Lido:** ready to integrate into receipt pipeline

---

## Session: 2026-05-18 — MTP Prep App: Bug Fixes + Play Store Submission

### Bug Fixes (deployed to Vercel)
1. **TTS reading arrows aloud** — Erica reported speaker button says "arrow"
   - Root cause: 28 cards had → characters in `back` field data
   - Fix: `speech.ts` — added `sanitizeForSpeech()` stripping Unicode arrows, bullets, dashes before `Speech.speak()`
   - All 3 speak functions (speakLatin, speakEnglish, speakAuto) go through sanitizer
2. **Flashcard content clipped/cut off** — Erica reported content not visible
   - Root cause: `cardContainer` had `overflow: hidden` + fixed `minHeight: 280`, clipping long translations
   - Fix: `FlashcardCard.tsx` — replaced `<View>` with `<ScrollView>` for both card faces, removed overflow:hidden, added maxHeight:340 scroll cap
3. Both fixes committed to master, pushed to GitHub, deployed to Vercel

### Vercel Deploy Fix
- Previous deploys failed because `.vercel/project.json` was only in `app/` subdirectory
- Vercel project "app" has `rootDirectory: app` configured — deploy must come from repo root
- Copied `.vercel/project.json` to repo root, added `.vercel/` to `.gitignore`
- GitHub auto-deploy already connected (manyTalents/ManyTalentsPrep)
- Future deploys: just `git push` and it auto-deploys

### Google Play Store Submission (in progress)
1. **Search Console verification** — DONE
   - HTML file method: `google20e8163a0dd7e380.html` in ManyTalentsMore `public/`
   - DNS TXT record: `google-site-verification=Vi_Tu9mgfDP8OfTFbOlDDNtHNYw18R2bkp6csmJed-s`
   - Ownership verified for `manytalentsmore.com`
2. **Developer account setup** — DONE
   - Account: ManyTalentMore.com (Personal), wit@manytalentsmore.com
   - Phone verified, identity verified
3. **App created** — `com.manytalents.testprep` / "ManyTalents Prep"
4. **Privacy policy** — deployed at https://manytalentsmore.com/privacy
5. **Data deletion page** — deployed at https://manytalentsmore.com/delete-data
6. **Content rating** — completed (all No — educational app, no violence/sharing/ads)
7. **Data safety** — in progress (email, app interactions, purchase history declared)
8. **Store settings** — Category: Education, email: wit@manytalentsmore.com, website: manytalentsmore.com
9. **Store listing text** — written (short: 79 chars, full: ~900 chars)

### GCP Access
- Granted wit@manytalentsmore.com Owner access to `alltec-receipt-ocr` GCP project
- Owner account: christoph3reverding@gmail.com (personal), alltecplumbing@gmail.com is company

### Still needed for Play Store:
- Store listing graphics (512x512 icon, 1024x500 feature graphic, phone/tablet screenshots)
- Upload production AAB (`npx eas-cli build --profile production --platform android`)
- Closed testing: 12 testers opted in for 14 days minimum
- Then apply for production access

### Files created/modified:
- MODIFIED: `test prep app ManyTalentsMore/app/src/services/speech.ts` (sanitizeForSpeech)
- MODIFIED: `test prep app ManyTalentsMore/app/src/components/FlashcardCard.tsx` (ScrollView, overflow fix)
- MODIFIED: `test prep app ManyTalentsMore/.gitignore` (added .vercel/)
- CREATED: `test prep app ManyTalentsMore/.vercel/project.json` (repo root link)
- CREATED: `ManyTalentsMore/public/google20e8163a0dd7e380.html` (Search Console verification)
- CREATED: `ManyTalentsMore/src/app/privacy/page.tsx` (privacy policy)
- CREATED: `ManyTalentsMore/src/app/delete-data/page.tsx` (data deletion request page)

### Resume Point (2026-05-18):
- **Play Store submission in progress** — finish data safety, store listing graphics, upload AAB
- **Closed testing gate:** 12 testers x 14 days before production access
- **Mobile Stripe still pending** — next feature session after Play Store setup

---

## Session: 2026-05-18 — Lido Doc Processing Test + Skill Review

### What was done:

**1. New Skills Review**
- Reviewed all newly installed skills from 2026-05-16/17 upgrade
- Notable additions: crypto analysis tools (batch-token-price-lookup, technical-analyzer, token-security-analyzer, trending-pools-analyzer), Expo/RN skills (expo-horizon, expo-ui-swiftui, expo-ui-jetpack-compose, rnrepo, radon-mcp), context-mode suite, Remotion video production, Lido document processing

**2. Lido Document Processing — TESTED SUCCESSFULLY**
- Tested `extract_file_data` on 2 real supplier invoices (phone photos, sideways orientation):
  1. **Coburn's Packing Slip** (05/14/2026) — PO 41035CE, 3 line items extracted perfectly
     - 7/8 x 50 LF Copper Refrig Tubing ($413.90), 3/8 x 50 LF ($122.74), Rubatex Insulation 48ft ($36.00)
     - Total: $635.63
  2. **Wholesale Electric Pick Ticket** (05/07/2026) — PO 41023CE, 1 line item
     - 16ea LED T8 4FT 18W 4000K ($6.512/ea = $104.20)
     - Total: $115.66
- Both extracted: supplier, ticket#, date, PO#, job name, item numbers, descriptions, quantities, units, unit prices, extended prices
- Handles rotated phone photos, multi-row invoices, mixed units (RL, FT, ea)
- Owner asked about automation — discussed 3 options: folder watch, mobile app button, batch end-of-day

### Key finding:
- Lido replaces need for custom OCR parsing in the AllTec receipt pipeline
- Currently using Google Cloud Vision OCR + custom receipt_parser.py
- Lido is higher-level: structured extraction with column definitions, not raw text OCR
- Could supplement or replace the existing OCR → LLM parser chain

### Resume Point (2026-05-19):
- **Lido proven** — ready to integrate into receipt pipeline
- **Decision needed:** supplement existing OCR chain or replace it with Lido
- **Play Store:** still in progress (data safety, graphics, AAB upload)
- **Mobile Stripe:** next feature session

---

## Session: 2026-05-17 — MTP Prep App: Flashcards + AI Intake System

### Flashcard System (completed)
- Generated weeks-06-10 flashcard batch (147 cards, was missing from crash)
- Merged all 6 batches into main JSON — 759 cards across 30 weeks
- Added "parsing" card type to FlashcardType, FlashcardCard, exam-config
- Fixed card flip toggle (was one-way only)
- Removed duplicate related-questions link overlapping card text
- All committed and pushed

### Vercel / Domain Fixes
- Fixed Vercel git builds for MTP app: Root Directory set to `app` in project settings
- Fixed www.manytalentsmore.com: moved from old `website` project to `manytalents-more` project
- All git-triggered builds now working

### APK Build + Distribution
- Built Android APK via EAS (preview profile) from non-OneDrive temp dir (OneDrive EPERM workaround)
- Uploaded to GitHub Releases: v1.0.0-preview
- Added "Download Android App" button on web auth screen

### Bitwarden Integration
- BW CLI already installed, used for secret retrieval
- Saved to BW: Supabase MTM Options Service Role, Supabase MTP Prep Service Role, Supabase Personal Access Token
- Pattern: pull keys from BW → set as Supabase Edge Function secrets

### AI Intake System (designed, built, deployed)
- **Design spec:** .tracking/specs/2026-05-17-ai-intake-system-design.md
- **Implementation plan:** .tracking/specs/2026-05-17-ai-intake-system.md (15 tasks)
- **Database:** trade_requests, trade_messages, trade_files tables + trade-uploads bucket
- **Edge functions:** ai-intake (Gemini 2.5 Flash-Lite conversation + phase gates) + charge-delivery
- **Client:** intakeApi service, useIntakeStore, IntakeAnimation, EmailVerifyGate, FileUploadButton, PaymentGate (Stripe.js web), request-trade.tsx rewrite
- **Stripe:** SetupIntent for charge-on-delivery ($79), card element on web
- **Email:** Design doc emailed to wit@manytalentsmore.com via Resend on intake completion
- **Secrets set in Supabase:** GEMINI_API_KEY, STRIPE_SECRET_KEY, RESEND_API_KEY
- **Legal brief:** Routed to Team Inbox for Legal hire
- **Tested live:** AI responded correctly to "Louisiana Master Plumber exam" test

### Pending
- Mobile Stripe card collection (web-only for now)
- Admin UI for delivery/charge workflow
- Feedback survey (Option C: end-of-intake + standalone)
- Legal disclaimer text from Legal team

### Resume Point (2026-05-18):
- **MTP intake system is LIVE** — monitor for first real customer
- **Legal disclaimers needed** — route through Berry hiring pipeline
- **Admin delivery UI** — Owner deciding approach (dashboard button vs DB webhook vs script)
- **Feedback survey** — next feature iteration

---

## Session Log — 2026-05-16/17 (Skill & MCP Upgrade)

### What was done:

**1. Full Skill Audit & Installation**
- Researched new Claude Code skills/MCPs since April 2026 (3 DATA agents in parallel)
- Installed 100 skills via `npx skills add` from 8 sources:
  - remotion-dev/skills (1) — video production
  - DojoCodingLabs/remotion-superpowers (2) — full video studio (5 MCPs, 13 commands)
  - software-mansion-labs/skills (5) — RN animations, gestures, architecture
  - expo/skills (13) — official Expo SDK 55/56 skills
  - callstackincubator/agent-skills (6) — RN perf, upgrading, GitHub
  - mksglu/claude-context-mode (7) — token management
  - coinpaprika/claude-marketplace (5) — free crypto data (no API key)
  - OpenAEC-Foundation/Frappe_Claude_Skill_Package (61) — Frappe v14-v16
- Git-cloned 6 reference libraries: video-use, video-toolkit, scientific-skills, health-tracking, openclaw-medical, healthcare-compliance

**2. MCP Server Buildout (37 total)**
- Wired 8 new local MCPs with Bitwarden bw-launch.sh pattern:
  - coinbase-trade (BW: 16a1e7d2) — direct Advanced Trade API
  - stripe (BW: ad1ab072) — payments via @stripe/mcp
  - elevenlabs (BW: b9ce0dc0) — TTS for video production
  - supabase-direct (BW: 110bd324) — direct DB access
  - google-maps (BW: 8ae9907e) — 18 tools (geocode, routes, places, distance matrix)
  - alphavantage (BW: 8336a217) — free market data
  - resend (BW: be1bd8c1) — transactional email
  - (coinbase-cdp via Composio remote)
- Added 4 project stdio MCPs: lido (document extraction), next-devtools (Vercel Next.js), postiz (social publishing), reap-video (video post-production)
- Added 22 remote MCPs (user config, zero tokens until invoked):
  - higgsfield, exa-search, deepwiki, manifold-markets, huggingface, aws-knowledge, pixa, stripe-remote, vercel, cloudflare-docs, neon, square, calendly, sentry, notion, canva, cloudinary, google-maps-remote, reap-video, zapier, linear, invideo
- Created 2 new BW entries: Google Maps API key, Alpha Vantage API key
- Created bw-launch wrappers (ready, no MCP package yet): Polygon (BW: 2959f28e), Tradier (BW: 6a9af359)

**3. Google Maps API Setup**
- Owner created Maps API key on GCP project alltec-receipt-ocr
- 7 APIs to enable: Routes, Geocoding, Places (New), Maps Static, Geolocation, Distance Matrix, Roads
- Maps Static API = HCP's address preview feature
- Geofencing runs on-device via expo-location (free, no Google API calls)

### Decisions made:
- Every secret in Bitwarden — no exceptions. bw-launch.sh wrapper pattern is standard.
- Skills installed via npx have activation guards — only load when file patterns match (~0.3% context overhead)
- Remote MCPs cost zero until invoked
- Google Maps covers: route optimization, address preview, geofencing support, travel time, nearest-tech dispatch

### Key ecosystem changes noted:
- obra/superpowers: 94K stars, in official Anthropic marketplace
- Skills format now cross-platform (Claude Code, Codex, Cursor, Gemini CLI, Windsurf)
- Expo SDK 55 shipped (New Architecture default, React 19.2)
- 15,134+ plugins indexed as of May 2026
- Claude Code Routines: scheduled cloud tasks (Pro: 15 runs/day)

### Files created/modified:
- CREATED: .10T/tools/stripe-mcp/bw-launch.sh
- CREATED: .10T/tools/elevenlabs-mcp/bw-launch.sh
- CREATED: .10T/tools/coinbase-mcp/bw-launch.sh
- CREATED: .10T/tools/supabase-mcp/bw-launch.sh
- CREATED: .10T/tools/google-maps-mcp/bw-launch.sh
- CREATED: .10T/tools/alphavantage-mcp/bw-launch.sh
- CREATED: .10T/tools/resend-mcp/bw-launch.sh
- CREATED: .10T/tools/polygon-mcp/bw-launch.sh (ready, no MCP pkg yet)
- CREATED: .10T/tools/tradier-mcp/bw-launch.sh (ready, no MCP pkg yet)
- MODIFIED: .mcp.json (3 → 11 servers)
- MODIFIED: .10T/SKILL_CATALOG.md (updated stats + Section 18: Installed & Active)
- CREATED: Owner's Inbox/skill-upgrade-report-2026-05-16.md
- BW CREATED: "Google Maps - API Key (AllTec)" (8ae9907e)
- BW CREATED: "Alpha Vantage - API Key (Free)" (8336a217)

### Resume Point (2026-05-17):
- **Skill/MCP upgrade COMPLETE — 37 MCPs, 100 skills, 6 reference libraries**
- **Google Maps APIs:** Owner needs to enable 7 APIs in GCP console, then restrict the key
- **Tabled:** ATTOM Property ($95/mo trial), Spike Health (paid API)
- **Next:** Resume project work

---

## Session Log — 2026-05-04 (The Machine Fix + Dashboard Wiring)

### What was done:

**1. The Machine — CDE Contract Sizing Bug FIXED**
- Root cause: grid computed fractional base sizes (e.g. "0.000297") but CDE products require integer contract counts (base_min_size=1, base_increment=1)
- Failed orders returned success=false without exception, storing empty order_ids
- `get_order("")` spammed 404 errors (40+ per tick, every 30 seconds)
- Additional: price rounding used wrong field (quote_increment vs price_increment)
- Additional: grid center used stale 24h VWAP instead of live mid-price

**Fixes applied (droplet + committed to GitHub):**
- `coinbase_client.py`: added `get_product_spec()` with 1hr cache (contract_size, base_increment, price_increment)
- `adaptive_grid.py`: `_compute_order_qty()` for integer contract counts, `_order_succeeded()` validates responses, `_round_price()` uses price_increment, grid centers on live mid-price
- `grid_scanner.py`: affordability filter rejects instruments where min contract cost > per-level budget
- `indicators.py`: `get_scanner_indicators()` returns min_contract_cost for filtering
- `main.py`: added `/api/v1/trades` endpoint (read-only, returns real grid fills)

**Results:**
- Bot running clean since 12:57 UTC — zero 404s, zero errors
- 32 real fills in first ~4 hours, +$16.92 realized PnL
- 5 real orders on Coinbase (ET-29MAY26-CDE + ETP-20DEC30-CDE)
- Grid auto-grew from 2 to 18 active levels per instrument

**2. Crypto Dashboard — WIRED TO LIVE DATA**
- `money-api.ts` rewritten to pull real data from Machine API:
  - stats: real PnL, trade count, win rate from /api/v1/trades
  - balance: includes unrealized PnL from grid
  - trades: shows recent real grid fills
  - strategies: rounded allocations, real win rates
  - risk: live equity with grid PnL
- Fixed pre-existing build error (kingdom-contact route crashing on missing RESEND_API_KEY)
- Deployed to Vercel

**3. Previous Session Error Identified**
- Last night's session told Owner "go sleep, bot is fine" based only on `grep "grid fill logged"`
- Never checked for errors — 404s were already happening alongside paper fills since 2:28 AM
- Bot was trading on paper (auto-promoted after 355K bogus paper fills) but failing silently on real orders

### Commits:
- `1125df0` on veoe-trade/main: "fix: CDE contract sizing, price precision, and order validation"
- `d7d7430` on manytalents-more/master: "fix: wire crypto dashboard to live Machine data"

### Key learnings (for CDE products):
- `price_increment` is the REAL tick size (not `quote_increment`)
- `base_increment=1`, `base_min_size=1` → orders must be integer contract counts
- BIT=0.01 BTC/contract (~$800), ET=0.1 ETH/contract (~$235), SOL=5 SOL/contract (~$420)
- Scanner must filter by affordability before selecting instruments
- Always validate order responses (`success: false` does NOT throw an exception)

### Resume Point (2026-05-04):
- **The Machine:** LIVE and trading, monitor for consistent fills over next few days
- **Dashboard:** Deployed, verify it renders correctly on next visit
- **Perps bug:** Still open (GitHub #125), check periodically
- **ET-31JUL26-CDE:** No 1H candle data yet (non-critical, skips gracefully)

---

---

## Session: 2026-05-19 → 2026-05-24 — 10T System Overhaul (Multi-Day)

### Research Phase (2026-05-19)
- 3 parallel DATA agents researched Nate B Jones (291K YouTube, 152K+ Substack)
- 40+ Substack articles, 25+ YouTube videos, 30+ web sources analyzed
- 4 deliverables: research brief, channel brief, substack brief, synthesis+recommendations
- OB1 evaluated → DEFERRED (our .tracking/ system works at current scale)
- MTM + AllTec websites audited for agent-readability (both invisible to AI agents)
- 12 Agentic Harness Primitives mapped: 6 COVERED, 5 PARTIAL, 1 MISSING
- Skill plugin audit: IDENTITY files are proto-plugins, need eval criteria + failure modes

### Round 1: Nate B Jones Frameworks Implemented (2026-05-19)
- **Judge Protocol** (GREEN/YELLOW/RED) — ORCHESTRATOR.md + CLAUDE.md
- **Work-Shape Classification** (BUILD/BUY/HIRE/WAIT gate) — replaces auto-hiring
- **Two-Audience Rule + Callable Business Mandate** — agent-era marketing

### Round 2: Self-Identified Improvements (2026-05-23)
- **3 Lifecycle Hooks** — judge_protocol.py (Bash), judge_write_guard.py (Write/Edit), audit_logger.py (PostToolUse)
- **All 30 IDENTITY files upgraded** — eval criteria + known failure modes (2 batch agents)
- **PROGRESS.md compressed** — 1,048 → 454 lines, archive at .tracking/archives/
- **MCP Profiles** — 37 MCPs scoped across 7 domains in .10T/MCP_PROFILES.md
- **Decision Audit Log** — .tracking/AUDIT.md, auto-logged by PostToolUse hook

### Grok Expert Panel Review (2026-05-23)
- 7-reviewer panel assembled (AI architect, security, org design, trading, ERP, product, SRE)
- Score: "Advanced for a 1-person operation. 6/12 primitives COVERED."
- Top finding: structural enforcement gap — hooks only caught Bash, not MCP/Write
- Full report provided by Owner from Grok project

### Round 3: Grok Review Response (2026-05-24)
- **Expanded hooks** — Write/Edit guard (blocks .env, prod paths, settings, REGISTRY) + auto audit logger
- **RED-A/RED-B split** — Owner-absent escalation path (RED-A waits forever, RED-B 10T approves after 2hr)
- **Trading kill switches DEPLOYED** to droplet 104.131.176.130:
  - safety_gates.py created, 7 config constants added, scheduler job every 30s
  - 5 gates: equity floor ($500), daily loss cap ($100), max positions (10), API circuit breaker, heartbeat kill
  - Pre-flight check wired into grid tick — blocks if halted/blocked
  - Backups: /root/config.py.bak.killswitch, /root/main.py.bak.killswitch
- **Relevant Lessons Injector** built — .10T/tools/lessons_injector.py
  - Keyword + recency search across LESSONS.md, STANDARDS.md, failure modes, SOLUTIONS_LOG
  - Auto-surfaces top 3-5 relevant lessons during task delegation
  - ORCHESTRATOR.md + CLAUDE.md updated to make this a formal delegation step
  - LESSONS_TEMPLATE.md created for standardizing member lesson files

### Other Work This Session
- Kraken portfolio spreadsheet .bat fixed (Coinbase auth → Kraken public API, WAXL token mapping fixed)
- Lido document processing tested on 2 supplier invoices
- Grok review instructions prepared (7 expert personas + file list)

### Files Created
- `.10T/hooks/judge_protocol.py` — PreToolUse Bash guard (7 RED triggers)
- `.10T/hooks/judge_write_guard.py` — PreToolUse Write/Edit guard (5 path patterns)
- `.10T/hooks/audit_logger.py` — PostToolUse auto-logger for AUDIT.md
- `.10T/hooks/INSTALL.md` — Hook installation guide
- `.10T/MCP_PROFILES.md` — Per-domain MCP access profiles
- `.10T/tools/safety_gates.py` — Trading kill switch design (local copy)
- `.10T/tools/lessons_injector.py` — Relevant Lessons Injector
- `.tracking/AUDIT.md` — Decision audit log
- `.tracking/archives/PROGRESS-archive-2026-Q1Q2.md` — Compressed old sessions
- `Team/LESSONS_TEMPLATE.md` — Standard template for member lessons
- `Owner's Inbox/nate-b-jones-*.md` (4 research briefs)
- `Owner's Inbox/ob1-vs-tracking-evaluation.md`
- `Owner's Inbox/12-primitives-gap-analysis.md`
- `Owner's Inbox/skill-plugin-upgrade-audit.md`
- `Owner's Inbox/alltecplumbing-ai-readability-audit.md`
- `Owner's Inbox/mtm-ai-agent-readability-audit.md`
- `Owner's Inbox/trading-kill-switches-design.md`
- `Owner's Inbox/grok-review-instructions.md`
- `Owner's Inbox/grok-review-file-list.md`
- Settings: `.claude/projects/.../settings.json` (3 hooks configured)

### Files Modified
- `CLAUDE.md` — Rule #2 (Work-Shape), Judge Protocol, Two-Audience Rule, AUDIT.md in tracking table, RED-A/RED-B, Lessons Injection
- `.10T/ORCHESTRATOR.md` — Judge Protocol, Work-Shape Classification, Callable Business, Structural Enforcement, Capability Modulation, Owner-Absent Escalation, PROGRESS Compression SOP, Lessons Injection
- `STANDARDS.md` — referenced but not directly modified this session
- All 30 `Team/*/IDENTITY.md` files — Eval Criteria + Known Failure Modes added
- `.tracking/PROGRESS.md` — compressed + this session log
- `.tracking/CURRENT.md` — updated with all active work
- Droplet: `/opt/the-machine/src/safety_gates.py` (created), `config.py` (safety constants), `main.py` (safety gates wired)

### Resume Point (2026-05-24)
- **10T system overhaul COMPLETE** — 3 rounds of improvements all live
- **Kill switches running** on droplet, verify no false halts over next 24h
- **VEOE kill switches** — design ready, deploy in separate session
- **AllTec website** — JSON-LD structured data ready to paste into Squarespace (or migrate to custom)
- **MTM website** — needs entity-correct structured data (platform, not plumber)
- **Remaining from Grok:** encode Shield's risk rules as hard gates in VEOE execution layer
- **Play Store:** still pending (graphics, AAB, closed testing)
- **FC worker cache:** still blocking receipt pipeline + invite system
