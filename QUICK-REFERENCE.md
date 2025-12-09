# AWS Cloud WAN PoC - Quick Reference Guide

## Essential Commands

### Deployment
```bash
# Initialize
terraform init

# Plan
terraform plan

# Deploy
terraform apply

# Destroy
terraform destroy
```

### Verification
```bash
# Get Cloud WAN Core Network ID
terraform output -json | jq -r '.core_network_id.value'

# List all instances
terraform output instances

# Check Cloud WAN status
aws networkmanager get-core-network --core-network-id <id>

# List attachments
aws networkmanager list-attachments --core-network-id <id>
```

### SD-WAN BGP Verification
```bash
# Connect to SD-WAN instance
aws ssm start-session --target <instance-id> --region eu-central-1

# Check BGP status
sudo vtysh -c "show ip bgp summary"
sudo vtysh -c "show ip bgp neighbors"
sudo vtysh -c "show ip route"

# View logs
sudo tail -f /var/log/frr/frr.log
cat /var/log/frr-setup.log
```

### Connectivity Testing
```bash
# Connect to workload instance
aws ssm start-session --target <instance-id> --region <region>

# Test connectivity
ping <remote-ip>
traceroute <remote-ip>

# Test DNS
nslookup s3.amazonaws.com
dig s3.amazonaws.com
```

## CIDR Allocation Quick Reference

### Regional CIDRs
| Region        | CIDR          | Short Name |
|---------------|---------------|------------|
| eu-central-1  | 10.0.0.0/16   | euc1       |
| eu-south-2    | 10.1.0.0/16   | eus2       |
| eu-south-1    | 10.2.0.0/16   | eus1       |
| eu-west-1     | 10.3.0.0/16   | euw1       |

### Per-Region Allocation Pattern
| Component         | CIDR Pattern      | Example (euc1)  |
|-------------------|-------------------|-----------------|
| Inspection (NFG)  | 100.64.0.0/20     | 100.64.0.0/20   |
| Network Firewall  | 10.x.255.0/24     | 10.0.255.0/24   |
| Shared Services   | 10.x.250.0/24     | 10.0.250.0/24   |
| SD-WAN            | 10.x.254.0/24     | 10.0.254.0/24   |
| Production VPC    | 10.x.0.0/24       | 10.0.0.0/24     |
| Dev VPC           | 10.x.64.0/24      | 10.0.64.0/24    |

### Special CIDRs
| Purpose           | CIDR              | Notes                    |
|-------------------|-------------------|--------------------------|
| Secondary CIDR    | 100.64.100.0/22   | Non-routable, data tier  |
| Cloud WAN Inside  | 192.168.0.0/16    | Internal addressing      |
| SD-WAN Announced  | 172.16.0.0/16     | On-premises networks     |
|                   | 172.18.0.0/16     |                          |
|                   | 172.20.0.0/16     |                          |

## Network Segments

| Segment           | Code | Purpose                  | Isolation | Inspection |
|-------------------|------|--------------------------|-----------|------------|
| Production        | pro  | Production workloads     | Yes       | Yes        |
| Non-Production    | npd  | Dev/Test workloads       | Yes       | Yes        |
| Shared Services   | shr  | VPC Endpoints, DNS       | No        | No         |
| NVA               | nva  | Network Firewall VPCs    | Yes       | N/A        |
| Hybrid            | hyb  | SD-WAN/VPN connectivity  | Yes       | Yes        |

## Routing Policies

| Policy                  | Direction | Number | Purpose                           |
|-------------------------|-----------|--------|-----------------------------------|
| secondaryCidrFiltering  | Inbound   | 100    | Block 100.64.0.0/10               |
| summarizeCloud          | Outbound  | 200    | Aggregate regional CIDRs          |
| blockSDWanTransit       | Inbound   | 300    | Block SD-WAN VPC CIDRs            |
| blockInsideCidrs        | Inbound   | 400    | Block Cloud WAN inside CIDRs      |

## Resource Naming Convention

**Pattern**: `{project_code}-{region_short}-{resource_type}-{suffix}`

**Examples**:
- VPC: `pcc-euc1-pro-vpc`
- Instance: `pcc-euc1-sdw-ec2`
- Security Group: `pcc-euw1-sdw-sg`
- Subnet: `pcc-eus2-app-snt`

## Key Terraform Variables

### Minimal Configuration
```hcl
owner        = "your-name"
project_name = "PoC Cloud WAN"
project_code = "pcc"  # Must be 3 lowercase chars

core_network_config = {
  asn_ranges         = ["65000-65100"]
  inside_cidr_blocks = ["192.168.0.0/16"]
  edge_locations     = [/* ... */]
  segments           = [/* ... */]
}

vpcs = [/* List of VPCs */]
```

### SD-WAN Configuration
```hcl
sdwan = {
  regions = ["eu-central-1"]
  asn     = 64600
  cidrs   = ["172.16.0.0/16", "172.18.0.0/16", "172.20.0.0/16"]
}
```

## Common Issues and Solutions

