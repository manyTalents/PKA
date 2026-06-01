# mtm_payroll — Module Specification (Future)

**Date:** 2026-05-31
**Authors:** Claude (10Tc) + Grok (10Tg) + Chris (Owner)
**Status:** Approved phased approach — Phase 0 now (Gusto), Phase 1 when 5-10 platform clients

---

## Core Philosophy

Start by owning the experience, not the full compliance burden. Use Gusto as the compliance engine initially. Gradually increase ownership where it creates clear platform advantage and margin.

## Current Recommendation

**AllTec (now):** Use Gusto (~$46/mo). Not worth the build or risk for 2 employees.

Build a custom integration layer (Phase 1 of mtm_payroll) so payroll data flows cleanly into ERPNext with proper entity handling, cost centers, and reporting.

## Phased Roadmap

| Phase | Name | Scope | Trigger | Risk |
|-------|------|-------|---------|------|
| 0 | Gusto + Basic Integration | Manual journal entries from Gusto data | Now | Very Low |
| 1 | Smart Integration Layer | Automated rich Journal Entries, entity splitting, cost centers, reporting | 5-10 platform clients | Low |
| 2 | Calculation Assistance | Own tax engine + AI monitoring (with human QC gate) | 20-50+ clients | Medium |
| 3 | Payments & Deposits | ACH via Moov/Dwolla + EFTPS automation | After Phase 2 stable | Medium-High |
| 4 | Full Filings | W-2 generation + electronic filing | High volume + E&O insurance | High |
| 5 | White-label / Embedded | Full mtm_payroll as standalone product | Platform maturity | High |

## Phase 1 Spec: Smart Integration Layer

### Objective
When a client runs payroll in Gusto, the data automatically appears in their MTM/ERPNext instance as clean, properly allocated Journal Entries with full multi-entity and fund accounting support.

### Key Features
- **Automated Journal Entry Creation** — Pull from Gusto API, create multi-line JEs, split across entities, apply Cost Centers for fund accounting, support Principal/Income tagging
- **Employee & Pay History Sync** — Basic history visible inside MTM, linked to ERPNext Employee records
- **Reporting** — Payroll expense by entity, cost center, job. P&L impact. CPA-ready exports.
- **Permissions** — Chris = everything, Erica = Providence only, Maddie = AllTec payroll, CPA = read-only
- **Audit** — Human approval before JE submission, full audit trail, error logging

### Technical Approach
- New Frappe app: `mtm_payroll`
- DocTypes: Payroll Run Import, Payroll Journal Mapping, Entity Allocation Rule
- Gusto API + webhooks
- Strong idempotency (prevent duplicate entries)

## Why Not Build Full Payroll Now

| Component | Looks Simple | Reality |
|-----------|-------------|---------|
| Tax Tables | Public data + AI scraping | IRS Pub 15-T has multiple methods, bonus rules, YTD reconciliation, multi-W4 jobs. One parsing error = client penalties. |
| Direct Deposit (ACH) | API with Moov/Dwolla | Returns handling, prenotification, fraud patterns, bank verification, NACHA compliance |
| W-2 / e-filing | Generate PDFs | Strict schemas, error correction workflows, deadlines. Operational overhead at scale. |
| Tax Deposits | Calculate + EFTPS | Deposit frequency varies, multi-state = matrix, LaTAP automation isn't trivial |
| Support | E&O insurance | Employee disputes, IRS notices, garnishments — this is where DIY attempts die |

"It's just math" underestimates how often the rules have exceptions and how much support payroll generates even when the math is correct.

## Platform Economics (Why This Matters at Scale)

- Gusto charges $40/mo + $6/employee per client
- 5-employee plumbing company pays Gusto $70/mo
- MTM payroll add-on at $15/mo with ~$0.50/mo cost = pure margin
- At 1,000 clients: $15K/mo additional revenue vs ~$500/mo cost
- Eliminates the #1 reason a client needs a service outside the platform

## Key Risks

| Risk | Mitigation |
|------|-----------|
| Incorrect tax calculations | Keep in Gusto during Phase 1-2. Human QC gate in later phases. |
| IRS/state penalties to clients | Clear disclaimers + E&O insurance before owning calculations |
| Support burden | Start integration-only. Add dedicated support before Phase 3+ |
| Scope creep | Strict phase gates. Only advance after previous phase is stable + profitable |

## Open Decisions

1. Gusto vs OnPay for API depth?
2. Real-time vs nightly batch journal entries?
3. Integration in main ERPNext or separate MTM app?
4. What client volume triggers Phase 2?
5. When to get E&O insurance quotes?
