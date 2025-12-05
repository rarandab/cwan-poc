resource "local_file" "policy" {
  filename = "${path.module}/policy.json"
  content  = jsonencode(local.cwan_policy)
}

resource "local_file" "cmds" {
  filename = "${path.module}/cmds.txt"
  content = templatefile(
    "${path.module}/cmds.tftpl",
    {
      global_network_id = aws_networkmanager_global_network.this.id
      core_network_id   = aws_networkmanager_core_network.this.id
      vpc_attachments = [
        for v, v_d in module.wkl_vpc : {
          id = v_d.core_network_attachment.id
        }
      ]
      hybrid_attachments = [
        { id = aws_networkmanager_site_to_site_vpn_attachment.site2site.id }
      ]
      onprem = {
        id     = aws_cloudformation_stack.vpnclient.outputs.oVpnGatewayId
        region = var.onprem.region
      }
      instances = flatten([
        for c, c_d in module.compute : [
          for i, ic in c_d.instances_created : {
            name   = format("%s%g", c, i)
            id     = ic.id
            region = ic.region
          }
        ]
      ])
  })
}
