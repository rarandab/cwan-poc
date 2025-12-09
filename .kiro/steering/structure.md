---
inclusion: always
---

# Project Structure & Conventions

## File Organization

When modifying this codebase, respect the domain-driven file structure:

- **config.tf** - Terraform/provider configuration only
- **variables.tf** - Input variable definitions (no values)
- **locals.tf** - Computed values, CIDR calculations, regional mappings
- **data.tf** - Data source lookups (AMIs, availability zones, etc.)
- **iam.tf** - IAM roles and instance profiles
- **cwan.tf** - Cloud WAN core network and policy documents
- **inspection.tf** - Inspection VPCs, Network Firewall, GWLB endpoints
- **sharedservices.tf** - Shared services VPCs, VPC endpoints, Route 53 Resolver
- **workloads.tf** - Workload VPCs, compute instances, resolver associations
- **sdwan.tf** - SD-WAN VPCs, Connect attachments, FRRouting instances
- **outputs.tf** - Output values
- **files.tf** - Local file generation for debugging
- **\*.tftpl** - Template files for user data scripts

Place new resources in the appropriate domain file. Do not create new root-level `.tf` files unless introducing a new domain.

## Module Conventions

Modules follow standard Terraform structure:
- `main.tf` - Resource definitions
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `providers.tf` - Provider configuration
- `locals.tf` - Local computed values

Modules are located in `modules/{module-name}/` and instantiated using `for_each` loops.

## Naming Conventions

### Resources

Format: `{project_code}-{region_short}-{resource_type}-{purpose}`

- `{project_code}` - Project identifier (e.g., `pcc`)
- `{region_short}` - 4-character region code (see mapping below)
- `{resource_type}` - 3-letter abbreviation (`vpc`, `ec2`, `nfg`, `nfw`, `gwl`, etc.)
- `{purpose}` - Resource purpose (`pro`, `npd`, `shr`, `ins`, `sdw`, etc.)

Examples:
- `pcc-euc1-vpc-pro` - Production VPC in eu-central-1
- `pcc-euw1-ec2-sdw` - SD-WAN instance in eu-west-1
- `pcc-eus2-nfw-ins` - Network Firewall in eu-south-2

### Resource Types
- `vpc` - VPCs
- `vsn` - VPC Subnets
- `vsg` - VPC Security Groups
- `vpl` - VPC Prefix List
- `eni` - Elastic Network Interfaces
- `cgn` - Cloud Wan Global Network
- `ccn` - Cloud Wan Core Network
- `cat` - Cloud Wan Attachment
- `irl` - IAM Role
- `ipl` - IAM Policy
- `iip` - IAM Instance Profile
- `ec2` - EC2 instances
- `glb` - Gateway Load Balancers
- `ltg` - Target Groups
- `gle` - Gateway Load Balancer Endpoints
- `ves` - VPC Endpoint Services
- `smp` - Systems Manager Parameter
- `sms` - Systems Manager Secret

### Region Short Names

Mapping defined in `locals.tf`:
- `eu-central-1` → `euc1`
- `eu-west-1` → `euw1`
- `eu-south-1` → `eus1`
- `eu-south-2` → `eus2`
- `eu-north-1` → `eun1`

Always use these short names in resource identifiers.

### Cloud WAN Segments

Format: `cwnsgm{ProjectCode}{SegmentName}`
- Example: `cwnsgnPccPro` (production segment)
- Example: `cwnsgnPccNpd` (non-production segment)

### Network Function Groups

Format: `cwnnfg{ProjectCode}{Purpose}`
- Example: `cwnnfgPccIns` (inspection NFG)

## CIDR Allocation Strategy

Per region using `10.x.0.0/16` blocks:

- **Inspection VPCs**: `.255.0/24` (last octet 255)
- **Shared Services**: `.250.0/24` (octet 250)
- **SD-WAN VPCs**: `.254.0/24` (octet 254)
- **Workload VPCs**: Smaller allocations from main regional CIDR
- **Secondary CIDRs**: `100.64.0.0/20` (inspection), `100.64.100.0/22` (workloads)

When adding new VPCs, follow this allocation pattern to avoid conflicts.

## Code Patterns

### Multi-Region Deployment

Use `for_each` with region-based keys:

```hcl
module "example" {
  for_each = { for v in var.vpcs : "${local.region_short_names[v.region]}-${v.name}" => v }
  source   = "./modules/example"
  # ...
}
```

This pattern enables consistent multi-region deployments.

### Resource Dependencies

Follow the data flow:
1. Variables (`variables.tf`) → User values (`terraform.tfvars`)
2. Computed locals (`locals.tf`)
3. Data sources (`data.tf`)
4. Resources (domain-specific `.tf` files)
5. Outputs (`outputs.tf`)

When adding resources, ensure dependencies are properly referenced using `depends_on` or implicit references.

### Segment Isolation

Resources belong to specific Cloud WAN segments. When creating VPC attachments or routing policies, always specify the correct segment:
- `pro` - Production workloads
- `npd` - Non-production workloads
- `shr` - Shared services
- `nva` - Network virtual appliances
- `hyb` - Hybrid connectivity (SD-WAN)

## Modification Guidelines

- Maintain domain separation: networking changes go in domain files, not `main.tf`
- Use descriptive resource names following the naming convention
- Add comments for complex routing policies or CIDR calculations
- Update `outputs.tf` when exposing new resource attributes
- Keep modules generic and reusable across regions
- Use `local.region_short_names` for region abbreviations
- Validate CIDR allocations against the strategy before adding VPCs
