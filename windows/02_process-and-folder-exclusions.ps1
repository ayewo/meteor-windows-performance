# Adding process and folder exclusions to Windows Defender
Write-Host "Adding process and folder exclusions to Windows Defender, please stand by."

# Super useful blog post revealing additional Get-MpPerformanceReport options for tracking down all the paths that should be excluded:
# https://mortenknudsen.net/?p=415

# These are one-off tooling exclusions: i.e. tools like Vmware and Terraform which I used for VM-based benchmarks.
# The actual exclusions, necessary for day-to-day development, start on line 26.

Add-MpPreference -ExclusionPath "C:\Temp\terraform_*.cmd"
Add-MpPreference -ExclusionPath "C:\Users\Administrator\meteor-timings\*"
Add-MpPreference -ExclusionPath "C:\Users\Administrator\UserData.log"

Add-MpPreference -ExclusionProcess "vmtoolsd.exe"
Add-MpPreference -ExclusionPath "C:\Program Files\VMware\VMware Tools\vmtoolsd.exe"

Add-MpPreference -ExclusionProcess "choco.exe"
Add-MpPreference -ExclusionPath "C:\ProgramData\chocolatey\bin\*"
Add-MpPreference -ExclusionPath "C:\ProgramData\chocolatey\lib\*"
Add-MpPreference -ExclusionPath "C:\ProgramData\chocolatey\.chocolatey\*"

Add-MpPreference -ExclusionProcess "ptime.exe"
Add-MpPreference -ExclusionPath "C:\ProgramData\chocolatey\bin\ptime.exe"
Add-MpPreference -ExclusionPath "C:\ProgramData\chocolatey\lib\ptime\tools\ptime.exe"

# Process exclusion list
# Defender won't scan files OPENED by any excluded process in this list, no matter where the files are located (i.e. on-device or removable disks). 
# Two types of process exclusions are used: by image name and by full path.
# See https://learn.microsoft.com/en-us/defender-endpoint/configure-process-opened-file-exclusions-microsoft-defender-antivirus

# File exclusion list
# Excluded processes will still be SCANNED by Defender unless the processes are also added to this file exclusion list.
# See https://learn.microsoft.com/en-us/defender-endpoint/configure-extension-file-exclusions-microsoft-defender-antivirus


Add-MpPreference -ExclusionProcess "git-remote-https.exe"
Add-MpPreference -ExclusionPath "C:\Program Files\Git\etc\gitconfig\git-remote-https.exe"
Add-MpPreference -ExclusionPath "C:\Program Files\Git\mingw64\libexec\git-core\git-remote-https.exe"

Add-MpPreference -ExclusionProcess "node.exe"
Add-MpPreference -ExclusionPath "C:\Program Files\nodejs\*"

Add-MpPreference -ExclusionProcess "7z.exe"
Add-MpPreference -ExclusionPath "C:\Program Files\7-Zip\*"

# contains node.exe & 7z.exe 
Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\bin\*"

Add-MpPreference -ExclusionProcess "python.exe"
Add-MpPreference -ExclusionProcess "pythonw.exe"
Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\python\*"
Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\python\Lib\venv\scripts\nt\*"

Add-MpPreference -ExclusionProcess "mongod.exe"
Add-MpPreference -ExclusionProcess "mongos.exe"
Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\mongodb\bin\*"

Add-MpPreference -ExclusionProcess "pip.exe"
Add-MpPreference -ExclusionProcess "pip3.exe"
Add-MpPreference -ExclusionProcess "pip3.9.exe"
Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\python\Scripts\*"

Add-MpPreference -ExclusionProcess "term-size.exe"
Add-MpPreference -ExclusionPath "C:\Users\*\AppData\Local\.meteor\packages\meteor-tool\*\mt-os.windows.x86_64\dev_bundle\lib\node_modules\npm\node_modules\term-size\vendor\windows\*"

# 7za.exe
Add-MpPreference -ExclusionProcess "7za.exe"
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

Write-Host "Adding process and folder exclusions to Windows Defender, complete."
