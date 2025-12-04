module "compute" {
  for_each = { for v in var.vpcs : "${local.region_short_names[v.region]}-${v.name}" => v }

  region                   = each.value.region
  source                   = "./modules/compute"
  vpc_name                 = format("%s-%s-vpc", var.project_code, each.key)
  vpc_id                   = module.wkl_vpc[each.key].vpc_attributes.id
  workload_subnets         = values({ for k, v in module.wkl_vpc[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "app" })
  instance_type            = "t3.micro"
  ec2_iam_instance_profile = aws_iam_instance_profile.common.id
  number_azs               = length(module.wkl_vpc[each.key].azs)
  identifier               = var.project_code
}
