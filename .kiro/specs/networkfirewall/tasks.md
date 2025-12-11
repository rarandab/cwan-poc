# Implementation Plan

- [ ] 1. Add inspection_type input variable
  - [ ] 1.1 Create inspection_type variable in variables.tf
    - Add variable with type string, default "gwlbtunfw"
    - Add validation block to restrict values to "gwlbtunfw" or "network_firewall"
    - _Requirements: 1.1, 1.2, 1.3, 1.4_
  - [ ]* 1.2 Write property test for inspection type validation
    - **Property 2: Invalid Inspection Type Rejection**
    - **Validates: Requirements 1.4**

- [ ] 2. Add conditional logic to existing GWLB resources
  - [ ] 2.1 Update gwlbtunfw module instantiation with conditional for_each
    - Modify for_each to only create resources when inspection_type == "gwlbtunfw"
    - _Requirements: 1.1_
  - [ ] 2.2 Update GWLB endpoint resources with conditional for_each
    - Modify aws_vpc_endpoint.firewall for_each to check inspection_type
    - _Requirements: 1.1_
  - [ ] 2.3 Update GWLB-related routes with conditional for_each
    - Modify aws_route.nfg_cwn_dfl and aws_route.nfg_pub_corpo for_each expressions
    - _Requirements: 1.1_

- [ ] 3. Implement Network Firewall rule group
  - [ ] 3.1 Create stateful rule group resource for ICMP and HTTP
    - Add aws_networkfirewall_rule_group with conditional for_each
    - Include ICMP PASS rule with sid 1
    - Include HTTP PASS rule on port 80 with sid 2
    - Use naming convention: {project_code}-{region_short}-nfwrg-allow
    - _Requirements: 2.1, 3.1_
  - [ ]* 3.2 Write property test for rule group completeness
    - **Property 3: Network Firewall Rule Group Completeness**
    - **Validates: Requirements 2.1, 3.1**

- [ ] 4. Implement Network Firewall policy
  - [ ] 4.1 Create firewall policy resource
    - Add aws_networkfirewall_firewall_policy with conditional for_each
    - Configure stateless_default_actions to forward to stateful engine
    - Reference the rule group created in task 3.1
    - Use naming convention: {project_code}-{region_short}-nfwpol
    - _Requirements: 2.1, 3.1_

- [ ] 5. Implement Network Firewall and endpoints
  - [ ] 5.1 Create Network Firewall resource
    - Add aws_networkfirewall_firewall with conditional for_each
    - Configure subnet_mapping to use NFG VPC firewall subnets
    - Reference the firewall policy created in task 4.1
    - Use naming convention: {project_code}-{region_short}-nfw
    - _Requirements: 4.1_
  - [ ] 5.2 Add locals for extracting firewall endpoint IDs
    - Create local variable to extract endpoint IDs from firewall_status
    - Map endpoints by region and availability zone
    - _Requirements: 4.1, 4.2_
  - [ ]* 5.3 Write property test for firewall endpoint placement
    - **Property 4: Firewall Endpoint Subnet Placement**
    - **Validates: Requirements 4.1**

- [ ] 6. Implement Network Firewall routing
  - [ ] 6.1 Create routes from Cloud WAN subnets to firewall endpoints
    - Add aws_route resources with conditional for_each for inspection_type == "network_firewall"
    - Route default traffic (0.0.0.0/0) to firewall endpoints
    - _Requirements: 4.2_
  - [ ] 6.2 Create return routes from firewall subnets to NAT Gateway
    - Configure routes for corporate CIDRs through firewall endpoints
    - _Requirements: 4.3_
  - [ ]* 6.3 Write property test for inspection type mutual exclusivity
    - **Property 1: Inspection Type Mutual Exclusivity**
    - **Validates: Requirements 1.1, 1.2**

- [ ] 7. Implement Network Firewall logging
  - [ ] 7.1 Create CloudWatch Log Group for firewall alerts
    - Add aws_cloudwatch_log_group with conditional for_each
    - Use naming convention: /aws/networkfirewall/{project_code}-{region_short}-nfw
    - Set retention_in_days to 7
    - _Requirements: 5.1_
  - [ ] 7.2 Create logging configuration resource
    - Add aws_networkfirewall_logging_configuration with conditional for_each
    - Configure ALERT log type to CloudWatch Logs
    - Reference the log group created in task 7.1
    - _Requirements: 5.2_
  - [ ]* 7.3 Write property test for logging configuration
    - **Property 5: Logging Configuration Completeness**
    - **Validates: Requirements 5.1, 5.2**

- [ ] 8. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Update documentation and outputs
  - [ ] 9.1 Update terraform.tfvars with inspection_type example
    - Add commented example showing both options
    - _Requirements: 1.1, 1.2, 1.3_
  - [ ] 9.2 Add Network Firewall outputs to outputs.tf
    - Output firewall ARNs
    - Output firewall endpoint IDs
    - Output CloudWatch Log Group names
    - _Requirements: 4.1, 5.1_

- [ ] 10. Final Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.
