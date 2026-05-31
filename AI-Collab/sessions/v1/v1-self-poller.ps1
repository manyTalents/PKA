$logPath = 'C:\Users\chris\OneDrive\Documentos\PKA\AI-Collab\sessions\v1\SIGNALS\v1-self-poller.log'
"=== V1 SELF-POLLER STARTED: $(Get-Date) ===" | Out-File $logPath -Append

$maxCycles = 100
$cycle = 0

while ($cycle -lt $maxCycles) {
    $cycle++

    for ($i = 1; $i -le 10; $i++) {
        Write-Output "V1-POLLER TICK $i/10 | Cycle $cycle/$maxCycles | $(Get-Date -Format 'HH:mm:ss')"
        Start-Sleep -Seconds 1
    }

    Write-Output "V1-POLLER CHECK START | Cycle $cycle"

    $recentFiles = Get-ChildItem 'C:\Users\chris\OneDrive\Documentos\PKA\AI-Collab\sessions\v1' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 6 |
        ForEach-Object { "$($_.Name) | $($_.LastWriteTime)" }

    $recentFiles | Write-Output

    if (Test-Path 'C:\Users\chris\OneDrive\Documentos\PKA\AI-Collab\sessions\v1\PENDING.md') {
        $pendingContent = Get-Content 'C:\Users\chris\OneDrive\Documentos\PKA\AI-Collab\sessions\v1\PENDING.md' -Raw
        "PENDING: $pendingContent" | Write-Output
    }

    Write-Output "V1-POLLER CHECK END | Cycle $cycle"

    "=== POLLER CYCLE $cycle LOGGED AT $(Get-Date) ===" | Out-File $logPath -Append
}

Write-Output "V1-POLLER: $maxCycles cycles completed."
