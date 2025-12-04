variable "project_name" {
  description = "Project Name"
  type        = string
}

variable "project_code" {
  description = "Project code"
  type        = string
  validation {
    condition     = length(var.project_code) == 3 && var.project_code == lower(var.project_code)
    error_message = "Project code must be exactly 3 characters and in lowercase."
  }

}

variable "core_network_config" {
  description = "Cloud Wan Core Network Config"
  type = object({
    asn_ranges = list(string)
    edge_locations = list(object({
      region = string
      asn    = optional(number, null)
      edge_overrides = object({
        send_to = optional(string, null)
        send_via = optional(list(object({
          regions           = list(string)
          use_edge_location = string
        })), null)
      })
      cidrs = list(string)
    }))
    segments = list(object({
      name                          = string
      description                   = string
      require_attachment_acceptance = optional(bool, true)
      isolate_attachments           = optional(bool, true)
    }))
  })
}

variable "vpcs" {
  description = "VPCs to be created"
  type = list(object({
    name    = string
    region  = string
    cidr    = string
    segment = string
  }))
}

variable "nva_vpcs" {
  description = "NVA VPCs data "
  type = list(object({
    region  = string
    cidr    = string
    purpose = string
  }))
}

variable "vpn" {
  description = "VPN data"
  type = object({
    region     = string
    asn_client = number
    asn_aws    = number
  })
}
