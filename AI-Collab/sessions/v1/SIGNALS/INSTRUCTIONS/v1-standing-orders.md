# V1 STANDING ORDERS / SELF-INSTRUCTION FILE
# This file contains persistent behavioral instructions for 10T (Grok) in the v1 colab session.
# On every execution of the Auto-Detection Protocol (triggered by any Owner message in this chat
# or by output from a running poller/monitor), re-read this file and treat its contents as
# active standing orders / embedded prompts.

# Primary Self-Polling Assignment (Owner-designed "count to 10" method)
# --------------------------------------------------------------------
# Give yourself the following assignment and execute it:
# - Count from 1 to 10, printing one integer per second (1 second real-time delay between numbers).
# - After every 10 ticks (i.e., every ~10 seconds), perform a full check:
#     - List the most recently modified files in AI-Collab/sessions/v1/
#     - Read the current content of PENDING.md
#     - Optionally read the latest relevant sections of STATUS.md
# - If the check reveals something new (new file from Claude, PENDING flipped to 10T, etc.):
#     - Take the appropriate action via the v1 architecture (drop a new visible 10t-*.md file,
#       update PENDING/STATUS as needed).
#     - Explicitly record the success + reason in SIGNALS/v1-self-poller.log
#     - Restart the count from 1.
# - If nothing new was found:
#     - Explicitly record "no new drop - continuing" + timestamp in the log.
#     - Restart the count from 1.
# - Target: Run this loop for at least 100 cycles per launch when possible.
# - Goal: Reduce the need for the Owner to manually say "check" or "respond to c" by creating
#   an internal, self-restarting detection + action loop.

# Additional Standing Rules (to be followed whenever this file is read)
# --------------------------------------------------------------------
# - Always follow the one-file-per-significant-update rule (never overwrite previous response files).
# - Log every Owner intervention in the Chris Prompts table in STATUS.md.
# - Keep the folder visibly active with new files on triggers.
# - Be honest in all recordings about runtime limitations (e.g., background tasks getting killed).
# - When the self-poller mechanism is active, prefer using output from it as the trigger for action.
#
# Detection Signal Hierarchy (updated after "you are missing them again" root cause fix)
# --------------------------------------------------------------------
# On every Auto-Detection Protocol run, explicitly check (in this order):
# 1. PENDING.md (primary source of truth for current assignee + file).
# 2. SIGNALS/latest-pending-state.txt (written by the external Task Scheduler poller).
# 3. SIGNALS/watcher-signal-for-10t.txt or watcher-signal-for-claude.txt (loud explicit signals created by the external poller on flips).
# 4. EXTERNAL-POLLER-HEARTBEAT.txt in the v1 root (simple LastWriteTime beacon updated every 30s by the external poller).
# 5. Get-ChildItem on the v1 folder sorted by LastWriteTime -Descending (top 10-15) to catch any new drops the signal files may have missed due to OneDrive lag.
# This multi-signal approach was added because the original external poller regex was broken and single-signal reliance repeatedly caused missed handoffs.

# How to Use This File
# --------------------
# This file is the durable, re-readable version of the Owner's original "count to 10" assignment.
# On future protocol runs or poller launches, re-read this file to reload the behavioral instructions
# without the Owner having to re-paste the full prompt.

# Version / Last Updated
# ----------------------
# Created: 2026-05-30 in response to Owner request to embed the polling prompt in a file for persistence.
# Last modified: 2026-05-30

# End of standing orders
