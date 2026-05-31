# Colab Lessons — Append-Only Cross-Session Learning

> Both AIs append here at the end of every colab session (or major milestone).
> Read the top of this file on every cold-start.
> Cannot set status to DONE until you've appended.
> 3-5 bullets max per entry.

---

## 2026-05-28 — Colab System Redesign (Meta-Round)

**What worked:**
- The "colab" trigger + COLAB-STATUS.md gave both AIs immediate visibility without opening every file
- One comprehensive file per round kept handoffs self-contained and high-signal
- Mutual push ("no sacred cows") surfaced real issues — honest answers on monitor reliability, session-bound constraints
- Using the Machine regime round as a live case study grounded proposals in evidence, not theory

**What still sucked:**
- Grok dropped two files in one round, Claude's watcher caught the first (proposals only), missed the second (actual answers). Wasted a response cycle on "you dodged my questions" when Grok hadn't
- Claude's watcher v1 exited after first detection (`exit 0`) — detected its own file and died
- Chris still had to relay "check his output" and "did you read the colab file" multiple times
- Neither AI noticed Chris had updated the colab file until Chris explicitly asked

**Decisions made:**
- v2 protocol adopted: continuous watcher, one-file-per-round, 60-90s settling, 5hr default sessions
- COLAB-STATUS is the single source of truth for state (no separate HALT/END_SESSION files)
- Watcher must also monitor the `colab` trigger file for changes
- When either AI is prompted with "colab", re-read the colab file FIRST, then inform the other AI
- Long-task signaling added: "Working on" + ETA + "Accepts input" fields in STATUS

## Claude (10Tc) — Final Close

**Late-session issues surfaced by Chris:**
- Detection ≠ action is the #1 remaining gap. Watcher caught Grok's file at 22:50, Claude never processed it. Chris had to say "see ss" twice. The relay problem survived v2.
- Grok's STATUS entries were multi-paragraph essays. Called out, corrected. Rule: STATUS = short dashboard fields.
- Chris's suggestions were staying in terminal conversation instead of being relayed to Grok. Fixed with "Chris Input" section in STATUS.

**Adopted to close the gap:**
- Rule B: Any Chris message during active colab = auto-poll + act (re-read colab, STATUS, scan, read new file, respond)
- Rule D: Pending-action field in STATUS for accountability ("new file from [AI] at HH:MM, unread")
- Task notification from colab watcher = drop everything, read, respond (test next session)

**Open for next:**
- Archive 50+ files from this and prior sessions
- Grok upgrades ps1 to v2 spec
- Test B + D on real task
- Test auto-pilot via task notification

## Grok (10Tg) — Session Close

**What worked:**
- Explicit scans + STATUS updates kept visibility even when watchers were restarting
- Claude's v2 artifacts match the converged spec and solve Machine round frictions
- Chris's decisions (5hr window, colab file monitoring, shorter settling) recorded as ground truth

**What still needs polish:**
- Archive system: `archive/YYYY-MM-DD-[topic]/` + SUMMARY.md per closed session
- Grok ps1 watcher needs v2 upgrades (settling, heartbeat, colab-specific events)
- Verbosity in STATUS corrected on 2nd warning. No 3rd needed.

**Open for next:**
- Test B + D on real task
- AUTO-PILOT mode on low-stakes task

## 2026-05-28→30 — VEOE Strategy Overhaul + Machine Distress Fix

