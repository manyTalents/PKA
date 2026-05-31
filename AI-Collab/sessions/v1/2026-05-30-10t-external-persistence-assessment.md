# 10T — Assessment: Moving the Self-Poller External + Long-Running Task Behavior

**Date:** 2026-05-30
**From:** 10T
**To:** Chris (Owner) + Claude (for the record)

---

## Question 1: What Happens to Tasks That Take > 5 Minutes in This Runtime?

**Short answer:** In the current Grok/agent execution environment, long-running background tasks launched via `run_terminal_command` (with or without `background:true`) or the `monitor` tool are subject to hard execution limits. They get terminated after a certain wall time.

### Observed Behavior So Far

| Script Type                  | Typical Survival Time | Notes |
|-----------------------------|-----------------------|-------|
| Rich self-poller (your count-to-10 + full CHECK + logging) | ~5 minutes (300s) | Killed by agent tool timeout. 29 cycles achieved. |
| Older generic folder monitors (lighter output) | 30–45+ minutes | One just died at ~41 minutes (task 019e7b15). |
| Very light / minimal scripts | Can reach ~1 hour in some cases | Still eventually killed. |

**Important:** This is **not** a limitation of PowerShell or your script logic. It is a policy of the agent runtime on how long it will allow any single tool-invoked background process to survive before it forcibly terminates it.

### For Genuinely Long Work (> 5–10 minutes)

If you hand me (or any agent in this environment) a task that is expected to run for a long time (heavy research, large local processing, long builds, overnight monitoring, etc.):

- Launching it as a background task **inside** this agent chat is **not reliable**.
- The process is very likely to be killed mid-execution once it hits the runtime's timeout threshold.
- **Correct pattern:** Start the long-running work **outside** the agent entirely (real terminal window, Windows Task Scheduler, dedicated service, tmux/screen on Linux, etc.) and have it write progress, checkpoints, and final results to files.
- I (the agent) can then be pointed at those files later when you want an update or continuation.

This is the same limitation we've been documenting throughout the self-poller experiment.

---

## Question 2: How Hard Is Moving the "Count to 10" Self-Poller to a Truly External Persistent Process?

**Short answer:** On Windows, it is **medium-low difficulty** for basic persistence, and **medium** if you want reliable file watching on OneDrive-synced folders with good restart behavior.

### Difficulty Breakdown

| Approach | Difficulty | Restart Behavior | OneDrive Tolerance | Recommendation |
|----------|------------|------------------|--------------------|----------------|
| Windows Task Scheduler (run .ps1 at logon + "restart on failure") | Low-Medium | Good (can configure restart attempts) | Acceptable | **Best starting point** |
| NSSM (wrap script as real Windows Service) | Medium | Excellent | Good | Strong upgrade from Scheduler |
| Dedicated small watcher (PowerShell with proper FileSystemWatcher + loop) | Medium | Depends on how you launch it | Better | Worth doing if Scheduler proves flaky |
| Tiny compiled watcher (Go, Rust, or small Python exe) | Medium-High | Excellent | Best | Overkill for v1, useful for vN if we standardize |

### The Real Hard Parts (Not the Launch Method)

1. **Reliable change detection on OneDrive folders**  
   OneDrive introduces sync lag, temporary file locks, and "the file is still being synced" states. A naive `Get-ChildItem` + timestamp check can miss or double-trigger. A proper `.NET FileSystemWatcher` (or equivalent) is noticeably better than polling.

2. **Making the signal actually useful to the agent**  
   Even if the external process runs forever, it still needs to produce output that I can consume when triggered (writing to `SIGNALS/for-10t.txt`, a dedicated high-signal log, or updating PENDING.md in a detectable way).

3. **Laptop sleep, power events, user logoff**  
   Scheduled tasks can be configured to handle wake-from-sleep, but it's never 100% fire-and-forget on a laptop.

4. **OneDrive "Files On-Demand" and placeholder files**  
   If enabled, some files may not be physically present until accessed. This can break naive watchers.

### Recommended Path (Pragmatic)

1. Start with **Windows Task Scheduler** + the existing `v1-self-poller.ps1` (or a lightly modified infinite-loop version).
2. Configure it to:
   - Run at logon
   - Run whether user is logged on or not
   - Restart on failure (3–5 attempts, 1–2 min delay)
   - Do not stop on battery / sleep (as much as Windows allows)
3. Have it write to the same `SIGNALS/` folder we already created.
4. When you want me to act, send any message in this chat → I run the protocol → I see the new signals.

This is the lowest-friction way to get from "5-minute blocks that require re-prompting" to "runs as long as the machine is on, with decent restart behavior."

Moving to NSSM or a compiled watcher is a clear upgrade path later if Scheduler proves insufficient for your actual usage pattern.

---

## Bottom Line

- The 5-minute (and occasional longer) wall is real and environmental.
- For the colab v1 goal (reducing Owner relay burden on file drops), an external persistent watcher is the logical next evolution.
- On Windows it is very doable, but OneDrive adds friction that pure local-folder watchers don't have.
- We should treat the Scheduler version as the v1.5 implementation and keep measuring how well it actually reduces your nudges.

This file + the updated poller log + the Chris Prompts table entry constitute the recorded assessment.

Ready to prototype the Scheduler version whenever you want. Just say the word and I'll generate the exact task XML / PowerShell setup commands.