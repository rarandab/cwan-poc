project_name = "PoC Cloud WAN"

project_code = "pcc"

core_network_config = {
  asn_ranges = ["65000-65100"]
  edge_locations = [
    {
      region         = "eu-central-1"
      asn            = 65000
      edge_overrides = {}
      cidrs = ["10.0.0.0/16"]
    },
    {
      region         = "eu-south-2"
      asn            = 65001
      edge_overrides = {}
      cidrs = ["10.1.0.0/16"]
    },
    {
      region = "eu-south-1"
      asn    = 65002
      edge_overrides = {
        send_to = "eu-south-2"
        send_via = [
          {
            regions           = ["eu-central-1"]
            use_edge_location = "eu-central-1"
          },
          {
            regions           = ["eu-south-2","eu-west-1"]
            use_edge_location = "eu-south-2"
          }
        ]
      }
      cidrs = ["10.2.0.0/16"]
    },
    {
      region = "eu-west-1"
      asn    = 65003
      edge_overrides = {
        send_to = "eu-central-1"
        send_via = [
          {
            regions           = ["eu-central-1","eu-south-2"]
            use_edge_location = "eu-central-1"
          },
          {
            regions           = ["eu-south-2"]
            use_edge_location = "eu-south-2"
          }
        ]
      }
      cidrs = ["10.3.0.0/16"]
    }
  ]
  segments = [
    {
      name                          = "pro"
      description                   = "Production segment"
      require_attachment_acceptance = true
      isolate_attachments           = true
    },
    {
      name                          = "npd"
      description                   = "Non Production segment"
      require_attachment_acceptance = true
      isolate_attachments           = true
    }
  ]
}

vpcs = [
  {
    name    = "pro"
    cidr    = "10.0.0.0/24"
    region  = "eu-central-1"
    segment = "pro"
  },
  {
    name    = "dev"
    cidr    = "10.0.64.0/24"
    region  = "eu-central-1"
    segment = "npd"
  },
  {
    name    = "pro"
    cidr    = "10.1.0.0/24"
    region  = "eu-south-2"
    segment = "pro"
  },
  {
    name    = "dev"
    cidr    = "10.2.64.0/24"
    region  = "eu-south-1"
    segment = "npd"
  }
]

nva_vpcs = [
  {
    region  = "eu-central-1"
    cidr    = "10.0.255.0/24"
    purpose = "nfw"
  },
  {
    region  = "eu-south-2"
    cidr    = "10.1.255.0/24"
    purpose = "nfw"
  }
]

vpn = {
  region     = "eu-west-1"
  asn_client = 64600
  asn_aws    = 64601
}
