variable "region" {
  type        = string
  description = "Region"
}

variable "region_short_name" {
  type        = string
  description = "Region Short Name"
}

variable "identifier" {
  type        = string
  description = "Project identifier."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to create the instances."
}

variable "firewall_subnets" {
  type        = list(string)
  description = "Subnets in the VPC to create the instances."
}

variable "gwlb_subnets" {
  type        = list(string)
  description = "Subnets in the VPC to create the instances."
}

variable "gwlb_subnets_cidr" {
  type        = list(string)
  description = "CIDRs of GWLB subnets"
}

variable "number_azs" {
  type        = number
  description = "Number of AZs to place instances."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
}

variable "ec2_iam_instance_profile" {
  type        = string
  description = "EC2 instance profile to attach to the EC2 instance(s)"
}

variable "allow_ping_cidrs" {
  type        = list(string)
  description = "CIDRs to allow ping from"
  default     = []
}
