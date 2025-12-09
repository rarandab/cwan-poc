resource "local_file" "policy" {
  filename = "${path.module}/outputs/policy.json"
  content  = jsonencode(local.cwan_policy)
}

resource "local_file" "sdwan" {
  for_each = local.sdw_cidrs

  filename = "${path.module}/outputs/userdata-${local.region_short_names[each.key]}.sh"
  content  = data.template_cloudinit_config.sdwan[each.key].rendered
}

resource "local_file" "cmds" {
  filename = "${path.module}/outputs/cmds.txt"
  content = templatefile(
    "${path.module}/cmds.tftpl",
    {
      nfg               = format("cwnnfg%sIns", title(var.project_code))
      default_region    = var.core_network_config.edge_locations[0].region
      segments          = [for s, s_d in local.cwn_all_segments : format("cwnsgm%s%s", title(var.project_code), title(s))]
      global_network_id = aws_networkmanager_global_network.this.id
      core_network_id   = aws_networkmanager_core_network.this.id
      vpc_attachments = [
        for v, v_d in module.wkl_vpc : {
          name = v
          id   = v_d.core_network_attachment.id
        }
      ]
      hybrid_attachments = [
        for a, a_d in aws_networkmanager_connect_attachment.sdwan : {
          region = a
          id     = a_d.id
        }
      ]
      ec2_instances = flatten([
        for c, c_d in module.compute : [
          for i, ic in c_d.instances_created : {
            name   = format("%s%g", c, i)
            id     = ic.id
            region = ic.region
          }
        ]
      ])
      nfw_instances = flatten([
        for c, c_d in module.firewall : [
          for i, ic in c_d.instances_created : {
            name   = format("%s%g", c, i)
            id     = ic.id
            region = ic.region
          }
        ]
      ])
      sdw_instances = [
        for s, s_d in aws_instance.sdwan :
        {
          name   = s
          id     = s_d.id
          region = s_d.region
        }
      ]
  })
}
