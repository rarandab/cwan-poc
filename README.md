# AWS Cloud WAN Proof of Concept (PoC)

## Overview

This Terraform project deploys a comprehensive AWS Cloud WAN architecture demonstrating enterprise-grade multi-region networking with centralized inspection, shared services, SD-WAN integration, and workload segmentation.

## Architecture Overview

### Core Components

The PoC creates a hub-and-spoke topology using AWS Cloud WAN as the central hub, connecting multiple VPCs across regions with mandatory traffic inspection and segment isolation.

#### Always Created Resources

These resources are created regardless of variable configuration:

**Global Infrastructure:**
- AWS Cloud WAN Global Network and Core Network
- IAM roles and instance profiles for EC2 SSM access
- Managed prefix lists for corporate CIDR blocks

**Per-Region Resources (for each region in `core_network_config.edge_locations`):**
- **Shared Services VPC** (`shr` segment): VPC endpoints, Route 53 Resolver endpoints
- **Network Function Group (NFG) VPC**: Non-routable CIDR (100.64.0.0/20) for inspection endpoints
- Route 53 Resolver inbound/outbound endpoints for cross-region DNS resolution
- VPC Flow Logs for all VPCs

**Per-Inspection-Region Resources (where `inspection = true`):**
- **Inspection VPCs**: Either fake firewall VPC or Network Firewall resources based on `inspection_type`
- Gateway Load Balancer endpoints or Network Firewall endpoints

#### Variable-Dependent Resources

These resources are created based on configuration variables:

**Workload VPCs** (based on `var.vpcs`):
- Application VPCs with primary and secondary CIDRs
- EC2 instances for workload simulation
- Application Load Balancers and target groups

**SD-WAN Infrastructure** (based on `var.sdwan`):
- SD-WAN VPCs with Connect Tunnel-Less attachments
- FRRouting instances for BGP peering
- Connect peers and attachments

**VPC Endpoints** (based on `var.endpoints`):
- AWS service endpoints in shared services VPCs

**Inspection Type** (based on `var.inspection_type`):
- `fake_firewall`: Gateway Load Balancer with tunnel handler instances
- `network_firewall`: AWS Network Firewall with stateful rules and CloudWatch logging

### Network Segments

The architecture implements five isolated network segments:

| Segment | Purpose | Always Created | Variable Dependent |
|---------|---------|----------------|-------------------|
| **pro** | Production workloads | Segment definition | Workload VPCs (via `var.vpcs`) |
| **npd** | Non-production/development | Segment definition | Workload VPCs (via `var.vpcs`) |
| **shr** | Shared services | VPC, endpoints, DNS | Service endpoints (via `var.endpoints`) |
| **nva** | Network virtual appliances | NFG VPC | Inspection type (via `var.inspection_type`) |
| **hyb** | Hybrid connectivity | Segment definition | SD-WAN VPCs (via `var.sdwan`) |

### Traffic Flow Patterns

1. **Intra-Segment**: Traffic within the same segment routes through inspection (nva segment)
2. **Inter-Segment**: All traffic between segments MUST route through inspection layer
3. **Shared Services Access**: All segments can reach shr segment directly without inspection
4. **Hybrid Connectivity**: SD-WAN instances advertise on-premises routes via BGP to Cloud WAN

### VPC Architecture and CIDR Strategy

| VPC Type | CIDR Allocation | Purpose | Creation Logic |
|----------|-----------------|---------|----------------|
| **NFG VPC** | 100.64.0.0/20 (non-routable) | Network Function Group for inspection endpoints | Always created per inspection region |
| **Fake Firewall VPC** | Regional .255.0/24 | GWLB tunnel handler deployment | Created when `inspection_type = "fake_firewall"` |
| **Shared Services VPC** | Regional .250.0/24 | VPC endpoints, Route 53 Resolver | Always created per region |
| **SD-WAN VPC** | Regional .254.0/24 | Connect Tunnel-Less BGP peering | Created when `var.sdwan` is defined |
| **Workload VPCs** | User-defined + 100.64.128.0/18 secondary | Application workloads | Created per entry in `var.vpcs` |

### Inspection Options

