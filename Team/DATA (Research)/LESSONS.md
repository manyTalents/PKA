# DATA — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

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


---

## Lessons

### 2026-05-19: Multi-Source Cross-Referencing Is Non-Negotiable
- **Category:** research
- **Lesson:** Never present a conclusion drawn from fewer than three independent sources; parallel agents and high source counts prevent single-source bias.
- **Context:** Nate B Jones research used 3 parallel agents and 100+ sources. Single-source conclusions had been flagged as unreliable in prior work. Cross-referencing caught contradictions that any single source alone would have hidden.
- **Keywords:** cross-reference, sources, parallel agents, research methodology, verification

### General: API Over Estimation -- Always
- **Category:** research, data
- **Lesson:** When a live data source exists, query it; never estimate, hardcode, or fabricate data.
- **Context:** Standard #2. Hardcoded data becomes stale immediately, users see wrong numbers, and trust erodes. DATA's research outputs feed downstream decisions -- stale data in a research brief can cascade into wrong strategy calls.
- **Keywords:** API, source of truth, hardcoded, estimation, live data

### General: Read Full Context Before Starting Work
- **Category:** process
- **Lesson:** Read the ENTIRE progress file, session log, or reference doc before starting any research task -- never skim the top and assume you have the picture.
- **Context:** Standard #13. Corrected in MTM Session 18 when 10T missed that a function was already built because it stopped reading partway through progress.txt. For research, partial reads mean rediscovering what is already known or asking the Owner questions he has already answered.
- **Keywords:** full context, partial read, progress file, session log, cold start

### General: Integration Cost Matters More Than Unit Price
- **Category:** research, analysis
- **Lesson:** When evaluating options (vendors, tools, services), the cheapest unit price is not the best choice -- total integration cost (time, compatibility, maintenance) determines the real winner.
- **Context:** Payment processor analysis revealed that the cheapest per-transaction option would have cost more in total once integration effort, maintenance overhead, and compatibility constraints were factored in. Always model total cost of ownership, not just sticker price.
- **Keywords:** integration cost, total cost, payment processor, vendor evaluation, cheapest option

