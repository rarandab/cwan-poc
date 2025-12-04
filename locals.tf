locals {
  region_short_names = {
    "eu-central-1" = "euc1"
    "eu-west-1"    = "euw1"
    "eu-west-2"    = "euw2"
    "eu-west-3"    = "euw3"
    "eu-north-1"   = "eun1"
    "eu-south-1"   = "eus1"
    "eu-south-2"   = "eus2"
  }
  azs_by_region = {
    "eu-central-1" = ["a", "b"]
    "eu-west-1"    = ["a", "b"]
    "eu-west-2"    = ["a", "b"]
    "eu-west-3"    = ["a", "b"]
    "eu-north-1"   = ["a", "b"]
    "eu-south-1"   = ["a", "b"]
    "eu-south-2"   = ["a", "b"]
  }
  corpo_cidrs = {
    onprem = "172.16.0.0/12"
    cloud  = "10.0.0.0/8"
  }
  cwn_basic_segments = [
    {
      name                          = "nva"
      description                   = "NVAs segment"
      require_attachment_acceptance = true
      isolate_attachments           = true
    },
    {
      name                          = "hyb"
      description                   = "Hybrid segment"
      require_attachment_acceptance = true
      isolate_attachments           = true
    }
  ]
  cwn_all_segments = merge(
    {
      for s in local.cwn_basic_segments : s.name => s
    },
    {
      for s in var.core_network_config.segments : s.name => s
    }
  )
  non_routeable_cidrs = {
    secondary  = "100.64.100.0/22"
    inspection = "100.64.0.0/20"
  }
  blackhole_cidrs = [for k, v in local.non_routeable_cidrs : v]
  nfg_nfw_subnets = flatten([
    for v, v_d in module.nfg_vpc : [
      for az in v_d.azs : {
        vpc_key   = v
        az_id     = az
        subnet_id = v_d.private_subnet_attributes_by_az["nfw/${az}"].id
      }
    ]
  ])
  nfg_cwn_routes = flatten([
    for v, v_d in module.nfg_vpc : [
      for az in v_d.azs : {
        vpc_key = v
        az_id   = az
        rt_id   = v_d.rt_attributes_by_type_by_az.core_network[az].id
      }
    ]
  ])
  nfg_pub_routes = flatten([
    for v, v_d in module.nfg_vpc : [
      for c, c_d in local.corpo_cidrs : [
        for az in v_d.azs : {
          vpc_key = v
          az_id   = az
          rt_id   = v_d.rt_attributes_by_type_by_az.public[az].id
          cidr    = c_d
        }
      ]
    ]
  ])
}
