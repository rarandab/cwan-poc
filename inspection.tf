resource "aws_ec2_managed_prefix_list" "corpo" {
  for_each = toset([for el in var.core_network_config.edge_locations : el.region])

  region         = each.key
  name           = format("%s-%s-vpl-corpo", var.project_code, local.region_short_names[each.key])
  address_family = "IPv4"
  max_entries    = 5
  dynamic "entry" {
    for_each = local.corpo_cidrs
    content {
      description = entry.key
      cidr        = entry.value
    }
  }
}

module "ffw_vpc" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source   = "../terraform-aws-vpc"
  for_each = var.inspection_type == "fake_firewall" ? { for el in var.core_network_config.edge_locations : el.region => el if el.inspection } : {}

  name                                 = format("%s-%s-vpc-ffw", var.project_code, local.region_short_names[each.key])
  region                               = each.value.region
  cidr_block                           = local.ffw_cidrs[each.key]
  vpc_assign_generated_ipv6_cidr_block = false
  vpc_egress_only_internet_gateway     = false
  azs                                  = slice(data.aws_availability_zones.available[each.value.region].names, 0, 2)
  //azs                                  = [for az in local.azs_by_region[each.value.region] : "${each.value.region}${az}"]
  core_network = {
    id  = aws_networkmanager_core_network.this.id
    arn = aws_networkmanager_core_network.this.arn
  }
  subnets = {
    public = {
      name_prefix               = format("%s-%s-vsn-pub", var.project_code, local.region_short_names[each.key])
      cidrs                     = cidrsubnets(cidrsubnet(local.ffw_cidrs[each.key], 2, 0), 1, 1)
      nat_gateway_configuration = "single_az"
      map_public_ip_on_launch   = false
    }
    wkl = {
      name_prefix             = format("%s-%s-vsn-wkl", var.project_code, local.region_short_names[each.key])
      cidrs                   = cidrsubnets(cidrsubnet(local.ffw_cidrs[each.key], 2, 1), 1, 1)
      connect_to_public_natgw = true
    }
    glb = {
      name_prefix = format("%s-%s-vsn-glb", var.project_code, local.region_short_names[each.key])
      cidrs       = cidrsubnets(cidrsubnet(local.ffw_cidrs[each.key], 2, 2), 1, 1)
    }
    core_network = {
      name_prefix            = format("%s-%s-vsn-cwn", var.project_code, local.region_short_names[each.key])
      cidrs                  = cidrsubnets(cidrsubnet(local.ffw_cidrs[each.key], 2, 3), 1, 1)
      appliance_mode_support = false
      require_acceptance     = true
      accept_attachment      = true
      tags = {
        "tec:cwnsgm" = format("cwnsgm%sNva", title(var.project_code))
      }
    }
  }
  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 1
  }
}

module "nfg_vpc" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source   = "../terraform-aws-vpc"
  for_each = toset([for el in var.core_network_config.edge_locations : el.region if el.inspection])

  name                                 = format("%s-%s-vpc-nfg", var.project_code, local.region_short_names[each.key])
  region                               = each.value
  cidr_block                           = local.non_routeable_cidrs["inspection"]
  vpc_assign_generated_ipv6_cidr_block = false
  vpc_egress_only_internet_gateway     = false
  azs                                  = slice(data.aws_availability_zones.available[each.value].names, 0, 2)
  core_network = {
    id  = aws_networkmanager_core_network.this.id
    arn = aws_networkmanager_core_network.this.arn
  }
  subnets = {
    core_network = {
      name_prefix            = format("%s-%s-vsn-cwn", var.project_code, local.region_short_names[each.key])
      cidrs                  = cidrsubnets(cidrsubnet(local.non_routeable_cidrs["inspection"], 2, 0), 1, 1)
      appliance_mode_support = true
      require_acceptance     = true
      accept_attachment      = true
      tags = {
        "tec:cwnnfg" = format("cwnnfg%sIns", title(var.project_code))
      }
    }
    nfw = {
      name_prefix             = format("%s-%s-vsn-nfw", var.project_code, local.region_short_names[each.key])
      cidrs                   = cidrsubnets(cidrsubnet(local.non_routeable_cidrs["inspection"], 2, 1), 1, 1)
      connect_to_public_natgw = true
    }
    public = {
      name_prefix               = format("%s-%s-vsn-pub", var.project_code, local.region_short_names[each.key])
      cidrs                     = cidrsubnets(cidrsubnet(local.non_routeable_cidrs["inspection"], 2, 2), 1, 1)
      nat_gateway_configuration = "all_azs"
      map_public_ip_on_launch   = false
    }
  }
  core_network_routes = {
    nfw = aws_ec2_managed_prefix_list.corpo[each.key].id
  }
  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 1
  }
}

module "fake_firewall" {
  source   = "./modules/fake_firewall"
  for_each = var.inspection_type == "fake_firewall" ? { for el in var.core_network_config.edge_locations : el.region => el if el.inspection } : {}

  region                   = each.value.region
  region_short_name        = local.region_short_names[each.value.region]
  vpc_id                   = module.ffw_vpc[each.key].vpc_attributes.id
  firewall_subnets         = values({ for k, v in module.ffw_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "wkl" })
  gwlb_subnets             = values({ for k, v in module.ffw_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "glb" })
  gwlb_subnets_cidr        = values({ for k, v in module.ffw_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.cidr_block if split("/", k)[0] == "glb" })
  instance_type            = "t3.small"
  ec2_iam_instance_profile = aws_iam_instance_profile.common.id
  number_azs               = length(module.ffw_vpc[each.key].azs)
  identifier               = var.project_code
}

