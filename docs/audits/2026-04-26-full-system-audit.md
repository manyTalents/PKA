# MTM Full System Audit — Team Conference Report

**Date:** 2026-04-26
**Reviewers:** Swift (Mobile), Glass (Web), Forge (Backend APIs), Forge (OCR/Matching Pipeline), Live API Tester
**Scope:** 100% of codebase — mobile app, web app, backend APIs, OCR pipeline, email intake, matching, sync, auth

---

## Executive Summary

| Area | Critical | Important | Minor | Improvements |
|------|----------|-----------|-------|-------------|
| Mobile App (Swift) | 4 | 7 | 6 | 5 |
| Web App (Glass) | 7 | 14 | 14 | 8 |
| Backend APIs (Forge) | 4 | 13 | 15 | 5 |
| OCR/Matching Pipeline (Forge) | 1 | 14 | 5 | 0 |
| Live API Tests | 1 | 0 | 0 | 0 |
| **TOTAL** | **17** | **48** | **40** | **18** |

After cross-review and deduplication: **15 unique critical issues, 42 unique important issues.**

---

## CRITICAL ISSUES — Fix First

### Backend (Production Correctness)

| # | File | Issue | Impact |
|---|------|-------|--------|
| **B1** | `core/sku_matcher.py:139` | `score_match` import doesn't exist in `item_classifier.py` | Layer 2.5 matching **completely non-functional** — silent ImportError on every receipt |
| **B2** | `api/tech_utils.py:835` | References `"HCP Settings"` (doesn't exist) — should be `"HCP Replacement Settings"` | Pricebook search **throws 500** on every call |
| **B3** | `api/tech_utils.py:~989,1016,1029` | `get_daily_restock`, `mark_restock_pulled`, `reject_restock` missing `@frappe.whitelist()` | Mobile restock **403 Forbidden** — entire restock workflow broken |
| **B4** | `api/email_receipt.py:116` | Wrong doctype `"HCP Receipt Item"` (should be `"HCP Receipt Parsed Item"`) | Receipt item counts **always show 0** |
| **B5** | `core/hcp_sync.py:217-218` | Direct child table list reassignment (`doc.services = [filtered]`) | **Duplicate line items** accumulate on every HCP sync |

### Mobile App

| # | File | Issue | Impact |
|---|------|-------|--------|
| **M1** | `components/job/LimboSection.tsx` | Sends `ocr_quantity` instead of `dispatch_quantity` in partial dispatch | Materials **over-dispatched** — wrong inventory |
| **M2** | `api/jobs.ts`, `limbo.ts`, `inventory.ts`, `restock.ts`, `frappe.ts` | `callMethod()` duplicated in 5 files with no `AbortController` timeout | App **hangs indefinitely** on bad network — 5 files affected |
| **M3** | `screens/LoginScreen.tsx` | `login()` called before connection test — sets `isLoggedIn=true` first | **Race condition** — app briefly navigates to authenticated screens before snapping back |

### Web App (Security)

| # | File | Issue | Impact |
|---|------|-------|--------|
| **W1** | `money/options/rec/[id]/page.tsx` | Trade details blurred via CSS only — full data in DOM | **Paid content bypassed** — anyone can read gated data via DevTools |
| **W2** | `api/options/execute/route.ts`, `close/`, `adjust-stop/` | No auth check on trade execution routes | **Anyone can execute/close/adjust trades** without authentication |
| **W3** | `api/options/recommendations/route.ts` | Daily run limit not atomic — race condition | **Subscribers bypass limit** with concurrent requests |
| **W4** | `api/options/webhook/route.ts` | No Stripe webhook idempotency check | **Duplicate purchases** on webhook retry |
| **W5** | `money/options/page.tsx` | `handleRunClick` with `isRealRun=true` never calls `analyze()` | **Real analysis runs are a no-op** — core paid feature broken |
| **W6** | `manager/events/page.tsx` | Missing authentication check | **Unauthenticated access** to manager events page |
| **W7** | `api/money/verify/route.ts` | Plain string equality password check (timing attack vulnerable) | **Money dashboard password extractable** via timing oracle |

### Pipeline

| # | File | Issue | Impact |
|---|------|-------|--------|
| **P1** | `core/sku_matcher.py:178-195` | Supplier name not normalized through `SUPPLIER_MAP` in `_build_supplier_code_map` | Layer 1 **returns nothing** for Coburn's — learned mappings never used |

---

## IMPORTANT ISSUES — Fix Before Production

### Backend

| # | File | Issue |
|---|------|-------|
| B6 | `api/match_review.py` | No role check on write endpoints — any tech can modify pricebook matches |
| B7 | `api/tech_utils.py` | `send_to_check` and `approve_for_invoice` have no permission check |
| B8 | `core/ocr_engine.py` | Receipt stuck "Processed" on parse failure — no rollback to "Failed" |
| B9 | `core/llm_parser.py` | No timeout on Claude API call — worker blocks indefinitely |
| B10 | `core/stock_processor.py` | Financial document creation not in try/except — job submit can fail halfway |
| B11 | `core/email_poller.py` | Missing `frappe.db.commit()` in background job — receipts can vanish |
| B12 | `api/limbo.py:115` | `get_global_limbo` SQL has no LIMIT — loads entire table into memory |
| B13 | `core/hcp_sync.py` | `_resolve_hcp_uuid` makes 10 sequential HCP API calls — blocks worker 30-60s |
| B14 | `api/receipt_ocr.py` | `debug_ocr` accessible to any user — can bill Vision API + read receipts |
| B15 | `api/restock.py` | Stock Entry + pull list marking not atomic — can double-pull |
| B16 | `core/price_monitor.py` | `_notify_office_price_change` email failure aborts entire nightly run |
| B17 | `core/price_monitor.py:136` | Reads from `"HCP Integration Settings"` — wrong doctype, auto-update enabled by default |
| B18 | `core/sku_matcher.py:96` | Partial supplier name LIKE matching pulls wrong supplier codes |

### Pipeline

| # | File | Issue |
|---|------|-------|
| P2 | `core/receipt_parser.py:125` | Coburn's PO regex fires on product codes (`45005808 EA`) — wrong job link |
| P3 | `core/receipt_parser.py:38` | `"Lows"` supplier name not matched in `SUPPLIER_TRADES` — trade filter bypassed |
| P4 | `core/receipt_parser.py:131` | `price_unit_re` only matches 2-letter units — `BOX`, `SET`, `ROL` lost |
| P5 | `core/item_classifier.py:72` | `"90"` in description returns `"elbow"` even for `"90 amp breaker"` |
| P6 | `core/item_classifier.py:232` | `_is_real_size` filters out pipe lengths (`"10 ft"`) — all pipes look identical |
| P7 | `core/email_receipt_processor.py:163` | `receipt_date` set to `now_datetime()` — not actual receipt date |
| P8 | `core/email_receipt_processor.py:254` | Lowe's body receipts skip dedup entirely |
| P9 | `core/ocr_engine.py` | `receipt_date` never updated from OCR parsed data — all dates wrong |
| P10 | `core/constants.py:159` | `WES` receipts not trade-filtered — electrical items can match plumbing |
| P11 | `core/receipt_dedup.py:90` | Zero-total receipts match each other — false dedup on OCR failures |
| P12 | `core/llm_parser.py:88` | No system prompt — Claude may hallucinate items on bad OCR input |
| P13 | `core/llm_parser.py:165` | `_extract_product_codes` doesn't filter date strings — inflates coverage |
| P14 | `core/sku_matcher.py:138` | Layer 2.5 iterates ALL items × ALL parsed items — O(n*m) performance |
| P15 | `store/queue.ts` | Mobile `notes` field dropped — never sent to server |

### Mobile

| # | File | Issue |
|---|------|-------|
| M4 | `theme/colors.ts` | `getStatusColor` missing Needs Check / Invoiced / Canceled — invisible badges |
| M5 | `screens/HomeScreen.tsx` | Restock badge reads `summary.pulled` not `summary.pending` — wrong count |
| M6 | `components/inventory/DispatchItemCard.tsx` | "My Truck" chip silent failure when no van assigned |
| M7 | `components/inventory/ReceiptDetailScreen.tsx` | `handleDispatchSingle` silent return when no job linked |
| M8 | `screens/JobDetailScreen.tsx:514` | Dynamic `require()` inside callback — breaks production builds |
| M9 | `store/queue.ts` | OCR poll loop has no cancellation — runs through backgrounding |
| M10 | `components/inventory/WarehouseDetailScreen.tsx` | `require()` in async — breaks New Architecture |

### Web

| # | File | Issue |
|---|------|-------|
| W8 | `lib/money-api.ts` | 4 crypto endpoints are hardcoded stubs — dashboard shows fake data |
| W9 | `money/veoe/page.tsx` | `Promise.all` not `allSettled` — one failed endpoint crashes whole page |
| W10 | `manager/dashboard/page.tsx` | Search bar `hidden sm:block` — no mobile search |
| W11 | `manager/jobs/page.tsx` | No pagination on job list — degrades with scale |
| W12 | `manager/admin/requests/page.tsx` | Infinite spinner on auth failure — no error state |
| W13 | `manager/inventory/page.tsx:2380` | ESLint suppression hiding stale closure in keyboard shortcuts |
| W14 | `manager/components/EventPanel.tsx` | No focus trap, no aria-modal — accessibility failure |

---

## WHAT'S WORKING WELL

### Mobile (Swift's assessment)
- **Offline architecture** — SQLite queue with FIFO replay and NetInfo auto-sync is production-grade
- **Auth store** — expo-secure-store with URL normalization is clean and correct
- **Job color system** — diagonal LinearGradient split for multi-state jobs is sophisticated
- **LaborRateSection** — 5-second debounced timer with 0.5hr boundary detection is elegant
- **ErrorBoundary** — class-based with backend logging, better than most RN apps
- **FinishJobChecklist** — server-persisted state with clockOut + status + HCP note atomically

### Web (Glass's assessment)
- **Magic-link auth** — complete and working, with invite token auto-redemption
- **Admin flows** — invite, onboard, access request, approval chain all functional
- **Pricebook editor** — inline editing, bulk markup, pagination, debounced save
- **Inventory matches tab** — most sophisticated UI in the app (bulk approve, keyboard shortcuts, new part flow)
- **Stripe webhook verification** — correctly uses raw body

### Backend (Forge's assessment)
- **Receipt processing pipeline** — ambitious and mostly working (OCR → parse → match → dedup → dispatch)
- **Event logging system** — comprehensive structured logging throughout
- **Invoice creation** — proper Sales Invoice lifecycle with email send
- **Restock computation** — rollover detection, per-truck grouping

### Pipeline (Forge's assessment)
- **Item classifier module** — 500+ LOC, synonym tables, structured attribute parsing — excellent design, just not wired in correctly
- **Dedup fingerprinting** — receipt-number + composite scoring is clever
- **LLM parser design** — training-tool-not-dependency approach is sound architecture

---

## TOP 10 FIXES BY IMPACT (Recommended Order)

| Priority | Issue | Fix | Time |
|----------|-------|-----|------|
| 1 | **B2** — `"HCP Settings"` wrong doctype | Change to `"HCP Replacement Settings"` | 1 min |
| 2 | **B3** — Restock missing `@frappe.whitelist()` | Add decorators to 3 functions + 2 aliases | 2 min |
| 3 | **B1** — `score_match` import broken | Change to `search_attrs.match_score(item_attrs)` | 2 min |
| 4 | **P1** — Supplier name not normalized | Add `SUPPLIER_MAP.get()` in `_build_supplier_code_map` | 2 min |
| 5 | **M1** — Wrong quantity in limbo dispatch | Change `ocr_quantity` to `dispatch_quantity` | 1 min |
| 6 | **B4** — Wrong doctype in email_receipt | Change `"HCP Receipt Item"` to `"HCP Receipt Parsed Item"` | 1 min |
| 7 | **B5** — Child table list reassignment | Use proper Frappe pattern (clear + reappend) | 10 min |
| 8 | **W1+W2** — Options security (CSS blur + no auth on execute) | Server-side data gating + auth middleware | 30 min |
| 9 | **P9** — receipt_date never updated from OCR | Add `receipt.receipt_date = parsed.get("receipt_date")` | 2 min |
| 10 | **B9** — LLM no timeout | Add `timeout=30.0` to Claude API call | 1 min |

**Fixes 1-6 are one-liners that fix critical production bugs.** They should be deployed immediately.

---

## IMPROVEMENT INSIGHTS (Do Not Implement — For Future Reference)

1. **API client consolidation (Mobile)** — 6 duplicate `callMethod()` implementations → single `client.ts` import
2. **Remove unused deps (Web)** — `react-query`, `zustand`, `recharts` = 356KB dead weight
3. **Shared search component** — `PricebookSearchModal` and `MaterialSearch` use different endpoints, violating the shared search rule
4. **Photo upload async** — `classify_photo` Vision API call blocks the mobile upload response 5-15s
5. **Inventory page uses raw hex** — should use Tailwind theme tokens like rest of app
6. **Event cleanup limit** — 1000 rows/day can't keep up at scale; increase to 10,000+
7. **N+1 queries** — `_get_running_timesheet`, `get_weekly_hours`, `_resolve_buyer_name` all load too many docs
8. **Bulk operations** — `bulk_update_markup`, `_refresh_group_metadata` do one DB call per item
9. **Global error boundary (Web)** — no React ErrorBoundary, uncaught render error = white screen
10. **expo-image-picker plugin** — missing from `app.json`, iOS gallery will fail in App Store build

---

## LIVE API TEST RESULTS

All 22 authenticated endpoints returned **401 — AuthenticationError**. The API key `3ac4c8f5530ec6b:57394de8aa94140` has been rotated. Web app and Frappe Cloud site are healthy (HTTP 200).

**Action needed:** Update API credentials in Bitwarden and re-run the full test suite post-fix.

---

## CONFERENCE CONSENSUS

All reviewers agree on the following:

1. **The system is architecturally sound.** The pipeline design (OCR → parse → match → dedup → dispatch), offline-first mobile architecture, and magic-link auth are well-designed.

2. **Critical bugs are concentrated in wiring, not design.** Wrong doctype names, missing decorators, broken imports — these are typo-level fixes with outsized impact. The designs are right; the connections are wrong.

3. **Security issues in the /money/options section need immediate attention** before any paid launch. CSS-only blur gating, unauthenticated trade execution routes, and timing-attack-vulnerable password checks are serious.

4. **The item_classifier is the most underutilized asset.** 500+ lines of sophisticated matching logic, never called. Fixing the import and wiring it correctly would be the single biggest accuracy improvement to the receipt pipeline.

5. **Supplier name normalization is the #1 matching fix.** Layer 1 (exact supplier code lookup) returns nothing for Coburn's because `"Coburn's"` doesn't match `"Coburn Supply"` in the LIKE query. One line of code unlocks all learned mappings.

6. **The top 6 fixes are all one-liners.** Total time to fix: ~10 minutes. Total impact: unblocks restock, pricebook search, matching pipeline, dispatch quantities, receipt counts, and item classification.
