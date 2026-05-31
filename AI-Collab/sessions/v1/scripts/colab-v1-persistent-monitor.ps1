# Colab v1 Persistent Monitor
# Runs outside any AI session via Windows Task Scheduler
# Writes current turn state to a file that either AI can read when active

$basePath = "C:\Users\chris\OneDrive\Documentos\PKA\AI-Collab\sessions\v1"
$pendingPath = Join-Path $basePath "PENDING.md"
$statePath   = Join-Path $basePath "SIGNALS\pending-state.txt"

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if (Test-Path $pendingPath) {
    $pendingContent = Get-Content $pendingPath -Raw -ErrorAction SilentlyContinue

    if ($pendingContent -match "For:\*\* 10T") {
        $state = "ACTION_FOR_10T"
        # Try to extract the file name if present
        if ($pendingContent -match "File:\*\* (.+)") {
            $file = $matches[1].Trim()
            $state += " | File: $file"
        }
    } elseif ($pendingContent -match "For:\*\* Claude") {
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
