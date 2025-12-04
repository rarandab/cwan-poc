module "onprem" {
  source = "../terraform-aws-vpc"

  region     = var.vpn.region
  name       = format("%s-%s-onprem-vpc", var.project_code, local.region_short_names[var.vpn.region])
  cidr_block = "172.16.0.0/25"
  az_count   = 1

  subnets = {
    public = {
      netmask = 28
      tags = {
        sntype = "public"
      }
    }
  }
}

resource "aws_eip" "vpnclient" {
  region = var.vpn.region
  domain = "vpc"
  tags = {
    Name = format("%s-%s-vpn-eip", var.project_code, local.region_short_names[var.vpn.region])
  }
}

resource "aws_cloudformation_stack" "vpnclient" {
  region = var.vpn.region
  name   = format("%s-%s-vpnclient-cfs", var.project_code, local.region_short_names[var.vpn.region])
  parameters = {
    pOrg                         = "rarandab"
    pSystem                      = "ireland"
    pApp                         = "vpn"
    pUseElasticIp                = "true"
    pEipAllocationId             = aws_eip.vpnclient.allocation_id
    pTunnel1PskSecretName        = aws_secretsmanager_secret.s2s_tunnel1_psk.name
    pTunnel1VgwOutsideIpAddress  = aws_vpn_connection.site2site.tunnel1_address
    pTunnel1CgwInsideIpAddress   = "${aws_vpn_connection.site2site.tunnel1_cgw_inside_address}/30"
    pTunnel1VgwInsideIpAddress   = "${aws_vpn_connection.site2site.tunnel1_vgw_inside_address}/30"
    pTunnel1VgwBgpAsn            = aws_vpn_connection.site2site.tunnel1_bgp_asn
    pTunnel1BgpNeighborIpAddress = aws_vpn_connection.site2site.tunnel1_vgw_inside_address
    pTunnel2PskSecretName        = aws_secretsmanager_secret.s2s_tunnel2_psk.name
    pTunnel2VgwOutsideIpAddress  = aws_vpn_connection.site2site.tunnel2_address
    pTunnel2CgwInsideIpAddress   = "${aws_vpn_connection.site2site.tunnel2_cgw_inside_address}/30"
    pTunnel2VgwInsideIpAddress   = "${aws_vpn_connection.site2site.tunnel2_vgw_inside_address}/30"
    pTunnel2VgwBgpAsn            = aws_vpn_connection.site2site.tunnel2_bgp_asn
    pTunnel2BgpNeighborIpAddress = aws_vpn_connection.site2site.tunnel2_vgw_inside_address
    pLocalBgpAsn                 = aws_customer_gateway.vpnclient.bgp_asn
    pVpcId                       = module.onprem.vpc_attributes.id
    pVpcCidr                     = module.onprem.vpc_attributes.cidr_block
    pSubnetId                    = module.onprem.public_subnet_attributes_by_az[module.onprem.azs[0]].id
    pRole                        = aws_iam_role.common.name
  }
  template_body = file("${path.module}/vpn-gateway-strongswan.yml")
  capabilities  = ["CAPABILITY_NAMED_IAM"]
  //lifecycle {
  //  ignore_changes = [template_body]
  //}
}
