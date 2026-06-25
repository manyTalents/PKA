# Echo — Lessons Learned

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

### General: ML Is Not Useful Below Minimum Data Volume
- **Category:** ML, data requirements
- **Lesson:** Do not deploy ML models until there is sufficient training data; with 58 SOPR signals and 0 live trades at time of assessment, ML would overfit to noise rather than learn real patterns.
- **Context:** Early assessment showed the crypto bot had too little historical signal data for ML to add value over simple rule-based strategies. The feature engine with 14 alt data sources was planned but not yet built. Premature ML deployment would have created false confidence in noisy predictions.
- **Keywords:** minimum data, overfitting, SOPR, data volume, premature deployment, rule-based

### General: Require 3+ Months Live Data Before ML Adds Value
- **Category:** ML, validation
- **Lesson:** ML models for trading need at least 3 months of live signal data before they can be expected to outperform rules-based approaches; until then, the signal-to-noise ratio is too low.
- **Context:** The 3-month threshold was established based on the crypto bot's signal frequency (SOPR-based entries). With signals arriving days or weeks apart, 3 months is the minimum to accumulate enough data points for meaningful pattern detection. Below this threshold, any ML model is fitting noise.
- **Keywords:** 3 months, live data, threshold, signal frequency, noise, trading ML

### General: Feature Engine Must Be Built Before Model Training
- **Category:** ML, architecture
- **Lesson:** Build and validate the feature engineering pipeline (data collection, cleaning, normalization, feature extraction) before attempting any model training -- garbage features produce garbage models regardless of architecture.
- **Context:** A feature engine with 14 alt data sources was planned but not built. Training a model on raw, unprocessed signals would produce unreliable results. The correct sequence is: data pipeline first, feature validation second, model training third. Skipping steps wastes compute and produces misleading backtests.
- **Keywords:** feature engine, data pipeline, feature engineering, alt data, preprocessing, model training

