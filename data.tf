data "aws_availability_zones" "available" {
  for_each = toset([for el in var.core_network_config.edge_locations : el.region])

  region = each.value
  state  = "available"
}
