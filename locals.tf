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
  ffw_cidrs = { for el in var.core_network_config.edge_locations : el.region => cidrsubnet(el.cidr, 8, 255) if el.inspection }
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
        en_id   = var.inspection_type == "fake_firewall" ? aws_vpc_endpoint.fake_firewall["${v}-${az}"].id : local.nfw_endpoints["${v}-${az}"]
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
          en_id   = var.inspection_type == "fake_firewall" ? aws_vpc_endpoint.fake_firewall["${v}-${az}"].id : local.nfw_endpoints["${v}-${az}"]
        }
      ]
    ]
  ])

  nfw_endpoints_flat = var.inspection_type == "network_firewall" ? flatten([
    for region_key, fw in aws_networkfirewall_firewall.this : [
      for sync_state in fw.firewall_status[0].sync_states : {
        region_key = region_key
        az_id      = sync_state.availability_zone
        endpoint   = sync_state.attachment[0].endpoint_id
      }
    ]
  ]) : []
  nfw_endpoints = { for ep in local.nfw_endpoints_flat : "${ep.region_key}-${ep.az_id}" => ep.endpoint }

  wkl_app_rt = flatten([
    for v, v_d in module.wkl_vpc : [
      for az in v_d.azs : {
        vpc_key = v
        region  = v_d.vpc_attributes.region
        az_id   = az
        rt_id   = v_d.rt_attributes_by_type_by_az.private["app/${az}"].id
      }
    ]
  ])
  wkl_ilb_rt = flatten([
    for v, v_d in module.wkl_vpc : [
      for az in v_d.azs : {
        vpc_key = v
        region  = v_d.vpc_attributes.region
        az_id   = az
        rt_id   = v_d.rt_attributes_by_type_by_az.private["ilb/${az}"].id
      }
    ]
  ])
  //flatten([
  //  for v, v_d in module.nfg_vpc : [
  //    for az in v_d.azs : {
  //      vpc_key   = v
  //      az_id     = az
  //      subnet_id = v_d.private_subnet_attributes_by_az["nfw/${az}"].id
  //    }
  //  ]
  //])
  regional_endpoints = flatten([
    for el in var.core_network_config.edge_locations : [
      for ep in var.endpoints : {
        region  = el.region
        service = ep
      }
    ]
  ])
}
