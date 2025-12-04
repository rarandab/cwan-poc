module "firewall" {
  source   = "./modules/firewall"
  for_each = { for v in var.nva_vpcs : v.region => v if v.purpose == "nfw" }

  region                   = each.value.region
  region_short_name        = local.region_short_names[each.value.region]
  vpc_id                   = module.nfw_vpc[each.key].vpc_attributes.id
  firewall_subnets         = values({ for k, v in module.nfw_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "nfw" })
  gwlb_subnets             = values({ for k, v in module.nfw_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "glb" })
  gwlb_subnets_cidr        = values({ for k, v in module.nfw_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.cidr_block if split("/", k)[0] == "glb" })
  instance_type            = "t3.micro"
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

