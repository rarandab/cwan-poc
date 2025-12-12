variable "owner" {
  description = "Infrastructure Owner"
  type        = string
}

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
    asn_ranges         = list(string)
    inside_cidr_blocks = optional(list(string), null)
    edge_locations = list(object({
      region             = string
      asn                = optional(number, null)
      inside_cidr_blocks = optional(list(string), null)
      edge_overrides = object({
        send_to = optional(string, null)
        send_via = optional(list(object({
          regions           = list(string)
          use_edge_location = string
        })), null)
      })
      cidr       = string
      inspection = optional(bool, false)
    }))
    segments = list(object({
      name                          = string
      description                   = string
      require_attachment_acceptance = optional(bool, true)
      isolate_attachments           = optional(bool, true)
    }))
  })
}

variable "endpoints" {
  description = "Endpoints to be created in each region"
  type        = list(string)
  default     = []
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

variable "sdwan" {
  description = "Cloud WAN Connect Tunnel-Less configuration"
  type = object({
    regions = list(string)
    asn     = number
    cidrs   = optional(list(string), [])
  })
  default = null
}

variable "inspection_type" {
  description = "Type of inspection to deploy: fake_firewall (GWLB with tunnel handler) or network_firewall (AWS Network Firewall)"
  type        = string
  default     = "fake_firewall"

  validation {
    condition     = contains(["fake_firewall", "network_firewall"], var.inspection_type)
    error_message = "inspection_type must be either 'fake_firewall' or 'network_firewall'."
  }
}
