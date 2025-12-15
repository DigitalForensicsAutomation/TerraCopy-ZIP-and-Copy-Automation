 # ====================== EXECUTION POLICY  ====================== 
set-executionpolicy remotesigned

 # ====================== CONFIGURATION ======================
$WatchFolder     = "C:\transfer\WatchFolder"
$TempFolder      = "C:\transfer\Temp7z"
$TargetPath      = "C:\transfer\target"
$CompletedFolder = "C:\transfer\completed"
$FailedFolder    = "C:\transfer\transferfailed"
$LogFolder       = "C:\transfer\log"
$SplitSize       = "5g"
$SevenZip        = "C:\Program Files\7-Zip\7z.exe"
$TeraCopy        = "C:\Program Files\TeraCopy\TeraCopy.exe"
# ===========================================================

Write-Host "`n Direct Folder Backup Robot (PowerShell Version) - ACTIVE" -ForegroundColor Cyan
Write-Host " ==========================================================="
Write-Host " Watching     : $WatchFolder"
Write-Host " Temp         : $TempFolder"
Write-Host " Target       : $TargetPath"
Write-Host " Completed    : $CompletedFolder"
Write-Host " Failed       : $FailedFolder"
Write-Host " Logs         : $LogFolder"
Write-Host " Split size   : $SplitSize"
Write-Host "`n Drop any file or folder — it will be processed automatically"
Write-Host "===========================================================`n"

# ---------------- Ensure folders exist ----------------
$folders = @($WatchFolder, $TempFolder, $CompletedFolder, $FailedFolder, $LogFolder)
foreach ($f in $folders) {
    if (-not (Test-Path $f)) {
        New-Item -ItemType Directory -Path $f | Out-Null
    }
}

# ---------------- File-Lock Check ----------------
function Test-FileLocked {
    param([string]$Path)

    try {
        $stream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        if ($stream) { $stream.Close() }
        return $false   # Not locked
    } catch {
        return $true    # Locked
    }
}

# ---------------- Timestamp function ----------------
function Get-Timestamp {
    return (Get-Date).ToString("yyyyMMddHHmmss")
}

# ====================================================
#                    MAIN LOOP
# ====================================================

while ($true) {

    $items = Get-ChildItem -LiteralPath $WatchFolder | Where-Object {
        $_.Name -notlike ".*"
    }

    if ($items.Count -eq 0) {
        Start-Sleep -Seconds 10
        continue
    }

    foreach ($item in $items) {

        $name = $item.Name
        $full = $item.FullName

        # Skip if already processed
        if (Test-Path "$CompletedFolder\$name") { continue }
        if (Test-Path "$FailedFolder\$name")    { continue }

        # Skip if file is still being copied
        if (-not $item.PSIsContainer) {
            if (Test-FileLocked -Path $full) {
                continue
            }
        }

        Write-Host "`n Processing: $name  [$(Get-Date)]" -ForegroundColor Yellow

        # -----------------------------------------------------
        #                     ZIP PHASE
        # -----------------------------------------------------
        $timestamp = Get-Timestamp
        $zipBase = Join-Path $TempFolder "$name`_$timestamp.zip"

        # Clean temp folder
        Remove-Item "$TempFolder\*" -Force -Recurse -ErrorAction Ignore

        Write-Host "   Compressing with 7-Zip..."

        $zipArgs = @(
            "a", "-tzip", "-mx0",
            "`"$zipBase`"", # final zip file
            "`"$full`"",    # source folder/file
            "-v$SplitSize"
        )

        $zipProcess = Start-Process -FilePath $SevenZip -ArgumentList $zipArgs -Wait -PassThru -NoNewWindow

        if ($zipProcess.ExitCode -ne 0) {
            Write-Host "   ❌ 7-Zip failed → moving to FAILED" -ForegroundColor Red
            Move-Item -LiteralPath $full -Destination $FailedFolder -Force
            continue
        }

        # -----------------------------------------------------
        #                 COPY PHASE (TeraCopy)
        # -----------------------------------------------------
        Write-Host "   Copying via TeraCopy..."

        $logFile = Join-Path $LogFolder "$name`_$timestamp.log"

        $tcArgs = @(
            "Copy",
            "`"$TempFolder`"",
            "`"$TargetPath`"",
            "/SkipAll",
            "/LogFile=$logFile",
            "/Close"
        )

        $tcProcess = Start-Process -FilePath $TeraCopy -ArgumentList $tcArgs -Wait -PassThru -NoNewWindow

        if ($tcProcess.ExitCode -ne 0) {
            Write-Host "   ❌ TeraCopy failed → moving to FAILED" -ForegroundColor Red
            Move-Item -LiteralPath $full -Destination $FailedFolder -Force
            continue
        }

        # -----------------------------------------------------
        #                 SUCCESS
        # -----------------------------------------------------
        Write-Host "   ✅ SUCCESS → moved to COMPLETED" -ForegroundColor Green
        Move-Item -LiteralPath $full -Destination $CompletedFolder -Force
    }

    Start-Sleep -Seconds 5
}
