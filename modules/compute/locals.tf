locals {
  instance_sg = {
    name        = format("%s-%s-vsg-wkl", var.identifier, var.region_short_name)
    description = "Instance SG (Allowing ICMP and HTTP/HTTPS access)"
    ingress = {
      icmp = {
        description     = "ping"
        from            = -1
        to              = -1
        protocol        = "icmp"
        prefix_list_ids = [var.allowed_icmp_pls]
      }
      http = {
        description = "HTTP"
        from        = 80
        to          = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]
      }
    }
    egress = {
      icmp = {
        description     = "ping"
        from            = -1
        to              = -1
        protocol        = "icmp"
        prefix_list_ids = [var.allowed_icmp_pls]
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
