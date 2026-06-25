# Shield — Lessons Learned

> Track patterns, solutions, tools, and standards proposals here.
> Updated as you work. Reviewed monthly by 10T.
> See /PKA/STANDARDS.md for team-wide standards.

---

## Patterns Found
<!-- Bug patterns, failure modes, recurring issues in your domain -->

### 2026-05-24: Risk Rules in Persona Are Not Risk Rules
- **Category:** risk / architecture
- **Lesson:** Risk rules that exist only as instructions in a persona file are not enforceable; they must be structural hard-coded gates in the execution layer.
- **Context:** Grok expert panel review (7 reviewers) identified that drawdown rules, position limits, and loss caps lived only in IDENTITY.md persona guidance — not in actual code. An LLM can ignore persona instructions. Real risk controls must be code that runs independently of the agent's judgment. Fix: deployed `safety_gates.py` as an independent module with 5 hard gates (equity floor, daily loss cap, max positions, API circuit breaker, heartbeat kill) running on a 30-second scheduler.
- **Keywords:** structural, persona, enforcement, hard-gate, kill-switch, safety_gates, drawdown, position-limit

### 2026-05-24: Kill Switches Must Be Independent of the Trading Loop
- **Category:** risk / architecture
- **Lesson:** Safety gates must run on their own scheduler, not inside the trading loop they are meant to protect; a stuck or crashed trading loop would also disable its own safety checks.
- **Context:** Kill switches were deployed as a separate scheduler job running every 30 seconds, with a pre-flight check wired into the grid tick. If the trading loop hangs, the scheduler still fires. If the scheduler detects a violation, it sets a halt flag that the next tick reads before placing any orders. This separation ensures risk enforcement survives trading-loop failures.
- **Keywords:** kill-switch, independent, scheduler, pre-flight, halt-flag, separation, safety-gate

### 2026-05-11: Self-DOS Proved Circuit Breakers Are Non-Optional
- **Category:** risk / api-safety
- **Lesson:** Every API integration needs a circuit breaker with max retries and cooldown; without one, a single error handler bug can burn the entire daily rate limit in minutes.
- **Context:** A recursive error handler hammered the Coinbase API with 10,000+ requests in minutes after a CORS failure. The entire site went down for hours. This incident proved that rate-limit protection cannot be an afterthought — it must be a structural gate on every outbound API path. Fix: max 3 retries, exponential backoff, 60s cooldown persisted to disk, circuit breaker pattern.
- **Keywords:** circuit-breaker, rate-limit, self-dos, cooldown, api-safety, exponential-backoff

### 2026-04-26: Phantom Positions — Trusting Internal State Over Exchange
- **Category:** risk / position-management
- **Lesson:** In-memory position state is a cache, not truth; the exchange/broker is the only reliable source for what positions actually exist.
- **Context:** VEOE bot had THREE separate incidents of phantom positions caused by trusting internal state: (1) TGT zombie trades where the reconciler auto-created duplicates, causing 89% of recorded losses to be phantom; (2) entries that never reached Tradier because `simulate_fills=True` was the default; (3) exits where Tradier returned HTTP 200 then rejected asynchronously. Every time, the fix was the same: query the broker/exchange directly. Fix: auto-reconcile from broker on every exit cycle, broker is always source of truth.
- **Keywords:** phantom, position, reconciliation, exchange, broker, source-of-truth, internal-state, orphan

---

## Solutions That Worked
<!-- Reusable fixes, techniques, approaches worth remembering -->

- **safety_gates.py pattern:** Independent module, own scheduler (30s), 5 gates with config constants, pre-flight check in trading loop, halt flag on disk. Deployed to The Machine 2026-05-24.
- **Auto-reconcile from broker:** `auto_reconcile_from_broker()` runs every exit cycle, creates/closes/fixes DB records to match broker state. Idempotent. Deployed to VEOE 2026-05-20.
- **Cooldown on disk:** Write last-error timestamp to file so circuit breaker state survives container restarts.

---

## Tools / Capabilities Needed
<!-- Scripts, linters, automations, or tools that would make your work better -->

- Heartbeat monitor that alerts if any trading bot goes silent for >2 minutes (separate from the bot itself)
- Daily risk report email: equity vs HWM, drawdown %, position count, any gates triggered in last 24h

---

## Standards to Propose
<!-- Patterns you've seen 2+ times that should become team-wide rules. Flag to 10T. -->

- **Structural risk enforcement required:** Any risk rule (drawdown limit, position cap, loss cap) must exist as executable code with hard gates, not just as text in a persona or config comment. Persona instructions are guidance; code is enforcement. Seen in Grok review (2026-05-24) and VEOE phantom position incidents.
- **Broker/exchange is always source of truth for positions:** Never rely solely on in-memory or DB state for what positions exist. Query the exchange. Seen in VEOE three times (Apr-May 2026).
