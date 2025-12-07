# Cloud WAN Connect Tunnel-Less Attachment Configuration
# This creates a Linux instance with FRRouting that connects to Cloud WAN via Connect Tunnel-Less
#
# Connect Tunnel-Less simplifies the setup by eliminating GRE tunnels - BGP runs directly
# over the VPC connection to Cloud WAN, making configuration much simpler.
#
# Example terraform.tfvars configuration:
# connect = {
#   region           = "eu-west-1"
#   vpc_cidr         = "172.17.0.0/25"
#   segment          = "hyb"
#   bgp_asn          = 65100
#   instance_type    = "t3.micro"
#   additional_cidrs = ["172.30.0.0/16"]
#   bgp_peer_cidr    = "169.254.10.0/29"
# }

# Data source for Amazon Linux 2023 AMI
data "aws_ssm_parameter" "sdwan" {
  for_each = local.sdw_cidrs

  region = each.key
  name   = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

module "sdw_vpc" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source   = "../terraform-aws-vpc"
  for_each = local.sdw_cidrs

  name                                 = format("%s-%s-sdw-vpc", var.project_code, local.region_short_names[each.key])
  region                               = each.key
  cidr_block                           = each.value
  vpc_assign_generated_ipv6_cidr_block = false
  vpc_egress_only_internet_gateway     = false
  az_count                             = 1
  core_network = {
    id  = aws_networkmanager_core_network.this.id
    arn = aws_networkmanager_core_network.this.arn
  }
  subnets = {
    public = {
      name_prefix               = format("%s-%s-sdw-pub-snt", var.project_code, local.region_short_names[each.key])
      netmask                   = 28
      nat_gateway_configuration = "single_az"
      map_public_ip_on_launch   = false
    }
    core_network = {
      name_prefix             = format("%s-%s-sdw-cwn-snt", var.project_code, local.region_short_names[each.key])
      netmask                 = 28
      connect_to_public_natgw = true
      appliance_mode_support  = false
      require_acceptance      = true
      accept_attachment       = true

      tags = {
        "tec:cwnsgm" = format("cwnsgm%sHyb", title(var.project_code))
      }
    }
  }
  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 1
  }
}

resource "aws_security_group" "sdwan" {
  for_each = local.sdw_cidrs

  region      = each.key
  name        = format("%s-%s-sdw-sg", var.project_code, local.region_short_names[each.key])
  description = "Security group for Cloud WAN Connect Tunnel-Less instance"
  vpc_id      = module.sdw_vpc[each.key].vpc_attributes.id
}

resource "aws_security_group_rule" "sdwan_i_bgp" {
  for_each = local.sdw_cidrs

  region            = each.key
  security_group_id = aws_security_group.sdwan[each.key].id
  type              = "ingress"
  description       = "BGP from Cloud Wan"
  protocol          = "tcp"
  from_port         = 179
  to_port           = 179
  cidr_blocks       = [for bc in try(aws_networkmanager_connect_peer.sdwan_peer[each.key].configuration[0].bgp_configurations, []) : format("%s/32", bc.core_network_address)]
}

resource "aws_security_group_rule" "sdwan_o_any" {
  for_each = local.sdw_cidrs

  region            = each.key
  security_group_id = aws_security_group.sdwan[each.key].id
  type              = "egress"
  description       = "All outbound"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_network_interface" "sdwan" {
  for_each = local.sdw_cidrs

  region          = each.key
  subnet_id       = module.sdw_vpc[each.key].core_network_subnet_attributes_by_az[module.sdw_vpc[each.key].azs[0]].id
  security_groups = [aws_security_group.sdwan[each.key].id]
  tags = {
    Name = format("%s-%s-sdw-eni", var.project_code, local.region_short_names[each.key])
  }
}

# EC2 instances
data "template_cloudinit_config" "sdwan" {
  for_each = local.sdw_cidrs

  base64_encode = true
  gzip          = true
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/sdwan-frr-userdata.sh.tftpl", {
      instance_id   = format("sdwan-%s", local.region_short_names[each.key])
      instance_ip   = aws_network_interface.sdwan[each.key].private_ip
      local_bgp_asn = var.sdwan.asn
      peer_asn      = aws_networkmanager_connect_peer.sdwan_peer[each.key].configuration[0].bgp_configurations[0].core_network_asn
      peer_ip1      = aws_networkmanager_connect_peer.sdwan_peer[each.key].configuration[0].bgp_configurations[0].core_network_address
      peer_ip2      = aws_networkmanager_connect_peer.sdwan_peer[each.key].configuration[0].bgp_configurations[1].core_network_address
      cidrs         = var.sdwan.cidrs
    })
  }
}

resource "aws_instance" "sdwan" {
  for_each = local.sdw_cidrs

  region                      = each.key
  ami                         = data.aws_ssm_parameter.sdwan[each.key].value
  instance_type               = "t3.micro"
  iam_instance_profile        = aws_iam_instance_profile.common.name
  user_data_base64            = data.template_cloudinit_config.sdwan[each.key].rendered
  user_data_replace_on_change = true
  primary_network_interface {
    network_interface_id = aws_network_interface.sdwan[each.key].id
  }
  tags = {
    Name = format("%s-%s-sdw-ec2", var.project_code, local.region_short_names[each.key])
  }
}

resource "aws_networkmanager_connect_attachment" "sdwan" {
  for_each = local.sdw_cidrs

  core_network_id         = aws_networkmanager_core_network.this.id
  transport_attachment_id = module.sdw_vpc[each.key].core_network_attachment.id
  edge_location           = each.key
  options {
    protocol = "NO_ENCAP"
  }
  tags = {
    "Name"       = format("%s-%s-sdw-connect-att", var.project_code, local.region_short_names[each.key])
    "tec:cwnsgm" = format("cwnsgm%sHyb", title(var.project_code))
  }
  depends_on = [aws_networkmanager_core_network_policy_attachment.this]
}

resource "aws_networkmanager_attachment_accepter" "sdwan" {
  for_each        = local.sdw_cidrs
  attachment_id   = aws_networkmanager_connect_attachment.sdwan[each.key].id
  attachment_type = aws_networkmanager_connect_attachment.sdwan[each.key].attachment_type
}

# Connect Peer
resource "aws_networkmanager_connect_peer" "sdwan_peer" {
  for_each = local.sdw_cidrs

  connect_attachment_id = aws_networkmanager_connect_attachment.sdwan[each.key].id
  peer_address          = aws_network_interface.sdwan[each.key].private_ip
  bgp_options {
    peer_asn = var.sdwan.asn
  }
  subnet_arn = module.sdw_vpc[each.key].core_network_subnet_attributes_by_az[module.sdw_vpc[each.key].azs[0]].arn

  tags = {
    Name = format("%s-%s-sdw-connect-peer", var.project_code, local.region_short_names[each.key])
  }
}

resource "aws_route" "cwan_peers" {
  for_each = { for i in flatten([for k, v in local.sdw_cidrs : [for index in range(0, 2) : { region = k, index = index }]]) : "${i.region}-${i.index}" => i }

  region                 = each.value.region
  route_table_id         = module.sdw_vpc[each.value.region].rt_attributes_by_type_by_az.core_network[module.sdw_vpc[each.value.region].azs[0]].id
  destination_cidr_block = format("%s/32", aws_networkmanager_connect_peer.sdwan_peer[each.value.region].configuration[0].bgp_configurations[each.value.index].core_network_address)
  core_network_arn       = aws_networkmanager_core_network.this.arn
}

