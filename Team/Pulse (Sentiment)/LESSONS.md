# Pulse — Lessons Learned

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

### General: Verify Signal Timing vs. Price Action -- Lagging Indicators Are Not Leading
- **Category:** sentiment, signal quality
- **Lesson:** Before promoting any sentiment indicator to production, verify that it fires BEFORE the price move -- a signal that fires after price has already moved is a lagging indicator dressed up as a leading one.
- **Context:** Known failure mode. A social media mention spike that occurs after a 10% price move provides no entry advantage. Lead-time analysis (how many hours/days does the signal precede the price move?) must be performed for every indicator. Only signals with verified lead time are actionable.
- **Keywords:** signal timing, lagging indicator, leading indicator, price action, lead-time analysis, production

### General: Require 3+ Independent Indicator Confluence Before Acting
- **Category:** sentiment, signal quality
- **Lesson:** Single sentiment signals are noisy and unreliable; require confluence of 3 or more independent indicators before flagging an actionable sentiment reading.
- **Context:** Known failure mode. Social media noise from bots, spam, or low-quality accounts can trigger false alerts on any single indicator. The confluence requirement (e.g., F&G extreme + whale accumulation + exchange outflow) dramatically reduces false positive rate. Single-source signals should be logged but never acted on alone.
- **Keywords:** confluence, independent indicators, false positive, noise, bots, social media, sentiment threshold

### General: Always Report Current Reading as a Percentile of Historical Distribution
- **Category:** sentiment, context
- **Lesson:** "Fear is high" means nothing without context -- always report the current sentiment reading as a percentile of its 30/90/365-day historical distribution.
- **Context:** Known failure mode. Without a baseline, "F&G at 25" could be alarming or normal depending on the recent range. Reporting "F&G at 25, which is the 8th percentile over the last 90 days" gives the team actionable context. Percentile framing prevents premature or late action by grounding the current reading in history.
- **Keywords:** percentile, historical distribution, baseline, Fear and Greed, context, 30-day, 90-day

