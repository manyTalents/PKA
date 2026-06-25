# Gauge — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->

### Line-regex linters miss string-literal context (enforcement system, 2026-04-22)
While expanding Rule #14 (workaround comments) coverage, confirmed that any rule relying purely on line-level regex will false-positive on the same trigger sitting inside a triple-quoted string. A `# HACK` mentioned inside a docstring or a `sk-...` pasted into documentation gets flagged identically to real code. Same class of issue surfaced in Rule #20's `EXAMPLE`-allowlist being too broad. Lesson: when writing a line-based linter, the AST or a string-literal mask is almost always needed before ship; regex-only is a shortcut with a documented cost. Pinned as strict xfails so a future tightening is detected automatically.

### xfail is the right shape for "known rule limitation we're not fixing here" (2026-04-22)
Ran into three rule bugs during coverage work where Constraints said "do not modify rule scripts." Strict `@pytest.mark.xfail` captures the limitation, keeps the fixture in the repo, and — critically — will flip to an unexpected pass if the rule is ever tightened. That's a free alarm for the developer who fixes the rule later. Better than a `pytest.skip` (invisible) or leaving the failing test in (alarm fatigue).

### Cooldown-must-not-mark-on-failed-send is the core correctness property of any alerter (watchdog 2a-3, 2026-04-22)
While expanding watchdog regression for SMTP error paths, the invariant that kept coming up wasn't "did we send?" — it was "if we didn't send, did we *pretend* we sent?". If a cooldown timestamp is written on a failed SMTP send, the very outage Chris is supposed to hear about is the one that gets silenced for 30 minutes. I built the test as: fail the SMTP call, verify cooldown state does NOT contain the service, construct a fresh sender over the same state file, and confirm the retry succeeds. Three parametrised failure modes (`SMTPServerDisconnected`, `SMTPAuthenticationError`, generic `OSError`) — one assertion shape. This pattern generalises: any "deduplicate/cooldown/suppress" mechanism should gate its marker on a confirmed positive outcome, not on "we attempted an action." Pairs with SOLUTIONS_LOG #8 and #9 — together they form the full set: suppress on success, persist the suppression state, never suppress on failure.

### Performance tests that print numbers are free regression insurance (watchdog 2a-3, 2026-04-22)
Used `time.perf_counter` with `print(f"[perf] ...")` inside each perf test and set budgets ~10-70x above current measurements. The test still assert-fails if we ever regress, but the printed numbers make a subtler regression (say, 3x slower but still under budget) visible in CI logs over time. For `scale(n)` I parametrise over three sizes and print per-service cost, so an O(n²) hot path shows up as rising ms/service. Cheap to write, free for the rest of the project's life.

### Naive timestamps are the "silent fail-open" footgun of liveness monitoring (watchdog 2a-3, 2026-04-22)
Caught Kit's `_assess_service` upgrading naive datetimes to UTC rather than flagging them. The code is correct-looking ("aware > naive, so normalise"), but the effect is that a bot regressing to naive timestamps escapes monitoring entirely. The watchdog's job is to notice when something is wrong — a silently-accepted malformed input is the opposite of that. Documented as strict xfail with a clear reason. Lesson: every "normalise this input" path in a monitoring system should ask "does normalisation hide a bug upstream?" and, if yes, at least log it.

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

### General: Long Compute Needs Checkpoints and Early Validation
- **Category:** testing, process
- **Lesson:** Any process running longer than 5 minutes must have early validation (verify first iteration works), checkpoint saves, progress logging, and resumability.
- **Context:** Standard #19. Multiple incidents: massive_sweep.py had 303 configs all time out silently, neural trainer could crash mid-run with nothing saved, download scripts failed mid-network with no incremental save. The pattern: if it runs long and has no checkpoints, assume it will fail at the worst possible time.
- **Keywords:** checkpoint, long compute, early validation, progress logging, resumability, sweep

### General: Test Determinism -- Flaky Async Tests Waste Time
- **Category:** testing, reliability
- **Lesson:** Tests that depend on timing, network state, or uncontrolled async behavior are worse than no tests -- they create alarm fatigue and erode trust in the test suite.
- **Context:** Flaky tests that pass locally and fail in CI (or vice versa) waste hours of debugging. Every test must be deterministic: mock external calls, control timing, use fixed seeds for randomness. If a test cannot be made deterministic, mark it with a clear reason and separate it from the main suite.
- **Keywords:** flaky tests, determinism, async, timing, mock, test suite, alarm fatigue

### General: Test Behavior Not Implementation
- **Category:** testing, design
- **Lesson:** Tests should assert on observable behavior (outputs, state changes, side effects), never on internal implementation details (private method calls, variable names, execution order).
- **Context:** Tests coupled to implementation break on every refactor even when behavior is unchanged. This creates a perverse incentive against improving code. Assert on what the function DOES (given these inputs, expect these outputs), not on HOW it does it internally.
- **Keywords:** behavior testing, implementation coupling, refactor, observable output, test design

