# timings.ps1.tpl
Start-Transcript -Path "${timings_folder}\timings.log" -Append

# Using this 3rd-party module for logging due to the transcript's limitation https://github.com/PowerShell/PowerShell/issues/10994
# PowerShell's transcript is not as robust as the Unix "script" command https://www-users.cse.umn.edu/~gini/1901-07s/files/script.html
Import-Module PowerShellLogging 
$TranscriptFile = Enable-LogFile -Path "${timings_folder}\timings-full.log"
$VerbosePreference = "Continue"

# Post-reboot setup tasks
Write-Output "Performing benchmark setup..."

# Ensure TLS 1.2 is enabled
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;

# Set Execution Policy
Set-ExecutionPolicy Bypass -Scope Process -Force

# Create timings folder
$timings_folder = "${timings_folder}"
if (-Not (Test-Path -Path $timings_folder)) {
    New-Item -ItemType Directory -Path $timings_folder
}

# If set, use the patched @ayewo/meteor package in the first command
$patch_meteor = "${patch_meteor}"
$first_command = "npm install -g meteor@2.14"

if ($patch_meteor -and $patch_meteor -eq 'true') {
    $first_command = "npm install -g @ayewo/meteor"
    Add-Content -Force -Path $env:USERPROFILE\.npmrc -Value "${npmrc}" 
}

# Ensure the recently installed "node" & "npm" commands are in the PATH
# From: https://stackoverflow.com/questions/17794507/reload-the-path-in-powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")



# Step 1.0: Install Meteor
$command = $first_command
$time_start = Get-Date
Write-Host "[timings-#1] Starting execution of command '$command' ..."

Invoke-Expression $command

$time_end = Get-Date
Write-Host "[timings-#1] Stopping execution of command '$command'."
$duration = ($time_end - $time_start).TotalSeconds
Add-Content -Path "$timings_folder\\timings.csv" -Value "1, '$command', $($time_start.ToString('o')), $($time_end.ToString('o')), $duration"



# Step 2.0: Create Meteor app
$env:Path += ";$env:USERPROFILE\AppData\Local\.meteor"
Set-Location -Path "$timings_folder"
$command = "meteor create testapp --blaze"
$time_start = Get-Date
Write-Host "[timings-#2] Starting execution of command '$command' ..."

Invoke-Expression $command

$time_end = Get-Date
Write-Host "[timings-#2] Stopping execution of command '$command'."

$duration = ($time_end - $time_start).TotalSeconds
Add-Content -Path "$timings_folder\\timings.csv" -Value "2, '$command', $($time_start.ToString('o')), $($time_end.ToString('o')), $duration"



# Step 3.0: Start Meteor server
Set-Location -Path "$timings_folder\\testapp"
$command = "meteor"
$time_start = Get-Date
Write-Host "[timings-#3] Starting execution of command '$command' ..."

$logFile = "$timings_folder\\testapp\\meteor.txt"
Write-Host "Meteor file: $logFile"
$meteorProcess = Start-Process -FilePath "meteor" -RedirectStandardOutput $logFile -PassThru

$patternFound = $false
while (-not $patternFound) {
    Start-Sleep -Seconds 1
    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile
        if ($logContent -match "App running at: http://localhost:3000/") {
            $patternFound = $true
        }
    }
}
Write-Host "Meteor server is running"

$time_end = Get-Date
Write-Host "[timings-#3] Stopping execution of command '$command'."
$duration = ($time_end - $time_start).TotalSeconds
Add-Content -Path "$timings_folder\\timings.csv" -Value "3, '$command', $($time_start.ToString('o')), $($time_end.ToString('o')), $duration"

# Function to get all child processes of a given process
function Get-ChildProcesses {
    param (
        [int]$parentId
    )

    $childProcesses = Get-WmiObject -Query "Select * From Win32_Process Where ParentProcessId=$parentId"
    $childProcesses | ForEach-Object {
        Get-ChildProcesses -parentId $_.ProcessId
    }
    $childProcesses
}

# Get all 4 child processes spawned by the Meteor process
$childProcesses = Get-ChildProcesses -parentId $meteorProcess.Id

# Stop all 4 child processes otherwise invoking "Stop-Process" on Meteor will not succeed
foreach ($childProcess in $childProcesses) {
    Stop-Process -Id $childProcess.ProcessId -Force
}

# Stop the Meteor process
Stop-Process -Id $meteorProcess.Id -Force



# Step 4.0: Add package to Meteor app
$command = "meteor add ostrio:flow-router-extra"
$time_start = Get-Date
Write-Host "[timings-#4] Starting execution of command '$command' ..."

Invoke-Expression $command

$time_end = Get-Date
Write-Host "[timings-#4] Stopping execution of command '$command'."
$duration = ($time_end - $time_start).TotalSeconds
Add-Content -Path "$timings_folder\\timings.csv" -Value "4, '$command', $($time_start.ToString('o')), $($time_end.ToString('o')), $duration"



# Step 5.0:
# meteor v3.x requires Node v20 so replace node v14 with v20 inside C:\Program Files\nodejs\
choco install nodejs.install --version=20.11.1 -y

# $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
# refreshenv will do the same as the previous line
Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
refreshenv

# Install other build dependencies
#npm install --global --production windows-build-tools

$command = "meteor update --release 3.0-alpha.19"
$time_start = Get-Date
Write-Host "[timings-#5] Starting execution of command '$command' ..."

Invoke-Expression $command

$time_end = Get-Date
Write-Host "[timings-#5] Stopping execution of command '$command'."
$duration = ($time_end - $time_start).TotalSeconds
Add-Content -Path "$timings_folder\\timings.csv" -Value "5, '$command', $($time_start.ToString('o')), $($time_end.ToString('o')), $duration"

Set-Location ..

Stop-Transcript
$TranscriptFile | Disable-LogFile
