module "shr_vpc" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source   = "../terraform-aws-vpc"
  for_each = { for el in var.core_network_config.edge_locations : el.region => el }

  name                                 = format("%s-%s-vpc-shr", var.project_code, local.region_short_names[each.key])
  region                               = each.value.region
  cidr_block                           = local.shr_cidrs[each.key]
  vpc_assign_generated_ipv6_cidr_block = false
  vpc_egress_only_internet_gateway     = false
  azs                                  = slice(data.aws_availability_zones.available[each.value.region].names, 0, 2)
  core_network = {
    id  = aws_networkmanager_core_network.this.id
    arn = aws_networkmanager_core_network.this.arn
  }
  core_network_routes = {
    enp = aws_ec2_managed_prefix_list.corpo[each.key].id
    dns = aws_ec2_managed_prefix_list.corpo[each.key].id
  }
  subnets = {
    enp = {
      name_prefix = format("%s-%s-vsn-enp", var.project_code, local.region_short_names[each.key])
      cidrs       = cidrsubnets(cidrsubnet(local.shr_cidrs[each.key], 1, 0), 1, 1)
    }
    dns = {
      name_prefix = format("%s-%s-vsn-dns", var.project_code, local.region_short_names[each.key])
      cidrs       = cidrsubnets(cidrsubnet(local.shr_cidrs[each.key], 2, 2), 1, 1)
    }
    core_network = {
      name_prefix            = format("%s-%s-vsn-cwn", var.project_code, local.region_short_names[each.key])
      cidrs                  = cidrsubnets(cidrsubnet(local.shr_cidrs[each.key], 2, 3), 1, 1)
      appliance_mode_support = false
      require_acceptance     = true
      accept_attachment      = true

      tags = {
        "tec:cwnsgm" = format("cwnsgm%sShr", title(var.project_code))
      }
    }
  }
  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 1
  }
}

resource "aws_security_group" "endpoint" {
  for_each = { for el in var.core_network_config.edge_locations : el.region => el }

  region      = each.key
  name        = format("%s-%s-vsg-enpoints", var.project_code, local.region_short_names[each.key])
  description = "Service endpoints SG"
  vpc_id      = module.shr_vpc[each.key].vpc_attributes.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "service" {
  for_each = { for re in local.regional_endpoints : "${re.region}-${re.service}" => re }

  region              = each.value.region
  service_name        = format("com.amazonaws.%s.%s", each.value.region, each.value.service)
  vpc_id              = module.shr_vpc[each.value.region].vpc_attributes.id
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  dns_options {
    private_dns_only_for_inbound_resolver_endpoint = false
  }
  subnet_ids = values({ for k, v in module.shr_vpc[each.value.region].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "enp" })
  security_group_ids = [
    aws_security_group.endpoint[each.value.region].id,
  ]
  tags = {
    Name = format("%s-%s-enp-%s", var.project_code, local.region_short_names[each.value.region], each.value.service)
  }
}

resource "aws_security_group" "r53_inbound" {
  for_each = { for el in var.core_network_config.edge_locations : el.region => el }

  region      = each.key
  name        = format("%s-%s-vsg-iep", var.project_code, local.region_short_names[each.key])
  description = "Route53 resolver SG"
  vpc_id      = module.shr_vpc[each.key].vpc_attributes.id
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [for b in local.shr_cidrs : cidrsubnet(b, 2, 2)]
  }
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [for b in local.shr_cidrs : cidrsubnet(b, 2, 2)]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [for b in local.shr_cidrs : cidrsubnet(b, 2, 2)]
  }
}

resource "aws_security_group" "r53_outbound" {
  for_each = { for el in var.core_network_config.edge_locations : el.region => el }

  region      = each.key
  name        = format("%s-%s-vsg-oep", var.project_code, local.region_short_names[each.key])
  description = "Route53 resolver SG"
  vpc_id      = module.shr_vpc[each.key].vpc_attributes.id
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [for b in local.shr_cidrs : cidrsubnet(b, 2, 2)]
  }
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [for b in local.shr_cidrs : cidrsubnet(b, 2, 2)]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [for b in local.shr_cidrs : cidrsubnet(b, 2, 2)]
  }
}

resource "aws_route53_resolver_endpoint" "inbound" {
  for_each = { for el in var.core_network_config.edge_locations : el.region => el }

  region                 = each.key
  name                   = format("%s-%s-r53-iep", var.project_code, local.region_short_names[each.key])
  direction              = "INBOUND"
  resolver_endpoint_type = "IPV4"
  security_group_ids     = [aws_security_group.r53_inbound[each.key].id]
  dynamic "ip_address" {
    for_each = toset(values({ for k, v in module.shr_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "dns" }))
    content {
      subnet_id = ip_address.value
    }
  }
  protocols = ["Do53", "DoH"]
  tags = {
    Name = format("%s-%s-r53-iep", var.project_code, local.region_short_names[each.key])
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  for_each = { for el in var.core_network_config.edge_locations : el.region => el }

  region                 = each.key
  name                   = format("%s-%s-r53-oep", var.project_code, local.region_short_names[each.key])
  direction              = "OUTBOUND"
  resolver_endpoint_type = "IPV4"
  security_group_ids     = [aws_security_group.r53_outbound[each.key].id]
  dynamic "ip_address" {
    for_each = toset(values({ for k, v in module.shr_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "dns" }))
    content {
      subnet_id = ip_address.value
    }
  }
  protocols = ["Do53", "DoH"]
  tags = {
    Name = format("%s-%s-r53-oep", var.project_code, local.region_short_names[each.key])
  }
}

resource "aws_route53_resolver_rule" "default" {
  for_each = { for el in var.core_network_config.edge_locations : el.region => el }

  region               = each.key
  domain_name          = "."
  name                 = format("%s-%s-rrr-dfl", var.project_code, local.region_short_names[each.key])
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound[each.key].id
  dynamic "target_ip" {
    //for_each = toset(aws_route53_resolver_endpoint.outbound[each.key].ip_addresses)
    for_each = toset(aws_route53_resolver_endpoint.inbound[each.key].ip_address[*].ip)
    content {
      ip = target_ip.value
    }
  }
  tags = {
    Name = format("%s-%s-rrr-dfl", var.project_code, local.region_short_names[each.key])
  }
}

resource "aws_route53_resolver_rule" "aws" {
  //for_each = { for el in var.core_network_config.edge_locations : el.region => el }
  for_each = { for i in setproduct(
    [for el in var.core_network_config.edge_locations : el.region],
    [for el in var.core_network_config.edge_locations : el.region]
    ) : "${local.region_short_names[i[0]]}-${local.region_short_names[i[1]]}" => { orig = i[0], dest = i[1] } if i[0] != i[1]
  }

  region               = each.value.orig
  domain_name          = format("%s.amazonaws.com", each.value.dest)
  name                 = format("%s-%s-rrr-aws_%s", var.project_code, local.region_short_names[each.value.orig], local.region_short_names[each.value.dest])
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound[each.value.orig].id
  dynamic "target_ip" {
    //for_each = toset(aws_route53_resolver_endpoint.outbound[each.key].ip_addresses)
    for_each = toset(aws_route53_resolver_endpoint.inbound[each.value.dest].ip_address[*].ip)
    content {
      ip = target_ip.value
    }
  }
  tags = {
    Name = format("%s-%s-rrr-aws_%s", var.project_code, local.region_short_names[each.value.orig], local.region_short_names[each.value.dest])
  }
}
