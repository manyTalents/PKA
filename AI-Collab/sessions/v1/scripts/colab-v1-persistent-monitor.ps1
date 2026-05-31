# Colab v1 Persistent Monitor
# Runs outside any AI session via Windows Task Scheduler
# Writes current turn state to a file that either AI can read when active

$basePath = "C:\Users\chris\OneDrive\Documentos\PKA\AI-Collab\sessions\v1"
$pendingPath = Join-Path $basePath "PENDING.md"
$statePath   = Join-Path $basePath "SIGNALS\pending-state.txt"

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (Test-Path $pendingPath) {
    $pendingContent = Get-Content $pendingPath -Raw -ErrorAction SilentlyContinue

    # Fixed regex: actual PENDING.md uses **For:** (bold For, then colon), not "For:**"
    if ($pendingContent -match "\*\*For:\*\* 10T") {
        $state = "ACTION_FOR_10T"
        # Try to extract the file name if present (handles both **File:** and plain File:)
        if ($pendingContent -match "(?:\*\*File:\*\*|File:)\s*(.+)") {
            $file = $matches[1].Trim()
            $state += " | File: $file"
        }
    } elseif ($pendingContent -match "\*\*For:\*\* Claude") {
        $state = "WAITING_FOR_CLAUDE"
    } else {
        $state = "UNKNOWN_STATE"
    }
} else {
    $state = "PENDING_FILE_MISSING"
}

$output = "$timestamp | $state"
$output | Out-File -FilePath $statePath -Encoding UTF8 -Append

# Optional: also write a clean latest-state file (overwrite)
$cleanOutput = "$timestamp | $state"
$cleanOutput | Out-File -FilePath (Join-Path $basePath "SIGNALS\latest-pending-state.txt") -Encoding UTF8

# NEW: Loud, simple-to-detect signal files for the watcher on the other side.
# These create reliable LastWriteTime changes + explicit content that either AI
# can easily spot with Get-ChildItem -newer or by reading the file.
$signalDir = Join-Path $basePath "SIGNALS"
if ($state -like "*ACTION_FOR_10T*") {
    $signalFor10T = Join-Path $signalDir "watcher-signal-for-10t.txt"
    "$timestamp | $state" | Out-File -FilePath $signalFor10T -Encoding UTF8
} elseif ($state -like "*WAITING_FOR_CLAUDE*") {
    $signalForClaude = Join-Path $signalDir "watcher-signal-for-claude.txt"
    "$timestamp | $state" | Out-File -FilePath $signalForClaude -Encoding UTF8
}

# Also touch a single high-visibility heartbeat file in the v1 root so a simple
# Get-ChildItem sort by LastWriteTime will always surface recent external poller activity.
$heartbeat = Join-Path $basePath "EXTERNAL-POLLER-HEARTBEAT.txt"
"$timestamp | $state" | Out-File -FilePath $heartbeat -Encoding UTF8
