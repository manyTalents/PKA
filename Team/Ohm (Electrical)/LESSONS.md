# Ohm — Lessons Learned

> Continuous learning log. Updated as patterns emerge, solutions are found, and standards are proposed.

---

## Patterns Found


## Solutions That Worked


## Tools Needed


## Standards to Propose


---

## Lessons

### 2026-04-20: NEC Table Data Must Be Verified Value-by-Value
- **Category:** electrical code, data integrity
- **Lesson:** Every NEC table, chart, or reference value in ManyTalents Prep must be verified against the authoritative NEC 2023 / NFPA 70 source before shipping -- no approximations, no third-party summaries.
- **Context:** Standard #23. This is an exam prep product. A single wrong ampacity value means a student learns incorrect information and potentially fails a $300+ licensing exam. Ohm verified Table 310.16 value-by-value against NEC 2023 -- that is the standard for every table going forward.
- **Keywords:** NEC, Table 310.16, ampacity, verification, value-by-value, NFPA 70, exam prep

### 2026-04-20: Table 310.16 Is the Verification Gold Standard
- **Category:** electrical code, process
- **Lesson:** The Table 310.16 verification process -- cross-referencing every single value against the official NEC 2023 text -- is the template for verifying all future NEC tables (430.250, 310.15, demand factors, etc.).
- **Context:** Ohm completed the first full verification of Table 310.16 against NEC 2023. This process (value-by-value comparison with discrepancy logging) must be replicated for every electrical reference table added to MTP. No chart data file ships without a verification record signed off by Ohm.
- **Keywords:** verification process, Table 310.16, NEC 2023, cross-reference, sign-off, template

### General: Wrong Reference Data Has Legal and Financial Blast Radius
- **Category:** electrical code, risk
- **Lesson:** Incorrect electrical code data does not just cause a bad user experience -- it can cause exam failures ($300+), unsafe installations, and potential legal liability for the platform.
- **Context:** Unlike most software bugs where the worst case is a UI glitch, wrong NEC data in an exam prep tool has downstream consequences in the real world. Students rely on this data to pass licensing exams and to size conductors safely. Every number must be treated as safety-critical.
- **Keywords:** blast radius, exam failure, legal liability, safety-critical, NEC data, conductor sizing
