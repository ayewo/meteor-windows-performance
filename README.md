# Performance Improvement of Meteor on Windows
# Summary
The root cause of the slowness on Window boils down to 2 factors:
1. heavy interference from Windows Defender which scans files as they are extracted by different binaries  i.e. `npm`/`meteor`/`7zip` etc;
2. the design of `meteor` which [assumes](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/tools/PERFORMANCE.md#hardware-and-os) a UNIX-style filesystem for everything. This leads to extra work (read: additional I/O calls) on Windows in order to preserve this UNIX-style filesystem abstraction for `meteor` which is why [Windows is slower](https://github.com/meteor/meteor/tree/fc1fcfd999008c89166ee4b0745ae2c0878a293e/tools/fs#files-vs-fs-and-filespath-vs-path).


# Chapter 1.0.
## 1.1. Initial Guesses
A cursory look at the numbers shared in the GitHub [issue](https://github.com/meteor/meteor/issues/12935) suggests that the slowness might be due to:
* implementation differences in how certain CLI tools (`node`/`npm`, `meteor`) work on Windows versus on Linux or;
* file system differences or differences in file system access patterns of `meteor` on Windows versus on Linux.

It is also possible the root cause is a mixture of both factors. Since I'm completely new to Meteor, I need to review all relevant information describing the issue. 

## 1.2. Issues Review
I did a quick review of the 9 issues linked to the task and short-listed these 3 issues as highly plausible, relative to the other 6:
* interference from Windows antivirus e.g. [Meteor-tool 1.6.1 stuck on extracting](https://github.com/meteor/meteor/issues/9592) which has a [workaround](https://github.com/meteor/meteor/issues/9592#issuecomment-364870278) [^a];
* interference from [“native file watching library”](https://github.com/meteor/meteor/issues/12459#issuecomment-1438881666) logged against Meteor v2.4;
* first-time extraction of certain [dependencies](https://github.com/meteor/meteor/issues/12633) is slow but fast on the 2nd attempt .

## 1.3. Video Review
Videos comparing `meteor`'s performance on [Windows vs Linux](https://drive.google.com/drive/folders/1_OeBoJxg1X_sbVfSl9sVitUPMdBppD0a?usp=sharing) were helpfully shared. The videos provided crucial information like specific versions of each CLI used to illustrate the issue. This info is necessary so I can create a reproducer that will be used in benchmarks later.

|    | Windows | Linux |
|----------|-------------|------------|
| `meteor` | v2.14 | v2.14 |
| `node` | v14.17.3 | v14.21.3 |
| `npm`[^b] | v6.14.13 | v6.14.18 |

After reviewing [Installing Meteor First Time.mkv](https://drive.google.com/file/d/1Tf42ZkNFjdIAUUZRJI_-gtuFJd67VYr8/view?usp=drive_link), I expanded my initial guesses to include these possibilities:
* CLI routines that print to the console on Windows might be missing important optimizations making it slower compared to Linux[^c];

* `meteor` on Windows might be making more I/O calls than `meteor` on Linux to make up for the absence of platform-specific dependencies. For instance, `meteor` relies on precompiled binaries[^d] to work reliably on Windows so it clearly makes extra network calls to the npm registry to fetch binaries to disk compared to Linux or macOS.



# Chapter 2.0.
## 2.1. Reproducing the Issue
My first attempt to reproduce the issue on my machine led to some interesting results. 

I spun up a freshly-built instance of Windows 2022 Server on EC2 for my initial testing and the OOTB (out-of-the-box) run time for `npm install -g meteor` reported by the PowerShell `Measure-Command`[^g] was `00:40:22.5954133` (40:22 mins). 

The test was on a [t2.medium](https://instances.vantage.sh/aws/ec2/t2.medium) (2 vCPUs, 4.0 GiB RAM) which is a pretty underpowered instance type as far as instance types go. The high initial time was expected because the Windows Defender antivirus is enabled by default on new Windows installations.

### 2.1.1. Excluding Folders from Windows Defender
Next, I excluded these folders from Windows Defender:
* `"C:\Users\Administrator\AppData\Local"`
* `"C:\Users\Administrator\AppData\Roaming\npm"`
  
then un-installed `meteor` and re-ran the PowerShell timing command I used earlier: 
```bash
(Measure-Command { npm install -g meteor | Out-Default }).ToString()
```

* 1st test: `npm install -g meteor` dropped to `00:04:34.3928350` (4:34 mins)
* 2nd test: `npm install -g meteor` dropped to `00:04:35.1082152` (4:35 mins)

I expected the `npm` installation run time (4 mins 35 secs) to be *higher than* the number reported in the issue (10 min 3 secs) because I used a low-spec VM and not on a beefy dedicated machine for the tests and _assumed_ that some Windows Defender exclusions were in place in the test environment. 

Before continuing, I decided to correspond with the issue reporter ([Will](https://github.com/wreiske)) so I could learn more about his test environment. 

### 2.1.2. Test Environment
Over email, I asked Will the following questions: 

> 1. Can you please share your list of folder exclusions in MS Defender by executing the command below from PowerShell? Of course you can redact any sensitive info in the output.
`Get-MpPreference | Select-Object -Property ExclusionPath -ExpandProperty ExclusionPath`

> 2. Can you share the specs of the machine you used to time the commands? Would appreciate info on CPU class, RAM, HDD type & size and maybe even Internet speed.

I got back the following response:

> 1. Windows Defender was **enabled** on both instances **without any exclusions**.

> 2.
```bash
    CPU: Intel(R) Core(TM) i9-9900K CPU @ 3.60GHz, 8 cores (16 threads)
    RAM: 64GB DDR4
    Disk: 2x 980 PRO PCIe® NVMe® SSD 2TB as a RAID 1 mirror
    Internet Speed: 2.25 Gbps / 115 Mbps
```
    
I was surprised to hear back that he didn't have _any_ Windows Defender exclusions so I had to discard my assumption that folder exclusions were in place in the test environment.

## 2.2. Code Review
Further correspondence with Will did lead me to re-visit something that stood out when I reviewed the video.

In the `npm install -g meteor` [video](https://drive.google.com/file/d/1Tf42ZkNFjdIAUUZRJI_-gtuFJd67VYr8/view?usp=drive_link), the console messages started out being identical but they diverged slightly as the installation progressed. 

To understand what the `npm install -g meteor` command does on Windows, Linux and macOS, I looked at the output of `npm view meteor`:
```bash
npm view meteor    
meteor@2.15.0 | MIT | deps: 9 | versions: 68
Install Meteor

bin: meteor-installer

dist
.tarball: https://registry.npmjs.org/meteor/-/meteor-2.15.0.tgz
.shasum: a14338e2255b97fbff44dd8d569993cfc6ec3bff
.integrity: sha512-WeSajhullk9xTYv06I9Dww5VIsrwkX5Qyp0GgG3gy8kkrAa1fRiV/verefIQRYv4X+6OOwKln82/0oBwC2FXTQ==
.unpackedSize: 18.4 kB

...
```

<details>
<summary>Full output of <code>npm view meteor</code> (click to expand).</summary>
<pre>
npm view meteor    
meteor@2.15.0 | MIT | deps: 9 | versions: 68
Install Meteor

bin: meteor-installer

dist
.tarball: https://registry.npmjs.org/meteor/-/meteor-2.15.0.tgz
.shasum: a14338e2255b97fbff44dd8d569993cfc6ec3bff
.integrity: sha512-WeSajhullk9xTYv06I9Dww5VIsrwkX5Qyp0GgG3gy8kkrAa1fRiV/verefIQRYv4X+6OOwKln82/0oBwC2FXTQ==
.unpackedSize: 18.4 kB

dependencies:
7zip-bin: ^5.2.0                https-proxy-agent: ^5.0.1       node-downloader-helper: ^1.0.19 semver: ^7.3.7                  tmp: ^0.2.1                     
cli-progress: ^3.11.1           node-7z: ^2.1.2                 rimraf: ^3.0.2                  tar: ^6.1.11                    

maintainers:
- gywem <igcogi@gmail.com>
- hschmaiske <ishenriquealbert@gmail.com>
- grubba <grubba27@hotmail.com>
- fredmaiaarantes <fred@meteor.com>
- mdg <dev@meteor.com>
- denyhs <denilsonh2014@gmail.com>
- filipenevola <filipenevola@gmail.com>

dist-tags:
latest: 2.15.0  next: 2.15.0    

published 2 weeks ago by mdg <dev@meteor.com> 
</pre>
</details>

The parts I'm most interested in are the outputs for `bin` and `dist.tarball` which can be obtained individually with: `npm view meteor bin` and `npm view meteor dist.tarball`:

```bash
npm view meteor bin
{ 'meteor-installer': 'cli.js' }
```
```bash
npm view meteor dist.tarball
https://registry.npmjs.org/meteor/-/meteor-2.15.0.tgz
```

The output of `npm view meteor bin` clearly shows that `npm install -g meteor` doesn't really install the `meteor` binary directly. Instead it installs a `meteor-installer` binary from the tarball hosted on the [npm registry](https://registry.npmjs.org/meteor/-/meteor-2.15.0.tgz) as can be seen in the output of `npm view meteor dist.tarball`. 

After an `npm` binary is installed, `npm` then executes any lifecycle scripts (i.e. preinstall, install, postinstall) defined in the binary's `package.json`. `meteor-installer` defines an [`install`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/package.json#L7) lifecycle script so `npm` executes this for the actual installation of `meteor` on all platforms (Windows, Linux and macOS) using [`cli.js`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/cli.js).
 

### 2.2.1 `meteor-installer`
When `meteor-installer` is invoked it first constructs a platform-dependent [download URL](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/install.js#L84-L86) then proceeds to download a 300+ MB file (e.g. for v2.14 this is [330 MB](https://packages.meteor.com/bootstrap-link?arch=os.windows.x86_64&release=2.14) on Windows, [347 MB](https://packages.meteor.com/bootstrap-link?arch=os.linux.x86_64&release=2.14) on Linux and [324 MB](https://packages.meteor.com/bootstrap-link?arch=os.osx.x86_64&release=2.14) on macOS) which it then proceeds to unpack to:
* `C:\Users\<user>\AppData\Local\.meteor` on Windows;
* `$HOME/.meteor` on Linux and macOS.

Further review of the code showed that the logic executed by the [`download()`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/install.js#L167) function of `meteor-installer` is also platform-dependent.

When the detected OS is Windows, two functions are executed: 
* [`decompress()`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/install.js#L202) and;
* [`extract()`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/install.js#L244).

When the detected OS is Linux (or macOS), it executes only one function:
* [`extractWithNativeTar()`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/install.js#L209).

### 2.2.2. Non-idiomatic use of `tar`
The `tar` utility on UNIX can decompress (via the `z` option) and extract (via the `x` option) an `archive.tar.gz` in [one step](https://askubuntu.com/a/25348) as long as you combine those options correctly e.g. `tar zxf archive.tar.gz`.

But, `meteor-installer` is doing it in 2 steps on Windows via 2 functions: `decompress()` and `extract()`. Why?

As at the time of the `meteor` project's [release back in 2012](https://en.wikipedia.org/wiki/Meteor_(web_framework)#History), the `tar` utility was only native to Linux and macOS. This meant that on Windows, they had to either use [`tar.js`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/package.json#L20), which is a re-implementation of the `tar` utility in Node.js, or depend on a precompiled binary that can handle `tar` files. The project went with the open source [`7zip`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/package.json#L13) binary on Windows.

In fact, there’s a comment in the code saying [7zip can be ~15% faster than `tar.js` on Windows](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/install.js#L264-L266), if the user has permission to create symlinks. 

This non-idiomatic use of `tar` might potentially explain why `npm install -g meteor` is slower on Windows than on Linux.


## 2.3. Quick Win
Developers have been looking for a way to programmatically decompress and extract `tar.gz` files in a single step on Windows using 7zip [since at least 2009](https://stackoverflow.com/questions/1359793/programmatically-extract-tar-gz-in-a-single-step-on-windows-with-7-zip), but it wasn't really possible until the release of [7zip v9.04](https://superuser.com/a/1283392). 

Starting with [Windows 10 Insider Preview Build 17063](https://www.thomasmaurer.ch/2017/12/tar-and-curl-on-windows-10/), Microsoft announced in late 2017 that Windows 10 would ship with [native binaries](https://superuser.com/a/1428444) of `tar` based on [`bsdtar`](http://libarchive.org/)[^h]. So `tar` (and a few other utilities like `curl`) now ships by default on all copies of [Windows 10 version 1803](https://bsmadhu.wordpress.com/2018/08/23/curltar-ssh-tools-on-windows-10/) and newer, but more than 7 years later, the `meteor-installer` hasn't been updated to reflect this reality.

I decided to patch `meteor` to see if there would be any improvement with a switch to the native `tar.exe`.

### 2.3.1. Patching the Meteor Installer Package
1. I made a [fork](https://github.com/ayewo/meteor) of the [`meteor`](https://github.com/meteor/meteor) repo and cloned it locally:
```bash
git clone https://github.com/ayewo/meteor.git
```

2. Next, I patched the `meteor-installer` code to use `tar.exe` on newer editions of Windows (relevant [commit](https://github.com/ayewo/meteor/commit/0134c3b95a0bc61b8e58488173cb0162375e61f4)):
```bash
cd meteor/npm-packages/meteor-installer
# apply patch
...
```

3. Then created a [PAT](https://github.com/settings/tokens) (Personal Access Token) on GitHub and added it to my home directory at `~/.npmrc`:
```bash
@ayewo:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=ghp_Xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```
  Instead of a fine-grained token, I opted for a classic token with the following scopes:
  * `repo` (Full control of private repositories)
  * `write:packages`
  * `delete:packages`

4. Finally, I used `npm` to publish my patched package to the [GitHub Package Registry](https://npm.pkg.github.com):
```bash
cd meteor/npm-packages/meteor-installer
npm publish 
```
<details>
<summary>Full output of <code>npm publish</code> (click to expand).</summary>
<pre>
npm publish 
npm notice 
npm notice 📦  @ayewo/meteor@2.15.0
npm notice === Tarball Contents === 
npm notice 2.9kB  README.md   
npm notice 427B   cli.js      
npm notice 1.5kB  config.js   
npm notice 3.0kB  extract.js  
npm notice 10.1kB install.js  
npm notice 782B   package.json
npm notice 411B   uninstall.js
npm notice === Tarball Details === 
npm notice name:          @ayewo/meteor                           
npm notice version:       2.15.0                                  
npm notice filename:      @ayewo/meteor-2.15.0.tgz                
npm notice package size:  6.2 kB                                  
npm notice unpacked size: 19.0 kB                                 
npm notice shasum:        ae7dd789d7d807031e7e9916ab95f097cbe59081
npm notice integrity:     sha512-XqWLA+0gWZQZg[...]zWZTTk2gvCr4w==
npm notice total files:   7                                       
npm notice 
npm notice Publishing to https://npm.pkg.github.com
+ @ayewo/meteor@2.15.0  
</pre>
</details>


### 2.3.2. Using the Patched Meteor Installer Package
1. If you haven't already, create a `$HOME/.npmrc` file with the contents below so you can install `npm` packages from [other organizations](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-npm-registry#installing-packages-from-other-organizations):
```bash
cat <<EOF > ~/.npmrc
@ayewo:registry=https://npm.pkg.github.com
EOF
```

2. Use of my patched `meteor-installer` [package](https://github.com/users/ayewo/packages/npm/package/meteor) from `npm` is as simple as adding the `@ayewo/` prefix to `meteor` i.e.:
```bash
npm install -g @ayewo/meteor
```

### 2.3.3. Outcome
My patched version of the `meteor-installer` uses the native version of `tar` present in `C:\Windows\System32\tar.exe` on newer versions of Windows and this led to a nice speed up in the execution of the `npm install -g meteor` command. 

The run time of `00:04:35.1082152` (4:35 mins) dropped down to `00:02:27.9540000` (2:28 mins) on a `t2.medium` instance.

## 2.4. Windows Defender
While attempting to reproduce the issue with Windows Defender enabled, I noticed high CPU activity from Windows Defender each time I tried to run the `npm` or `meteor` commands. 

A review of this article on the internal workings of an [antivirus engine](https://www.adlice.com/making-an-antivirus-engine-the-guidelines/) suggests that `npm` and `meteor` seem to be failing one or more [malware detection](https://www.security.org/antivirus/how-does-antivirus-work/) methods used by Windows Defender.

This is understandable since I would expect any decent antivirus tool to properly supervise the `npm` process the moment it downloads this [7zip.exe](https://github.com/develar/7zip-bin/blob/234abf56ddc2935de44e07d5e3c40eecab95d5af/win/x64/7za.exe) from the npm registry since it is explicitly depended on by `meteor-installer` in its [`package.json`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/npm-packages/meteor-installer/package.json#L13) (i.e. heuristic-based detection) or `meteor`'s spawning of multiple child processes like [`mongod.exe`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/tools/runners/run-mongo.js#L88) and [`python.exe`](https://github.com/meteor/meteor/blob/fc1fcfd999008c89166ee4b0745ae2c0878a293e/tools/cli/dev-bundle-bin-helpers.js#L150) across multiple folders (i.e. behavior-based detection).

I used a combination of tools to surface the processes and files that should be excluded from extended antivirus scans when Windows Defender is active.

### 2.4.1. Process Monitor
The `meteor` binary on Windows is really just a batch file located at `C:\Users\Administrator\AppData\Local\.meteor\meteor.bat` that spawns multiple child processes depending on what it was invoked for. 

I used the excellent [Process Monitor](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon) tool to inspect what each of the various processes spawned by `meteor` is doing.
Process Monitor can be invoked from the CLI as [`Procmon.exe`](https://live.sysinternals.com/Procmon.exe) and it helped surfaced dozens of processes and files that are open each time a `meteor` command is executed on Windows.

Below is an example of using `Procmon.exe` in a [batch file](https://www.cloudnotes.io/how-to-automate-process-monitor/) to log all activity from the command `meteor create testapp --blaze`:
```bash
cat <<EOF > meteor-create.bat
set PM=D:\Procmon.exe
start %PM% /quiet /minimized /nofilter /backingfile D:\meteor-create.pml
%PM% /waitforidle
start /wait cmd /c "meteor create testapp --blaze"
rem %PM% /terminate
EOF
```

<details>
<summary>A sampling of the various paths surfaced by <code>Procmon.exe</code> (click to expand).</summary>
<pre>
C:\Users\Administrator\AppData\Local\.meteor/meteor.bat
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\meteor.bat
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\bin\node.exe
    # system
    C:\Windows\System32\dbghelp.dll
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\tools\index.js
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\tools\tool-env\install-promise.js
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\tools\tool-env\wrap-fibers.js
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\@wry\context\package.json 
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\@wry\context\lib\context.js   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\fibers\package.json   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\fibers\fibers.js 
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\fibers\bin\win32-x64-83\fibers.node
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\meteor-promise\package.json   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\meteor-promise\promise_server.js  
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\meteor-promise\fiber_pool.js  
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\tools\cli\dev-bundle-bin-commands.js
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\tools\cli\dev-bundle-bin-helpers.js   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\tools\cli\convert-to-os-path.js   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\tools\cli\dev-bundle.js   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\tools\cli\dev-bundle-links.js  
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\python\python.exe  
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\node-gyp\gyp\pylib  
    # system see https://superuser.com/questions/1688054/what-is-the-windows-apppatch-directory-purpose-and-contents
    C:\Windows\apppatch\sysmain.sdb

C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\bin\.meteor-commands.json
...
...
C:\Users\Administrator\AppData\Local\.meteor\package-metadata\v2.0.1\packages.data.db
...
msmpeng.exe # Microsoft Malware Protection Engine aka Antimalware service executable
C:\Users\Administrator\AppData\Roaming\npm-cache\_cacache\tmp\f09c87d3
C:\Users\Administrator\AppData\Roaming\npm-cache\_cacache\index-v5\06\fe\d663c0cf950e8b21ce9b8c92661bc2e46d8a9097c50ab2fa7b6e61f1cb20
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\bin\node.exe
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\fibers\bin\win32-x64-83\fibers.node
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\python\python.exe
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\python\vcruntime140.dll
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\python\python39.dll
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\sqlite3\lib\binding\napi-v3-win32-x64\node_sqlite3.node   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\vscode-nsfw\build\Release\nsfw.node   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\pathwatcher\build\Release\pathwatcher.node    
...
C:\Users\Administrator\AppData\Roaming\npm-cache\_cacache\index-v5\52\f7\13ab8ff096ebdfcc168c1f3c5df350c925fe641316ca0aff1289732608f5
C:\Users\Administrator\AppData\Roaming\npm-cache\_cacache\index-v5\52\f7\13ab8ff096ebdfcc168c1f3c5df350c925fe641316ca0aff1289732608f5
...
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\sqlite3\lib\binding\napi-v3-win32-x64\node_sqlite3.node   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\vscode-nsfw\build\Release\nsfw.node   
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\pathwatcher\build\Release\pathwatcher.node    
C:\Users\Administrator\AppData\Local\.meteor\packages\meteor-tool\2.14.0\mt-os.windows.x86_64\dev_bundle\lib\node_modules\fibers\bin\win32-x64-83\fibers.node   
...
</pre>
</details>


### 2.4.2. Performance Analyzer
PowerShell (in administrative mode) on Windows ships with these cmdlets: `New-MpPerformanceRecording` and `Get-MpPerformanceReport` which belong to the [performance analyzer tool](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/tune-performance-defender-antivirus?view=o365-worldwide) for Microsoft Defender Antivirus. 

The antivirus's performance analyzer can *"determine files, file extensions, and processes that might be causing performance issues ... during antivirus scans"*. It was equally useful in helping me shortlist additional paths that should be added to Windows Defender's *process* and *folder* exclusions to limit the excessive slowdown from the antivirus.

Below is an example of using `New-MpPerformanceRecording` to start a performance recording to an [ETL](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/trace-log) file prior to the execution of the `meteor create testapp --blaze` command: 
```bash
New-MpPerformanceRecording -RecordTo D:\meteor-create.etl
meteor create testapp --blaze
```

Below are examples of using `Get-MpPerformanceReport` to produce different reports from the performance recording created by `New-MpPerformanceRecording`:
```bash
Get-MpPerformanceReport -Path D:\meteor-create.etl -TopFiles 3 -TopScansPerFile 10
Get-MpPerformanceReport -Path D:\meteor-create.etl -TopFiles 20 -TopExtensions 20 -TopProcesses 20 -TopScans 20
Get-MpPerformanceReport -Path D:\meteor-create.etl -TopProcesses 10 -TopExtensionsPerProcess 3 -TopScansPerExtensionPerProcess 3
Get-MpPerformanceReport -Path D:\meteor-create.etl -TopScans 100 -MinDuration 100ms
```

The full list of *process* and *folder* exclusions that were added are in the file `process-and-folder-exclusions.ps1` used in the benchmarks.



# Chapter 3.0.
## 3.1. Overview
I initially wanted to develop the scripts for the benchmarks using Windows 10 Pro installed inside a VirtualBox VM[^f], especially because VirtualBox ships with multiple `VBox` CLI tools that make it easy to use from a script, but had to abandon the idea due to the high variance between test runs (due to my Internet connection).

Once I switched to using EC2 VMs launched using Terraform, the high variance problem went away.

## 3.2. Benchmarks
The benchmarks were developed and tested on a [`t2.small`](https://instances.vantage.sh/aws/ec2/t2.small) (Linux) and a [`t3.small`](https://instances.vantage.sh/aws/ec2/t3.small) (Windows) but the final numbers obtained below are from a [`c5a.2xlarge`](https://instances.vantage.sh/aws/ec2/c5a.2xlarge) instance type. 

|   | Command                               | Linux    | Windows (Defender❌) | Windows (Defender✔️) |
|---|---------------------------------------|---------------------|---------------------|--------------|
|1  | `npm install -g meteor`               | 19.137s  | 108.624s(†) | 91.628s(‡) |
|2  | `meteor create testapp --blaze`       | 48.594s | 70.036s  | 76.220s |
|3  | `meteor`                              | 21.077s | 25.177s  | 25.203s |
|4  | `meteor add ostrio:flow-router-extra` | 8.476s | 10.913s  | 16.579s |
|5  | `meteor update --release 3.0-alpha.19`| 2min 11.139s (131.139s) | 11min 30.851s (690.851s)  | - |

* † indicates that the command `npm i -g meteor` was used in this test.
* ‡ indicates that the command `npm i -g @ayewo/meteor` was used in this test.

### 3.2.1. Prerequisites
* [AWS Account](https://aws.amazon.com/free/)
* [Terraform](https://developer.hashicorp.com/terraform/install) v1.5.2+

Specify your AWS credentials inside `~/.aws/credentials`:
```bash
mkdir -p ~/.aws && cat << EOF > ~/.aws/credentials
# iam-user-with-appropriate-privileges
[default]
aws_access_key_id=AKIAIOSFODNN7EXAMPLE
aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF
```

Alternatively, you can use environment variables:
```bash
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

### 3.2.2. Linux
The Terraform script uses the Ubuntu 22.04 LTS[^1] [AMI](https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#ImageDetails:imageId=ami-0e001c9271cf7f3b9) to launch an EC2 VM for the benchmark tests on Linux.

To run the script:
```bash
cd linux
touch timings.sh
terraform init
terraform apply -auto-approve
terraform destroy -auto-approve
```
The runtime on Linux for all 5 commands will be written to `timings.csv` in the `linux/` folder (downloaded using `scp`).

### 3.2.3. Windows
The Terraform script uses the Windows 2022 [AMI](https://us-east-1.console.aws.amazon.com/ec2/home?region=us-east-1#ImageDetails:imageId=ami-0069eac59d05ae12b) to launch an EC2 VM. 

To run the script:
```bash
cd windows
touch timings.ps1
terraform init
terraform apply -auto-approve
terraform destroy -auto-approve
```
The runtime on Windows for all 5 commands will be written to `timings.csv` in the `windows/` folder (downloaded using `scp`).


# Chapter 4.0.
## 4.1. Further Considerations
The root device on most EC2 instances today now use EBS. EBS is slower, relative to instance storage, so one possibility to speed up the benchmarks would be to install `meteor` to instance storage on EC2 instances that come with NVMe SSD drives. This would mean switching the instance type from `c5a.2xlarge` to `c5ad.2xlarge` (the extra "d" after "c5a" indicates an instance store is available) to take advantage of the faster NVMe SSDs.

I found articles on how to install `meteor` outside of the default installation location i.e. outside of `$HOME/.meteor` on [Linux](https://github.com/meteor/meteor/issues/8489#issuecomment-286812145) and outside of `%LocalAppData%\.meteor` on [Windows](https://forums.meteor.com/t/cant-install-meteor-on-windows/51894).

## 4.2. Dev Drive
The next step would be to [Set up a Dev Drive on Windows 11](https://learn.microsoft.com/en-us/windows/dev-drive/) to take advantage of the improved file system performance of the underlying ReFS that has been enhanced with [CopyOnWrite (CoW) linking](https://devblogs.microsoft.com/engineering-at-microsoft/dev-drive-and-copy-on-write-for-developer-performance/) which makes it better suited to developer workloads than NTFS[^2].



## Footnotes
[^a]: The same workaround for Windows Defender is shared as a potential solution in another issue: https://github.com/meteor/meteor/issues/10601
[^b]: I cross-referenced the `node` versions shown in the video with [`index.json`](https://nodejs.org/dist/index.json) to obtain the corresponding versions for `npm`.
[^c]: Viewing the videos side-by-side immediately reminded me of this famous [Stackoverflow question](https://stackoverflow.com/questions/21947452/why-is-printing-b-dramatically-slower-than-printing), so it's possible that `meteor`'s [character-wrapping](https://stackoverflow.com/a/21947627) and/or [output buffering](https://stackoverflow.com/a/4438299) on the terminal are suboptimal on Windows relative to Linux.
[^d]: The `meteor-installer` [depends](https://github.com/meteor/meteor/blob/73fcfeeccf0320b30bf5d135b79f1f0d369124de/npm-packages/meteor-installer/package.json#L13-L21) on packages like `7zip` which has precompiled binaries for [Windows](https://github.com/develar/7zip-bin/tree/234abf56ddc2935de44e07d5e3c40eecab95d5af/win), Linux and macOS.
[^e]: Timely SO [comment](https://superuser.com/questions/1121942/does-an-excluded-directory-in-windows-10-defender-also-include-the-sub-directori#comment2753485_1331660) about universal malware test file (EICAR) talks about exclusion for both folders and *processes*: https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/configure-process-opened-file-exclusions-microsoft-defender-antivirus?view=o365-worldwide
[^f]: Microsoft offers a 20GB+ download of [Windows 11](https://developer.microsoft.com/en-us/windows/downloads/virtual-machines/) that expires after 90 days and a non-expiring 5.7GB download of [Windows 10 Pro](https://www.microsoft.com/en-us/software-download/windows10ISO). Plus, the [FLARE-VM](https://github.com/mandiant/flare-vm) project packs a ton of info on effective use of Windows 10 VMs.
[^g]: `Measure-Command` is only available in PowerShell. An command prompt [alternative](https://superuser.com/a/1373714/) is `ptime` which can be installed via `choco install ptime`.
[^h]: Tar on Windows is based on `bsdtar` and it used to be [very slow when extracting many small files](https://github.com/microsoft/Windows-Dev-Performance/issues/27). 

[^1]: The sponsor of this issue did his testing on Debian 12 on WSL. This is why I choose this version of Ubuntu since it is [based on Debian 12](https://askubuntu.com/questions/445487/what-debian-version-are-the-different-ubuntu-versions-based-on). 

[^2]: A [few](https://github.com/microsoft/Windows-Dev-Performance/issues/17#issuecomment-1643406687) folks reported significant improvement when they switched to a [Dev Drive](https://github.com/microsoft/Windows-Dev-Performance/issues/17#issuecomment-1567346040) in this thread: [nodejs and yarn are 4x slower on windows than ubuntu](https://github.com/microsoft/Windows-Dev-Performance/issues/17)
