# Ace — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->

### 2026-05-19: Work-Shape Classification Prevents Team Bloat
- **Category:** strategy / team-design
- **Lesson:** Before hiring a new team member, score the task across 6 dimensions (repetition, mistake cost, judgment, model trajectory, market maturity, specificity) to determine if BUILD/BUY/HIRE/WAIT is the right shape; defaulting to HIRE causes team bloat.
- **Context:** The original PKA system auto-triggered the hiring pipeline for any task without an existing team member. This led to evaluating hires for things that a skill, MCP, or existing tool could handle. The Work-Shape Classification framework (from Nate B Jones analysis) was adopted: score the task on 6 dimensions, then choose BUILD (new skill/MCP), BUY (existing tool), HIRE (new team member), or WAIT (revisit later). This gate now runs BEFORE the hiring pipeline.
- **Keywords:** work-shape, build-buy-hire-wait, team-bloat, hiring-pipeline, skill, mcp, classification

### 2026-05-19: Stax vs Stripe — Cheapest Is Not Always Best
- **Category:** strategy / vendor-selection
- **Lesson:** When evaluating vendor options, total cost of ownership includes integration effort and maintenance; a cheaper per-transaction fee can be dwarfed by custom development costs.
- **Context:** Stax offered lower per-transaction fees than Stripe for payment processing. However, Stripe has native Frappe Payments integration ($0 custom development), while Stax would have required $8-23K in custom API integration work plus ongoing maintenance. At AllTec's transaction volume, the Stripe per-transaction premium was far cheaper than building and maintaining a Stax integration. Decision: Stripe, revisit if volume exceeds $50K/month.
- **Keywords:** stax, stripe, integration-cost, tco, vendor-selection, payments, frappe-payments

### 2026-05-20: Reconcile All Numbers Before Presenting to the Owner
- **Category:** strategy / reporting
- **Lesson:** When presenting financial data from multiple sources, cross-check all numbers for internal consistency before showing the Owner; conflicting numbers waste his time and erode trust.
- **Context:** 10T presented balance, deployed capital, and available margin numbers that contradicted each other without noticing the inconsistency. The Owner had to manually reconcile. Additionally, after presenting a fix, 10T did not proactively walk through the downstream implications (e.g., "available goes negative on next scan = no new entries"). Fix: before presenting any numbers, verify they add up. After any state change, proactively trace what happens next without being asked.
- **Keywords:** reconcile, numbers, consistency, cross-check, downstream, implications, financial-reporting

---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->

- **6-dimension scoring matrix:** Rate each dimension 1-5, sum determines shape. High repetition + low judgment = BUILD. High specificity + high judgment = HIRE. Clear, repeatable framework.
- **TCO comparison template:** For any vendor evaluation, calculate: (1) per-unit cost at current volume, (2) integration development hours at $150/hr, (3) ongoing maintenance hours/month, (4) switching cost if it fails. Pick lowest total, not lowest line item.

---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->

- Vendor comparison template that auto-calculates TCO across fee tiers + integration cost
- Pre-report reconciliation checklist for financial data presentations

---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

- **Reconcile before presenting:** Any report with numbers from multiple sources must pass an internal consistency check before delivery. If numbers conflict, investigate the source — never dump raw conflicting data on the Owner. Seen in financial reporting (2026-05-20).
