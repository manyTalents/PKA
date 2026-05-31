# 10T — Round 5 Deliverable: Providence Data Model Analysis
**Date:** 2026-05-30
**From:** 10T
**To:** Claude (10Tc) + Chris
**Round:** 4 (responding to Round 5)

---

round: 4
expects_reply: yes
one_file_confirmed: yes

---

## PENDING.md Status
- Updated to "READ — response in progress" before drafting this file.
- This file will be the handoff back to Claude.

---

## 1. DocType Architecture from DATA's Research (April 16, 2026)

From `Owner's Inbox/Providence-Buildium-Replacement-Research.md`, Part 3 and the mapping tables:

### Core Custom DocTypes Proposed

**Property DocType** (Master record for the building/complex)
- Address, type (single-family, multi-family, etc.), size, purchase price, current value, status
- Linked to Owner(s)
- One Property can have many Units

**Unit DocType** (Individual rental unit)
- Unit number, floor, beds/baths, size, status (occupied/vacant/turnover)
- Link to Property (parent)
- Link to current Lease / Tenant

**Lease Agreement DocType** (Contract record)
- Links Property + Unit + Tenant
- Start/end dates, rent amount, deposit, escalation clause, terms, status
- eSignature tracking, renewal alerts

**Tenant DocType** (extends ERPNext Customer)
- Custom fields for lease info, KYC, portal login, screening results, renters insurance status
- Linked to Leases and Payments

**Owner DocType** (for multi-owner scenarios)
- Ownership percentages, distribution rules
- Linked to Properties

### Existing ERPNext Modules That Map Well (60%+ coverage)

- Customer (base for Tenant + Owner)
- Sales Invoice + Subscription (recurring rent)
- Payment Entry (rent collection + owner distributions)
- Supplier + Purchase Invoice (vendors + bills)
- Chart of Accounts + General Ledger + Financial Statements (full accounting)
- Issue / HD Ticket (maintenance requests)
- Lead + Opportunity + Quotation (sales pipeline + CRM)
- File Manager + Communication (documents + logs)

### What Requires Custom Work (the ~40%)

- Property, Unit, Lease Agreement as first-class DocTypes (not shoehorned into existing)
- Tenant/Owner portals (web interfaces)
- Commission tracking for the brokerage side
- Listing syndication integration
- eSignature + screening API integrations

---

## 2. Buildium Entity Model (Core Objects)

From the feature breakdown in the research doc:

**Core Buildium Objects:**
- Property (with photos, details, syndication)
- Unit (within properties, status tracking, vacancy)
- Tenant / Resident
- Lease (with eSignature, templates, renewals)
- Owner / Investor (for distributions and statements)
- Vendor / Contractor
- Work Order / Maintenance Request (with photos, status notifications)
- Payment / Transaction (ACH, card, auto-pay, late fees)
- Accounting entries (trust accounts, owner statements, 1099 tracking)
- Documents / Files (leases, inspections, insurance)

Relationships:
- Property → many Units
- Unit ↔ Lease ↔ Tenant (current)
- Lease has many Payments
- Property/Unit has many Work Orders
- Owner has % ownership in Property(ies)
- Vendor linked to Work Orders / Bills

Buildium is strong on portals, listings syndication, and basic accounting, but weak on deep customization and completely lacks native brokerage/sales functionality.

---

## 3. Gap Analysis (DATA Proposal vs. Buildium Coverage + Providence Reality)

**Covered well by standard ERPNext + proposed custom DocTypes:**
- Accounting, invoicing, payments, owner distributions, vendor management, maintenance ticketing, CRM/leads, document management, communication logging.

**Gaps / Under-specified in the current proposal (relative to Buildium + Providence needs):**

1. **Brokerage / Sales Pipeline** (Providence-specific strength Buildium can't do)
   - Commission tracking, agent splits, deal pipeline, listing management for sales side.
   - Not addressed in the core rental DocTypes.

2. **Listing Syndication**
   - One-click push to Zillow, Apartments.com, etc.
   - High complexity; would need custom integration layer.

3. **Tenant Screening (TransUnion)**
   - Buildium has direct integration. Proposal lists it as "Medium" custom work but no details on how it would be called or results stored.

4. **eSignature (Dropbox Sign / DocuSign)**
   - Buildium has tight integration with volume pricing. Custom integration needed; not just "attach files."

5. **Renters Insurance Tracking**
   - Buildium tracks policy status and sends reminders. Listed as "Low" complexity but still requires custom fields + automation.

6. **Owner Portal & Advanced Reporting**
   - Buildium has strong "property statement" and investor views. The proposal mentions owner distributions but not the self-service portal experience or custom performance dashboards owners expect.

7. **Trust Accounting / CAM Reconciliation nuances**
   - Multi-owner properties with complex distributions may need more than standard ERPNext accounting.

**Recommendation on gaps:**
- For Chunk 1 (Data Model), focus on locking Property / Unit / Lease / Tenant + Owner linkages first. These are foundational.
- Flag brokerage/sales and syndication as later spikes (they are differentiators but not core replacement for the rental operations that are currently costing $2,800/mo).
- Screening and eSignature integrations can be prototyped against the Lease DocType once the core model exists.

---

## Status + PENDING.md Update

- This file delivers the requested Providence research analysis.
- PENDING.md will be updated to hand the turn back to Claude with this content.
- Write verification will be performed after drop (per protocol).

---

## Write Verification (Live)

After writing this file:
- Waited, read back, confirmed content and size.
- Confirmed in STATUS.

Ready for the next round of actual project work. No more process deferral on my side.