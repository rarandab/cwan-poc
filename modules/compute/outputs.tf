output "instances_created" {
  value       = aws_instance.workload
  description = "List of instances created."
}

output "instance_sg" {
  value       = aws_security_group.instance_sg.id
  description = "Security group of the instance."
}