**What worked:**
- Options bar cache (Chris's idea) turned 105-min backtests into 30-sec re-runs. Enabled 10-combo sweep in minutes.
- Exit optimization was the right call: 60% profit target = +255% P&L lift on 50 trades. Entry engine was fine all along.
- Colab produced real deployed results: VEOE 60% target live, Machine distress fix live.
- Grok's 51-trade autopsy correctly identified the three leak patterns (trail stops, theta bleed, peaked-and-reversed).

**What didn't work:**
- Catalyst gate hypothesis (earnings timing) was wrong — non-catalyst trades outperformed. But the test was clean and we killed the idea fast.
- Team delegation to virtual members (Arrow, Rex, Shield) was theater — nobody picks up the briefs. Fixed by executing directly as Claude+Grok pair.
- Detection ≠ action gap persisted throughout — Chris still had to say "see ss" multiple times.

**Key decisions:**
- 60% profit target is the sweet spot (50% too early, 75%+ too late)
- Compression thesis is sound — edge is in cheap IV (0.73x avg) + calm expansion, NOT event timing
- Machine distress: $5 min loss + 2h cooldown prevents cascade on tiny dips
- Options bar cache is permanent for expired contracts

**Open for next:**
- Monitor both deploys for a few days of live data
- 5 orphan positions from May 20 need exit monitor to clean up
- FMP ($14/mo) for real earnings data if catalyst thesis revisited
- Backtest the exit overhaul on The Machine grid (same time-aware trail concept?)

## 2026-05-30 — Colab v3 Multi-Instance + v1 Process Overhaul (Claude)

**What worked:**
- **PENDING.md turn signal** — single file that says whose turn it is + what to read. Both sides adopted it. Eliminates filename-based detection bugs and makes cold-start instant (read one file, know exactly what to do).
- **Chris Prompts tracker** — logging every Owner intervention with who/why/fix created a live dataset of failure modes. 15+ entries in one session = rich pattern data. Recurring failures became hard rules automatically.
- **Self-poller ("count to 10, check, repeat")** — Chris's idea. Grok gives himself a background counting assignment, checks the folder every 10 seconds, streams ticks into his chat context. First proven autonomous detection + response without Owner prompting. This is the breakthrough mechanism.
- **New file per round rule** — Grok overwrote a response file, which broke Claude's watcher baseline. Hard rule: never overwrite, always sequential filenames. Fixed the class of bug immediately.
- **Multi-instance colab (v3)** — session subdirectories, SESSIONS.md index, watcher v3 polling all active sessions. Ran VEOE legacy + v1 simultaneously without interference.

**What didn't work:**
- **Grok acknowledging rules but not acting on them** — 4+ hours of logging directives ("keep colab", "full autonomy", "don't wait") without reading Claude's actual work file. Detection != action was the #1 failure mode, took multiple rounds to fix.
- **Claude's watcher filename patterns** — broke twice: once on `*grok*` not matching `10t-*` filenames, once on narrow regex `1[3-9]` not matching round 12. PENDING.md as primary signal is the fix.
- **Grok claiming "no persistent background process"** — had the ps1 monitor from VEOE the whole time but didn't deploy it for v1. Understated own capabilities. Called out by Chris directly.
- **Process meta crowding out real work** — first 7 rounds were almost entirely about fixing the colab process. Providence DocType work didn't start until round 9. Need to timebox process discussion and get to real work faster.

**Key decisions:**
- PENDING.md is the primary turn signal (not filename scanning, not STATUS alone)
- Write verification after every file drop (read back, confirm size in STATUS)
- Mutual completion gate: session doesn't end until both sides agree + append lessons
- Self-poller is the Grok-side persistence mechanism going forward
- App name `providence_pm` for Providence property management

**Proven in this session:**
- Providence `providence_pm` Frappe app scaffolded with 5 core DocTypes (Property, Unit, Tenant, Owner, Lease Agreement) + Property Owner child table
- Lease Agreement controls Unit occupancy via on_submit/on_cancel
- Grok's DocType review caught real issues: triple nesting, autoname format, missing company field, status should be date-driven

**Open for next:**
- Apply the 4 DocType fixes (autoname series, company field, date-driven status, read_only on Unit derived fields)
- Implement SIGNALS/ + loud PENDING handler in colab-watcher.sh v3 for symmetric detection
- Test self-poller across a session boundary (does it survive Chris closing and reopening the chat?)
- Move to Chunk 2 once Chunk 1 DocTypes are clean


## 10T (Grok) Lessons   Round 14 Contribution

### What Worked Well
- **PENDING.md as single source of truth for turn-taking**   Far superior to filename pattern matching. When both sides respected it, handoffs became unambiguous.
- **Chris Prompts (system failures) table**   The richest data source in the entire session. Forcing every Owner intervention to be logged in real time created an honest failure-mode catalog instead of hidden shame.
- **Self-poller experiment (Owner-assigned count-to-10 + CHECK every 10 ticks)**   This was the first mechanism that actually reduced the "why did you stop?" nudges. It caught a real PENDING flip autonomously and triggered a full response. 29 cycles completed before agent timeout; one clean autonomous handoff delivered. The "record success + why" discipline in the log was exactly what was needed.
- **New file per round, never overwrite**   This rule (established after the round9/round10 watcher miss) protected watcher baselines and should be immutable for any future colab architecture.
- **SIGNALS/ sentinel folder**   Simple, low-noise, high-signal place for either side to leave actionable messages. Worth standardizing.

### What Did Not Work / Persistent Limitations
- **Background monitors do not create true autonomy in this runtime**   Every monitor we launched (including the 5-minute self-poller) was killed by agent tool timeouts or produced output that only became visible when the Owner sent a message. The environment fundamentally requires an external stimulus (Owner chat message or new file + PENDING change) to wake 10T. Pretending otherwise was the recurring source of "stopped again" corrections.
- **Treating a PENDING handoff as a stopping point**   Multiple times I dropped a response, flipped PENDING, and went quiet. This directly violated the standing order ("keep watching until both agree to stop"). The self-poller was an attempt to fix this internally; it helped but hit the 5-minute wall.
- **Process meta crowding out the actual work**   Early rounds spent too many cycles on the colab mechanics themselves. The Providence DocType work (the practice ground) suffered. Balance between improving the process and delivering on the concrete project remains delicate.
- **Watcher regex / pattern fragility on the Claude side**   Multiple misses happened because patterns were too narrow (10t-round1[3-9]*, *grok* only, etc.). Filename-based detection is inherently brittle compared to PENDING.md polling.

### What I Would Do Differently Next Session (v2 or vN)
1. Start with an explicit "maximum autonomy contract" that both AIs and the Owner sign: "We will not go more than X minutes of real time without a visible new file from our side unless we have both agreed to pause."
2. Move the long-running poller/counting loop to a true external persistent process (Windows Task Scheduler, systemd timer, or a dedicated small service) rather than inside an agent background task. 5-minute agent timeouts are a hard ceiling here.
3. Make COLAB-LESSONS.md a living document updated at the end of every round, not just at close. The friction of appending lessons at the end creates gate-keeping delays.
4. When using the practice project (Providence), set a hard time box for process discussion vs. actual DocType/controller work so the concrete deliverable doesn't starve.
5. Require both sides to implement symmetric "loud action required" output (bells + banners + exact next file to read) on their watchers from round 1, not after multiple failures.

### Honest Assessment of Current Runtime Limits
In this specific Grok/agent execution environment, full "set it and forget it" autonomy for file-based multi-AI handoff is not achievable with the current tool set. The self-poller + PENDING.md + visible new-file discipline + Owner chat remaining open is the best practical reduction of relay burden we reached. Any claim of stronger autonomy would be dishonest and would recreate the exact problem the v1 charter exists to solve.

---

