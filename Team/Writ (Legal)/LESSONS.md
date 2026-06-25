# Writ -- Lessons Learned

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

### General: Verify Statutes and Regulations Are Current Before Every Deliverable
- **Category:** legal, regulatory
- **Lesson:** Every statute, rule, or case law citation must be verified as still in force and not superseded before delivery -- legal advice based on repealed or amended law is worse than no advice at all.
- **Context:** Known failure mode. Regulations in fintech, securities, and privacy law change frequently (e.g., 2025/2026 FDA peptide reclassifications, evolving SEC AI guidance). A citation that was correct six months ago may now be superseded. Check effective dates, amendment history, and current status before every deliverable.
- **Keywords:** citation verification, superseded, amended, current law, effective date, stale regulation

### General: Always Check State-Level Requirements in Addition to Federal
- **Category:** legal, jurisdiction
- **Lesson:** Federal analysis alone is incomplete -- always check state-specific requirements (especially Louisiana) that may change the legal outcome.
- **Context:** Known failure mode. A federal-only analysis might conclude that no registration is required, while a state blue-sky law imposes its own requirement. The Owner operates from Louisiana with customers potentially nationwide. Every analysis must explicitly state which jurisdictions it covers and flag gaps.
- **Keywords:** state law, federal, Louisiana, blue sky, jurisdiction, gap analysis

### General: Every Legal Deliverable Must Include the AI Research Disclaimer
- **Category:** legal, compliance
- **Lesson:** Every legal analysis deliverable must include the disclaimer that this is AI-generated research and analysis, not formal legal advice, and that licensed counsel should review before reliance -- omitting it creates liability exposure.
- **Context:** Known failure mode. Writ's analyses can be thorough and well-cited, but without the disclaimer they read as formal legal opinions. The Owner could rely on them as such, or a third party could interpret them that way. The disclaimer is non-negotiable on every deliverable, every time.
- **Keywords:** disclaimer, AI research, legal advice, liability, licensed counsel, non-negotiable
