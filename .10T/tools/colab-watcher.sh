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
PKA_ROOT="C:/Users/chris/OneDrive/Documentos/PKA"

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

# Support fractional hours via awk for testing (e.g., 0.01)
DURATION_SEC=$(awk "BEGIN {printf \"%d\", $DURATION_HOURS * 3600}")
ITERATIONS=$((DURATION_SEC / POLL_INTERVAL))
if [ "$ITERATIONS" -lt 1 ]; then ITERATIONS=1; fi

# --- Parse SESSIONS.md for active sessions ---
# Outputs lines of "session_name|absolute_path" for each ACTIVE session
parse_sessions() {
    if [ ! -f "$SESSIONS_FILE" ]; then
        echo "ERROR: SESSIONS.md not found at $SESSIONS_FILE" >&2
        return 1
    fi
    grep -i "| ACTIVE |" "$SESSIONS_FILE" 2>/dev/null | while IFS='|' read -r _ name status _ _ path _; do
        name=$(echo "$name" | xargs)
        path=$(echo "$path" | xargs)
        if [ "$path" = "AI-Collab/ (root)" ]; then
            echo "${name}|${COLLAB_DIR}"
        else
            echo "${name}|${PKA_ROOT}/${path%/}"
        fi
    done
}

# --- Initialize baselines for all active sessions ---
# Stores baselines and colab mtimes in temp files (bash 3 compat)
BASELINE_DIR=$(mktemp -d)
MTIME_DIR=$(mktemp -d)
trap "rm -rf $BASELINE_DIR $MTIME_DIR" EXIT

init_session() {
    local sname="$1"
    local spath="$2"

    # Baseline: newest .md file in session dir
    local baseline
    baseline=$(ls -t "$spath"/*.md 2>/dev/null | head -1)
    echo "${baseline:-NONE}" > "$BASELINE_DIR/$sname"

    # Colab file mtime
    local colab_file="$spath/colab"
    if [ -f "$colab_file" ]; then
        local mtime
        mtime=$(stat -c %Y "$colab_file" 2>/dev/null || stat -f %m "$colab_file" 2>/dev/null || echo "0")
        echo "$mtime" > "$MTIME_DIR/$sname"
    else
        echo "0" > "$MTIME_DIR/$sname"
    fi
}

load_sessions() {
    local count=0
    while IFS='|' read -r sname spath; do
        [ -z "$sname" ] && continue
        init_session "$sname" "$spath"
        echo "  [$sname] -> $spath"
        count=$((count + 1))
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
    while IFS='|' read -r sname spath; do
        [ -z "$sname" ] && continue

        local_baseline=$(cat "$BASELINE_DIR/$sname" 2>/dev/null)

        # Check for new response files from the other AI
        if [ -n "$local_baseline" ] && [ "$local_baseline" != "NONE" ]; then
            NEW_FILES=$(find "$spath" -maxdepth 1 -name "$WATCH_PATTERN" -newer "$local_baseline" -type f 2>/dev/null || true)
        else
            NEW_FILES=""
        fi

        if [ -n "$NEW_FILES" ]; then
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
            new_baseline=$(ls -t "$spath"/*.md 2>/dev/null | head -1)
            echo "${new_baseline:-$local_baseline}" > "$BASELINE_DIR/$sname"
        fi

        # Check for colab file changes
        colab_file="$spath/colab"
        if [ -f "$colab_file" ]; then
            CURRENT_MTIME=$(stat -c %Y "$colab_file" 2>/dev/null || stat -f %m "$colab_file" 2>/dev/null || echo "0")
            SAVED_MTIME=$(cat "$MTIME_DIR/$sname" 2>/dev/null || echo "0")
            if [ "$CURRENT_MTIME" != "$SAVED_MTIME" ]; then
                echo ""
                echo "[$(date '+%H:%M:%S')] === COLAB FILE UPDATED [$sname] ==="
                echo "  Chris changed the task file. Re-read $sname/colab immediately."
                echo "========================================="
                echo "$CURRENT_MTIME" > "$MTIME_DIR/$sname"
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
