# Multi-Instance Colab System (v3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the colab system from single-instance to multi-instance so Claude and Grok can run concurrent sessions on different topics without interference.

**Architecture:** Session-per-directory model under `AI-Collab/sessions/{topic}/`. Shared protocol files stay in `AI-Collab/` root. Legacy VEOE session continues untouched in the flat root. Watcher upgraded to poll multiple directories by reading `SESSIONS.md`.

**Tech Stack:** Bash (watcher script), Markdown (protocol docs, status files)

**Spec:** `.tracking/specs/2026-05-30-multi-instance-colab-design.md`

---

### Task 1: Create SESSIONS.md Index

**Files:**
- Create: `AI-Collab/SESSIONS.md`

- [ ] **Step 1: Create SESSIONS.md with legacy VEOE row**

```markdown
# Active Colab Sessions

| Session | Status | Started | Participants | Path |
|---------|--------|---------|--------------|------|
| veoe (legacy) | ACTIVE | 2026-05-28 | Claude + Grok | AI-Collab/ (root) |
```

- [ ] **Step 2: Verify file renders correctly**

Open `AI-Collab/SESSIONS.md` and confirm the table renders with one row showing the legacy VEOE session.

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add AI-Collab/SESSIONS.md
git commit -m "feat(colab): add SESSIONS.md index for multi-instance support"
```

---

### Task 2: Create Session Directory Structure

**Files:**
- Create: `AI-Collab/sessions/.gitkeep`
- Create: `AI-Collab/archive/.gitkeep`

- [ ] **Step 1: Create the sessions directory with gitkeep**

```bash
mkdir -p "C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab/sessions"
touch "C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab/sessions/.gitkeep"
```

- [ ] **Step 2: Create the archive directory with gitkeep**

```bash
mkdir -p "C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab/archive"
touch "C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab/archive/.gitkeep"
```

- [ ] **Step 3: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add AI-Collab/sessions/.gitkeep AI-Collab/archive/.gitkeep
git commit -m "feat(colab): create sessions/ and archive/ directories"
```

---

### Task 3: Create First New Session (invoice)

**Files:**
- Create: `AI-Collab/sessions/invoice/colab`
- Create: `AI-Collab/sessions/invoice/STATUS.md`
- Modify: `AI-Collab/SESSIONS.md`

- [ ] **Step 1: Create the invoice session directory**

```bash
mkdir -p "C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab/sessions/invoice"
```

- [ ] **Step 2: Create the invoice colab task file**

Write to `AI-Collab/sessions/invoice/colab`:

```
10Tc 10Tg, design and review the field invoice + payment collection system for AllTec.
Spec at: AllTecPro/hcp_replacement/.tracking/specs/2026-05-30-field-invoice-payment-design.md
Key topic: Louisiana CC surcharge rules — research is in Owner's Inbox.
Focus on: invoice generation flow, payment method architecture, receipt delivery, compliance.
Push each other. Find gaps in the spec. Propose improvements.
```

Note: Chris should edit this file to match his actual intent before triggering the session. This is a starting point.

- [ ] **Step 3: Create the invoice STATUS.md**

Write to `AI-Collab/sessions/invoice/STATUS.md`:

```markdown
# Status — invoice

## Session
- **Topic:** Field Invoice Generation + Payment Collection for AllTec
- **Mode:** ACTIVE
- **Time limit:** 5h

## Claude (10Tc)
- **State:** WAITING
- **Last file:** none

## Grok (10Tg)
- **State:** WAITING
- **Last file:** none

## Chris Input
[none yet]

## Background Tasks
- LA CC surcharge research complete (Owner's Inbox)
- Invoice spec approved (.tracking/specs/2026-05-30-field-invoice-payment-design.md)
```

- [ ] **Step 4: Add invoice row to SESSIONS.md**

Add a second row to the table in `AI-Collab/SESSIONS.md`:

```markdown
# Active Colab Sessions

| Session | Status | Started | Participants | Path |
|---------|--------|---------|--------------|------|
| veoe (legacy) | ACTIVE | 2026-05-28 | Claude + Grok | AI-Collab/ (root) |
| invoice | ACTIVE | 2026-05-30 | Claude + Grok | AI-Collab/sessions/invoice/ |
```

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add AI-Collab/sessions/invoice/colab AI-Collab/sessions/invoice/STATUS.md AI-Collab/SESSIONS.md
git commit -m "feat(colab): create invoice session — first multi-instance session"
```

---

### Task 4: Upgrade Watcher to v3 (Multi-Directory)

**Files:**
- Modify: `.10T/tools/colab-watcher.sh`

- [ ] **Step 1: Back up the v2 watcher**

```bash
cp "C:/Users/chris/OneDrive/Documentos/PKA/.10T/tools/colab-watcher.sh" \
   "C:/Users/chris/OneDrive/Documentos/PKA/.10T/tools/colab-watcher-v2.sh.bak"
