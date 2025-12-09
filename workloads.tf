module "wkl_vpc" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source   = "../terraform-aws-vpc"
  for_each = { for v in var.vpcs : "${local.region_short_names[v.region]}-${v.name}" => v }

  name                                 = format("%s-%s-vpc-%s", var.project_code, local.region_short_names[each.value.region], each.value.segment)
  region                               = each.value.region
  cidr_block                           = each.value.cidr
  vpc_assign_generated_ipv6_cidr_block = false
  vpc_egress_only_internet_gateway     = false
  azs                                  = slice(data.aws_availability_zones.available[each.value.region].names, 0, 2)
  //azs                                  = [for az in local.azs_by_region[each.value.region] : "${each.value.region}${az}"]
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
      name_prefix = format("%s-%s-vsn-app", var.project_code, local.region_short_names[each.value.region])
      cidrs       = cidrsubnets(cidrsubnet(each.value.cidr, 1, 0), 1, 1)
    }
    lbs = {
      name_prefix = format("%s-%s-vsn-lbs", var.project_code, local.region_short_names[each.value.region])
      cidrs       = cidrsubnets(cidrsubnet(each.value.cidr, 2, 2), 1, 1)
    }
    core_network = {
      name_prefix            = format("%s-%s-vsn-cwn", var.project_code, local.region_short_names[each.value.region])
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
    retention_in_days    = 1
  }
}

module "wkl_vpc-2nd_cidr" {
  //source   = "aws-ia/vpc/aws"
  //version  = ">= 4.8.0"
  source   = "../terraform-aws-vpc"
  for_each = { for v in var.vpcs : "${local.region_short_names[v.region]}-${v.name}" => v }

  name               = format("%s-%s-vpc-%s", var.project_code, local.region_short_names[each.value.region], each.value.segment)
  region             = each.value.region
  create_vpc         = false
  vpc_id             = module.wkl_vpc[each.key].vpc_attributes.id
  cidr_block         = local.non_routeable_cidrs["secondary"]
  vpc_secondary_cidr = true
  azs                = slice(data.aws_availability_zones.available[each.value.region].names, 0, 2)
  subnets = {
    dat = {
      name_prefix = format("%s-%s-vsn-dat", var.project_code, local.region_short_names[each.value.region])
      cidrs       = cidrsubnets(cidrsubnet(local.non_routeable_cidrs["secondary"], 2, 0), 1, 1)
    }
  }
  //depends_on = [aws_networkmanager_core_network_policy_attachment.this]
}

resource "aws_route53_resolver_rule_association" "dfl" {
  for_each = { for v in var.vpcs : "${local.region_short_names[v.region]}-${v.name}" => v }

  region           = each.value.region
  resolver_rule_id = aws_route53_resolver_rule.default[each.value.region].id
  vpc_id           = module.wkl_vpc[each.key].vpc_attributes.id
}

resource "aws_route53_resolver_rule_association" "aws" {
  for_each = { for i in flatten([
    for v in var.vpcs : [
      for rr, rr_d in aws_route53_resolver_rule.aws : merge(v, { vpc_key = "${local.region_short_names[v.region]}-${v.name}", rr_key = rr }) if rr_d.region == v.region
    ]
    ]) : "${i.vpc_key}-${i.rr_key}" => i
  }

  region           = each.value.region
  resolver_rule_id = aws_route53_resolver_rule.aws[each.value.rr_key].id
  vpc_id           = module.wkl_vpc[each.value.vpc_key].vpc_attributes.id
}

module "compute" {
  for_each = { for v in var.vpcs : "${local.region_short_names[v.region]}-${v.name}" => v }

  region                   = each.value.region
  region_short_name        = local.region_short_names[each.value.region]
  source                   = "./modules/compute"
  vpc_name                 = format("%s-%s-vpc-%s", var.project_code, local.region_short_names[each.value.region], each.value.segment)
  vpc_id                   = module.wkl_vpc[each.key].vpc_attributes.id
  workload_subnets         = values({ for k, v in module.wkl_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "app" })
  instance_type            = "t3.small"
  ec2_iam_instance_profile = aws_iam_instance_profile.common.id
  number_azs               = length(module.wkl_vpc[each.key].azs)
  identifier               = var.project_code
}
