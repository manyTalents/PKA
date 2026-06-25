# Forge — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Lessons

### 2026-04-04: frappe.enqueue deduplicate requires job_id
- **Category:** backend
- **Lesson:** Always provide a `job_id` parameter when calling `frappe.enqueue(..., deduplicate=True)` — Frappe silently requires it and blocks all operations without it.
- **Context:** SOLUTIONS_LOG #1. `hcp_sync.py` called `frappe.enqueue(push_job_to_hcp, deduplicate=True)` without `job_id`. This blocked ALL HCP Job operations — Start Time, customer updates, status changes, clock in/out. Fix: added `job_id=f"push_hcp_job_{doc.name}"`. Standard #7 created from this incident.
- **Keywords:** frappe, enqueue, deduplicate, job_id, background job, HCP, 417 error

### 2026-04-04: Reading job.company_name instead of customer.first_name
- **Category:** backend
- **Lesson:** HCP webhook `company_name` at the job level is YOUR company name ("AllTec"), not the customer — customer data lives in `customer.first_name` / `customer.last_name` / `customer.company`.
- **Context:** SOLUTIONS_LOG #3. Every HCP Job showed "AllTec" as customer name because code read `job.company_name` instead of `customer.first_name`. Additionally, `_upsert_hcp_job` only set customer on INSERT, not UPDATE. Standard #11 created from this incident.
- **Keywords:** HCP, webhook, customer, company_name, field mapping, payload

### 2026-04-04: Frappe Cloud worker caching delays new code
- **Category:** backend
- **Lesson:** After deploying to Frappe Cloud via `git push`, new/modified Python functions may not be callable for 15+ minutes because background workers cache modules.
- **Context:** SOLUTIONS_LOG #5. New whitelisted functions returned "module has no attribute" errors after deploy. Workers keep old code until they restart (~10-15 min). Workarounds: add to existing functions via parameters, wait for worker restart, or create doctypes via REST API with `custom=1`. Standard #8 created from this. No bench migrate/restart/execute on FC.
- **Keywords:** frappe cloud, deploy, worker cache, endpoint, module, bench, custom doctype

### 2026-04-29: Customer Group "All Customer Groups" is a group node
- **Category:** backend
- **Lesson:** When creating Customer records in ERPNext, use a leaf node like "Individual" for `customer_group` — "All Customer Groups" is a group node and will throw a validation error.
- **Context:** Customer creation from HCP webhook data failed because the code set `customer_group = "All Customer Groups"` which is the root group node in ERPNext's tree structure, not a valid leaf assignment. Fix: use "Individual" or another leaf-level group.
- **Keywords:** ERPNext, customer, customer_group, group node, leaf, Individual, validation

### 2026-04-29: HCP customer data returns string instead of dict
- **Category:** backend
- **Lesson:** Always add an `isinstance(data, dict)` guard before accessing nested fields on HCP webhook payloads — the customer field sometimes arrives as a string instead of a dict.
- **Context:** HCP webhook processing crashed intermittently when `payload["customer"]` was a string (e.g., a customer ID) rather than the expected dict with `first_name`/`last_name` fields. Fix: add type checking before field access to handle both shapes gracefully.
- **Keywords:** HCP, webhook, isinstance, type guard, customer, dict, string, payload parsing

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->


---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->


---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->


---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

