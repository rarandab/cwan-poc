locals {
  instance_sg = {
    name        = "instance_security_group"
    description = "Instance SG (Allowing ICMP and HTTP/HTTPS access)"
    ingress = {
      icmp = {
        description = "ping"
        from        = -1
        to          = -1
        protocol    = "icmp"
        cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]
      }
    }
    egress = {
      any = {
        description = "Any traffic"
        from        = 0
        to          = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }
  }
}