The PoC supports two inspection mechanisms controlled by the `inspection_type` variable:

| Option | Description | Resources Created | Use Case |
|--------|-------------|-------------------|----------|
| `fake_firewall` (default) | Gateway Load Balancer with Linux tunnel handler | GWLB, EC2 instances, VPC endpoints | PoC/simulation |
| `network_firewall` | AWS Network Firewall with stateful rules | Network Firewall, rule groups, CloudWatch logs | Production-ready |

## Prerequisites

- Terraform >= 1.0
- AWS Provider >= 6.0
- AWS CLI configured with appropriate credentials
- Multiple AWS regions enabled

## Quick Start

```bash
# Initialize
terraform init

# Review
terraform plan

# Deploy
terraform apply

# Destroy when done
terraform destroy
```

## Configuration Variables

### Required Variables

#### `owner`
Infrastructure owner identifier for resource tagging.
```hcl
owner = "network-team"
```

#### `project_name`
Human-readable project name used in resource descriptions.
```hcl
project_name = "Enterprise Cloud WAN"
```

#### `project_code`
Three-character lowercase code for resource naming convention.
```hcl
project_code = "ecw"
```

#### `core_network_config`
**Required.** Defines the Cloud WAN core network configuration including regions, segments, and inspection settings.

```hcl
core_network_config = {
  asn_ranges         = ["65000-65100"]
  inside_cidr_blocks = ["192.168.0.0/16"]
  
  edge_locations = [
    {
      region             = "us-east-1"
      asn                = 65000
      inside_cidr_blocks = ["192.168.0.0/24"]
      edge_overrides     = {}
      cidr               = "10.0.0.0/16"
      inspection         = true
    },
    {
      region         = "us-west-2"
      asn            = 65001
      edge_overrides = {
        send_to = "us-east-1"
        send_via = [
          {
            regions           = ["us-east-1"]
            use_edge_location = "us-east-1"
          }
        ]
      }
      cidr       = "10.1.0.0/16"
      inspection = false
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
      description                   = "Non-production segment"
      require_attachment_acceptance = true
      isolate_attachments           = true
    }
  ]
}
```

**Edge Location Parameters:**
- `region`: AWS region for the edge location
- `asn`: BGP ASN for the edge location (must be within `asn_ranges`)
- `inside_cidr_blocks`: Internal Cloud WAN addressing (optional)
- `edge_overrides`: Traffic steering for regions without local inspection
  - `send_to`: Preferred inspection region for traffic routing
  - `send_via`: Regional routing preferences with edge location mapping
- `cidr`: Regional CIDR allocation (/16 recommended for subnet allocation)
- `inspection`: Boolean flag to enable inspection VPCs in this region

**Segment Parameters:**
- `name`: Segment identifier (used in resource naming)
- `description`: Human-readable segment description
- `require_attachment_acceptance`: Require manual attachment acceptance
- `isolate_attachments`: Enable segment isolation

#### `vpcs`
**Required.** List of workload VPCs to create across regions and segments.

```hcl
vpcs = [
  {
    name    = "web-app"
    cidr    = "10.0.0.0/24"
    region  = "us-east-1"
    segment = "pro"
  },
  {
    name    = "api-service"
    cidr    = "10.0.64.0/24"
    region  = "us-east-1"
    segment = "npd"
  },
  {
    name    = "database"
    cidr    = "10.1.0.0/24"
    region  = "us-west-2"
    segment = "pro"
  }
]
```

### Optional Variables

#### `inspection_type`
Selects the traffic inspection mechanism. Defaults to `"fake_firewall"`.

```hcl
# Default: GWLB with tunnel handler (simulation)
inspection_type = "fake_firewall"

# Alternative: AWS Network Firewall (production-ready)
inspection_type = "network_firewall"
```

**Impact on Resources:**
- `fake_firewall`: Creates Gateway Load Balancer, EC2 instances with tunnel handler, VPC endpoints
- `network_firewall`: Creates AWS Network Firewall, rule groups, CloudWatch log groups

#### `sdwan`
Connect Tunnel-Less configuration for simulated on-premises connectivity. Optional - if not provided, no SD-WAN resources are created.

