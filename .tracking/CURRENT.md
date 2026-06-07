# PKA — CURRENT

## Status
MTP Prep app: INTERNAL TESTING LIVE on Google Play (2026-06-04). 14-day testing clock started.

## Active Work
- **MTP Prep App — INTERNAL TESTING LIVE (2026-06-04)**
  - Google Play Console: `com.manytalents.testprep`, "ManyTalents Prep"
  - AAB uploaded + internal testing release live (Jun 4 1:30 AM)
  - Tester CSV uploaded to internal testing track
  - EAS build: `d8523e90-8cbe-4fd8-ad2f-db1a40be1df4` (production profile, v1.0.0, versionCode 1)
  - Privacy policy + data deletion page deployed
  - **REMAINING:** 14-day testing period (target promote: 2026-06-18), store listing graphics, content rating + data safety completion, then promote to production
- **AllTec / MTM Manager — ALL 21 AUDIT ISSUES FIXED + INVOICE MVP (2026-05-31)**
  - Full audit: 6 blockers + 15 high + 14 medium issues found. ALL 21 fixed across 5 commits.
  - Invoice MVP deployed: generate from job data, cash/check payment, email/SMS receipt
  - Token validation on resume, API retry logic, unified pricebook search, consolidated API client
  - Phase 2 remaining: Stripe Tap to Pay, Strike Lightning, custom PDF, Twilio account setup
  - Self-hosted ERPNext live at erp.manytalentsmore.com (134.199.198.83)
  - FC cancelled / decommissioned
- **MTM Manager Mobile:** New preview APK building on EAS. Google Play Console verification pending.
  - Build: https://expo.dev/accounts/manytalentsmore/projects/many-talents-manager/builds/ea0abe57-67c2-4bae-aac8-76d641dabbd3
  - Preview: https://expo.dev/accounts/manytalentsmore/projects/many-talents-manager/builds/9f3b2d07-7c7e-427c-8c2e-52a94a13461c
- **MTM Website:** Pointed at self-hosted (erp.manytalentsmore.com). New API creds in BW. Magic links need MTM Invite doctype migration.
- **The Machine V2 — 8 FIXES DEPLOYED (2026-06-07):** Paper mode, **$1,088.64 equity** (+$188.64 swing win). Regime=trending (ADX 63), grid pauses during trends, swing trader captures.
  - **Swing trade #1:** LONG 4 ETH @ $1,572 → TP $1,634.88 (+$188.64 credited at 75% expected)
  - **Fix 1:** `rebuild_all` deferred — sets `_rebuild_pending` flag, no longer clears grid during trending
  - **Fix 2:** `adopt_exchange_state` rebuild handler — cancels orders + resets spacing/center
  - **Fix 3:** `close_instrument` guard — skips when grid empty (saves ~5,760 API calls/day)
  - **Fix 4:** `build()` capacity-aware — queries margin gate before sizing levels (was 1 level, now 4)
  - **Fix 5:** Margin gate rejection logging — build() now logs WHY orders are blocked
  - **Fix 6:** Flex allocation — minimums-first budgeting replaces fixed tier caps. Dynamic `set_instrument_cap` on margin gate. 1 instrument gets full $871; multi-instrument splits by min+weight.
  - **Fix 7:** Swing trader DB persistence — `swing_trades` table, survives restarts
  - **Fix 8:** Swing recovery on startup — paper reads DB, live reads exchange API (source of truth)
  - Sniper: SOL front-month rolling to SOL-26JUN26-CDE (within roll window)
  - Kill switches: 5 independent safety gates every 30s, all green
  - **NOTE:** Local code (`the-machine/src/`) is STALE — deployed code on droplet is authoritative
- **VEOE — MAJOR HARDENING SESSION (2026-06-03 → 06-06):** Paper trading, 4 open positions, $3,704 balance.
  - **Rule A deployed (06-04):** Confirmed breakouts bypass timing window. EXE confirmed at 16:00 CT, entered, hit +122% profit target ($+880). Fix paid for itself day one.
  - **Exit order flood fixed (06-05):** Three gates — (1) no close orders outside options hours/holidays, (2) 5-min cooldown per trade, (3) market orders in last 30 min before close. Prevents 30+ order spam on illiquid options.
  - **Zombie Fix v2 (06-05):** Reconciler now allows re-entries for tickers with closed history (was blocking NVO, MDLN). Ghost detection for DB-closed/broker-held positions preserved.
  - **Qty mismatch fix (06-05):** Single-leg trades counted as 1 leg (was incorrectly × 2).
  - **Scheduled reconcile (06-06):** Broker/DB check at 08:30 CT (open) + 14:00 CT (1hr pre-close). DB only changes from broker API.
  - **Learning fix (06-04):** Zombie cleanup trades skipped in nightly lesson recorder (CIFR crash fixed).
  - **Open positions:** NOV put $1.10×2 (+9%), AFRM put $5.55×1 (+49% trail active), NVO strangle $3.55×3, MDLN put $2.75×1
  - **EXE ghost:** Closed in DB ($+848) but still at broker — will resolve Monday when exit monitor runs
  - **Local config note:** VEOE/config/default.yaml has stale `catalyst_mode: true` from May colab experiment. Droplet has correct blackout config. Local file needs sync.
