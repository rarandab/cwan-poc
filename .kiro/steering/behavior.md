# MCP Server Integration Behaviors

## AWS Documentation and Terraform MCP Server Usage

When working with AWS infrastructure and Terraform code, leverage the installed MCP servers to provide accurate, up-to-date information and analysis.

### Available MCP Servers

1. **aws-docs** - AWS Documentation MCP Server
2. **awslabs-terraform** - AWS Labs Terraform MCP Server

### AWS Documentation Server Usage

#### When to Use AWS Documentation Tools

- **Before implementing new AWS services**: Always search AWS documentation first
- **When troubleshooting AWS service issues**: Look up service-specific documentation
- **For understanding service limits and constraints**: Check official AWS documentation
- **When designing architecture**: Reference AWS best practices and service capabilities

#### Recommended Workflow

1. **Search First**: Use `search_documentation` to find relevant AWS service documentation
2. **Read Details**: Use `read_documentation` to get comprehensive information about specific services
3. **Get Recommendations**: Use `recommend` to discover related AWS services and features

#### Example Usage Patterns

```
# Search for specific AWS services
- "Search AWS documentation for VPC Flow Logs configuration"
- "Find AWS documentation about Cloud WAN routing policies"
- "Look up AWS Network Firewall best practices"

# Read specific documentation pages
- "Read the AWS documentation for EC2 instance types"
- "Get details about AWS Systems Manager Session Manager"

# Get recommendations for related services
- "What other AWS services work with Cloud WAN?"
- "Find related documentation for VPC networking"
```

### Terraform MCP Server Usage

#### When to Use Terraform Tools

- **Before writing Terraform code**: Search for existing modules and best practices
- **When troubleshooting Terraform**: Use validation and scanning tools
- **For security compliance**: Run Checkov scans on Terraform code
- **When exploring AWS provider resources**: Search provider documentation

#### Available Tools and Usage

1. **Module Search and Discovery**
   - `SearchAwsProviderDocs`: Find AWS provider resource documentation
   - `SearchAwsccProviderDocs`: Find AWSCC provider resource documentation  
   - `SearchSpecificAwsIaModules`: Search AWS-IA curated modules
   - `SearchUserProvidedModule`: Analyze any Terraform registry module

2. **Code Analysis and Validation**
   - `ExecuteTerraformCommand`: Run terraform init, plan, validate, apply, destroy

#### Recommended Workflow

1. **Research Phase**: Search for existing modules and provider documentation
2. **Implementation Phase**: Use terraform commands for validation

#### Example Usage Patterns

```
# Module and resource research
- "Search for AWS VPC Terraform modules"
- "Find documentation for aws_cloudwan_core_network resource"
- "Look up AWS-IA modules for networking"

# Code validation and execution
- "Run terraform validate on current directory"
- "Execute terraform plan to preview changes"
- "Run Checkov security scan on Terraform code"

# Provider documentation lookup
- "Find AWS provider docs for EC2 instances"
- "Search AWSCC provider for S3 bucket resources"
```

### Integration Best Practices

#### Always Start with Documentation

Before implementing any AWS service or Terraform resource:

1. **Search AWS documentation** to understand the service capabilities and constraints
2. **Look up Terraform provider documentation** to understand resource syntax and arguments
3. **Search for existing modules** to avoid reinventing the wheel
4. **Check security best practices** using Checkov or AWS documentation

#### Combine Both Servers Effectively

- Use **AWS docs** for understanding service concepts and architecture
- Use **Terraform MCP** for implementation details and code validation
- Cross-reference between official AWS docs and Terraform provider docs
- Validate security compliance using both AWS security guidelines and Checkov

#### Error Handling and Troubleshooting

When encountering issues:

1. **Check AWS service documentation** for service-specific troubleshooting
2. **Validate Terraform syntax** using terraform validate
3. **Review Terraform plan output** for resource conflicts
4. **Run security scans** to identify compliance issues
5. **Search for similar issues** in AWS documentation

### Specific Use Cases for This Project

#### Cloud WAN Architecture

- Search AWS docs for "Cloud WAN routing policies"
- Look up "AWS Cloud WAN Network Function Groups"
- Find Terraform aws_cloudwan_* resource documentation
- Search for AWS-IA networking modules

#### VPC and Networking

- Reference AWS VPC documentation for CIDR planning
- Look up AWS documentation for VPC Flow Logs
- Search Terraform aws_vpc and related resource docs
- Find networking security best practices

#### Security and Compliance

- Use AWS security documentation for IAM best practices
- Run Checkov scans on all Terraform code
- Reference AWS security guidelines for network segmentation
- Look up AWS Systems Manager documentation for secure access

#### Multi-Region Deployment

- Search AWS docs for region-specific service availability
- Look up AWS documentation for cross-region networking
- Find Terraform provider docs for region-specific resources
- Search for multi-region architecture patterns

### Command Examples

#### AWS Documentation Queries
```
# Service-specific searches
"Search AWS documentation for Cloud WAN core network configuration"
"Find AWS docs about VPC endpoint services"
"Look up AWS Network Firewall rule groups"

# Architecture and best practices
"Search for AWS multi-region networking best practices"
"Find AWS documentation about network segmentation"
"Look up AWS security best practices for VPC"
```

#### Terraform MCP Queries
```
# Resource documentation
"Search AWS provider docs for cloudwan_core_network"
"Find Terraform documentation for aws_vpc resource"
"Look up aws_ec2_instance resource arguments"

# Module discovery
"Search AWS-IA modules for VPC networking"
"Find Terraform modules for Cloud WAN"
"Search for AWS networking modules"

# Code validation
"Run terraform validate on current configuration"
"Execute terraform plan for infrastructure changes"
"Run Checkov security scan on Terraform files"
```

### Notes and Limitations

#### Known Issues

- **Checkov on Windows**: The RunCheckovScan tool may have path resolution issues on Windows
  - Workaround: Use PowerShell directly: `checkov --quiet -d . --framework terraform --output json`
- **Large outputs**: Some documentation searches may return large results
  - Use specific search terms to narrow results
- **Rate limiting**: AWS documentation API may have rate limits
  - Space out requests if encountering limits

#### Best Practices

- **Be specific** in search queries to get relevant results
- **Combine multiple sources** - don't rely on just one tool
- **Validate information** by cross-referencing AWS docs and Terraform docs
- **Test configurations** using terraform plan before applying
- **Run security scans** regularly during development

### Integration with Project Structure

Given this project's domain-driven file structure:

- Use AWS docs when working on **architecture decisions** (cwan.tf, inspection.tf)
- Use Terraform MCP when **implementing resources** in domain files
- **Validate configurations** before committing changes
- **Run security scans** on modules and main configuration
- **Reference documentation** when adding new regions or services

This steering file ensures you leverage both MCP servers effectively for AWS infrastructure development with Terraform.