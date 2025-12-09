# AWS Cloud WAN Proof of Concept (PoC)

## Overview

This Terraform project deploys a comprehensive AWS Cloud WAN architecture that demonstrates enterprise-grade multi-region networking with centralized inspection, shared services, SD-WAN integration, and workload segmentation. The solution provides a scalable, secure, and highly available network infrastructure across multiple AWS regions.

## Architecture

This PoC creates a complete Cloud WAN deployment with the following components:

### 1. **AWS Cloud WAN Core Network**
- Global network spanning multiple AWS regions
- Configurable ASN ranges and inside CIDR blocks
- Dynamic segment-based routing with isolation and sharing policies
- Advanced routing policies for traffic filtering and summarization
- Network Function Groups for centralized inspection

### 2. **Network Segments**
The architecture implements multiple isolated network segments:

- **Production (pro)**: Isolated production workloads
- **Non-Production (npd)**: Development and testing environments
- **Shared Services (shr)**: Centralized services (VPC endpoints, DNS resolvers)
- **Network Virtual Appliances (nva)**: Inspection VPCs with AWS Network Firewall
- **Hybrid (hyb)**: SD-WAN and VPN connectivity for on-premises integration

### 3. **Inspection Architecture**
- **Inspection VPCs (nfg_vpc)**: Non-routable CIDR space (100.64.0.0/20) with appliance mode enabled
- **Firewall VPCs (nfw_vpc)**: AWS Network Firewall deployment with Gateway Load Balancer
- **Service Insertion**: Automatic traffic steering through inspection layer using Cloud WAN send-via policies
- **Multi-AZ Deployment**: High availability across availability zones

### 4. **Shared Services**
- **VPC Endpoints**: Centralized interface endpoints for AWS services (S3, etc.)
- **Route 53 Resolver**: Inbound and outbound DNS endpoints for hybrid DNS resolution
- **Cross-Region DNS**: Automatic DNS forwarding rules between regions
- **Centralized Access**: All segments can access shared services

### 5. **SD-WAN Integration**
- **Connect Tunnel-Less**: Simplified BGP peering without GRE tunnels
- **FRRouting (FRR)**: Open-source BGP daemon on Amazon Linux 2023
- **Multi-Region Support**: Deploy SD-WAN instances in multiple regions
- **Dynamic BGP**: Automatic neighbor discovery and route advertisement
- **CIDR Announcement**: Configurable list of on-premises CIDRs to advertise

### 6. **Workload VPCs**
- **Segmented Workloads**: VPCs attached to specific Cloud WAN segments
- **Multi-Subnet Design**: Application, load balancer, and Cloud WAN subnets
- **Secondary CIDRs**: Non-routable CIDR blocks for data tier isolation
- **Compute Instances**: EC2 instances with SSM access for testing

### 7. **Advanced Routing Policies**
- **Secondary CIDR Filtering**: Blocks carrier-grade NAT space (100.64.0.0/10)
- **Cloud CIDR Summarization**: Aggregates regional CIDRs for efficient routing
- **SD-WAN Transit Blocking**: Prevents SD-WAN VPC CIDRs from transiting Cloud WAN
- **Inside CIDR Blocking**: Protects Cloud WAN internal addressing
- **Attachment-Based Policies**: Different policies for VPC vs hybrid attachments

## Architecture Diagram

![Architecture Diagram](architecture.png)

