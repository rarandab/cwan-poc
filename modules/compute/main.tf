# Data resource to determine the latest Amazon Linux2 AMI
data "aws_ssm_parameter" "amzn-linux-ami" {
  region = var.region
  name   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Security Group - EC2 instance
resource "aws_security_group" "instance_sg" {
  region      = var.region
  name        = local.instance_sg.name
  description = local.instance_sg.description
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = local.instance_sg.ingress
    content {
      description = ingress.value.description
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = local.instance_sg.egress
    content {
      description = egress.value.description
      from_port   = egress.value.from
      to_port     = egress.value.to
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = {
    Name = local.instance_sg.name
  }
}

resource "aws_instance" "workload" {
  count = var.number_azs

  region                      = var.region
  ami                         = data.aws_ssm_parameter.amzn-linux-ami.value
  associate_public_ip_address = false
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  subnet_id                   = var.workload_subnets[count.index]
  iam_instance_profile        = var.ec2_iam_instance_profile

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name                = format("%s-%s-ec2-wkl%02d", var.identifier, var.region_short_name, count.index + 1)
    coe_scheduler_state = "running"
  }
}
