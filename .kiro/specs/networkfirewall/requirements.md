# Requirements Document

## Introduction

This feature adds AWS Network Firewall as an alternative traffic inspection option to the existing Gateway Load Balancer with tunnel handler (`gwlbtunfw`) implementation. The PoC currently simulates centralized traffic inspection using Linux instances with the GWLB tunnel handler. This enhancement provides users with the choice to use AWS Network Firewall for a more production-ready inspection solution while maintaining backward compatibility with the existing approach.

## Glossary

- **Inspection_System**: The centralized traffic inspection component deployed in the NVA (Network Virtual Appliance) segment that inspects inter-segment traffic flowing through Cloud WAN
- **GWLB_Tunnel_Handler**: The current inspection implementation using Gateway Load Balancer with Linux instances running aws-gateway-load-balancer-tunnel-handler software
- **AWS_Network_Firewall**: AWS managed stateful network firewall service that provides network traffic filtering and intrusion prevention
- **Inspection_Type_Variable**: A Terraform input variable that determines which inspection mechanism to deploy
- **NFG_VPC**: The Network Function Group VPC where inspection endpoints are deployed using non-routable CIDR (100.64.0.0/20)
- **Cloud_WAN_Segment**: A logical isolation boundary within Cloud WAN (pro, npd, shr, nva, hyb)

## Requirements

### Requirement 1

**User Story:** As an infrastructure operator, I want to select between GWLB tunnel handler and AWS Network Firewall for traffic inspection, so that I can choose the appropriate inspection mechanism for my use case.

#### Acceptance Criteria

1. WHEN the Inspection_Type_Variable is set to "gwlbtunfw" THEN the Inspection_System SHALL deploy the existing GWLB tunnel handler module for traffic inspection
2. WHEN the Inspection_Type_Variable is set to "network_firewall" THEN the Inspection_System SHALL deploy AWS Network Firewall resources for traffic inspection
3. WHEN the Inspection_Type_Variable is not explicitly set THEN the Inspection_System SHALL default to deploying the GWLB tunnel handler module
4. WHEN the Inspection_Type_Variable contains an invalid value THEN the Inspection_System SHALL reject the configuration with a validation error

### Requirement 2

**User Story:** As an infrastructure operator, I want AWS Network Firewall to allow ICMP traffic between segments, so that I can perform network connectivity testing and troubleshooting.

#### Acceptance Criteria

1. WHEN AWS Network Firewall is deployed THEN the Inspection_System SHALL include a stateful rule group that permits ICMP protocol traffic
2. WHEN ICMP traffic traverses the AWS Network Firewall THEN the Inspection_System SHALL allow the traffic to pass without blocking

### Requirement 3

**User Story:** As an infrastructure operator, I want AWS Network Firewall to allow HTTP traffic between Cloud WAN segments, so that workloads can communicate over standard web protocols.

#### Acceptance Criteria

1. WHEN AWS Network Firewall is deployed THEN the Inspection_System SHALL include a stateful rule group that permits HTTP traffic on port 80
2. WHEN HTTP traffic originates from one Cloud_WAN_Segment and is destined for another Cloud_WAN_Segment THEN the Inspection_System SHALL allow the traffic to pass through the firewall

### Requirement 4

**User Story:** As an infrastructure operator, I want the Network Firewall deployment to integrate with the existing NFG VPC architecture, so that traffic routing through Cloud WAN Network Function Groups continues to work correctly.

#### Acceptance Criteria

1. WHEN AWS Network Firewall is deployed THEN the Inspection_System SHALL create firewall endpoints in the NFG_VPC firewall subnets
2. WHEN AWS Network Firewall is deployed THEN the Inspection_System SHALL configure routes from Cloud WAN attachment subnets to the firewall endpoints
3. WHEN AWS Network Firewall is deployed THEN the Inspection_System SHALL configure return routes from firewall subnets to the NAT Gateway for internet-bound traffic

### Requirement 5

**User Story:** As an infrastructure operator, I want Network Firewall logs sent to CloudWatch Logs, so that I can monitor and troubleshoot firewall activity.

#### Acceptance Criteria

1. WHEN AWS Network Firewall is deployed THEN the Inspection_System SHALL create a CloudWatch Log Group for firewall alert logs
2. WHEN AWS Network Firewall is deployed THEN the Inspection_System SHALL configure the firewall to send alert logs to the CloudWatch Log Group

