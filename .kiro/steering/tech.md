---
inclusion: always
---

# Technology Stack & Constraints

## Infrastructure as Code

- **Terraform**: >= 1.0 (HCL syntax only)
- **AWS Provider**: >= 6.0
- Use declarative configuration via `.tf` files and `terraform.tfvars`
- No build system - pure Terraform deployment

## AWS Service Requirements

### Core Networking
- **AWS Cloud WAN**: Core network with segments and Network Function Groups
- **VPC Module**: Use `aws-ia/vpc/aws` module for VPC creation
- **Gateway Load Balancer**: For traffic inspection with tunnel handler

### Compute & Access
- **EC2 Instances**: ONLY use `t3.small` or `t3.micro` instance types
- **Amazon Linux 2023**: Required base AMI for all EC2 instances
- **SSM Access**: Use AWS Systems Manager for instance access - NEVER use SSH keys or private keys

### Security & Monitoring
- **IAM**: Create instance profiles with SSM access permissions
- **CloudWatch Logs**: Enable VPC Flow Logs for network monitoring
- **Route 53 Resolver**: For DNS resolution across segments

### Third-Party Software
- **FRRouting (FRR)**: BGP daemon for SD-WAN instances using Connect Tunnel-Less
- **aws-gateway-load-balancer-tunnel-handler**: For GWLB integration on inspection instances

## Terraform Workflow

Standard Terraform commands apply:
```bash
terraform init      # Initialize providers and modules
terraform validate  # Validate HCL syntax
terraform plan      # Preview changes
terraform apply     # Deploy infrastructure
terraform destroy   # Tear down infrastructure
```

## Verification Commands

### Cloud WAN Status
```bash
aws networkmanager get-core-network --core-network-id <id>
aws networkmanager list-attachments --core-network-id <id>
```

### Instance Access (SSM Only)
```bash
aws ssm start-session --target <instance-id> --region <region>
```

### BGP Verification (on SD-WAN instances)
```bash
sudo vtysh -c "show ip bgp summary"
sudo vtysh -c "show ip route"
```

### Log Inspection
```bash
sudo tail -f /var/log/frr/frr.log                           # FRR logs
aws logs tail /aws/networkfirewall/<name> --follow          # Network Firewall
aws logs tail <log-group-name> --follow                     # VPC Flow Logs
```

## Critical Constraints

- NO SSH keys or private keys in EC2 instances - use SSM exclusively
- EC2 instance types limited to t3.small or t3.micro for cost control
- All infrastructure must be defined in Terraform - no manual AWS console changes
- Use Amazon Linux 2023 AMI - lookup via data source in `data.tf`