> **Note**: To create the `architecture.png` file, see the instructions in `CREATE-ARCHITECTURE-PNG.md`. 
> You can use the Mermaid diagram in `architecture.md` with [Mermaid Live Editor](https://mermaid.live/) 
> or follow the detailed Draw.io guide in `ARCHITECTURE-DRAWIO-GUIDE.md`.
> 
> A text-based ASCII diagram is also available in `architecture.txt` for quick reference.

The diagram illustrates:
- Multi-region Cloud WAN deployment
- Segment isolation and sharing relationships
- Inspection flow through Network Function Groups
- SD-WAN connectivity with BGP peering
- Shared services distribution
- Workload VPC attachments

## Prerequisites

- Terraform >= 1.0
- AWS Provider >= 6.0
- AWS CLI configured with appropriate credentials
- Permissions to create Cloud WAN, VPCs, EC2, Network Firewall, and related resources
- Multiple AWS regions enabled in your account

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd cwan-poc
   ```

2. **Configure variables**
   - Copy and modify `terraform.tfvars` with your settings
   - Update `owner`, `project_name`, and `project_code`
   - Configure regions, CIDRs, and segments

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Review the plan**
   ```bash
   terraform plan
   ```

5. **Deploy the infrastructure**
   ```bash
   terraform apply
   ```

## Configuration Variables

### Core Variables

#### `owner` (string, required)
Infrastructure owner identifier for tagging.

**Example:**
```hcl
owner = "rarandab"
```

#### `project_name` (string, required)
Human-readable project name for resource descriptions.

**Example:**
```hcl
project_name = "PoC Cloud WAN"
```

#### `project_code` (string, required)
Three-character lowercase project code used in resource naming.

**Validation:** Must be exactly 3 characters and lowercase.

**Example:**
```hcl
project_code = "pcc"
```

### Core Network Configuration

#### `core_network_config` (object, required)
Comprehensive Cloud WAN core network configuration.

**Structure:**
```hcl
core_network_config = {
  asn_ranges         = list(string)           # ASN ranges for Cloud WAN
  inside_cidr_blocks = list(string)           # Internal Cloud WAN addressing
  edge_locations     = list(object({          # Regional edge locations
    region             = string               # AWS region
    asn                = number               # Regional ASN
    inside_cidr_blocks = list(string)         # Regional inside CIDRs
    edge_overrides     = object({             # Traffic steering overrides
      send_to  = string                       # Preferred inspection region
      send_via = list(object({                # Regional routing preferences
        regions           = list(string)      # Source regions
        use_edge_location = string            # Target edge location
      }))
    })
    cidr       = string                       # Regional CIDR allocation
    inspection = bool                         # Enable inspection in region
  }))
  segments = list(object({                    # Custom segments
    name                          = string
    description                   = string
    require_attachment_acceptance = bool
    isolate_attachments           = bool
  }))
}
```

**Example:**
```hcl
core_network_config = {
  asn_ranges         = ["65000-65100"]
  inside_cidr_blocks = ["192.168.0.0/16"]
  edge_locations = [
    {
      region             = "eu-central-1"
      asn                = 65000
      inside_cidr_blocks = ["192.168.0.0/24"]
      edge_overrides     = {}
      cidr               = "10.0.0.0/16"
      inspection         = true
    },
    {
      region         = "eu-south-2"
      asn            = 65001
      edge_overrides = {}
      cidr           = "10.1.0.0/16"
      inspection     = true
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
            regions           = ["eu-south-2", "eu-west-1"]
            use_edge_location = "eu-south-2"
          }
        ]
      }
      cidr = "10.2.0.0/16"
    },
    {
      region = "eu-west-1"
      asn    = 65003
      edge_overrides = {
        send_to = "eu-central-1"
        send_via = [
          {
            regions           = ["eu-central-1", "eu-south-2"]
            use_edge_location = "eu-central-1"
          },
          {
            regions           = ["eu-south-2"]
            use_edge_location = "eu-south-2"
          }
        ]
      }
      cidr = "10.3.0.0/16"
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
```

**CIDR Allocation Strategy:**
- Each region gets a `/16` CIDR block
- Inspection VPCs use `/24` from the last octet (`.255.0/24`)
- Shared Services VPCs use `/24` from octet 250 (`.250.0/24`)
- SD-WAN VPCs use `/24` from octet 254 (`.254.0/24`)
- Workload VPCs use smaller allocations from the main regional CIDR

### Workload VPCs

#### `vpcs` (list(object), required)
List of workload VPCs to create and attach to Cloud WAN segments.

**Structure:**
```hcl
vpcs = list(object({
  name    = string  # VPC name (pro, dev, test, etc.)
  region  = string  # AWS region
  cidr    = string  # VPC CIDR block
  segment = string  # Cloud WAN segment (pro, npd, etc.)
}))
```

**Example:**
```hcl
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
    cidr    = "10.1.64.0/24"
    region  = "eu-south-2"
    segment = "npd"
  },
  {
    name    = "dev"
    cidr    = "10.2.64.0/24"
    region  = "eu-south-1"
    segment = "npd"
  },
  {
    name    = "dev"
    cidr    = "10.3.64.0/24"
    region  = "eu-west-1"
    segment = "npd"
  }
]
```

### SD-WAN Configuration

#### `sdwan` (object, optional)
SD-WAN Connect Tunnel-Less configuration for on-premises integration.

**Structure:**
```hcl
sdwan = object({
  regions = list(string)  # Regions to deploy SD-WAN instances
  asn     = number        # BGP ASN for SD-WAN
  cidrs   = list(string)  # On-premises CIDRs to announce via BGP
})
```

**Example:**
```hcl
sdwan = {
  regions = ["eu-central-1"]
  asn     = 64600
  cidrs   = ["172.16.0.0/16", "172.18.0.0/16", "172.20.0.0/16"]
}
```

**How it works:**
- Deploys Amazon Linux 2023 EC2 instances with FRRouting
- Creates Connect Tunnel-Less attachments (NO_ENCAP protocol)
- Establishes BGP peering with Cloud WAN using actual subnet IPs
- Announces configured CIDRs to Cloud WAN via BGP
- Uses static routes to Null0 to make CIDRs routable

### On-Premises Configuration

#### `onprem` (object, required)
On-premises connectivity configuration (currently defined but not deployed).

**Structure:**
```hcl
onprem = object({
  region           = string        # Region for VPN gateway
  asn              = number        # BGP ASN for on-premises
  additional_cidrs = list(string)  # Additional CIDRs to announce
})
```

**Example:**
```hcl
onprem = {
  region           = "eu-west-1"
  asn              = 64600
  additional_cidrs = ["172.20.0.0/16", "172.21.0.0/16", "172.22.0.0/16"]
}
```

### VPN Configuration

#### `vpn` (object, required)
VPN configuration (currently defined but not deployed).

**Structure:**
```hcl
vpn = object({
  region = string  # Region for VPN deployment
})
```

**Example:**
```hcl
vpn = {
  region = "eu-central-1"
}
```

### VPC Endpoints

#### `endpoints` (list(string), optional)
List of AWS service endpoints to create in shared services VPCs.

**Default:** `[]`

**Example:**
```hcl
endpoints = [
  "s3"
]
```

**Supported Services:**
- s3
- ec2
- ssm
- logs
- Any AWS service supporting interface endpoints

## Key Features

### 1. Segment Isolation and Sharing
- Production and non-production segments are fully isolated
- Shared services segment accessible from all segments
- Hybrid segment for on-premises connectivity
- Configurable sharing relationships between segments

### 2. Centralized Inspection
- All inter-segment traffic flows through inspection VPCs
- AWS Network Firewall with Gateway Load Balancer
- Appliance mode enabled for stateful inspection
- Multi-AZ deployment for high availability

### 3. Advanced Routing Policies
- **Secondary CIDR Filtering**: Blocks 100.64.0.0/10 from VPC attachments
- **Cloud Summarization**: Aggregates regional CIDRs on outbound
- **SD-WAN Transit Blocking**: Prevents SD-WAN VPC CIDRs from transiting
- **Inside CIDR Blocking**: Protects Cloud WAN internal addressing
- **Attachment-Based Rules**: Different policies for VPC vs hybrid attachments

### 4. SD-WAN Integration
- Connect Tunnel-Less for simplified BGP peering
- No GRE tunnels required
- FRRouting for enterprise-grade BGP
- Multi-region support
- Dynamic route advertisement

### 5. DNS Resolution
- Route 53 Resolver endpoints in each region
- Inbound endpoints for on-premises queries
- Outbound endpoints for AWS service resolution
- Cross-region DNS forwarding
- Automatic resolver rule associations

### 6. High Availability
- Multi-AZ deployment across all components
- Redundant BGP peering (2 peers per Connect attachment)
- NAT Gateway in each AZ
- Distributed inspection layer

### 7. Security
- VPC Flow Logs enabled on all VPCs
- Security groups with least privilege
- IAM roles with SSM access for management
- Network segmentation with Cloud WAN
- Centralized traffic inspection

## Resource Naming Convention

Resources follow a consistent naming pattern:
```
{project_code}-{region_short}-{resource_type}-{suffix}
```

**Examples:**
- `pcc-euc1-pro-vpc` - Production VPC in eu-central-1
- `pcc-euw1-sdw-ec2` - SD-WAN instance in eu-west-1
- `pcc-eus2-nfw-vpc` - Firewall VPC in eu-south-2

**Region Short Names:**
- eu-central-1 → euc1
- eu-west-1 → euw1
- eu-south-1 → eus1
- eu-south-2 → eus2
- eu-north-1 → eun1

## Outputs

### `instances`
Map of all EC2 instances created with their private IP addresses.

**Format:**
```hcl
{
  "euc1-pro0" = "10.0.0.10"
  "euc1-dev0" = "10.0.64.10"
  ...
}
```

## File Structure

```
.
├── config.tf                      # Terraform and provider configuration
├── variables.tf                   # Variable definitions
├── terraform.tfvars               # Variable values (customize this)
├── locals.tf                      # Local variables and computed values
├── data.tf                        # Data sources
├── iam.tf                         # IAM roles and instance profiles
├── cwan.tf                        # Cloud WAN core network and policies
├── inspection.tf                  # Inspection VPCs and Network Firewall
├── sharedservices.tf              # Shared services VPCs and endpoints
├── workloads.tf                   # Workload VPCs and compute instances
├── sdwan.tf                       # SD-WAN Connect Tunnel-Less configuration
├── outputs.tf                     # Output definitions
├── files.tf                       # Local file outputs for debugging
├── sdwan-frr-userdata.sh.tftpl    # FRRouting user data template
├── modules/
│   ├── compute/                   # EC2 instance module
│   └── firewall/                  # Network Firewall module
└── outputs/                       # Generated output files
    ├── policy.json                # Cloud WAN policy document
    └── userdata-*.sh              # SD-WAN user data scripts
