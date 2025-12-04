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
  source   = "../terraform-aws-vpc"
  for_each = { for v in var.nva_vpcs : v.region => v if v.purpose == "nfw" }

  name                                 = format("%s-%s-nfw-vpc", var.project_code, local.region_short_names[each.key])
  region                               = each.value.region
  cidr_block                           = each.value.cidr
  vpc_assign_generated_ipv6_cidr_block = false
  vpc_egress_only_internet_gateway     = false
  azs                                  = [for az in local.azs_by_region[each.value.region] : "${each.value.region}${az}"]
  core_network = {
    id  = aws_networkmanager_core_network.this.id
    arn = aws_networkmanager_core_network.this.arn
  }
  subnets = {
    public = {
      name_prefix               = format("%s-%s-pub-snt", var.project_code, local.region_short_names[each.key])
      cidrs                     = cidrsubnets(cidrsubnet(each.value.cidr, 2, 0), 1, 1)
      nat_gateway_configuration = "single_az"
      map_public_ip_on_launch   = false
    }
    nfw = {
      name_prefix             = format("%s-%s-app-snt", var.project_code, local.region_short_names[each.key])
      cidrs                   = cidrsubnets(cidrsubnet(each.value.cidr, 2, 1), 1, 1)
      connect_to_public_natgw = true
    }
    glb = {
      name_prefix = format("%s-%s-lbs-snt", var.project_code, local.region_short_names[each.key])
      cidrs       = cidrsubnets(cidrsubnet(each.value.cidr, 2, 2), 1, 1)
    }
    core_network = {
      name_prefix            = format("%s-%s-cwn-snt", var.project_code, local.region_short_names[each.key])
      cidrs                  = cidrsubnets(cidrsubnet(each.value.cidr, 2, 3), 1, 1)
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
  }
  //depends_on = [aws_networkmanager_core_network_policy_attachment.this]
}

module "nfg_vpc" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source   = "../terraform-aws-vpc"
  for_each = toset([for v in var.nva_vpcs : v.region if v.purpose == "nfw"])

  name                                 = format("%s-%s-nfg-vpc", var.project_code, local.region_short_names[each.key])
  region                               = each.value
  cidr_block                           = local.non_routeable_cidrs["inspection"]
  vpc_assign_generated_ipv6_cidr_block = false
  vpc_egress_only_internet_gateway     = false
  azs                                  = [for az in local.azs_by_region[each.value] : "${each.value}${az}"]
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
  }
  //depends_on = [aws_networkmanager_core_network_policy_attachment.this]
}

module "wkl_vpc" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source   = "../terraform-aws-vpc"
  for_each = { for v in var.vpcs : "${local.region_short_names[v.region]}-${v.name}" => v }

  name                                 = format("%s-%s-vpc", var.project_code, each.key)
  region                               = each.value.region
  cidr_block                           = each.value.cidr
  vpc_assign_generated_ipv6_cidr_block = false
  vpc_egress_only_internet_gateway     = false
  azs                                  = [for az in local.azs_by_region[each.value.region] : "${each.value.region}${az}"]
  core_network = {
    id  = aws_networkmanager_core_network.this.id
    arn = aws_networkmanager_core_network.this.arn
  }
  core_network_routes = {
    app = "0.0.0.0/0"
    lbs = "0.0.0.0/0"
  }
  subnets = {
    app = {
      name_prefix = format("%s-%s-app-snt", var.project_code, each.key)
      cidrs       = cidrsubnets(cidrsubnet(each.value.cidr, 1, 0), 1, 1)
    }
    lbs = {
      name_prefix = format("%s-%s-lbs-snt", var.project_code, each.key)
      cidrs       = cidrsubnets(cidrsubnet(each.value.cidr, 2, 2), 1, 1)
    }
    core_network = {
      name_prefix            = format("%s-%s-cwn-snt", var.project_code, each.key)
      cidrs                  = cidrsubnets(cidrsubnet(each.value.cidr, 2, 3), 1, 1)
      appliance_mode_support = false
      require_acceptance     = true
      accept_attachment      = true
      tags = {
        "tec:cwnsgm" = format("cwnsgm%s%s", title(var.project_code), title(each.value.segment))
      }
    }
  }
  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
  }
}

module "wkl_vpc-2nd_cidr" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source   = "../terraform-aws-vpc"
  for_each = { for v in var.vpcs : "${local.region_short_names[v.region]}-${v.name}" => v }

  name               = format("%s-%s-vpc", var.project_code, each.key)
  region             = each.value.region
  create_vpc         = false
  vpc_id             = module.wkl_vpc[each.key].vpc_attributes.id
  cidr_block         = local.non_routeable_cidrs["secondary"]
  vpc_secondary_cidr = true
  azs                = [for az in local.azs_by_region[each.value.region] : "${each.value.region}${az}"]

  subnets = {
    dat = {
      name_prefix = format("%s-%s-dat-snt", var.project_code, each.key)
      cidrs       = cidrsubnets(cidrsubnet(local.non_routeable_cidrs["secondary"], 2, 0), 1, 1)
    }
  }

  //depends_on = [aws_networkmanager_core_network_policy_attachment.this]
}