```hcl
sdwan = {
  regions = ["us-east-1"]
  asn     = 64600
  cidrs   = ["172.16.0.0/16", "172.18.0.0/16"]
}
```

**Parameters:**
- `regions`: List of regions to deploy SD-WAN instances (must be subset of edge locations)
- `asn`: BGP ASN for SD-WAN (must not overlap with Cloud WAN ASN ranges)
- `cidrs`: On-premises CIDRs to advertise via BGP (typically 172.16.0.0/12 range)

**Created Resources:**
- SD-WAN VPCs with Connect Tunnel-Less attachments
- EC2 instances running FRRouting for BGP
- Connect peers and network interfaces

#### `endpoints`
AWS service endpoints to create in shared services VPCs. Defaults to empty list.

```hcl
endpoints = ["s3", "ssm", "ec2messages", "ssmmessages"]
```

**Common Services:**
- `s3`: Amazon S3 service endpoint
- `ssm`: Systems Manager endpoint (required for EC2 access)
- `ec2messages`: EC2 Messages endpoint (required for SSM)
- `ssmmessages`: SSM Messages endpoint (required for Session Manager)

## Complete Configuration Example

```hcl
# terraform.tfvars

owner        = "network-team"
project_name = "Enterprise Cloud WAN"
project_code = "ecw"

core_network_config = {
  asn_ranges         = ["65000-65100"]
  inside_cidr_blocks = ["192.168.0.0/16"]
  
  edge_locations = [
    {
      region             = "us-east-1"
      asn                = 65000
      inside_cidr_blocks = ["192.168.0.0/24"]
      edge_overrides     = {}
      cidr               = "10.0.0.0/16"
      inspection         = true
    },
    {
      region         = "us-west-2"
      asn            = 65001
      edge_overrides = {}
      cidr           = "10.1.0.0/16"
      inspection     = true
    },
    {
      region = "eu-west-1"
      asn    = 65002
      edge_overrides = {
        send_to = "us-east-1"
        send_via = [
          {
            regions           = ["us-east-1", "us-west-2"]
            use_edge_location = "us-east-1"
          }
        ]
      }
      cidr = "10.2.0.0/16"
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
      description                   = "Non-production segment"
      require_attachment_acceptance = true
      isolate_attachments           = true
    }
  ]
}

vpcs = [
  { name = "web-app",    cidr = "10.0.0.0/24",   region = "us-east-1", segment = "pro" },
  { name = "api-dev",    cidr = "10.0.64.0/24",  region = "us-east-1", segment = "npd" },
  { name = "database",   cidr = "10.1.0.0/24",   region = "us-west-2", segment = "pro" },
  { name = "analytics",  cidr = "10.1.64.0/24",  region = "us-west-2", segment = "npd" },
  { name = "monitoring", cidr = "10.2.64.0/24",  region = "eu-west-1", segment = "npd" }
]

endpoints = ["s3", "ssm", "ec2messages", "ssmmessages"]

sdwan = {
  regions = ["us-east-1"]
  asn     = 64600
  cidrs   = ["172.16.0.0/16", "172.18.0.0/16", "172.20.0.0/16"]
}

# Optional: Use AWS Network Firewall instead of GWLB tunnel handler
# inspection_type = "network_firewall"
```

### Resource Creation Matrix

This table shows which resources are created based on your configuration:

| Resource Type | Always Created | Condition | Variable Dependency |
|---------------|----------------|-----------|-------------------|
| **Global Network & Core Network** | ✅ | Always | `core_network_config` |
| **IAM Roles & Instance Profiles** | ✅ | Always | None |
| **Shared Services VPC** | ✅ | Per region | `core_network_config.edge_locations` |
| **NFG VPC** | ✅ | Per inspection region | `edge_locations[].inspection = true` |
| **Route 53 Resolver** | ✅ | Per region | `core_network_config.edge_locations` |
| **Fake Firewall VPC & GWLB** | ❌ | When fake firewall | `inspection_type = "fake_firewall"` |
| **Network Firewall** | ❌ | When NFW selected | `inspection_type = "network_firewall"` |
| **Workload VPCs** | ❌ | Per VPC definition | `var.vpcs` |
| **EC2 Workload Instances** | ❌ | Per VPC definition | `var.vpcs` |
| **SD-WAN VPCs & Instances** | ❌ | When SD-WAN configured | `var.sdwan` |
| **VPC Endpoints** | ❌ | Per service | `var.endpoints` |
| **Application Load Balancers** | ❌ | Per workload VPC | `var.vpcs` |

