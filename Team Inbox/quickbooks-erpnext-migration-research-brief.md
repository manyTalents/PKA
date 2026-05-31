# Research Brief: QuickBooks → ERPNext Migration + Multi-Entity Setup

**From:** 10T
**To:** DATA (Senior Researcher)
**Date:** 2026-05-31
**Priority:** High — next major expense elimination on roadmap

---

## Assignment

Research and deliver a comprehensive migration plan for replacing QuickBooks with ERPNext accounting for AllTec Plumbing, plus scoping the multi-entity setup for all Everding family businesses on the existing self-hosted ERPNext instance (erp.manytalentsmore.com, 134.199.198.83).

## Context

- ERPNext is already live and self-hosted with AllTec data (8,233 jobs, 1,023 customers, 96 receipts)
- AllTec already creates Sales Invoices (field invoice system), Payment Entries (payment API), and Purchase Invoices (receipt pipeline) in ERPNext
- QuickBooks is currently duplicating what ERPNext already does — this is the redundancy to eliminate
- Multiple family entities need to be consolidated on one ERPNext instance

## Entities to Set Up

| Entity | Type | Status |
|--------|------|--------|
| AllTec Plumbing LLC | Service company | Already in ERPNext |
| Providence Real Estate LLC | Property management (300-400 units) | providence_pm app built, not yet deployed |
| Everding Family Trust | Trust | Needs setup |
| [TBD] 501(c)(3) | Nonprofit | Needs setup |
| RE Holding LLC(s) | Real estate holding companies (multiple) | Needs setup |

## Research Deliverables

### Part 1: QuickBooks Migration Path
1. What data needs to come from QB? (Chart of Accounts, open invoices, customer/vendor lists, bank transactions, historical transactions for tax continuity)
2. QB export formats available (CSV, QBX, IIF) and which ERPNext can import
3. Step-by-step migration procedure (what order to import, how to reconcile opening balances)
4. Bank feed options post-migration (Plaid integration vs manual CSV import vs OFX)
5. What QB features AllTec currently uses that need ERPNext equivalents
6. Recommended cutover strategy (parallel run period? clean-cut on a fiscal boundary?)
7. Louisiana-specific tax/reporting requirements that QB handles — verify ERPNext covers them

### Part 2: Multi-Entity ERPNext Setup
1. ERPNext Company record configuration for each entity type:
   - Standard LLC (AllTec, Providence)
   - Trust — any special accounting treatment? Chart of Accounts differences?
   - 501(c)(3) nonprofit — fund accounting? donor tracking? IRS reporting (Form 990)?
   - RE Holding LLCs — asset-focused accounting, depreciation, property valuation
2. Chart of Accounts templates — should each entity use a standard template or custom?
3. Inter-company transactions — how do they work in ERPNext? (AllTec does plumbing for a Providence property, trust distributes to entities, etc.)
4. Consolidated reporting — can Chris see a combined view across all entities?
5. User permissions — how to restrict who sees what (Erica sees Providence only, Maddie sees AllTec payroll only, Chris sees everything)
6. Tax ID / EIN management per entity
7. 1099 generation for vendors across entities

### Part 3: Cost/Risk Analysis
1. Current QuickBooks cost (plan tier, per-entity fees, add-ons)
2. Any QB features that ERPNext genuinely cannot replace (and workarounds)
3. Migration risks and rollback plan
4. Timeline estimate for the migration

## Constraints
- This is for the FAMILY instance (erp.manytalentsmore.com) — NOT the MTM SaaS platform
- ERPNext is self-hosted Docker on DigitalOcean ($28/mo droplet)
- Chris does not code — all setup must be doable via UI or scripted by the AI team
- The 95% rule applies — ask clarifying questions before delivering

## Delivery
Put the completed research at: `PKA/Owner's Inbox/QuickBooks-ERPNext-Migration-Research.md`
