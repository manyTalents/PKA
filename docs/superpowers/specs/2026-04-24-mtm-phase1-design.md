# MTM Phase 1 — Consolidated Design Spec

**Date:** 2026-04-24
**Status:** Draft
**Owners:** Glass (web), Swift (mobile), Forge (backend)

**Goal:** Ship Phase 1 — techs use MTM daily for jobs + inventory; office has dashboard, customers, invoicing, estimates, service plans. Get to Phase 2 (retire HCP invoicing).

**Tech Stack:**
- Web: Next.js 15, React 19, Tailwind, custom components (no shadcn/ui)
- Mobile: React Native / Expo
- Backend: Frappe Cloud (hcp_replacement app), ERPNext
- API: Frappe REST + whitelisted methods in `tech_utils`, `auth_utils`, `inventory`

**Site:** https://manytalentsmore.com/manager/dashboard
**Frappe:** https://manytalentsmore.v.frappe.cloud

---

## Module A: Dashboard Widgets & Presets

### What exists
Pipeline cards (Finished/Needs Checked/To Invoice/Pending Payment/Paid Today), global search bar, "Coming Soon" placeholders for Today's Activity and Inventory Alerts.

### What to build

**10-widget library**, each draggable/pinnable:

| # | Widget | Type | Period | Data source |
|---|--------|------|--------|-------------|
| 1 | Average Job Size | Bar chart | Weekly | `get_job_stats` (new) |
| 2 | Job Revenue | Bar chart | Weekly | `get_job_stats` |
| 3 | Job Count | Bar chart | Weekly | `get_job_stats` |
| 4 | Team Leaderboard | Horiz bars per tech | Weekly | `get_team_stats` (new) |
| 5 | Clocked vs Billable | Grouped bars per tech | Weekly | `get_team_stats` |
| 6 | A/R Aging | 4 cards (0-30/31-60/61-90/91+) | Live | `get_ar_aging` (new) |
| 7 | Needs Check Queue | List + count | Live | `get_jobs_by_status("needs_checked")` |
| 8 | Need Estimate Queue | List + count | Live | `get_jobs_needing_estimate` (new) |
| 9 | Service Plans Due | List + count | Live | `get_plans_due` (new) |
| 10 | Jobs Images | Grid thumbs | Recent | `get_recent_job_images` (new) |

**Role presets (starting layout, user can customize):**
- **Office (Zach):** Jobs Images, Job Count, Needs Check, A/R Aging
- **Operations (Adam):** Avg Job Size, Job Revenue, Team Leaderboard, Need Estimate
- **Management (Chris):** Team Leaderboard, Clocked vs Billable, A/R Aging, Job Revenue, Service Plans Due

**Widget behaviors:**
- Period selector in header: Weekly / Monthly / YTD / Custom
- Every bar/card/row is clickable — drills to filtered job/invoice list
- Default to $ (money), not time — time as tooltip/secondary
- Pin/unpin/reorder persisted to localStorage per user

**Implementation:**
- New file: `src/app/manager/dashboard/widgets/` — one component per widget
- Widget registry: `src/app/manager/dashboard/widget-registry.ts`
- Layout state: localStorage key `mtm_dashboard_layout`
- Charts: `recharts` (already in deps)
- New backend endpoints for aggregation (6 new whitelisted methods)

---

## Module B: A/R Aging Dashboard

### What to build

Four cards on dashboard (also standalone `/manager/invoices` page):

| Bucket | Colour | Behavior |
|--------|--------|----------|
| 0-30 days | White (default), green on resend | Click → invoice list |
| 31-60 days | White (default), green on resend | Click → invoice list |
| 61-90 days | White (default), green on resend | Click → invoice list |
| 91+ days | Dark red outline always | Click → invoice list + Collections flag |

