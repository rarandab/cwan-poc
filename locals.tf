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
  corpo_cidrs = {
    onprem = "172.16.0.0/12"
    cloud  = "10.0.0.0/8"
  }
  cwn_basic_segments = [
    {
      name                          = "shr"
      description                   = "Shared Services segment"
      require_attachment_acceptance = true
      isolate_attachments           = false
      share_with                    = concat(["hyb"], [for s in var.core_network_config.segments : s.name])
    },
    {
      name                          = "nva"
      description                   = "NVAs segment"
      require_attachment_acceptance = true
      isolate_attachments           = true
      share_with                    = ["hyb"]
    },
    {
      name                          = "hyb"
      description                   = "Hybrid segment"
      require_attachment_acceptance = true
      isolate_attachments           = true
      share_with                    = ["nva", "shr"]
    }
  ]
  reverse_segment_sharing = flatten([
    for s in var.core_network_config.segments : [
      for bs in local.cwn_basic_segments : {
        segment    = s.name
        share_with = bs.name
      } if contains(bs.share_with, s.name)
    ]
  ])
  cwn_all_segments = merge(
    {
      for s in local.cwn_basic_segments : s.name => s
    },
    {
      for s in var.core_network_config.segments : s.name => s
    }
  )
  nfw_cidrs = { for el in var.core_network_config.edge_locations : el.region => cidrsubnet(el.cidr, 8, 255) if el.inspection }
  shr_cidrs = { for el in var.core_network_config.edge_locations : el.region => cidrsubnet(el.cidr, 8, 250) }
  sdw_cidrs = { for el in var.core_network_config.edge_locations : el.region => cidrsubnet(el.cidr, 8, 254) if contains(try(var.sdwan.regions, []), el.region) }
  non_routeable_cidrs = {
    workload   = "100.64.128.0/18"
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
  regional_endpoints = flatten([
    for el in var.core_network_config.edge_locations : [
      for ep in var.endpoints : {
        region  = el.region
        service = ep
      }
    ]
  ])
}