```

## Verification

After deployment, verify the infrastructure:

### 1. Cloud WAN Status
```bash
# Check core network status
aws networkmanager get-core-network \
  --core-network-id <core-network-id>

# List attachments
aws networkmanager list-attachments \
  --core-network-id <core-network-id>
```

### 2. SD-WAN BGP Status
```bash
# Connect to SD-WAN instance via SSM
aws ssm start-session --target <instance-id> --region <region>

# Check BGP status
sudo vtysh -c "show ip bgp summary"
sudo vtysh -c "show ip bgp neighbors"
sudo vtysh -c "show ip route"

# View FRR logs
sudo tail -f /var/log/frr/frr.log
cat /var/log/frr-setup.log
```

### 3. Network Connectivity
```bash
# Connect to workload instance
aws ssm start-session --target <instance-id> --region <region>

# Test connectivity to other VPCs
ping <remote-instance-ip>

# Test DNS resolution
nslookup s3.amazonaws.com
```

### 4. Inspection Flow
```bash
# Check Network Firewall logs
aws logs tail /aws/networkfirewall/<firewall-name> --follow

# View VPC Flow Logs
aws logs tail <log-group-name> --follow
```

## Cost Considerations

This PoC deploys significant AWS resources. Key cost drivers:

- **Cloud WAN**: Core network and attachments (per hour + data transfer)
- **Network Firewall**: Firewall endpoints and processing (per hour + GB processed)
- **Gateway Load Balancer**: Endpoints and data processing
- **NAT Gateways**: Per hour + data transfer
- **EC2 Instances**: t3.small instances for workloads and SD-WAN
- **VPC Endpoints**: Interface endpoints (per hour)
- **Route 53 Resolver**: Endpoints (per hour + queries)
- **Data Transfer**: Inter-region and inter-AZ traffic

**Recommendation:** Destroy the environment when not in use:
```bash
terraform destroy
```

## Troubleshooting

### SD-WAN BGP Not Establishing
1. Check security group allows TCP/179 from Cloud WAN peer IPs
2. Verify Connect Peer is in AVAILABLE state
3. Check FRR logs: `sudo tail -f /var/log/frr/frr.log`
4. Verify routes to Cloud WAN peers exist in route table

### Attachment Stuck in Pending
1. Check attachment acceptance is configured correctly
2. Verify segment tags match Cloud WAN policy
3. Review Cloud WAN policy attachment status

### No Connectivity Between VPCs
1. Verify attachments are in AVAILABLE state
2. Check segment sharing configuration
3. Review routing policies for blocks
4. Verify security groups allow traffic

### Inspection Not Working
1. Check appliance mode is enabled on inspection VPC
2. Verify send-via policies are configured
3. Check Network Firewall rules
4. Review VPC Flow Logs for dropped traffic

## Limitations

- VPN gateway configuration is defined but not deployed (commented out)
- On-premises connectivity requires manual VPN setup
- Network Firewall rules are basic (customize for production)
- Single NAT Gateway per region (not fully HA)
- Limited to EU regions in examples

## Future Enhancements

- [ ] Deploy VPN gateway with CloudFormation template
- [ ] Add AWS Transit Gateway integration
- [ ] Implement AWS Network Manager events and monitoring
- [ ] Add CloudWatch dashboards for visibility
- [ ] Implement automated failover testing
- [ ] Add support for IPv6
- [ ] Implement AWS Firewall Manager policies
- [ ] Add VPC Lattice integration

## Security Best Practices

1. **Least Privilege**: Review and restrict IAM roles
2. **Encryption**: Enable encryption at rest and in transit
3. **Monitoring**: Enable CloudTrail, Config, and GuardDuty
4. **Network Segmentation**: Use security groups and NACLs
5. **Patch Management**: Keep instances updated via SSM
6. **Secrets Management**: Use AWS Secrets Manager for credentials
7. **Backup**: Implement backup strategies for stateful resources

## Contributing

This is a PoC project. For production use:
1. Review and customize security groups
2. Implement proper CIDR planning
3. Add monitoring and alerting
4. Implement backup and disaster recovery
5. Add compliance controls as needed
6. Review and optimize costs

## License

This project is provided as-is for demonstration purposes.

## Support

For issues or questions:
1. Review AWS Cloud WAN documentation
2. Check Terraform AWS provider documentation
3. Review FRRouting documentation for BGP issues
4. Consult AWS Support for service-specific issues

## References

- [AWS Cloud WAN Documentation](https://docs.aws.amazon.com/vpc/latest/cloudwan/)
- [AWS Network Firewall](https://docs.aws.amazon.com/network-firewall/)
- [FRRouting Documentation](https://docs.frrouting.org/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Module](https://github.com/aws-ia/terraform-aws-vpc)

---

**Project Code:** pcc  
**Version:** 1.0  
**Last Updated:** December 2024
