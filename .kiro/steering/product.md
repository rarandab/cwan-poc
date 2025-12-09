---
inclusion: always
---

# Product Overview

This is an AWS Cloud WAN Proof of Concept demonstrating enterprise-grade multi-region networking with centralized traffic inspection and hybrid connectivity.

## Architecture Principles

When working with this codebase, understand these core design principles:

1. **Hub-and-Spoke Topology**: Cloud WAN acts as the central hub connecting all VPCs across regions
2. **Mandatory Inspection**: All inter-segment traffic MUST route through inspection VPCs with GWLB
3. **Segment Isolation**: Traffic between segments is controlled via Cloud WAN routing policies
4. **Shared Services Model**: Common services (VPC endpoints, DNS) are centralized to reduce duplication
5. **Simulated Components**: Inspection and SD-WAN use Linux instances to simulate appliances (not production-grade)

## Network Segments

The architecture uses five Cloud WAN segments with specific purposes:

- **pro** (Production): Production workloads, isolated from non-production
- **npd** (Non-Production): Development/test workloads, isolated from production
- **shr** (Shared Services): VPC endpoints, Route 53 Resolver endpoints, accessible by all segments
- **nva** (Network Virtual Appliances): Inspection VPCs with GWLB, all inter-segment traffic flows here
- **hyb** (Hybrid): SD-WAN Connect attachments for simulated on-premises connectivity via BGP

## Traffic Flow Patterns

When modifying routing or adding resources, respect these traffic flows:

1. **Intra-Segment**: Direct routing within same segment (pro-to-pro, npd-to-npd)
2. **Inter-Segment**: MUST route through inspection VPCs (pro → nva → npd)
3. **Shared Services Access**: All segments can reach shr segment directly
4. **Hybrid Connectivity**: SD-WAN instances in hyb segment advertise routes via BGP to Cloud WAN
5. **Internet Egress**: Not implemented in this PoC (add NAT Gateways if needed)

## Component Purposes

### Inspection VPCs (nva segment)
- Simulate centralized traffic inspection using Linux instances with GWLB tunnel handler
- NOT production Network Firewall - uses basic Linux instances for PoC demonstration
- One per region for high availability
- Secondary CIDR (100.64.0.0/20) for GWLB endpoints

### Shared Services VPCs (shr segment)
- Centralized VPC endpoints (SSM, EC2 Messages, SSM Messages) for private instance access
- Route 53 Resolver endpoints for cross-region DNS resolution
- Accessible from all other segments without inspection

### Workload VPCs (pro/npd segments)
- Host application workloads (simulated with test EC2 instances)
- Isolated by segment - production cannot directly reach non-production
- Use shared services for SSM access and DNS

### SD-WAN VPCs (hyb segment)
- Simulate on-premises connectivity using FRRouting (FRR) on Linux instances
- BGP peering with Cloud WAN via Connect Tunnel-Less (no GRE tunnels)
- Advertise on-premises routes (simulated with 172.16.0.0/16)

## Key Constraints for Modifications

- All EC2 instances use SSM for access - NEVER add SSH keys or security group rules for port 22
- Instance types limited to t3.small or t3.micro for cost control
- Amazon Linux 2023 is the required base AMI
- CIDR allocations follow strict patterns (see structure.md) - verify before adding VPCs
- Cloud WAN policy changes require understanding segment isolation rules
- Inspection is simulated - do not expect production-grade firewall features

## Expected Behavior

When the infrastructure is deployed:
- Workload instances in different segments can communicate through inspection VPCs
- All instances can reach shared services directly
- SD-WAN instances establish BGP sessions with Cloud WAN
- Route 53 Resolver provides DNS resolution across regions
- VPC Flow Logs capture traffic for troubleshooting

## Modification Scenarios

### Adding a New Workload VPC
1. Add entry to `var.workload_vpcs` in terraform.tfvars
2. Assign to correct segment (pro or npd)
3. Allocate CIDR from regional block following structure.md patterns
4. VPC will automatically attach to Cloud WAN and inherit routing policies

### Adding a New Region
1. Add region to `var.regions` in terraform.tfvars
2. Add region short name mapping to locals.tf
3. Create inspection, shared services, and optionally SD-WAN VPCs for that region
4. Cloud WAN automatically extends to new region

### Modifying Traffic Inspection Rules
- Inspection instances run basic tunnel handler - no stateful firewall rules
- To add filtering, modify bootstrap scripts in modules/firewall/bootstrap.sh
- Consider replacing with AWS Network Firewall for production use cases