### Issue: BGP Not Establishing
**Solution**:
1. Check security group allows TCP/179
2. Verify Connect Peer is AVAILABLE
3. Check FRR logs: `sudo tail -f /var/log/frr/frr.log`

### Issue: No Connectivity Between VPCs
**Solution**:
1. Verify attachments are AVAILABLE
2. Check segment sharing in policy
3. Review routing policies
4. Check security groups

### Issue: Attachment Stuck in Pending
**Solution**:
1. Check `require_acceptance` and `accept_attachment` settings
2. Verify segment tags match policy
3. Check policy attachment status

### Issue: Inspection Not Working
**Solution**:
1. Verify appliance mode enabled on NFG VPC
2. Check send-via policies configured
3. Review Network Firewall rules
4. Check VPC Flow Logs

## Port Requirements

### SD-WAN / BGP
- **TCP 179**: BGP peering
- **ICMP**: Connectivity testing

### Shared Services
- **TCP 443**: VPC Endpoints, HTTPS
- **UDP 53**: DNS queries
- **TCP 53**: DNS zone transfers

### Management
- **TCP 443**: SSM Session Manager

## File Locations

### Configuration Files
- `terraform.tfvars` - Variable values
- `variables.tf` - Variable definitions
- `locals.tf` - Local variables

### Main Infrastructure
- `cwan.tf` - Cloud WAN core and policies
- `sdwan.tf` - SD-WAN Connect Tunnel-Less
- `inspection.tf` - Inspection VPCs and Network Firewall
- `sharedservices.tf` - Shared Services VPCs
- `workloads.tf` - Workload VPCs

### Templates
- `sdwan-frr-userdata.sh.tftpl` - FRRouting configuration

### Outputs
- `outputs/policy.json` - Cloud WAN policy document
- `outputs/userdata-*.sh` - SD-WAN user data scripts

## Useful AWS CLI Commands

### Cloud WAN
```bash
# Get core network
aws networkmanager get-core-network --core-network-id <id>

# List attachments
aws networkmanager list-attachments --core-network-id <id>

# Get attachment details
aws networkmanager get-attachment --attachment-id <id>

# Get connect peer
aws networkmanager get-connect-peer --connect-peer-id <id>
```

### VPC
```bash
# List VPCs
aws ec2 describe-vpcs --region <region>

# List subnets
aws ec2 describe-subnets --region <region>

# List route tables
aws ec2 describe-route-tables --region <region>
```

### EC2
```bash
# List instances
aws ec2 describe-instances --region <region>

# Start SSM session
aws ssm start-session --target <instance-id> --region <region>
```

### Network Firewall
```bash
# List firewalls
aws network-firewall list-firewalls --region <region>

# Describe firewall
aws network-firewall describe-firewall --firewall-name <name> --region <region>
```

### Logs
```bash
# Tail CloudWatch logs
aws logs tail <log-group-name> --follow --region <region>

# Get log streams
aws logs describe-log-streams --log-group-name <name> --region <region>
```

## Cost Optimization Tips

1. **Destroy when not in use**: `terraform destroy`
2. **Use smaller instance types**: t3.micro for testing
3. **Limit regions**: Start with 1-2 regions
4. **Reduce NAT Gateways**: Use single_az configuration
5. **Monitor data transfer**: Inter-region traffic is expensive
6. **Use VPC endpoints**: Reduce NAT Gateway data transfer

## Security Checklist

- [ ] Review security group rules
- [ ] Enable VPC Flow Logs (already enabled)
- [ ] Enable CloudTrail
- [ ] Enable AWS Config
- [ ] Review IAM roles and policies
- [ ] Enable GuardDuty
- [ ] Review Network Firewall rules
- [ ] Implement backup strategy
- [ ] Enable encryption at rest
- [ ] Review compliance requirements

## Monitoring and Logging

### Enabled by Default
- VPC Flow Logs (CloudWatch, 1 day retention)
- Network Firewall logs
- FRRouting logs (`/var/log/frr/`)

### Recommended Additions
- CloudWatch dashboards
- CloudWatch alarms for BGP status
- SNS notifications for attachment state changes
- AWS Network Manager events

## Documentation Files

- `README.md` - Complete documentation
- `architecture.md` - Mermaid diagram
- `architecture.txt` - ASCII diagram
- `ARCHITECTURE-DRAWIO-GUIDE.md` - Draw.io guide
- `CREATE-ARCHITECTURE-PNG.md` - PNG creation guide
- `QUICK-REFERENCE.md` - This file

## Support Resources

- [AWS Cloud WAN Docs](https://docs.aws.amazon.com/vpc/latest/cloudwan/)
- [AWS Network Firewall Docs](https://docs.aws.amazon.com/network-firewall/)
- [FRRouting Docs](https://docs.frrouting.org/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Version Information

- **Terraform**: >= 1.0
- **AWS Provider**: >= 6.0
- **FRRouting**: 8.0 (installed via package manager)
- **Amazon Linux**: 2023

---

**Quick Tip**: Bookmark this file for fast reference during deployment and troubleshooting!
