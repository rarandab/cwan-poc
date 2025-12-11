output "instances_created" {
  value       = aws_instance.firewall
  description = "List of instances created."
}

output "endpoint_service" {
  value       = aws_vpc_endpoint_service.firewall
  description = "Firewall endpoint service created."
}
