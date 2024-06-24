variable "private_key_path" {
  description = "The full path to your private key for SSH authentication"
  type        = string
  # default     = "~/.ssh/id_rsa"
  # You can set a default value or leave it empty and provide the value when running Terraform
  # default = "/path/to/your/private/key"
}

variable "region" {
  description = "The AWS region to launch resources in"
  type = string
  default     = "us-east-1"
}

variable "key_pair_name" {
  description = "The name of the key pair to use to launch VMs within the specified AWS region"
  type = string
  default     = "<key-pair-name>"
}

variable "user_subfolder" {
  description = "The user account subfolder where the shell script will be run on the VM"
  type = string
  default = "meteor-timings"
}

variable "user_name" {
  description = "The user account under which the shell script will be run on the VM"
  type = string
  default = "ubuntu"
}

variable "instance_type" {
  description = "The AWS instance type to use"
  type = string
  default = "t2.small"
}