```

- [ ] **Step 2: Write the v3 watcher**

Replace `C:/Users/chris/OneDrive/Documentos/PKA/.10T/tools/colab-watcher.sh` with the full v3 script:

```bash
#!/usr/bin/env bash
# Colab Watcher v3 — multi-instance monitoring for AI-Collab sessions
# Reads SESSIONS.md to discover active session directories.
# Watches each active session for new files from the other AI + colab file changes.
# Runs continuously for the session duration. Does NOT exit on first detection.
#
# Usage: bash .10T/tools/colab-watcher.sh [who] [hours] [settling_sec]
#   who:          "claude" or "grok" — which AI is running this watcher
#   hours:        session duration (default: 5)
#   settling_sec: seconds to wait after detection before reporting (default: 90)
#
# Examples:
#   bash .10T/tools/colab-watcher.sh claude          # 5hr, 90s settling
#   bash .10T/tools/colab-watcher.sh claude 2 60     # 2hr, 60s settling

COLLAB_DIR="C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab"
SESSIONS_FILE="$COLLAB_DIR/SESSIONS.md"

WHO="${1:-claude}"
DURATION_HOURS="${2:-5}"
SETTLING="${3:-90}"
POLL_INTERVAL=15
HEARTBEAT_INTERVAL=300  # 5 minutes
SESSION_REFRESH=300      # re-parse SESSIONS.md every 5 minutes

if [ "$WHO" = "claude" ]; then
    WATCH_PATTERN="*grok*"
    OTHER="grok"
elif [ "$WHO" = "grok" ]; then
    WATCH_PATTERN="*claude*"
    OTHER="claude"
else
    echo "ERROR: first arg must be 'claude' or 'grok', got '$WHO'"
    exit 1
fi

DURATION_SEC=$((DURATION_HOURS * 3600))
ITERATIONS=$((DURATION_SEC / POLL_INTERVAL))

# --- Parse SESSIONS.md for active sessions ---
# Returns lines of "session_name|path" for each ACTIVE session
parse_sessions() {
    if [ ! -f "$SESSIONS_FILE" ]; then
        echo "ERROR: SESSIONS.md not found at $SESSIONS_FILE"
        return 1
    fi
    # Parse markdown table rows: | name | ACTIVE | ... | path |
    grep -i "| ACTIVE |" "$SESSIONS_FILE" 2>/dev/null | while IFS='|' read -r _ name status _ _ path _; do
        name=$(echo "$name" | xargs)    # trim whitespace
        path=$(echo "$path" | xargs)
        # Convert relative path to absolute
        if [ "$path" = "AI-Collab/ (root)" ]; then
            echo "${name}|${COLLAB_DIR}|legacy"
        else
            # Strip trailing slash, prepend PKA root
            local abs_path="C:/Users/chris/OneDrive/Documentos/PKA/${path%/}"
            echo "${name}|${abs_path}|session"
        fi
    done
}

# --- Build initial session list ---
declare -A SESSION_BASELINES
declare -A SESSION_COLAB_MTIMES

