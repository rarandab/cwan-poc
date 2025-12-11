locals {
  instance_sg = {
    name        = format("%s-%s-vsg-nfw", var.identifier, var.region_short_name)
    description = "Instance SG (Allowing ICMP and HTTP/HTTPS access)"
    ingress = merge(
      (length(var.allow_ping_cidrs) > 0 ?
        {
          ping = {
            description = "ping"
            from        = -1
            to          = -1
            protocol    = "icmp"
            cidr_blocks = ["10.0.0.0/8"]
          }
        } : {}
      ),
      {
        http = {
          description = "HTTP"
          from        = 80
          to          = 80
          protocol    = "tcp"
          cidr_blocks = var.gwlb_subnets_cidr
        }
        geneve = {
          description = "GENEVE"
          from        = 6081
          to          = 6081
          protocol    = "udp"
          cidr_blocks = var.gwlb_subnets_cidr
        }
    })
    egress = {
      geneve = {
        description = "GENEVE"
        from        = 6081
        to          = 6081
        protocol    = "udp"
        cidr_blocks = var.gwlb_subnets_cidr
      }
      https = {
        description = "HTTPs"
        from        = 443
        to          = 443
        protocol    = "tcp"
        cidr_blocks = var.gwlb_subnets_cidr
      }
    }
  }
}
