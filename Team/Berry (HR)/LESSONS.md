# Berry — Lessons Learned

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

### 2026-05-19: Classify Work Shape Before Hiring
- **Category:** hiring, process
- **Lesson:** Before triggering the hiring pipeline, classify the work as BUILD / BUY / HIRE / WAIT -- not every gap requires a new team member.
- **Context:** Work-Shape Classification framework established. Some tasks are better solved by building a tool (BUILD), purchasing a service (BUY), or deferring until demand is proven (WAIT). Hiring a permanent member for a one-off task wastes team capacity and increases coordination overhead.
- **Keywords:** work-shape, BUILD, BUY, HIRE, WAIT, classification, hiring pipeline

### General: Monitor Coordination Cost as Team Grows
- **Category:** team management
- **Lesson:** As the team grows past 20+ members, overlapping responsibilities create coordination overhead that can outweigh the benefit of specialization; actively audit for role overlap.
- **Context:** Team grew to 30 members. Some roles may overlap (e.g., Shield and Gauge on risk/testing, Macro and Pulse on market context). Without active monitoring, tasks get routed to the wrong member or duplicated across two members. Berry must maintain a clear responsibility matrix and flag overlaps during monthly reviews.
- **Keywords:** coordination cost, team size, overlap, responsibility matrix, scaling

### General: IDENTITY.md Quality Determines Routing Accuracy
- **Category:** hiring, identity
- **Lesson:** A vague or generic IDENTITY.md leads to wrong task routing by 10T; every identity file must have specific responsibilities, clear boundaries, and concrete examples of what the member does and does not do.
- **Context:** Vague identities (e.g., "handles data tasks") cause 10T to route unrelated work to the wrong member. The more precise the IDENTITY.md -- with explicit responsibilities, boundaries, failure modes, and eval criteria -- the more accurately 10T can match tasks to members.
- **Keywords:** IDENTITY.md, task routing, vague identity, precision, boundaries

