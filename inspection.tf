resource "aws_ec2_managed_prefix_list" "corpo" {
  for_each = toset([for el in var.core_network_config.edge_locations : el.region])

  region         = each.key
  name           = format("%s-%s-corpo-pl", var.project_code, each.key)
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

module "nfw_vpc" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source = "../terraform-aws-vpc"
  //for_each = { for v in var.nva_vpcs : v.region => v if v.purpose == "nfw" }
  for_each = { for el in var.core_network_config.edge_locations : el.region => el if el.inspection }

  name                                 = format("%s-%s-nfw-vpc", var.project_code, local.region_short_names[each.key])
  region                               = each.value.region
  cidr_block                           = local.nfw_cidrs[each.key]
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
      name_prefix               = format("%s-%s-nfw-pub-snt", var.project_code, local.region_short_names[each.key])
      cidrs                     = cidrsubnets(cidrsubnet(local.nfw_cidrs[each.key], 2, 0), 1, 1)
      nat_gateway_configuration = "single_az"
      map_public_ip_on_launch   = false
    }
    nfw = {
      name_prefix             = format("%s-%s-nfw-nfw-snt", var.project_code, local.region_short_names[each.key])
      cidrs                   = cidrsubnets(cidrsubnet(local.nfw_cidrs[each.key], 2, 1), 1, 1)
      connect_to_public_natgw = true
    }
    glb = {
      name_prefix = format("%s-%s-nfw-glb-snt", var.project_code, local.region_short_names[each.key])
      cidrs       = cidrsubnets(cidrsubnet(local.nfw_cidrs[each.key], 2, 2), 1, 1)
    }
    core_network = {
      name_prefix            = format("%s-%s-nfw-cwn-snt", var.project_code, local.region_short_names[each.key])
      cidrs                  = cidrsubnets(cidrsubnet(local.nfw_cidrs[each.key], 2, 3), 1, 1)
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
  source = "../terraform-aws-vpc"
  //for_each = toset([for v in var.nva_vpcs : v.region if v.purpose == "nfw"])
  for_each = toset([for el in var.core_network_config.edge_locations : el.region if el.inspection])

  name                                 = format("%s-%s-nfg-vpc", var.project_code, local.region_short_names[each.key])
  region                               = each.value
  cidr_block                           = local.non_routeable_cidrs["inspection"]
  vpc_assign_generated_ipv6_cidr_block = false
  vpc_egress_only_internet_gateway     = false
  azs                                  = slice(data.aws_availability_zones.available[each.value].names, 0, 2)
  //azs                                  = [for az in local.azs_by_region[each.value] : "${each.value}${az}"]
  core_network = {
    id  = aws_networkmanager_core_network.this.id
    arn = aws_networkmanager_core_network.this.arn
  }
  subnets = {
    public = {
      name_prefix               = format("%s-%s-pub-snt", var.project_code, local.region_short_names[each.key])
      cidrs                     = cidrsubnets(cidrsubnet(local.non_routeable_cidrs["inspection"], 2, 0), 1, 1)
      nat_gateway_configuration = "single_az"
      map_public_ip_on_launch   = false
    }
    nfw = {
      name_prefix             = format("%s-%s-nfw-snt", var.project_code, local.region_short_names[each.key])
      cidrs                   = cidrsubnets(cidrsubnet(local.non_routeable_cidrs["inspection"], 2, 1), 1, 1)
      connect_to_public_natgw = true
    }
    core_network = {
      name_prefix            = format("%s-%s-cwn-snt", var.project_code, local.region_short_names[each.key])
      cidrs                  = cidrsubnets(cidrsubnet(local.non_routeable_cidrs["inspection"], 2, 3), 1, 1)
      appliance_mode_support = true
      require_acceptance     = true
      accept_attachment      = true

      tags = {
        "tec:cwnnfg" = format("cwnnfg%sIns", title(var.project_code))
      }
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

module "firewall" {
  source   = "./modules/firewall"
  for_each = { for el in var.core_network_config.edge_locations : el.region => el if el.inspection }

  region                   = each.value.region
  region_short_name        = local.region_short_names[each.value.region]
  vpc_id                   = module.nfw_vpc[each.key].vpc_attributes.id
  firewall_subnets         = values({ for k, v in module.nfw_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "nfw" })
  gwlb_subnets             = values({ for k, v in module.nfw_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "glb" })
  gwlb_subnets_cidr        = values({ for k, v in module.nfw_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.cidr_block if split("/", k)[0] == "glb" })
  instance_type            = "t3.small"
  ec2_iam_instance_profile = aws_iam_instance_profile.common.id
  number_azs               = length(module.nfw_vpc[each.key].azs)
  identifier               = var.project_code
}

resource "aws_vpc_endpoint" "firewall" {
  for_each = { for s in local.nfg_nfw_subnets : "${s.vpc_key}-${s.az_id}" => s }

  region            = each.value.vpc_key
  service_name      = module.firewall[each.value.vpc_key].endpoint_service.service_name
  subnet_ids        = [each.value.subnet_id]
  vpc_endpoint_type = module.firewall[each.value.vpc_key].endpoint_service.service_type
  vpc_id            = module.nfg_vpc[each.value.vpc_key].vpc_attributes.id
  tags = {
    Name = format("%s-%s-vse", var.project_code, each.key)
  }
}

resource "aws_route" "nfg_cwn_dfl" {
  for_each = { for rt in local.nfg_cwn_routes : "${rt.vpc_key}-${rt.az_id}" => rt }

  region                 = each.value.vpc_key
  route_table_id         = each.value.rt_id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = aws_vpc_endpoint.firewall[each.key].id
}

resource "aws_route" "nfg_pub_corpo" {
  for_each = { for rt in local.nfg_pub_routes : "${rt.vpc_key}-${rt.az_id}-${rt.cidr}" => rt }

  region                 = each.value.vpc_key
  route_table_id         = each.value.rt_id
  destination_cidr_block = each.value.cidr
  vpc_endpoint_id        = aws_vpc_endpoint.firewall["${each.value.vpc_key}-${each.value.az_id}"].id
}

