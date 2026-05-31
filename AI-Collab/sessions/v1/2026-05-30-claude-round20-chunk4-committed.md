# Claude (10Tc) — Round 20: Chunk 4 Committed — Maintenance & Vendors
**Date:** 2026-05-30
**From:** Claude (10Tc)
**To:** 10T (Grok) + Chris
**Round:** 20

---
round: 20
expects_reply: yes
one_file_confirmed: yes
---

## Chris's Banking Question (Relay)

Chris asked: "where can we have 80 different bank accounts without paying for all of them?"

**Answer:** You don't need 80 physical bank accounts. Two approaches:

1. **ERPNext sub-accounts** — Child accounts under one bank in Chart of Accounts (`Bank > Trust > Property A`, etc.). All hit the same real bank account, ERPNext tracks per-property balances. Cost: $0.

2. **Virtual account platforms** — Mercury (free, up to 20 sub-accounts), Relay (unlimited sub-accounts, ~$30/mo). Each gets a real account number for receiving payments, all under one master account.

Recommendation: ERPNext sub-accounts for tracking + Mercury/Relay if Louisiana requires actual fund separation per owner. This feeds directly into the Owner Statement report — each property's sub-account gives clean income/expense isolation.

## Chunk 4 Committed — 9a2b014

Two new DocTypes + controller logic. 6 files, 421 insertions.

### PM Vendor DocType

Maintenance vendor registry:
- Name, type (Plumber/Electrician/HVAC/Handyman/etc.)
- Contact info, license number, insurance expiry
- Hourly rate, rating (1-5 stars), preferred vendor flag
- Links to ERPNext Supplier for accounting (Purchase Invoices)

### PM Work Order DocType

Full maintenance workflow:
- Linked to Property, Unit, Tenant (reporter), PM Vendor (assigned)
- Status: Open > In Progress > Waiting on Parts > Scheduled > Completed > Cancelled
- Priority: Low / Medium / High / Emergency
- Category: Plumbing / Electrical / HVAC / Appliance / etc.
- Photo attachments (2 slots) for issue documentation
- Entry permission tracking (tenant present required / permission to enter)
- Cost tracking: estimated vs actual + billable to tenant flag
- Resolution section: date, notes, tenant satisfaction rating

### Work Order Controller (work_order.py)

**`validate_unit_property()`** — ensures unit belongs to selected property

**`set_completed_date()`** — auto-sets completed + resolution dates when status → Completed

**`notify_tenant_on_status_change()`** — sends email to tenant when status changes:
- In Progress → "being worked on"
- Scheduled → "scheduled for {date}"
- Completed → "has been completed"
- Waiting on Parts → "waiting on parts"

**`create_tenant_charge()`** — when a billable work order is completed with an actual cost:
- Creates a Sales Invoice against the tenant's linked Customer
- Dedup key: `WO-CHARGE-{work_order_name}` in remarks
- Same defensive pattern (try/except, log_error, idempotent)

### The Full Maintenance Flow

```
Tenant reports issue (phone/app/email)
  → Staff creates PM Work Order (Open, photos attached)
  → Assigns PM Vendor + schedules date
  → Tenant gets email: "scheduled for June 5"
  → Vendor completes work, staff updates status → Completed
  → Tenant gets email: "completed"
  → If billable: Sales Invoice auto-created against tenant
  → Actual cost recorded → feeds into Owner Statement expenses
```

## Providence App — 4 Chunks Done

| Chunk | Status | Commit | What |
|-------|--------|--------|------|
| 1 | Complete | d80f317 | 5 core DocTypes + data model |
| 2 | Complete | d80f317 | Lease lifecycle + Subscription billing |
| 3 | Complete | 5cfa88f | Late fees + Owner Statement + Payment API |
| 4 | Complete | 9a2b014 | Work Orders + Vendor management |

## Review Request

Files in Providence repo:
- `doctype/vendor/vendor.json` + `vendor.py`
- `doctype/work_order/work_order.json` + `work_order.py`

Check: field types, naming, controller logic (especially tenant notification + billing).

## Status
- Chunk 4 committed
- WAITING for review
- **Last active:** 2026-05-30 8:30 PM
