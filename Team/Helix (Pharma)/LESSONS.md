# Helix -- Lessons Learned

> Log patterns, solutions, tools needed, and standards to propose here.
> Updated continuously during task work.

---

## Patterns Found


## Solutions That Worked


## Tools Needed


## Standards to Propose


---

## Lessons

### General: Never Recommend a Compound Without Checking the Full Stack
- **Category:** pharma, safety
- **Lesson:** Every compound recommendation must be evaluated against the Owner's complete current stack -- peptides, supplements, and medications -- for interaction risks, timing conflicts, and receptor competition.
- **Context:** Known failure mode. Designing a protocol in isolation misses critical interactions: timing conflicts between GH secretagogues and meals, receptor competition between stacked peptides, or contraindications with existing medications. Always ask for the full stack before recommending anything.
- **Keywords:** drug interaction, full stack, timing conflict, receptor competition, compound recommendation

### General: Regulatory Status Changes Fast -- Verify Before Every Protocol
- **Category:** pharma, regulatory
- **Lesson:** The FDA peptide regulatory landscape moves rapidly; verify the current status (Category 1 vs Category 2, compounding availability, PCAC review outcomes) of every compound before including it in a protocol.
- **Context:** Known failure mode. Between February and April 2026, 14 of 19 Category 2 peptides were reclassified back to Category 1. A protocol written in January could reference a compound that was inaccessible in March but accessible again in April. Stale regulatory information leads to either missed opportunities or illegal recommendations.
- **Keywords:** FDA, regulatory status, Category 1, Category 2, compounding, PCAC, reclassification

### General: Always Flag Off-Label Use Explicitly
- **Category:** pharma, evidence
- **Lesson:** When recommending a compound for a purpose outside its FDA-approved indication, explicitly label it as off-label and state the evidence tier for the off-label use.
- **Context:** Known failure mode. Many compounds the Owner uses (BPC-157 for healing, NMN for NAD+ support) are off-label or have no FDA-approved indication at all. Presenting these with the same confidence as FDA-approved uses is misleading. Every off-label recommendation must be tagged so the Owner can weigh the evidence-risk tradeoff.
- **Keywords:** off-label, FDA-approved, evidence tier, indication, compound use, labeling
