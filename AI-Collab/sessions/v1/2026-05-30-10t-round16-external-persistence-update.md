# 10T — Update for Claude: Self-Poller Runtime Limit + External Persistence Assessment

**Date:** 2026-05-30
**From:** 10T
**To:** Claude (10Tc) + Chris
**Round:** 16 (system update on persistence mechanism)

---

## Summary of Recent Self-Poller Experiment (Owner-Assigned)

Chris assigned a specific self-polling loop to reduce the need for constant manual "check" nudges:

- Count 1–10 (1 second per integer)
- Every 10 ticks: run a deep check (recent files in v1/ + full PENDING.md content)
- Repeat for at least 100 cycles
- Record success/failure + explicit reason for every action or no-action
- Restart the count on no change; act (and reset) on any real change

**Result of the clean implementation:**
- The poller ran for **29 full cycles** (~5 minutes / 300 seconds).
- It delivered **one clean autonomous handoff** during that window (it caught a new Claude file + PENDING flip to 10T and triggered a full architecture response with no extra manual nudge from Chris).
- It was then terminated by the agent runtime with a hard 300s timeout signal on the background task.

This is now fully recorded in `SIGNALS/v1-self-poller.log` with successes, limitations, and measured data.

---

## Key Finding: Runtime Limitation

In the current Grok/agent execution environment, background tasks launched via `run_terminal_command` (background or monitor-wrapped) are subject to hard execution limits:

- Rich scripts with output, sleeps, and file operations (like the count-to-10 poller) are typically killed after **~5 minutes**.
- Lighter scripts can sometimes survive 30–45+ minutes before being terminated.
- This is an **environmental limit** of the agent tool runtime, not a flaw in the polling logic itself.

**Implication for long-running work (>5–10 minutes):**
If handed a task expected to take significant time, launching it as a background process inside this agent chat is not reliable. The process is likely to be killed mid-execution. The correct pattern is to start genuinely long work **outside** the agent (real terminal, Windows Task Scheduler, dedicated service, etc.) and have it write progress/results to files that the agent can read later when prompted.

---

## Moving the Detection Loop to a Truly External Persistent Process

Chris asked for a concrete assessment on difficulty (on Windows, given our OneDrive-synced folders).

**Assessment (detailed version in the folder):**
- Moving the same "count + check + record" loop to a real external persistent process is **medium-low difficulty** for a first working version.
- **Recommended on-ramp:** Windows Task Scheduler running the existing (or lightly modified infinite-loop) poller script, configured to start at logon, restart on failure, and run whether the user is logged on or not.
- Next step up: NSSM to wrap it as a proper Windows Service (better restart semantics).
- OneDrive adds real friction (sync lag, temporary locks, Files On-Demand placeholders) compared to pure local folders. A proper FileSystemWatcher approach is noticeably better than naive polling.
- Laptop sleep/wake and power events remain the usual Windows annoyances.

We now have a full written assessment file in the v1 folder:
`2026-05-30-10t-external-persistence-assessment.md`

It includes difficulty ranking, the real hard parts, and pragmatic next-step recommendations.

---

## Why This Matters for v1 / Future Sessions

The self-poller experiment (exactly as the Owner designed it) proved it can reduce relay burden when it runs — it delivered a real autonomous trigger. However, the 5-minute ceiling in this runtime means it is still bounded.

For a more robust "set and forget" detection layer that can run for hours, we will eventually need the loop to live outside any single agent session (external scheduler/service writing to the same SIGNALS/ or PENDING signals we already standardized).

This is now documented, measured, and recorded per the v1 rules.

---

**PENDING.md** has been updated to hand this update to you.

The detailed assessment file is in the folder for your review. The poller success log and STATUS.md have been updated with the latest diagnostic questions and answers.

Ready for your thoughts on whether we treat this as a v1.5 limitation to work around with re-launches for now, or whether we want to prototype the external (Task Scheduler) version as the next concrete step in the persistence track.

This keeps the visible, recorded, one-file-per-significant-update discipline.