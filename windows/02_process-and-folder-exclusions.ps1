# Adding process and folder exclusions to Windows Defender
Write-Host "Adding process and folder exclusions to Windows Defender, please stand by."

Add-MpPreference -ExclusionPath "C:\Users\Administrator\AppData\Local"
Add-MpPreference -ExclusionPath "C:\Users\Administrator\AppData\Roaming\npm"
Add-MpPreference -ExclusionPath "C:\Users\Administrator\AppData\Roaming\npm-cache\"
Add-MpPreference -ExclusionPath "C:\Users\Administrator\AppData\Local\.meteor\"

Add-MpPreference -ExclusionProcess "node.exe"
Add-MpPreference -ExclusionProcess "mongod.exe"
Add-MpPreference -ExclusionProcess "python.exe"
Add-MpPreference -ExclusionProcess "meteor.bat"
Add-MpPreference -ExclusionProcess "npm.cmd"
Add-MpPreference -ExclusionProcess "C:\Users\Administrator\AppData\Local\.meteor\meteor.bat"

Write-Host "Adding process and folder exclusions to Windows Defender, complete."
