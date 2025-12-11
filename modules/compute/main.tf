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
  tags = {
    Name = local.instance_sg.name
  }
}

resource "aws_security_group_rule" "instance_i" {
  for_each = local.instance_sg.ingress

  region            = var.region
  security_group_id = aws_security_group.instance_sg.id
  type              = "ingress"
  from_port         = each.value.from
  to_port           = each.value.to
  protocol          = each.value.protocol
  cidr_blocks       = try(each.value.cidr_blocks, null)
  prefix_list_ids   = try(each.value.prefix_list_ids, null)
  description       = each.value.description
}

resource "aws_security_group_rule" "instance_e" {
  for_each = local.instance_sg.egress

  region            = var.region
  security_group_id = aws_security_group.instance_sg.id
  type              = "ingress"
  from_port         = each.value.from
  to_port           = each.value.to
  protocol          = each.value.protocol
  cidr_blocks       = try(each.value.cidr_blocks, null)
  prefix_list_ids   = try(each.value.prefix_list_ids, null)
  description       = each.value.description
}

data "template_cloudinit_config" "user_data" {
  base64_encode = true
  gzip          = false

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/bootstrap.sh")
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
  monitoring                  = true
  ebs_optimized               = true

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


resource "aws_lb_target_group_attachment" "workload" {
  count = var.number_azs

  region           = var.region
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.workload[count.index].id
  port             = 80
}