## Resource Naming Convention

```
{project_code}-{region_short}-{resource_type}-{purpose}
```

**Region Short Names:**
| Region | Short |
|--------|-------|
| eu-central-1 | euc1 |
| eu-west-1 | euw1 |
| eu-south-1 | eus1 |
| eu-south-2 | eus2 |
| eu-north-1 | eun1 |

**Examples:**
- `cwp-euc1-vpc-pro` - Production VPC in eu-central-1
- `cwp-euw1-ec2-sdw` - SD-WAN instance in eu-west-1
- `cwp-eus2-nfw` - Network Firewall in eu-south-2

## Verification

### Cloud WAN Status
```bash
aws networkmanager get-core-network --core-network-id <id>
aws networkmanager list-attachments --core-network-id <id>
```

### Instance Access (SSM)
```bash
aws ssm start-session --target <instance-id> --region <region>
```

### SD-WAN BGP Status
```bash
# On SD-WAN instance via SSM
sudo vtysh -c "show ip bgp summary"
sudo vtysh -c "show ip route"
```

### Network Firewall Logs
```bash
aws logs tail /aws/networkfirewall/<firewall-name> --follow
```

### Connectivity Testing
```bash
# From workload instance via SSM
ping <remote-instance-ip>
curl http://<alb-dns-name>
```

## File Structure

```
├── config.tf           # Provider configuration
├── variables.tf        # Input variables
├── terraform.tfvars    # Variable values
├── locals.tf           # Computed values
├── data.tf             # Data sources
├── iam.tf              # IAM roles and profiles
├── cwan.tf             # Cloud WAN core network
├── inspection.tf       # Inspection VPCs (GWLB/NFW)
├── sharedservices.tf   # Shared services VPCs
├── workloads.tf        # Workload VPCs
├── sdwan.tf            # SD-WAN configuration
├── outputs.tf          # Output values
└── modules/
    ├── compute/        # EC2 workload instances
    └── fake_firewall/      # GWLB tunnel handler
```

## Key Features

- **Segment Isolation**: Production and non-production fully isolated
- **Centralized Inspection**: All inter-segment traffic inspected
- **Multi-Region**: Deploy across multiple AWS regions
- **SD-WAN Integration**: Connect Tunnel-Less with FRRouting BGP
- **DNS Resolution**: Route 53 Resolver with cross-region forwarding
- **VPC Flow Logs**: Enabled on all VPCs
- **SSM Access**: No SSH keys required

## Routing Policies

The Cloud WAN policy includes advanced routing rules:

| Policy | Direction | Purpose |
|--------|-----------|---------|
| Secondary CIDR Filtering | Inbound | Blocks 100.64.0.0/10 from VPC attachments |
| Cloud Summarization | Outbound | Aggregates regional CIDRs |
| SD-WAN Transit Blocking | Inbound | Prevents SD-WAN VPC CIDRs from transiting |
| Inside CIDR Blocking | Inbound | Protects Cloud WAN internal addressing |

## Cost Considerations

Key cost drivers:
- Cloud WAN core network and attachments
- Network Firewall (if selected) or EC2 instances
- NAT Gateways
- VPC Endpoints
- Route 53 Resolver endpoints
- Data transfer

**Recommendation:** Destroy when not in use with `terraform destroy`

## Limitations

- EC2 instances limited to t3.small/t3.micro
- Amazon Linux 2023 required for all instances
- No SSH access - SSM only
- Network Firewall rules are basic (ICMP, HTTP)
- Single NAT Gateway per region

## References

- [AWS Cloud WAN Documentation](https://docs.aws.amazon.com/vpc/latest/cloudwan/)
- [AWS Network Firewall](https://docs.aws.amazon.com/network-firewall/)
- [FRRouting Documentation](https://docs.frrouting.org/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Module](https://github.com/aws-ia/terraform-aws-vpc)
