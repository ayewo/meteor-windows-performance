
locals { 
  timings_sh_hash           = filemd5("${path.module}/timings.ps1")
  timings_folder            = "C:/Users/${var.user_name}/${var.user_subfolder}" 
  user_data_done            = "C:/Users/${var.user_name}/${var.user_subfolder}/done" 
  path_public_key           = "${var.public_key_path}"
}

data "local_file" "npmrc" {
  filename = "${path.module}/.npmrc"
}

data "template_file" "timings_sh" {
  template = file("${path.module}/timings.ps1.tpl")

  vars = {
    timings_folder = "${local.timings_folder}"
    patch_meteor = "${var.patch_meteor}"
    npmrc = data.local_file.npmrc.content
  }
}

resource "local_file" "timings_sh" {
  filename = "${path.module}/timings.ps1"
  content  = data.template_file.timings_sh.rendered
}

data "local_file" "ssh_public_key" {
  filename = local.path_public_key
}


# Windows Bootstrapping PowerShell Script. 
data "template_file" "windows-userdata" {
  template = <<EOF
<script>
  winrm quickconfig -q & winrm set winrm/config @{MaxTimeoutms="1800000"} & winrm set winrm/config/service @{AllowUnencrypted="true"} & winrm set winrm/config/service/auth @{Basic="true"}
</script>  
<powershell>
# The transcript will be saved to C:\Users\Administrator\meteor-timings\timings.log
# See also the output of C:\ProgramData\Amazon\EC2Launch\log\agent.log
Start-Transcript -Path "C:\Users\${var.user_name}\UserData.log" -Append
$VerbosePreference = "Continue"

# From https://stackoverflow.com/a/45871712 
netsh advfirewall firewall add rule name="WinRM in" protocol=TCP dir=in profile=any localport=5985 remoteip=any localip=any action=allow

# Set Administrator password
$admin = [adsi]("WinNT://./administrator, user")
$admin.psbase.invoke("SetPassword", "${var.user_password}")

# Allow scripts to run without any restrictions or warnings
Set-ExecutionPolicy Bypass -Scope Process -Force;

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module PowerShellLogging -Verbose -Repository PSGallery -Force
Set-PSRepository PSGallery -InstallationPolicy Untrusted

# 1.0. Setup Windows Defender
$enable_defender = "${var.enable_defender}"
if ($enable_defender -and $enable_defender -eq 'false') {
    # Disable Windows Defender via https://businesshelp.avast.com/Content/Products/SysReqs/DisablingWinDefenderSrv1619.htm
    Uninstall-WindowsFeature -Name Windows-Defender

} else {
    # Apply process and folder exclusions to Windows Defender in the next provisioner
}



# 2.0 Enable OpenSSH Server
# From: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse?tabs=powershell#install-openssh-for-windows
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# These commands seem to not be available until after a reboot
#Start-Service sshd
#Set-Service -Name sshd -StartupType 'Automatic'

# Get the public key file for the "Administrator" user
$authorizedKey = "${data.local_file.ssh_public_key.content}"

# Add the public key to the "administrators_authorized_keys" file on the server
# From: https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement#deploying-the-public-key
Add-Content -Force -Path $env:ProgramData\ssh\administrators_authorized_keys -Value "$authorizedKey" 
icacls.exe "$env:ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F"



# 3.0. Install Dependencies
# Ensure TLS 1.2 is enabled
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;

# Install choco
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'));

# Install base dev tools v23.7.24.0+, v24.5.0+, v4.0.0.410700, and v126.0.0+ respectively
#choco install conemu -y
choco install 7zip.install -y
choco install sublimetext4 --version=4.0.0.410700 -y
#choco install firefox -y

# Install node v14.17.3
choco install nodejs.install --version=14.17.3 -y


# 4.0. Create the benchmark folder & add an signal that the "EC2Launch Service" is done executing everything inside "user_data"
# mkdir ${local.timings_folder}
New-Item -ItemType Directory -Path "${local.user_data_done}" -Force

Stop-Transcript
</powershell>
EOF
}

# Get latest Windows Server 2022 AMI
data "aws_ami" "windows-2022" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base*"]
  }
}


resource "aws_instance" "windows_server" {
  # ami                    = "ami-0069eac59d05ae12b" # Microsoft Windows Server 2022 Base
  ami                    = data.aws_ami.windows-2022.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.meteor_security_group.id]
  key_name               = var.key_pair_name
  user_data              = data.template_file.windows-userdata.rendered

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "meteor-server"
    Environment = "dev"
  }

  volume_tags = {
    Name = "meteor-volume"
  }

  provisioner "local-exec" {
    command    = "echo The server IP address is ${self.public_ip}."
    on_failure = continue
  }
}

resource "null_resource" "copy_scripts" {
  triggers = {
    timings_sh_hash               = local.timings_sh_hash
  }

  connection {
    type        = "winrm"
    user        = var.user_name
    password    = var.user_password
    host        = aws_instance.windows_server.public_ip
    timeout     = "50m"
  }

  provisioner "file" {
    source      = "${path.module}/01_folder-check.ps1"
    destination = "${local.timings_folder}/01_folder-check.ps1"
  }

  provisioner "file" {
    source      = "${path.module}/02_process-and-folder-exclusions.ps1"
    destination = "${local.timings_folder}/02_process-and-folder-exclusions.ps1"
  }

  provisioner "file" {
    source      = "${path.module}/timings.ps1"
    destination = "${local.timings_folder}/03_windows-timings.ps1"
  }

  # this will restart the server once EC2 Launch Agent finishes provisioning the instance
  provisioner "remote-exec" {
    inline = [<<-EOT
    powershell -ExecutionPolicy Bypass -File ${local.timings_folder}/01_folder-check.ps1 -folderPath "${local.user_data_done}"
    EOT
    ]
  }
  # wait while the server is rebooted in the previous step
  provisioner "local-exec" {
    command = "sleep 7"
  }

  # The transcript will be saved to C:\Users\Administrator\meteor-timings\timings.log
  provisioner "remote-exec" {
    inline = [<<-EOT
    powershell -ExecutionPolicy Bypass -File ${local.timings_folder}/02_process-and-folder-exclusions.ps1
    powershell -ExecutionPolicy Bypass -File ${local.timings_folder}/03_windows-timings.ps1
    powershell -Command "Start-Service sshd"
    EOT
    ]    
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.private_key_path} ${var.user_name}@${aws_instance.windows_server.public_ip}:${local.timings_folder}/timings.csv ."
  }

  depends_on = [
    aws_instance.windows_server
  ]
}

output "windows_server_ip" {
  value = aws_instance.windows_server.public_ip
}

output "windows_ami" {
  value = data.aws_ami.windows-2022.image_id
}
