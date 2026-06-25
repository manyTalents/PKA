# Arrow — Lessons Learned

> Log patterns, solutions, tools needed, and standards to propose here.
> Updated continuously during task work.

---

## Patterns Found


## Solutions That Worked


## Tools Needed


## Standards to Propose


---

## Lessons

### 2026-05-20: Entry Code Must Create Matching DB Records for Every Broker Position
- **Category:** options, data integrity
- **Lesson:** Every position opened at the broker must have a corresponding database record created atomically; orphan broker positions without DB records cause downstream systems to deadlock.
- **Context:** VEOE options bot entry code placed broker positions without creating matching DB records. The exit monitor could not find the positions in the database and deadlocked. The fix was auto-reconciliation between broker state and DB state, but the root cause was the entry path skipping the DB write.
- **Keywords:** VEOE, broker position, DB record, orphan, entry code, atomic, data integrity

### 2026-05-20: Exit Monitor Deadlocks From Broker/DB Mismatch
- **Category:** options, monitoring
- **Lesson:** The exit monitor must reconcile broker state against DB state on every cycle; if positions exist at the broker but not in the DB, auto-reconcile rather than deadlock.
- **Context:** Broker/DB mismatch caused the exit monitor to stall completely. It could not close positions it did not know about. Auto-reconciliation was implemented: on each cycle, the monitor queries the broker for open positions, compares to DB, and creates missing DB records before proceeding. This pattern applies to any system where two sources of truth must stay in sync.
- **Keywords:** exit monitor, deadlock, reconciliation, broker state, DB state, mismatch, VEOE

### 2026-05-20: OCC Symbol Matching Is Required for Options Exits
- **Category:** options, symbology
- **Lesson:** Options exits must match positions using OCC-standard symbols (e.g., AAPL250620C00200000), not ticker alone; mismatched symbology causes exit orders to target wrong positions or fail silently.
- **Context:** Options positions need precise OCC symbol matching for exits because the same underlying can have dozens of open positions across different strikes and expirations. Matching on ticker alone would close the wrong leg. The OCC symbol encodes underlying, expiration, put/call, and strike in a single unambiguous string.
- **Keywords:** OCC symbol, options exit, symbology, strike, expiration, position matching