resource "aws_vpc_endpoint" "fake_firewall" {
  for_each = var.inspection_type == "fake_firewall" ? { for s in local.nfg_nfw_subnets : "${s.vpc_key}-${s.az_id}" => s } : {}

  region            = each.value.vpc_key
  service_name      = module.fake_firewall[each.value.vpc_key].endpoint_service.service_name
  vpc_endpoint_type = module.fake_firewall[each.value.vpc_key].endpoint_service.service_type
  vpc_id            = module.nfg_vpc[each.value.vpc_key].vpc_attributes.id
  subnet_ids        = [each.value.subnet_id]
  tags = {
    Name = format("%s-%s-gle-nfg", var.project_code, each.key)
  }
}

resource "aws_route" "nfg_cwn_dfl" {
  for_each = { for rt in local.nfg_cwn_routes : "${rt.vpc_key}-${rt.az_id}" => rt }

  region                 = each.value.vpc_key
  route_table_id         = each.value.rt_id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = each.value.en_id
}

resource "aws_route" "nfg_pub_corpo" {
  for_each = { for rt in local.nfg_pub_routes : "${rt.vpc_key}-${rt.az_id}-${rt.cidr}" => rt }

  region                 = each.value.vpc_key
  route_table_id         = each.value.rt_id
  destination_cidr_block = each.value.cidr
  vpc_endpoint_id        = each.value.en_id
}

# -----------------------------------------------------------------------------
# AWS Network Firewall Resources (when inspection_type == "network_firewall")
# -----------------------------------------------------------------------------

resource "aws_networkfirewall_rule_group" "allow_icmp_http" {
  for_each = var.inspection_type == "network_firewall" ? {
    for el in var.core_network_config.edge_locations : el.region => el if el.inspection
  } : {}

  provider = aws
  region   = each.value.region
  capacity = 100
  name     = format("%s-%s-nfwrg-allow", var.project_code, local.region_short_names[each.key])
  type     = "STATEFUL"

  rule_group {
    rules_source {
      # ICMP Allow Rule
      stateful_rule {
        action = "PASS"
        header {
          destination      = "ANY"
          destination_port = "ANY"
          direction        = "ANY"
          protocol         = "ICMP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword  = "sid"
          settings = ["1"]
        }
      }
      # HTTP Allow Rule
      stateful_rule {
        action = "PASS"
        header {
          destination      = "ANY"
          destination_port = "80"
          direction        = "ANY"
          protocol         = "TCP"
          source           = "ANY"
          source_port      = "ANY"
        }
        rule_option {
          keyword  = "sid"
          settings = ["2"]
        }
      }
    }
  }

  tags = {
    Name = format("%s-%s-nfwrg-allow", var.project_code, local.region_short_names[each.key])
  }
}


resource "aws_networkfirewall_firewall_policy" "this" {
  for_each = var.inspection_type == "network_firewall" ? {
    for el in var.core_network_config.edge_locations : el.region => el if el.inspection
  } : {}

  provider = aws
  region   = each.value.region
  name     = format("%s-%s-nfwpol", var.project_code, local.region_short_names[each.key])

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.allow_icmp_http[each.key].arn
    }
  }

  tags = {
    Name = format("%s-%s-nfwpol", var.project_code, local.region_short_names[each.key])
  }
}

resource "aws_networkfirewall_firewall" "this" {
  for_each = var.inspection_type == "network_firewall" ? {
    for el in var.core_network_config.edge_locations : el.region => el if el.inspection
  } : {}

  provider            = aws
  region              = each.value.region
  name                = format("%s-%s-nfw", var.project_code, local.region_short_names[each.key])
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this[each.key].arn
  vpc_id              = module.nfg_vpc[each.key].vpc_attributes.id

  dynamic "subnet_mapping" {
    for_each = {
      for k, v in module.nfg_vpc[each.key].private_subnet_attributes_by_az :
      split("/", k)[1] => v.id if split("/", k)[0] == "nfw"
    }
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = {
    Name = format("%s-%s-nfw", var.project_code, local.region_short_names[each.key])
  }
}

# -----------------------------------------------------------------------------
# AWS Network Firewall Logging (when inspection_type == "network_firewall")
# -----------------------------------------------------------------------------

# CloudWatch Log Group for Network Firewall alert logs
# Naming convention: /aws/networkfirewall/{project_code}-{region_short}-nfw
resource "aws_cloudwatch_log_group" "nfw" {
  for_each = var.inspection_type == "network_firewall" ? {
    for el in var.core_network_config.edge_locations : el.region => el if el.inspection
  } : {}

  provider          = aws
  region            = each.value.region
  name              = format("/aws/networkfirewall/%s-%s-nfw", var.project_code, local.region_short_names[each.key])
  retention_in_days = 7

  tags = {
    Name = format("%s-%s-cwl-nfw", var.project_code, local.region_short_names[each.key])
  }
}

# Network Firewall logging configuration for ALERT logs to CloudWatch
resource "aws_networkfirewall_logging_configuration" "this" {
  for_each = var.inspection_type == "network_firewall" ? {
    for el in var.core_network_config.edge_locations : el.region => el if el.inspection
  } : {}

  provider     = aws
  region       = each.value.region
  firewall_arn = aws_networkfirewall_firewall.this[each.key].arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.nfw[each.key].name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }
  }
}
