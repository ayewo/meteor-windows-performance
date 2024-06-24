
locals { 
  timings_sh_hash           = filemd5("${path.module}/timings.sh")
  timings_folder            = "/home/${var.user_name}/${var.user_subfolder}" 
}

data "template_file" "timings_sh" {
  template = file("${path.module}/timings.sh.tpl")

  vars = {
    timings_folder = "${local.timings_folder}" 
  }
}

resource "local_file" "timings_sh" {
  filename = "${path.module}/timings.sh"
  content  = data.template_file.timings_sh.rendered
}

resource "aws_instance" "linux_server" {
  ami                    = "ami-0e001c9271cf7f3b9"
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.meteor_security_group.id]
  key_name               = var.key_pair_name

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
  }

  tags = {
    Name = "meteor-server"
  }

  volume_tags = {
    Name = "meteor-volume"
  }

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(pathexpand(var.private_key_path))
    host        = aws_instance.linux_server.public_ip
  }

  provisioner "local-exec" {
    command    = "echo The server IP address is ${self.public_ip}."
    on_failure = continue
  }

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      host = self.public_ip
      private_key = file(pathexpand(var.private_key_path))
    }

    inline = [<<-EOT
    # install updates, dependencies needed by node/gyp and the zip cli ("NEEDRESTART_MODE=a" tip from https://askubuntu.com/a/1431746)
    sudo add-apt-repository universe -y && sudo apt update -y && sudo NEEDRESTART_MODE=a apt install -y zip build-essential

    # create benchmark folders
    mkdir -p ${local.timings_folder}

    # install nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

    # install node 14 and 20
    nvm install 14.17.3
    nvm install 20.11.1
    nvm use 14.17.3

    node --version && npm --version

    EOT
    ]

    on_failure = fail
  }
}

resource "null_resource" "copy_scripts" {
  triggers = {
    timings_sh_hash               = local.timings_sh_hash
  }

  connection {
    type        = "ssh"
    user        = var.user_name
    private_key = file(pathexpand(var.private_key_path))
    host        = aws_instance.linux_server.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/timings.sh"
    destination = "${local.timings_folder}/timings.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "#!/bin/bash",
      "cd ${local.timings_folder}",
      "chmod +x ./timings.sh",
      "./timings.sh",
    ]
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.private_key_path} ${var.user_name}@${aws_instance.linux_server.public_ip}:${local.timings_folder}/timings.csv ."
  }

  depends_on = [
    aws_instance.linux_server
  ]
}


output "linux_server_ip" {
  value = aws_instance.linux_server.public_ip
}
