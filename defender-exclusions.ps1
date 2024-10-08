param(
    [string]$Action,
    [string]$FolderPath
)

# Function to add all predefined exclusions
function Add-PredefinedExclusions {
    # Process exclusion list
    # Defender won't scan files OPENED by any excluded process in this list, no matter where the files are located (i.e. local, network or removable volumes). 
    # Two types of process exclusions are used: by image name and by full path.
    # See https://learn.microsoft.com/en-us/defender-endpoint/configure-process-opened-file-exclusions-microsoft-defender-antivirus

    Add-MpPreference -ExclusionProcess "git-remote-https.exe"
    Add-MpPreference -ExclusionProcess "7z.exe"
    Add-MpPreference -ExclusionProcess "node.exe"
    Add-MpPreference -ExclusionProcess "python.exe"
    Add-MpPreference -ExclusionProcess "pythonw.exe"
    Add-MpPreference -ExclusionProcess "mongod.exe"
    Add-MpPreference -ExclusionProcess "mongos.exe"
    Add-MpPreference -ExclusionProcess "pip.exe"
    Add-MpPreference -ExclusionProcess "pip3.exe"
    Add-MpPreference -ExclusionProcess "pip3.9.exe"
    Add-MpPreference -ExclusionProcess "term-size.exe"
    Add-MpPreference -ExclusionProcess "7za.exe"

    # File exclusion list
    # The excluded processes above will still be SCANNED by Defender unless their paths are also added to this file exclusion list.
    # See https://learn.microsoft.com/en-us/defender-endpoint/configure-extension-file-exclusions-microsoft-defender-antivirus

    Add-MpPreference -ExclusionPath "C:\Program Files\Git\etc\gitconfig\git-remote-https.exe"
    Add-MpPreference -ExclusionPath "C:\Program Files\Git\mingw64\libexec\git-core\git-remote-https.exe"
    Add-MpPreference -ExclusionPath "C:\Program Files\nodejs\*"
    Add-MpPreference -ExclusionPath "C:\Program Files\7-Zip\*"
    # contains node.exe & 7z.exe 
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\bin\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\python\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\python\Lib\venv\scripts\nt\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\mongodb\bin\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\python\Scripts\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\lib\node_modules\npm\node_modules\term-size\vendor\windows\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Roaming\npm\node_modules\meteor\node_modules\7zip-bin\win\x64\7za.exe"
    # contains  wininst-*.exe
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\python\Lib\distutils\command\*"
    # contains t32.exe, t64.exe, w32.exe, w64.exe
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\python\Lib\site-packages\pip\_vendor\distlib\*"
    # contains cli-32.exe, cli-64.exe, cli.exe, gui-32.exe, gui-64.exe, gui.exe
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\python\Lib\site-packages\setuptools\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Roaming\npm\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Roaming\npm-cache\*"
    Add-MpPreference -ExclusionPath "C:\Users\*\meteor-timings\testapp\*"
    # BABEL_CACHE_DIR
    Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\.babel-cache\*"

    Write-Host "Predefined exclusions have been added."
}


if ($Action -eq "Add" -and $FolderPath) {
    # Add predefined exclusions
    Add-PredefinedExclusions

    # Add the user-specified folder to the exclusion list
    Add-MpPreference -ExclusionPath $FolderPath
    Write-Host "User-specified folder has been added to exclusions: $FolderPath"
}
elseif ($Action -eq "Add" -and -not $FolderPath) {
    Write-Host "Error: Folder path is required when using the Add action."
    Write-Host "Usage: .\defender-exclusions.ps1 Add C:\path\to\folder"
}
else {
    # Just run the script with predefined exclusions if no args are specified
    Add-PredefinedExclusions
}