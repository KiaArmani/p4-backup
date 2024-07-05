# Paths for logging and backup directories
$logFile = "C:\YourDestination\backup.log"
$backupRoot = "B:\YourBackupLocation\"

# Configurable variable to enable/disable console output
$printToConsole = $true

# Feel free to replace this with however you want to get the P4ROOT
$p4Root = $env:P4ROOT
if (-not $p4Root) {
    Write-Log "P4ROOT environment variable is not set."
    exit 1
}

# Function to write to log file and optionally print to console
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    $logMessage | Out-File -FilePath $logFile -Append

    if ($printToConsole) {
        Write-Host $logMessage
    }
}

# Step 0:
# Delete old checkpoints as we only need the latest one in case of a restore
$checkpointFiles = Get-ChildItem -Path $p4Root -Filter "checkpoint.*" | Where-Object { $_.Extension -ne ".md5" }
foreach ($file in $checkpointFiles) {
    Remove-Item -Path $file.FullName -Force
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Removed checkpoint file: $file.Name"
    } else {
        Write-Log "Failed to remove checkpoint file: $file.Name"
    }
}


# Step 1: Create a checkpoint
Write-Log "Creating a checkpoint"

# Pushing into P4ROOT because otherwise it creates just empty files
Push-Location -Path $p4Root
$p4dCheckpointOutput = & p4d -jc 2>&1
Pop-Location

if ($LASTEXITCODE -ne 0) {
    Write-Log "Checkpoint creation failed: $p4dCheckpointOutput"
} else {
    Write-Log "Checkpoint created successfully"
}

# Step 2: Check the MD5 checksum of the created checkpoint file
# Find the checkpoint file with the highest number suffix
$checkpointFile = Get-ChildItem -Path $p4Root -Filter "checkpoint.*" | Where-Object { $_.Extension -ne ".md5" } | Sort-Object Name -Descending | Select-Object -First 1
if ($checkpointFile -eq $null) {
    Write-Log "No checkpoint file found."
    exit 1
}
$checkpointFilePath = $checkpointFile.FullName
$md5FilePath = "$checkpointFilePath.md5"

# Check if MD5 of file matches the file
Write-Log "Verifying MD5 checksum of $checkpointFilePath"
$md5FileContent = Get-Content -Path $md5FilePath -Raw
if ($md5FileContent -match "MD5\s+\((.+?)\)\s+=\s+([A-Fa-f0-9]{32})") {
    $parsedFileName = $matches[1]
    $md5Checksum = $matches[2]

    if ($parsedFileName -ne $checkpointFile.Name) {
        Write-Log "MD5 file does not match the checkpoint file name."
        exit 1
    }

    $computedMd5 = Get-FileHash -Path $checkpointFilePath -Algorithm MD5 | Select-Object -ExpandProperty Hash

    if ($md5Checksum -eq $computedMd5) {
        Write-Log "MD5 checksum verification succeeded for $checkpointFilePath"
    } else {
        Write-Log "MD5 checksum verification failed for $checkpointFilePath"
        exit 1
    }
} else {
    Write-Log "Invalid MD5 file format."
    exit 1
}

# Step 3: Create a backup directory with the current date
$currentDate = Get-Date -Format "yyyy-MM-dd HH-mm-ss"
$backupDir = Join-Path -Path $backupRoot -ChildPath $currentDate
if (-Not (Test-Path -Path $backupDir)) {
    New-Item -Path $backupDir -ItemType Directory | Out-Null
    Write-Log "Created backup directory: $backupDir"
}

# Step 4: Copy checkpoint.* and journal.* files to the backup directory
Write-Log "Copying checkpoint and journal files"

if ($checkpointFile -ne $null) {
    Copy-Item -Path $checkpointFile.FullName -Destination $backupDir
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Copied journal file: $checkpointFile"
    } else {
        Write-Log "Failed to copy file: $checkpointFile"
    }
}

if ($md5FilePath -ne $null) {
    Copy-Item -Path $md5FilePath -Destination $backupDir
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Copied journal MD5 file: $md5FilePath"
    } else {
        Write-Log "Failed to copy file: $md5FilePath"
    }
}

$journalfilesToCopy = Get-ChildItem -Path $p4Root -Filter "journal.*"
foreach ($file in $journalfilesToCopy) {
    Copy-Item -Path $file.FullName -Destination $backupDir
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Copied journal file: $file"
    } else {
        Write-Log "Failed to copy file: $file"
    }
}

# Step 5: Copy all folders except "server.locks" to the backup directory
Write-Log "Copying all folders except 'server.locks' to the backup directory"
$foldersToCopy = Get-ChildItem -Path $p4Root -Directory | Where-Object { $_.Name -ne "server.locks" }

foreach ($folder in $foldersToCopy) {
    $destinationFolder = Join-Path -Path $backupDir -ChildPath $folder.Name
    Copy-Item -Path $folder.FullName -Destination $destinationFolder -Recurse
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Copied folder: $folder.Name"
    } else {
        Write-Log "Failed to copy folder: $folder.Name"
    }
}

# Step 6: Remove folders older than 7 days
Write-Log "Cleaning up old backup folders"
$directories = Get-ChildItem -Path $backupRoot -Directory
foreach ($directory in $directories) {
    if ($directory.CreationTime -lt (Get-Date).AddDays(-7)) {
        Remove-Item -Path $directory.FullName -Recurse -Force
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Removed old backup folder: $directory"
        } else {
            Write-Log "Failed to remove old backup folder: $directory"
        }
    }
}

Write-Log "Backup and cleanup process completed"