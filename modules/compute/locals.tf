locals {
  instance_sg = {
    name        = format("%s-%s-vsg-wkl%s", var.identifier, var.region_short_name, var.vpc_name)
    description = "Instance SG (Allowing ICMP and HTTP/HTTPS access)"
    ingress = merge({
      icmp = {
        description     = "ICMP"
        from            = -1
        to              = -1
        protocol        = "icmp"
        prefix_list_ids = var.allowed_icmp_pls
      }
      },
      { for sg in var.lb_sg_ids :
        format("http-%s", sg) => {
          description              = "HTTP"
          from                     = 80
          to                       = 80
          protocol                 = "tcp"
          source_security_group_id = sg
        }
      }
    )
    egress = {
      icmp = {
        description     = "ICMP"
        from            = -1
        to              = -1
        protocol        = "icmp"
        prefix_list_ids = var.allowed_icmp_pls
      }
      https = {
        description = "HTTPs"
        from        = 443
        to          = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }

    }
  }
}
