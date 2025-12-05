resource "aws_customer_gateway" "vpnclient" {
  region     = var.onprem.region
  bgp_asn    = var.onprem.asn
  ip_address = aws_eip.vpnclient.public_ip
  type       = "ipsec.1"

  tags = {
    Name = format("%s-%s-vpn-cgw", var.project_code, local.region_short_names[var.onprem.region])
  }
}

resource "aws_vpn_connection" "site2site" {
  region              = var.onprem.region
  customer_gateway_id = aws_customer_gateway.vpnclient.id
  type                = "ipsec.1"

  tags = {
    Name = format("%s-%s-vpn-con", var.project_code, local.region_short_names[var.onprem.region])
  }
}

resource "aws_secretsmanager_secret" "s2s_tunnel1_psk" {
  region                  = var.onprem.region
  name_prefix             = "tunnel1_psk"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "s2s_tunnel1_psk" {
  region        = var.onprem.region
  secret_id     = aws_secretsmanager_secret.s2s_tunnel1_psk.id
  secret_string = jsonencode({ psk = aws_vpn_connection.site2site.tunnel1_preshared_key })
}

resource "aws_secretsmanager_secret" "s2s_tunnel2_psk" {
  region                  = var.onprem.region
  name_prefix             = "tunnel2_psk"
  recovery_window_in_days = 0
}
resource "aws_secretsmanager_secret_version" "s2s_tunnel2_psk" {
  region        = var.onprem.region
  secret_id     = aws_secretsmanager_secret.s2s_tunnel2_psk.id
  secret_string = jsonencode({ psk = aws_vpn_connection.site2site.tunnel2_preshared_key })
}

resource "aws_networkmanager_site_to_site_vpn_attachment" "site2site" {
  core_network_id    = aws_networkmanager_core_network.this.id
  vpn_connection_arn = aws_vpn_connection.site2site.arn
  tags = {
    Name         = format("%s-%s-vpn-att", var.project_code, local.region_short_names[var.onprem.region])
    "tec:cwnsgm" = format("cwnsgm%sHyb", title(var.project_code))
  }
}

resource "aws_networkmanager_attachment_accepter" "site2site" {
  attachment_id   = aws_networkmanager_site_to_site_vpn_attachment.site2site.id
  attachment_type = aws_networkmanager_site_to_site_vpn_attachment.site2site.attachment_type
}
