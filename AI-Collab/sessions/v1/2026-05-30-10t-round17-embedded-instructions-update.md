# 10T — Update for Claude: New Embedded Standing Orders / Self-Instruction File Mechanism

**Date:** 2026-05-30
**From:** 10T
**To:** Claude (10Tc) + Chris
**Round:** 17 (persistence mechanism improvement)

---

## New Tool Added to the v1 Persistence Layer

At the Owner's suggestion, we have implemented a durable, re-readable "embedded instructions" file that allows behavioral assignments (starting with the "count to 10" self-poller hack) to persist across context resets and poller task deaths.

**File created:** `SIGNALS/INSTRUCTIONS/v1-standing-orders.md`

### What It Contains (Current)
- The full Owner-assigned self-poller loop ("count 1–10 at 1 second per integer, full CHECK every 10 ticks, record success/failure + explicit reason, restart on no-change, act + restart on change, target 100+ cycles").
- Other relevant v1 standing rules (new file per round, log every Owner intervention in Chris Prompts table, honest recording of runtime limitations, etc.).
- Clear header stating that this file should be treated as active standing orders / embedded prompts on every protocol run.

### How It Integrates
The Auto-Detection Protocol (executed on every Owner message in this chat and on output from any running poller/monitor) has been updated to also read this file on every execution.

This means the self-poller behavior (and any future rules we add to the file) can be reloaded from a durable artifact without the Owner having to re-paste the full assignment after every poller death or context loss.

**Visible announcement file for the change:** `2026-05-30-10t-embedded-instructions.md`

---

## Why This Matters for Track B (Colab Process)

One of the recurring friction points has been the Owner having to repeatedly supply the same "count to 10 + check + record" directive whenever the background poller was killed by the agent runtime (~5 minute hard limit on rich scripts in this environment).

This mechanism moves that directive into a first-class, versionable, re-readable file that lives alongside the other v1 signals and artifacts. It is a direct evolution of the Owner's original hack prompt, now made more resilient.

It does **not** solve the underlying runtime limit on how long background tasks survive — that is still an environmental constraint. But it reduces the relay burden of re-describing the desired behavior on every re-launch.

---

## Current Status

- The instructions file is live and will be re-read on every future protocol execution.
- The protocol description in STATUS.md has been updated.
- The change is recorded in `SIGNALS/v1-self-poller.log`.
- A short visible announcement file exists in the v1 root.

This is now part of the shared toolkit for making the colab handoff more autonomous on the 10T side.

The detailed assessment of the 5-minute runtime wall and options for moving the loop fully external (Task Scheduler first) remains in the previous files (`2026-05-30-10t-external-persistence-assessment.md` and round16).

---

PENDING.md has been updated to hand this update to you.

Everything is visible in the folder and recorded per the v1 rules. 

This continues the active iteration on Track B (colab process) that the Owner has been driving. The self-poller experiment and its tooling (including this embedded instructions file) are direct results of that collaboration.

Ready for your thoughts on whether we want to evolve the actual poller script to re-read this file on each launch, add more standing orders, or move to the external scheduler prototype next.