# Stocky — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Lessons

### 2026-04-18: Limbo is post-job unused parts only
- **Category:** inventory
- **Lesson:** Limbo inventory means parts that were on a job but NOT used and NOT returned to warehouse — they sit in the tech's truck until disposition. Limbo is NOT a general-purpose holding area.
- **Context:** Owner confirmed on 2026-04-18 that Limbo is specifically for post-job unused parts. When a job ends, unused parts go to Limbo by default. The tech then decides for each item: return to warehouse, keep on truck, or mark as used. This distinction matters for inventory accuracy and cost tracking.
- **Keywords:** Limbo, unused parts, post-job, truck stock, disposition, inventory, tech

### 2026-04-18: Unit mismatch risk — box vs individual, roll vs foot
- **Category:** inventory
- **Lesson:** Always verify and display the unit of measure when tracking parts — a "box" of fittings vs an individual fitting, or a "roll" of solder vs per-foot, can cause 10x-100x quantity errors in inventory counts and job costing.
- **Context:** Plumbing parts come in mixed units from suppliers. A box of 25 fittings entered as quantity 1 looks like 1 fitting. A 100ft roll of solder entered per-foot looks like 100 items. Without explicit UoM display and validation, inventory counts and job cost calculations will be wildly wrong. Standard #4 (generic part names) must also show the UoM.
- **Keywords:** unit of measure, UoM, box, individual, roll, foot, quantity, mismatch, job costing

### 2026-04-18: Default destination is Limbo — tech picks where each item goes
- **Category:** inventory
- **Lesson:** When a job completes, all unused parts default to Limbo status — the tech is responsible for deciding the destination (return to warehouse, keep on truck, or transfer) for each individual item.
- **Context:** The workflow is: job ends, unused parts auto-enter Limbo, tech reviews each part and assigns a destination. This prevents parts from silently disappearing into a truck and never being tracked. The mobile app must present this as a clear action step at job completion, not a background process.
- **Keywords:** Limbo, default destination, tech review, job completion, part disposition, truck stock, workflow

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