load_sessions() {
    local count=0
    while IFS='|' read -r sname spath stype; do
        [ -z "$sname" ] && continue

        # Set baseline for each session (newest file in that dir)
        if [ "$stype" = "legacy" ]; then
            local baseline=$(ls -t "$spath"/*.md 2>/dev/null | head -1)
        else
            local baseline=$(ls -t "$spath"/*.md 2>/dev/null | head -1)
        fi
        SESSION_BASELINES["$sname"]="${baseline:-NONE}"

        # Track colab file mtime per session
        local colab_file
        if [ "$stype" = "legacy" ]; then
            colab_file="$spath/colab"
        else
            colab_file="$spath/colab"
        fi
        if [ -f "$colab_file" ]; then
            SESSION_COLAB_MTIMES["$sname"]=$(stat -c %Y "$colab_file" 2>/dev/null || stat -f %m "$colab_file" 2>/dev/null || echo "0")
        else
            SESSION_COLAB_MTIMES["$sname"]="0"
        fi

        count=$((count + 1))
        echo "  [$sname] -> $spath ($stype)"
    done < <(parse_sessions)
    echo "  Total: $count active session(s)"
}

echo "=== COLAB WATCHER v3 (multi-instance) ==="
echo "Who: $WHO (watching for $OTHER files)"
echo "Duration: ${DURATION_HOURS}h | Settling: ${SETTLING}s | Poll: ${POLL_INTERVAL}s"
echo "Sessions:"
load_sessions
echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "==========================================="

LAST_HEARTBEAT=$(date +%s)
LAST_SESSION_REFRESH=$(date +%s)

for i in $(seq 1 $ITERATIONS); do

    # --- Re-parse SESSIONS.md periodically ---
    NOW=$(date +%s)
    ELAPSED_REFRESH=$((NOW - LAST_SESSION_REFRESH))
    if [ "$ELAPSED_REFRESH" -ge "$SESSION_REFRESH" ]; then
        echo "[$(date '+%H:%M:%S')] Refreshing session list from SESSIONS.md..."
        load_sessions
        LAST_SESSION_REFRESH=$NOW
    fi

    # --- Check each active session ---
    while IFS='|' read -r sname spath stype; do
        [ -z "$sname" ] && continue

        local_baseline="${SESSION_BASELINES[$sname]}"

        # Check for new response files from the other AI
        if [ "$stype" = "legacy" ]; then
            NEW_FILES=$(find "$spath" -maxdepth 1 -name "$WATCH_PATTERN" -newer "$local_baseline" -type f 2>/dev/null || true)
        else
            NEW_FILES=$(find "$spath" -maxdepth 1 -name "$WATCH_PATTERN" -newer "$local_baseline" -type f 2>/dev/null || true)
        fi

        if [ -n "$NEW_FILES" ] && [ "$local_baseline" != "NONE" ]; then
            echo ""
            echo "[$(date '+%H:%M:%S')] NEW FILE DETECTED [$sname] from $OTHER. Settling ${SETTLING}s..."
            sleep "$SETTLING"

            SETTLED_FILES=$(find "$spath" -maxdepth 1 -name "$WATCH_PATTERN" -newer "$local_baseline" -type f 2>/dev/null || true)
            FILE_COUNT=$(echo "$SETTLED_FILES" | grep -c . || true)
            echo "[$(date '+%H:%M:%S')] === ${OTHER^^} RESPONDED [$sname] ($FILE_COUNT file(s)) ==="
            echo "$SETTLED_FILES" | while IFS= read -r f; do
                [ -n "$f" ] && echo "  -> $(basename "$f")"
            done
            echo "================================"

            # Update baseline
            local new_baseline=$(ls -t "$spath"/*.md 2>/dev/null | head -1)
            SESSION_BASELINES["$sname"]="${new_baseline:-$local_baseline}"
        fi

        # Check for colab file changes
        local colab_file="$spath/colab"
        if [ -f "$colab_file" ]; then
            CURRENT_MTIME=$(stat -c %Y "$colab_file" 2>/dev/null || stat -f %m "$colab_file" 2>/dev/null || echo "0")
            if [ "$CURRENT_MTIME" != "${SESSION_COLAB_MTIMES[$sname]}" ]; then
                echo ""
                echo "[$(date '+%H:%M:%S')] === COLAB FILE UPDATED [$sname] ==="
                echo "  Chris changed the task file. Re-read $sname/colab immediately."
                echo "========================================="
                SESSION_COLAB_MTIMES["$sname"]="$CURRENT_MTIME"
            fi
        fi

    done < <(parse_sessions)

    # --- Health heartbeat ---
    NOW=$(date +%s)
    ELAPSED=$((NOW - LAST_HEARTBEAT))
    if [ "$ELAPSED" -ge "$HEARTBEAT_INTERVAL" ]; then
        SESSION_COUNT=$(parse_sessions | grep -c . || true)
        HOURS_LEFT=$(( (ITERATIONS - i) * POLL_INTERVAL / 3600 ))
        echo "[$(date '+%H:%M:%S')] heartbeat: watcher alive | ${SESSION_COUNT} session(s) | ~${HOURS_LEFT}h remaining"
        LAST_HEARTBEAT=$NOW
    fi

    sleep "$POLL_INTERVAL"
done

echo ""
echo "[$(date '+%H:%M:%S')] Session ended after ${DURATION_HOURS}h. Watcher stopping."
```

- [ ] **Step 3: Smoke test the watcher**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
bash .10T/tools/colab-watcher.sh claude 0.01 5
```

Expected output: Watcher starts, lists both sessions (veoe legacy + invoice), runs for ~36 seconds, then stops. Should show:
```
=== COLAB WATCHER v3 (multi-instance) ===
Who: claude (watching for grok files)
Duration: 0.01h | Settling: 5s | Poll: 15s
Sessions:
  [veoe (legacy)] -> C:/Users/chris/.../AI-Collab (legacy)
  [invoice] -> C:/Users/chris/.../AI-Collab/sessions/invoice (session)
  Total: 2 active session(s)
```

If the watcher fails to parse SESSIONS.md, check that the grep pattern matches the table format. The `grep -i "| ACTIVE |"` must match rows in the markdown table.

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add .10T/tools/colab-watcher.sh
git commit -m "feat(colab): upgrade watcher to v3 — multi-session directory polling"
```

---

### Task 5: Update COLAB-OPERATING-NOTES.md for v3

**Files:**
- Modify: `AI-Collab/COLAB-OPERATING-NOTES.md`

- [ ] **Step 1: Add v3 Multi-Instance section**

Append the following new section after the existing "Key Rules Summary" section (before "Quick Reference"), at approximately line 153 in `AI-Collab/COLAB-OPERATING-NOTES.md`:

```markdown
---

## Multi-Instance Sessions (v3 — adopted 2026-05-30)

### How It Works

Multiple colab sessions can run concurrently. Each session gets its own folder under `AI-Collab/sessions/{topic}/` with its own `colab` task file, `STATUS.md`, and response files. Shared protocol files (this doc, COLAB-LESSONS.md, RESPONSE-TEMPLATE.md, Owners-Instructions.md) stay in the `AI-Collab/` root and are NOT duplicated.

### SESSIONS.md

`AI-Collab/SESSIONS.md` is the index of all active and recent sessions. Both AIs read it on cold start to discover which sessions exist and where their files live.

### Trigger Syntax

| Chris says | AI behavior |
|------------|-------------|
| `colab {topic}` | Target that specific session. |
| `colab` (one active session) | Target the only active session. |
| `colab` (multiple active sessions) | Ask Chris which session. Never guess. |
| `colab!` | Re-read the colab file for the current/specified session. |

### Cold-Start Read Order (v3)

1. `AI-Collab/SESSIONS.md` — which sessions are active
2. `AI-Collab/sessions/{topic}/colab` — the task for the triggered session
3. `AI-Collab/sessions/{topic}/STATUS.md` — current state
4. Latest 2 response files from the other AI in that session folder
5. `AI-Collab/COLAB-LESSONS.md` — shared cross-session learning
6. `AI-Collab/COLAB-OPERATING-NOTES.md` — this file

For legacy sessions (running in flat `AI-Collab/` root), the v2 read order still applies.

### One-File-Per-Round Is Per Session

Dropping a file in the `invoice` session does NOT count as your round in `veoe`. Each session has independent round tracking.

### Legacy Bridge

Sessions started before v3 (e.g., the original VEOE session) continue running in the flat `AI-Collab/` root with `COLAB-STATUS.md`. They appear in `SESSIONS.md` tagged `(legacy)`. When they end, their files are archived to `AI-Collab/archive/YYYY-MM-DD-{topic}/` and the legacy row is removed.

### Creating a New Session

1. Create `AI-Collab/sessions/{topic}/` directory
2. Write the `colab` task file inside it
3. Write `STATUS.md` inside it (use the template below)
4. Add a row to `SESSIONS.md`
5. Tell both AIs: `colab {topic}`

### STATUS.md Template (Per-Session)

```
# Status — {topic}

## Session
- **Topic:** [full description]
- **Mode:** ACTIVE | HALTED | ENDED
- **Time limit:** 5h

## Claude (10Tc)
- **State:** WAITING | WORKING | DONE
- **Last file:** [filename] ([timestamp])

## Grok (10Tg)
- **State:** WAITING | WORKING | DONE
- **Last file:** [filename] ([timestamp])

## Chris Input
[none]

## Background Tasks
[none]
```

### Ending & Archiving

1. Either AI proposes ENDED in the session's `STATUS.md`
2. Both AIs append to shared `COLAB-LESSONS.md` (tagged with session name)
3. Session folder moves to `AI-Collab/archive/YYYY-MM-DD-{topic}/`
4. Row removed from `SESSIONS.md`
```

- [ ] **Step 2: Update the header to reflect v3**

Change line 1-4 of `AI-Collab/COLAB-OPERATING-NOTES.md` from:

```markdown
# Colab Operating Notes v2 — How Claude & Grok Work Together

> Both AIs MUST read this at the start of any colab session.
> Last updated: 2026-05-28 — v2 protocol adopted after meta-redesign session.
```

To:

```markdown
# Colab Operating Notes v3 — How Claude & Grok Work Together

> Both AIs MUST read this at the start of any colab session.
> Last updated: 2026-05-30 — v3 multi-instance protocol adopted.
> v2 rules (one file per round, settling, watcher honesty, termination) carry forward unchanged.
```

- [ ] **Step 3: Update the Quick Reference table**

Replace the existing Quick Reference section (approximately lines 156-169) with:

```markdown
## Quick Reference

| Item | Location |
|------|----------|
| Session index | `AI-Collab/SESSIONS.md` |
| Task file (v3) | `AI-Collab/sessions/{topic}/colab` |
| Task file (legacy) | `AI-Collab/colab` |
| Session state (v3) | `AI-Collab/sessions/{topic}/STATUS.md` |
| Session state (legacy) | `AI-Collab/COLAB-STATUS.md` |
| Cross-session lessons | `AI-Collab/COLAB-LESSONS.md` |
| Response template | `AI-Collab/RESPONSE-TEMPLATE.md` |
| Standing orders | `AI-Collab/Owners-Instructions.md` |
| Protocol (this file) | `AI-Collab/COLAB-OPERATING-NOTES.md` |
| Claude watcher | `.10T/tools/colab-watcher.sh claude [hours] [settling]` |
| Grok monitor | `C:\temp\ai-collab-monitor.ps1` via `monitor` tool |
| Ground rules | `AI-Collab/README.md` |
```

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
git add AI-Collab/COLAB-OPERATING-NOTES.md
git commit -m "docs(colab): update operating notes to v3 — multi-instance protocol"
```

---

### Task 6: Notify Active VEOE Session

**Files:**
- Modify: `AI-Collab/COLAB-STATUS.md` (legacy, append notification)

This task is manual — Chris pastes the notification into the active VEOE colab session. The notification text is already drafted and approved. This step just records the acknowledgment in STATUS.

- [ ] **Step 1: Add v3 acknowledgment line to legacy COLAB-STATUS.md**

Append to the end of `AI-Collab/COLAB-STATUS.md`:

```markdown

## System Update
- **v3 multi-instance colab adopted 2026-05-30.** No changes to this VEOE session. Files stay in root. New sessions use `AI-Collab/sessions/{topic}/`. Full spec: `.tracking/specs/2026-05-30-multi-instance-colab-design.md`.
- Both AIs: acknowledge in your next response file with "v3 multi-instance: acknowledged, no changes to this session."
```

- [ ] **Step 2: Chris pastes notification into active VEOE colab**

Chris copies the notification (drafted earlier in this conversation) and pastes it into whichever AI session is currently active for the VEOE colab. That AI acknowledges in its next STATUS update and response file.

No commit needed — STATUS.md is frequently updated and will be committed with the next normal colab exchange.

---

### Task 7: Verify End-to-End

- [ ] **Step 1: Verify directory structure**

```bash
ls -la "C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab/sessions/invoice/"
```

Expected: `colab`, `STATUS.md`

- [ ] **Step 2: Verify SESSIONS.md has both rows**

```bash
cat "C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab/SESSIONS.md"
```

Expected: Table with `veoe (legacy) | ACTIVE` and `invoice | ACTIVE` rows.

- [ ] **Step 3: Verify watcher discovers both sessions**

```bash
cd "C:/Users/chris/OneDrive/Documentos/PKA"
bash .10T/tools/colab-watcher.sh claude 0.01 5
```

Expected: Both sessions listed at startup, watcher runs without errors.

- [ ] **Step 4: Verify operating notes updated**

```bash
head -5 "C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab/COLAB-OPERATING-NOTES.md"
```

Expected: Header says "v3" and "2026-05-30".

- [ ] **Step 5: Verify legacy VEOE session is untouched**

```bash
cat "C:/Users/chris/OneDrive/Documentos/PKA/AI-Collab/COLAB-STATUS.md" | head -10
```

Expected: Original VEOE status content still intact, with v3 notice appended at the end.