**Colour model (Chris's decision):**
- Initial: white/neutral
- On Resend click: turns green ("I've chased this")
- On bucket transition (e.g., 30→31): resets to white
- 91+ cards keep dark red outline regardless
- Every resend logged in Activity Log with timestamp + user

**Invoice list page (`/manager/invoices`):**
- Columns: Invoice #, Customer, Amount, Days Outstanding, Status, Last Resend
- Filter by bucket (click from dashboard card)
- One-click Resend button per invoice
- Drill to job detail

**Backend:** `get_ar_aging` returns:
```python
{
  "buckets": [
    {"label": "0-30", "count": 12, "total": 4500.00, "invoices": [...]},
    {"label": "31-60", "count": 3, "total": 1200.00, "invoices": [...]},
    ...
  ]
}
```

Aging calculated from `sent_at` timestamp on Sales Invoice (custom field if not exists).

---

## Module C: Estimates Module

### What to build

**New pages:**
- `/manager/estimates` — list view
- `/manager/estimates/[name]` — estimate detail
- `/manager/estimates/new?job=JOB-NAME` — create estimate from job
- `/approve/estimate/[token]` — customer-facing approve/decline (no auth)

**Data model (new doctypes):**

**MTM Estimate:**
- `name` (auto), `estimate_number` (display), `customer`, `address`
- `linked_job`, `status` (Draft/Sent/Approved/Declined/Expired)
- `approval_mode`: "single" (one option only) or "multiple" (bundle)
- `sent_at`, `expires_at`, `approval_token`
- Child table: `MTM Estimate Option`

**MTM Estimate Option:**
- `option_index` (1, 2, 3...), `name_label` (e.g., "16 SEER AC Replacement")
- `status` (Pending/Approved/Declined) — independent per option
- `line_items` (child table: description, qty, rate, amount)
- `total_price`, `financing_available`

**Estimates list (`/manager/estimates`):**
- Columns: Estimate #, Customer, Status, Total, Created, Linked Job
- Filter chips: All / Draft / Sent / Approved / Declined

**Estimate detail (`/manager/estimates/[name]`):**
- Header: estimate #, customer, status, linked job link
- Options displayed as tabs or accordion
- Each option: name, line items table, total, status badge
- Actions: Send to Customer, Mark Expired

**Estimate on Job Detail:**
- New block on `/manager/jobs/[name]` showing linked estimates
- Button: "Create Estimate" → navigates to new estimate form

**Need-Estimate Tab:**
- Dashboard widget (#8): count + list of jobs flagged "Needs Estimate"
- Tech marks job in mobile → `estimate_required` field (already exists)
- Office: click → job detail → create estimate

**Customer-facing page (`/approve/estimate/[token]`):**
- No login required, tokenized URL
- Shows: company branding, estimate options with line items + totals
- Per option: Approve / Decline / Finance buttons
- Approvals update estimate status via API callback
- Token: single-use, 30-day expiry

---

## Module D: Service Plans Module

### What to build

**New pages:**
- `/manager/service-plans` — list view
- `/manager/service-plans/templates` — manage templates
- `/manager/service-plans/[name]` — plan instance detail
- `/approve/plan/[token]` — customer-facing approve/decline

**Data model (new doctypes):**

**MTM Service Plan Template:**
- `name_label`, `description` (customer-facing)
- `service_interval` (months), `visits_per_year`
- `price`, `billing_cadence` (per visit / annual / semi-annual)
- `contract_term` ("Indefinite" default)
- `checklist_items` (child table: item text, required flag)
- `stacking_rule` ("no_stack" default)
- `alert_lead_days` (default 14)

**6 templates to seed:**

| Template | Price | Cadence | Visits/yr |
|----------|-------|---------|-----------|
| HVAC Service Plan Pro | $75 | 6 months | 2 |
| Electrical Service Plan Pro | $95 | annual | 1 |
| Plumbing Service Plan Pro | $95 | annual | 1 |
| Generac Full | $495 | annual | 2 |
| Generac Light | $75 | 6 months | 2 |
| Tankless | $625 | annual | 1 |

**MTM Service Plan Instance:**
- `template`, `customer`, `address` (bound to ADDRESS, not customer)
- `status` (Draft/Sent/Active/Cancelled)
- `next_service_date`, `last_service_date`
- `approval_token`, `approved_at`

**Service Plans list (`/manager/service-plans`):**
- Columns: Plan Name, Customer, Address, Status, Next Service, Price
- Filter: Active / Due Soon / All

**Alert & Work Order:**
- When `next_service_date` is within `alert_lead_days`: surface in "Service Plans Due" widget
- Office clicks "Generate Work Order" → creates HCP Job from template
- Auto-advances `next_service_date` by `service_interval`

**Customer-facing (`/approve/plan/[token]`):**
- Plan name, covered services, rate, term
- Approve / Decline buttons
- Same token mechanism as estimates

---

## Module E: Customers Module

### What to build

**New pages:**
- `/manager/customers` — list view
- `/manager/customers/[name]` — customer profile

**Customers list (`/manager/customers`):**
- Columns: Name, Addresses Count, Total Owed, Lifetime Value, Last Job Date
- Search bar (name, phone, address)
- Click → profile

**Customer profile (`/manager/customers/[name]`):**
- **Identity:** name, phone(s), email, billing address, created date
- **Addresses:** list of all addresses owned (key for property managers)
- **Job history:** all jobs across all addresses, filterable by status
- **Financials:** total owed (unpaid invoices), lifetime value (all invoices)
- **Upcoming:** scheduled jobs, active service plans
- **Actions:** Create Job, Create Estimate, Send Invoice

**Cross-surface context (already partially built):**
- On job detail: collapsible panel showing prior jobs at this address + other addresses
- Backend: `get_customer_history` exists, may need `get_customer_profile` (new)

**Backend endpoints (new):**
- `get_customer_list(query, page)` — paginated, searchable
- `get_customer_profile(customer)` — full profile with addresses, jobs, invoices, plans

---

## Module F: Completion Checklist (Mobile)

### What to build

**On job detail screen in mobile app:**
- Checklist section appears based on job type
- Items pre-populated from template
- Each item: checkbox + label
- Required items must be checked before "Finish Job" is allowed
- "Pause" allowed without checklist
- Checklist events logged to Activity Log

**3 initial templates:**
1. AC Install
2. Water Heater Replace
3. HVAC Service Call

**Data model:**
- `HCP Job Checklist Item` child table on HCP Job
- Fields: `item_text`, `required`, `checked`, `checked_at`, `checked_by`
- Template stored on `HCP Replacement Settings` or separate `MTM Checklist Template` doctype

**Backend:**
- `get_checklist_template(job_type)` — returns items for the job type
- `update_checklist_item(job_name, item_idx, checked)` — toggle + timestamp
- Modify `update_job_status` to block "Completed" if required items unchecked

---

## Module G: Restock / Pull List

### What exists
Mobile: restock tab exists with pull/reject. Web: basic restock tab in inventory page.

### What to improve

**Web restock view (`/manager/inventory` Restock tab):**
- Group by tech/truck: "Adam's Truck needs: 3x 3/4 copper elbow, 2x 1/2 ball valve..."
- Source tracking: which job consumed each part
- Mark as Pulled button per item (Zach pulls from shelf)
- Batch "Pull All for [Truck]" button
- Rollover indicator: items not pulled from yesterday (purple highlight)

**Backend:**
- `get_daily_restock` exists — may need grouping by truck
- `mark_restock_pulled` exists
- No new endpoints needed, possibly enhancements

---

## Module H: Job Intake Form Polish

### What exists
`/manager/jobs/new` with customer search, address, location details, job description, trade checkboxes, schedule, priority, labor hours/rate.

### What to improve

Per features inventory §3.5:
- **Vacant toggle** — exists but verify it saves correctly
- **Customer "Create New" as explicit action** — prevent accidental duplicates
- **Occupant name/phone** — separate from customer phone (property management)
- **Urgency toggle** — sets red card colour
- **Schedule date blank = Unscheduled** — verify this behavior
- **Assignment** — add tech selector to intake form (currently missing)

Small polish items, not a new page.

---

## New Backend Endpoints Summary

| Endpoint | Module | Purpose |
|----------|--------|---------|
| `get_job_stats(period)` | Dashboard | Avg job size, revenue, count by period |
| `get_team_stats(period)` | Dashboard | Revenue + hours per tech |
| `get_ar_aging()` | A/R | Invoice aging buckets with counts + totals |
| `resend_invoice(invoice_name)` | A/R | Resend + log + update colour state |
| `get_jobs_needing_estimate()` | Estimates | Jobs with estimate_required=1 |
| `create_estimate(params)` | Estimates | Create MTM Estimate with options |
| `send_estimate(estimate_name)` | Estimates | Generate token, email customer |
| `approve_estimate_option(token, option)` | Estimates | Customer approval (guest) |
| `get_plans_due(days_ahead)` | Service Plans | Plans with upcoming service dates |
| `create_plan_instance(template, customer, address)` | Service Plans | Create from template |
| `generate_work_order(plan_name)` | Service Plans | Create HCP Job from plan |
| `approve_plan(token)` | Service Plans | Customer approval (guest) |
| `get_customer_list(query, page)` | Customers | Paginated customer list |
| `get_customer_profile(customer)` | Customers | Full profile aggregation |
| `get_recent_job_images(limit)` | Dashboard | Recent job photos for widget |
| `get_checklist_template(job_type)` | Checklist | Template items for job type |
| `update_checklist_item(job, idx, checked)` | Checklist | Toggle checklist item |

---

## New DocTypes Summary

| DocType | Type | Purpose |
|---------|------|---------|
| MTM Estimate | Document | Estimate with approval workflow |
| MTM Estimate Option | Child table | Option within estimate (independent status) |
| MTM Estimate Line Item | Child table | Line item within option |
| MTM Service Plan Template | Document | Reusable plan template |
| MTM Service Plan Template Checklist | Child table | Checklist items for template |
| MTM Service Plan Instance | Document | Active plan bound to address |
| MTM Checklist Template | Document | Job-type checklist template |
| MTM Checklist Template Item | Child table | Checklist item definition |
| HCP Job Checklist Item | Child table (on HCP Job) | Per-job checklist state |

---

## New Web Pages Summary

| Path | Module | Description |
|------|--------|-------------|
| `/manager/invoices` | A/R | Invoice list with aging filter |
| `/manager/estimates` | Estimates | Estimate list |
| `/manager/estimates/[name]` | Estimates | Estimate detail + options |
| `/manager/estimates/new` | Estimates | Create estimate (from job) |
| `/manager/service-plans` | Service Plans | Plan instance list |
| `/manager/service-plans/templates` | Service Plans | Manage templates |
| `/manager/service-plans/[name]` | Service Plans | Plan instance detail |
| `/manager/customers` | Customers | Customer list |
| `/manager/customers/[name]` | Customers | Customer profile |
| `/approve/estimate/[token]` | Estimates | Customer approve/decline (public) |
| `/approve/plan/[token]` | Service Plans | Customer approve/decline (public) |

---

## Parallel Build Tracks

**Track 1 — Glass (Web):** Dashboard widgets, A/R Aging, Invoices page, Customers, Estimates UI, Service Plans UI, Job Intake polish, Need-Estimate tab

**Track 2 — Swift (Mobile):** Completion checklist, Back button fix (DONE), restock improvements

**Track 3 — Forge (Backend):** New doctypes, new API endpoints, estimate/plan approval tokens, AR aging queries, team stats aggregation

Tracks 1-3 run in parallel. Backend endpoints needed before web pages can consume them, but can stub with mock data initially.

---

## Rollout

1. Deploy backend (new doctypes + endpoints) — Forge
2. Deploy web pages with real API calls — Glass
3. Deploy mobile checklist — Swift
4. Seed service plan templates — Forge
5. Office testing (Adam + Zach)
6. Full team rollout
