# Claude (10Tc) — Round 21: Chunk 5 — Portals Committed
**Date:** 2026-05-30
**From:** Claude (10Tc)
**To:** 10T (Grok) + Chris
**Round:** 21

---
round: 21
expects_reply: yes
one_file_confirmed: yes
---

## Chunk 5 Committed — 4cca5fb

7 files, 633 insertions. Both tenant and owner self-service portals.

### Tenant Portal (`/tenant_portal`)

What tenants see when they log in:
- **Lease info** — property, unit, rent, dates
- **Balance due** — real-time outstanding amount, color-coded (red = owes, green = paid up)
- **Maintenance requests** — submit new (subject, category, priority, entry permission) + view history with status
- **Payment history** — all payments with date, amount, method, reference

### Owner Portal (`/owner_portal`)

What property owners see:
- **Property overview** — all their properties with occupancy rates, unit counts, ownership %
- **Owner statement** — date range picker, generates the same data as the Script Report but in the portal UI. Shows income, late fees, expenses, net, ownership %, distribution amount per property. Total distribution at bottom.

### Portal API (`portal_api.py`)

Clean separation — all portal logic goes through whitelisted API endpoints:

**Tenant APIs:**
- `get_tenant_lease()` — active lease for logged-in user
- `get_tenant_balance()` — outstanding invoices total
- `get_tenant_work_orders()` — maintenance request history
- `get_tenant_payments()` — payment history
- `submit_maintenance_request()` — creates PM Work Order from portal

**Owner APIs:**
- `get_owner_properties()` — all properties with occupancy data
- `get_owner_statement_data()` — reuses the Owner Statement report logic

**Auth:** User-to-tenant/owner mapping via email match. Guest users get login prompt.

### The Full Providence PM App — 5 Chunks

| Chunk | What | Commit | Files |
|-------|------|--------|-------|
| 1 | Data Model | d80f317 | 26 |
| 2 | Lease Lifecycle | d80f317 | (included above) |
| 3 | Rent Collection | 5cfa88f | 8 |
| 4 | Maintenance | 9a2b014 | 6 |
| 5 | Portals | 4cca5fb | 7 |
| **Total** | | | **47 files, 2,274+ lines** |

This is a functional Buildium replacement covering: properties, units, tenants, owners, leases, billing, late fees, owner statements, payment recording, maintenance work orders, vendor management, and self-service portals for both tenants and owners.

## Review Request

- `portal_api.py` — auth pattern, data exposure, maintenance request creation
- `www/tenant_portal/` — HTML template, JS API calls, form handling
- `www/owner_portal/` — HTML template, JS statement generation

## Status
- Chunk 5 committed
- 5 chunks of the Providence app done in one session
- WAITING for review
- **Last active:** 2026-05-30 8:50 PM
