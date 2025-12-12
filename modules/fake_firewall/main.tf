data "aws_ssm_parameter" "amzn-linux-ami" {
  region = var.region
  name   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_caller_identity" "current" {}

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

# EC2 instances
data "template_cloudinit_config" "user_data" {
  base64_encode = true
  gzip          = false

  part {
    content_type = "text/x-shellscript"
    content      = file("${path.module}/bootstrap.sh")
  }
}

resource "aws_instance" "firewall" {
  count = var.number_azs

  region                      = var.region
  ami                         = data.aws_ssm_parameter.amzn-linux-ami.value
  associate_public_ip_address = false
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  subnet_id                   = var.firewall_subnets[count.index]
  iam_instance_profile        = var.ec2_iam_instance_profile
  user_data_base64            = data.template_cloudinit_config.user_data.rendered
  user_data_replace_on_change = true
  source_dest_check           = false
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
    Name                = format("%s-%s-ec2-nfw%02d", var.identifier, var.region_short_name, count.index + 1)
    coe_scheduler_state = "running"
  }
}

resource "aws_lb_target_group" "firewall_instances" {
  region   = var.region
  name     = format("%s-%s-ltg-nfw", var.identifier, var.region_short_name)
  port     = 6081
  protocol = "GENEVE"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "firewall" {
  count = length(aws_instance.firewall)

  region           = var.region
  target_group_arn = aws_lb_target_group.firewall_instances.arn
  target_id        = aws_instance.firewall[count.index].id
}

resource "aws_lb" "firewall" {
  region                           = var.region
  name                             = format("%s-%s-glb-nfw", var.identifier, var.region_short_name)
  load_balancer_type               = "gateway"
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = true

  dynamic "subnet_mapping" {
    for_each = var.gwlb_subnets
    content {
      subnet_id = subnet_mapping.value
    }
  }
}

resource "aws_lb_listener" "firewall" {
  region            = var.region
  load_balancer_arn = aws_lb.firewall.id

  default_action {
    target_group_arn = aws_lb_target_group.firewall_instances.id
    type             = "forward"
  }
}

resource "aws_vpc_endpoint_service" "firewall" {
  region                     = var.region
  acceptance_required        = true
  gateway_load_balancer_arns = [aws_lb.firewall.arn]
  tags = {
    Name = format("%s-%s-ves-nfw", var.identifier, var.region_short_name)
  }
}

resource "aws_vpc_endpoint_service_allowed_principal" "firewall_vpces_allow_me" {
  region                  = var.region
  vpc_endpoint_service_id = aws_vpc_endpoint_service.firewall.id
  principal_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}
