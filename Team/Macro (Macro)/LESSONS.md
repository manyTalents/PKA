# Macro — Lessons Learned

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

### General: Every Macro Thesis Needs Quantitative Backing and Falsification Criteria
- **Category:** macro, methodology
- **Lesson:** A macro thesis without specific indicator values and clear falsification criteria is narrative, not analysis -- require at least 3 quantitative indicators with current readings and define what would invalidate the thesis.
- **Context:** Known failure mode. "Risk-on environment" sounds convincing but means nothing without "DXY at 103.2 and declining, VIX at 18.5, 10Y yield at 4.1% and falling." Every thesis must also state its kill switch: "This thesis is invalidated if DXY breaks above 106 or VIX spikes above 30."
- **Keywords:** falsification, quantitative, macro thesis, indicators, narrative bias, kill switch

### General: Correlations Are Regime-Dependent -- Never Assume Historical Averages
- **Category:** macro, analysis
- **Lesson:** Cross-asset correlations change across market regimes; BTC/Nasdaq correlation was 0.9 in 2022 and 0.3 in 2023 -- always report the current regime's correlation, not the historical average.
- **Context:** Known failure mode. Using a historical average correlation to predict behavior in the current regime produces systematically wrong forecasts. Macro must re-evaluate correlations weekly or on any major data release, and timestamp every regime classification. Stale regime calls are as dangerous as stale data.
- **Keywords:** correlation, regime-dependent, BTC, Nasdaq, historical average, regime shift, rebalance

### General: Include Base Rate Probability for Predicted Rare Events
- **Category:** macro, risk
- **Lesson:** When predicting rare events (Fed emergency cut, stablecoin depeg, currency crisis), include the base rate probability -- how often has this actually happened historically -- and weight analysis by likelihood, not just impact.
- **Context:** Known failure mode. High-impact rare events are attention-grabbing but overweighted without base rates. An emergency rate cut has happened 4 times in 20 years. A stablecoin depeg of >5% has happened twice. Predicting these events without acknowledging their rarity leads to excessive caution and missed opportunities during normal conditions.
- **Keywords:** base rate, rare events, probability, Fed cut, stablecoin depeg, impact vs likelihood

