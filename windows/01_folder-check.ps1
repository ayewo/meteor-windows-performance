param (
    [Parameter(Mandatory=$true)]
    [string]$folderPath
)

while (!(Test-Path -Path $folderPath -PathType Container)) {
    Write-Host "Waiting for the folder '$folderPath' to be created..."
    Start-Sleep -Seconds 20
}

Write-Host "The folder '$folderPath' has been created!"

# Disabling Windows Defender will set the "Restart Needed" flag hence the forced reboot below
Write-Host "Restarting Windows, please stand by."
Restart-Computer -Force
