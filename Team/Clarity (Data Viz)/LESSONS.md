# Clarity — Lessons Learned

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

### General: Y-Axis Must Start at Zero Unless Explicitly Justified
- **Category:** data viz, integrity
- **Lesson:** Default the y-axis to zero; truncated axes exaggerate small changes, making a 2% dip look like a cliff -- if a zoomed view is needed, add a "scale note" annotation and show the full-range version alongside.
- **Context:** Known failure mode. Truncated y-axes are the most common way charts mislead. A $950 to $933 dip (-1.8%) looks catastrophic when the y-axis starts at $930. Stakeholders overreact to noise. The default is always zero; zoomed views are the exception, not the rule, and must be labeled.
- **Keywords:** y-axis, truncated, zero baseline, misleading, scale note, chart integrity

### General: Maintain a Color Registry -- No Ad Hoc Color Assignments
- **Category:** data viz, consistency
- **Lesson:** Maintain a single color registry where every strategy, data series, and category has a permanent color assignment; inconsistent colors across charts make data untrackable.
- **Context:** Known failure mode. Strategy A is blue on one chart and green on another -- users cannot track data across views. The color registry (Strategy A = always blue, BTC = always orange, etc.) must be audited against every chart before delivery. This is especially critical for dashboards where multiple charts appear side by side.
- **Keywords:** color registry, consistency, strategy color, data series, dashboard, color assignment

### General: One Chart, One Message -- If It Needs a Paragraph to Explain, Redesign It
- **Category:** data viz, design
- **Lesson:** Every chart should communicate exactly one takeaway; if a chart requires a paragraph of explanation to understand, the visualization is wrong and needs to be split, simplified, or redesigned.
- **Context:** Visualization rule. Complex charts that try to show everything show nothing. An equity curve should show portfolio value over time. A separate drawdown chart shows risk. A separate contribution chart shows strategy performance. Combining all three into one chart creates noise. Each chart answers one question.
- **Keywords:** one message, simplicity, chart design, split, noise, takeaway

