# PKA — CURRENT

## Status
MTP Prep app: Play Store submission in progress. Bug fixes deployed. AI intake system live.

## Active Work
- **MTP Prep App — PLAY STORE SUBMISSION IN PROGRESS (2026-05-18)**
  - Google Play Console: app created as `com.manytalents.testprep`, "ManyTalents Prep"
  - Search Console ownership verified (HTML file + DNS TXT)
  - Privacy policy deployed: https://manytalentsmore.com/privacy
  - Data deletion page deployed: https://manytalentsmore.com/delete-data
  - App setup checklist: content rating, data safety, store settings — being filled out now
  - Store listing text written (short + full description), needs graphics (icon, feature graphic, screenshots)
  - **REMAINING:** finish store listing graphics, upload AAB, closed testing (12 testers, 14 days), then production
  - Bug fixes deployed to Vercel (2026-05-18): TTS arrow sanitization + flashcard content overflow scroll
- **AllTec / MTM Manager — FIELD INVOICE MVP DEPLOYED (2026-05-30)**
  - Mobile audit: 6 blockers fixed (login URL, clock errors, timer lock, schedule errors, noon bug, QR reset)
  - Invoice MVP live: generate from job data, cash/check payment, email receipt (PDF), SMS receipt (Twilio)
  - Backend: MTM Invoice Settings doctype + invoice.py + receipt_delivery.py deployed + migrated
  - Mobile: InvoiceScreen + API client + JobDetailScreen hooks (INVOICE button + finish prompt)
  - Tested: generate_invoice returns correct data against live job #35774
  - Phase 2 remaining: Stripe Tap to Pay, Strike Lightning, custom PDF, web admin settings
  - Self-hosted ERPNext live at erp.manytalentsmore.com (134.199.198.83)
  - FC cancelled / decommissioned
- **MTM Manager Mobile:** Preview APK built. Play Store AAB ready. Google Play Console verification pending.
  - Preview: https://expo.dev/accounts/manytalentsmore/projects/many-talents-manager/builds/9f3b2d07-7c7e-427c-8c2e-52a94a13461c
- **MTM Website:** Pointed at self-hosted (erp.manytalentsmore.com). New API creds in BW. Magic links need MTM Invite doctype migration.
- **The Machine V2 — DISTRESS FIX DEPLOYED (2026-05-30):** ZEC grid LIVE, SHORT at $538.60.
  - Distress fix: $5 min loss gate + 2h cooldown (was firing on $0.55-$3 dips = -$14.20 wasted)
  - Regime filters: ADX 35 + MOM 5% active (deployed 2026-05-28)
  - Kill switches: 5 independent safety gates every 30s
  - Monitoring: watch distress trigger frequency with new thresholds
- **VEOE — EXIT OPTIMIZATION DEPLOYED (2026-05-30):** Paper trading, 0 open positions, ready for Monday.
  - 60% profit target deployed (backtest: +255% P&L, $967→$3,431 on 50 trades, 48% WR)
  - Time-aware trail: 25% early (first 2 days), 12% normal, 8% near expiry
  - Options bar cache: backtest re-runs in 30s vs 105 min (498 contracts cached)
  - Catalyst gate tested but NOT deployed (non-catalyst trades outperformed)
  - 5 stale orphan positions cleaned up (May 20 single_leg bug)
  - Colab session (Claude+Grok, 2026-05-28→30): 56 files exchanged, archived to AI-Collab/archive/
- **Colab System — v4 protocol (2026-05-30):** Major overhaul in v1 session (23 rounds, Claude+Grok).
  - v3 multi-instance: session subdirectories, SESSIONS.md index, watcher v3
  - v4 protocol: PENDING.md turn signal, 3-layer Grok persistence (Task Scheduler + self-poller + auto-detection), Chris Prompts tracker, write verification, mutual completion gate, session setup checklist
  - First autonomous AI-to-AI response achieved via self-poller mechanism
  - Written into COLAB-OPERATING-NOTES.md v4 — future sessions start pre-configured
- **Providence Buildium Replacement — APP SCAFFOLDED (2026-05-30):**
  - `providence_pm` Frappe app: 5 chunks, 47 files, 2,274+ lines
  - Chunk 1: Data model (Property, Unit, Tenant, Owner, Lease Agreement + Property Owner child table)
  - Chunk 2: Lease lifecycle (Subscription billing, daily auto-expiry, date-driven status)
  - Chunk 3: Rent collection (late fee automation, Owner Statement report, payment API)
  - Chunk 4: Maintenance (PM Work Order, PM Vendor, tenant notifications, billable charges)
  - Chunk 5: Tenant + Owner self-service portals with API layer
  - All reviewed by Grok in colab v1. Commits: d80f317, 5cfa88f, 9a2b014, 4cca5fb
  - Next: discovery meeting with Erica, then deploy to self-hosted ERPNext
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
7. Upload production AAB
8. Closed testing — 12 testers, 14 days minimum
9. Apply for production access

## Still Pending
- Mobile Stripe (`@stripe/stripe-react-native`) — $79 charge on mobile
- Legal disclaimers from Legal team (brief in Team Inbox)
- Admin delivery workflow (dashboard button or DB webhook)
- Feedback survey (Option C — end-of-intake + standalone)

## Known Issue (Minor)
cancel_all() silently swallows cancel errors then clears internal levels list.
