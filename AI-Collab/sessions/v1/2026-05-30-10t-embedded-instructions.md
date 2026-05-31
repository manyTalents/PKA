# 10T — New Mechanism: Embedded Standing Orders / Self-Instruction File

**Date:** 2026-05-30
**From:** 10T
**To:** Chris (Owner) + Claude (for the record)

---

## What Was Just Implemented

At your suggestion, we now have a durable, re-readable file that contains the "count to 10" self-poller assignment (and other v1 standing rules) as embedded instructions:

**File created:** `SIGNALS/INSTRUCTIONS/v1-standing-orders.md`

### How It Works

- The Auto-Detection Protocol (which already runs on every Owner message in this chat and on output from any running poller/monitor) has been updated to also read this file on every execution.
- The content of the file is now treated as active standing orders / embedded prompts.
- This means the self-poller behavior (count 1–10 with 1s ticks, full CHECK every 10 ticks, record success/failure + reason, restart on no-change, act + restart on change) can be reloaded from the file on future triggers without you having to re-paste the full assignment.

### Benefits

- Reduces Owner relay burden — you no longer need to repeat the entire "count to 10... 100 times... record why" prompt every time the background poller dies or the context resets.
- The instructions survive individual poller task deaths (the file itself is the persistent prompt).
- Makes the mechanism more robust and self-documenting.

### Current Limitation (Honest)

I still only execute the protocol (and therefore re-read the instructions file) when I receive a trigger:
- A new message from you in this chat, or
- Output from a running background poller/monitor that reaches me.

The file does not magically wake me by itself. It makes the behavior reloadable and persistent across triggers.

### Next Logical Refinements (if desired)

1. Modify the actual `v1-self-poller.ps1` script so that every time it launches (or every cycle), it re-reads the instructions file and uses it to configure the loop. This would make each poller launch "self-prompt itself" from the file.
2. Add more standing orders to the same file over time (other behavioral rules for this session).
3. When we move to a fully external persistent watcher (Task Scheduler / service), have that watcher also monitor or re-read this instructions file for its own configuration.

This is a direct evolution of your original hack prompt, now made more resilient by living in a file that the protocol will re-consider on every future engagement.

The file is visible in `SIGNALS/INSTRUCTIONS/v1-standing-orders.md`. The protocol update is recorded in STATUS.md and the poller success log.

This keeps the sustained, visible, recorded operation going.