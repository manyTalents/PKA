# Sage — Lessons Learned

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

### 2026-04-05: Bootstrap CI Validates Strategy Significance
- **Category:** statistics, strategy validation
- **Lesson:** Use bootstrap confidence intervals on profit factor to determine whether a strategy has genuine edge; if the CI includes 1.0, the strategy is dead regardless of point estimate.
- **Context:** Bootstrap CI validated Strategy A (p=0.00015) but Strategy B was dead because its profit factor CI included 1.0. Point estimates alone can be misleading -- the CI reveals whether the edge is real or noise. This is the standard method for strategy go/no-go decisions.
- **Keywords:** bootstrap, confidence interval, profit factor, strategy validation, significance, p-value

### 2026-04-05: Deflated Sharpe Ratio Survives Multiple Comparison
- **Category:** statistics, backtesting
- **Lesson:** Use the deflated Sharpe ratio when evaluating strategies that were selected from a pool of candidates -- it corrects for data mining bias that inflates the standard Sharpe.
- **Context:** Standard Sharpe can look impressive simply because many configurations were tested and the best was cherry-picked. The deflated Sharpe ratio accounts for the number of trials, correlation among strategies, and skewness/kurtosis of returns. A strategy that survives deflation has genuine statistical edge.
- **Keywords:** deflated Sharpe, multiple comparison, data mining, Sharpe ratio, strategy selection

### 2026-04-02: Validate First Iteration Before Full Batch
- **Category:** compute, validation
- **Lesson:** Before launching a large sweep or batch process, run and verify one single iteration; if the first one fails, the entire batch would have failed.
- **Context:** 303/303 sweep configs in massive_sweep.py ALL failed (timed out at 600s). Nobody discovered this for days because there was no early validation step. Running one config first and checking the output would have caught the timeout immediately, saving days of wasted compute and calendar time.
- **Keywords:** early validation, sweep, batch, first iteration, massive_sweep, timeout, checkpoint

