variable "prefix" {
  description = "The name prefix for all resources created by Terraform."
  type        = string
  default     = "meteor"
}

resource "aws_security_group" "meteor_security_group" {
  name        = "${var.prefix}_security-group"
  description = "meteor security group"
}

# Only available in Terraform AWS Provider version v4.40.0 and up
resource "aws_security_group_rule" "ingress22" {
  security_group_id = aws_security_group.meteor_security_group.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ingress3389" {
  security_group_id = aws_security_group.meteor_security_group.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 3389
  to_port     = 3389
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ingress5985" {
  security_group_id = aws_security_group.meteor_security_group.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 5985
  to_port     = 5986
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egressAny" {
  security_group_id = aws_security_group.meteor_security_group.id

  type        = "egress"
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_ec2_tag" "meteor_security_group_tag00" {
  resource_id = aws_security_group.meteor_security_group.id
  key         = "Name"
  value       = aws_security_group.meteor_security_group.name # "${var.prefix}_security-group"
}

resource "aws_ec2_tag" "meteor_security_group_rule_tag01" {
  resource_id = aws_security_group_rule.ingress22.security_group_rule_id
  key         = "Name"
  value       = "${var.prefix}_sg_ingress-22"
}

resource "aws_ec2_tag" "meteor_security_group_rule_tag02" {
  resource_id = aws_security_group_rule.ingress3389.security_group_rule_id
  key         = "Name"
  value       = "${var.prefix}_sg_ingress-3389"
}

resource "aws_ec2_tag" "meteor_security_group_rule_tag03" {
  resource_id = aws_security_group_rule.ingress5985.security_group_rule_id
  key         = "Name"
  value       = "${var.prefix}_sg_ingress-5985"
}

resource "aws_ec2_tag" "meteor_security_group_rule_tag04" {
  resource_id = aws_security_group_rule.egressAny.security_group_rule_id
  key         = "Name"
  value       = "${var.prefix}_sg_egress-any"
}