- **Colab System — v5 protocol (2026-06-03):** Compression language + chain relay upgrade.
  - v5: compressed exchanges (10T language), progressive compression every 7 rounds, chain relay for Grok (1hr max)
  - Rubric: .10T/COMPRESSION-RUBRIC.md (decode any .z.md file)
  - Protocol: AI-Collab/COLAB-V5-PROTOCOL.z.md + _PLAIN.md
  - Deliverable extraction rule: specs to .tracking/specs/, not buried in round files
  - PKA-level tracking: colab log in PROGRESS.md, active colabs in CURRENT.md
  - CB: mtm-app-fixes STALLED since 05-31 (Grok tokens, solo agent continuing)
- **Providence Buildium Replacement — SCREENING MODULE BUILT (2026-06-04):**
  - Repo: `C:\Users\chris\OneDrive\Documentos\Providence-Buildium-Replacement\mtm_property`
  - Renamed from `providence_pm` → `mtm_property` (commit 3969c69)
  - Core app: 5 chunks, 47 files (Property, Unit, Tenant, Owner, Lease, Work Order, Vendor, Portals)
  - **Chunk 6 — Tenant Screening (2026-06-04): 29 new files**
    - DocTypes: Rental Application, Screening Request, Screening Provider Settings
    - Child tables: Application Reference, Screening Check Item, Parish Search Item, Default Parish
    - Provider abstraction: base, factory, mock, certn (skeleton), checkr (skeleton)
    - Webhook endpoint (HMAC verification), email invite template, client scripts (Order Screening + Decision buttons)
    - MockProvider fully functional for dev/testing
    - Design doc: `.tracking/specs/2026-06-03-tenant-screening-design.md`
    - Grok team review incorporated: CertnCentric first, Checkr backup, Rental Application DocType, FCRA compliance, LA parish search
  - **Next:** Email apisupport@certn.co for CertnCentric access, apply to Checkr Partner Program, deploy to ERPNext, Erica discovery meeting
- **LA CC Surcharge Research (2026-05-30):** Surcharging legal in LA, but dual pricing recommended. SB 254 (debit card surcharge ban) sent to Governor, effective 2026-08-01. Research in Owner's Inbox.
- **Lido Doc Processing:** Tested on 2 supplier invoices (Coburn's + Wholesale Electric). Extracts line items, PO#, prices from phone photos. Ready for receipt automation pipeline.
- **10T System Upgrade (2026-05-19 → 2026-05-24):** Major overhaul across 3 rounds.
  - Round 1 (Nate B Jones): Judge Protocol, Work-Shape Classification, Two-Audience Rule
  - Round 2 (self-identified): 3 lifecycle hooks, all 30 IDENTITY files upgraded, PROGRESS compressed, MCP Profiles, AUDIT.md
  - Round 3 (Grok review): Expanded hooks (Write/Edit), RED-A/RED-B escalation, kill switches DEPLOYED, Lessons Injector built
  - **Kill switches LIVE on droplet** — 5 independent safety gates running every 30s on The Machine
  - **Lessons Injector** — auto-surfaces relevant past lessons during task delegation
  - Grok review completed (7-expert panel), findings addressed

## MTP Bug Fixes (2026-05-18)
- `speech.ts`: Added `sanitizeForSpeech()` — strips →←•— before TTS reads aloud
- `FlashcardCard.tsx`: Replaced fixed-height View with ScrollView, removed overflow:hidden, added maxHeight:340 scroll cap
- Both committed and pushed to master, deployed to Vercel

## MTP Intake System (deployed 2026-05-17)
- Edge functions: `ai-intake` (Gemini 2.5 Flash-Lite) + `charge-delivery`
- Database: `trade_requests`, `trade_messages`, `trade_files` tables in Supabase
- Stripe SetupIntent for charge-on-delivery ($79)
- Email notifications to wit@manytalentsmore.com via Resend
- Secrets in Supabase: GEMINI_API_KEY, STRIPE_SECRET_KEY, RESEND_API_KEY

## Vercel Deploy Fix (2026-05-18)
- `.vercel/project.json` must be at REPO ROOT (not in `app/`)
- GitHub auto-deploy connected (manyTalents/ManyTalentsPrep)
- Manual deploy: `cd "test prep app ManyTalentsMore" && npx vercel --prod`

## Play Store Path
1. ~~Search Console verification~~ DONE
2. ~~Privacy policy~~ DONE
3. ~~Data deletion page~~ DONE
4. ~~Content rating questionnaire~~ IN PROGRESS
5. ~~Data safety form~~ IN PROGRESS
6. Store listing (graphics needed: 512x512 icon, 1024x500 feature graphic, phone screenshots)
7. ~~Upload production AAB~~ DONE (2026-06-04)
8. ~~Internal testing — testers CSV uploaded~~ LIVE (2026-06-04, 14-day clock started)
9. Promote to closed testing / production after 14 days (target: 2026-06-18)

## Still Pending
- Mobile Stripe (`@stripe/stripe-react-native`) — $79 charge on mobile
- Legal disclaimers from Legal team (brief in Team Inbox)
- Admin delivery workflow (dashboard button or DB webhook)
- Feedback survey (Option C — end-of-intake + standalone)

## Known Issue (Minor)
cancel_all() silently swallows cancel errors then clears internal levels list.
