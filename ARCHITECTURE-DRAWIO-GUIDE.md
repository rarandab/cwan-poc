# Architecture Diagram Guide for Draw.io

This guide helps you create the architecture diagram in Draw.io manually.

## Layout Structure

### Top Level (Horizontal Layout)
```
[On-Premises/SD-WAN] ←→ [AWS Cloud WAN] ←→ [Multi-Region VPCs]
```

## Components to Draw

### 1. On-Premises / SD-WAN Section (Left Side)
**Shape**: Rectangle with rounded corners
**Color**: Orange (#FF9900)
**Content**:
```
SD-WAN / On-Premises
├─ FRRouting BGP Instance
├─ ASN: 64600
└─ CIDRs: 172.16.0.0/16
          172.18.0.0/16
          172.20.0.0/16
```

### 2. AWS Cloud WAN Core (Center)
**Shape**: Large rounded rectangle
**Color**: Dark Orange (#FF9900)
**Content**:

#### Cloud WAN Core Network
```
AWS Cloud WAN
Global Network
ASN Range: 65000-65100
Inside CIDR: 192.168.0.0/16
```

#### Network Segments (Inside Cloud WAN box)
Create 5 smaller boxes:

1. **Production Segment**
   - Color: Dark Green (#3F8624)
   - Text: "Production (pro)\nIsolated"

2. **Non-Production Segment**
   - Color: Dark Green (#3F8624)
   - Text: "Non-Production (npd)\nIsolated"

3. **Shared Services Segment**
   - Color: Blue (#527FFF)
   - Text: "Shared Services (shr)\nShared with all segments"

4. **NVA Segment**
   - Color: Red (#D13212)
   - Text: "Network Virtual Appliances (nva)\nInspection"

5. **Hybrid Segment**
   - Color: Orange (#FF9900)
   - Text: "Hybrid (hyb)\nSD-WAN/VPN"

#### Network Function Group (Inside Cloud WAN box)
**Shape**: Hexagon
**Color**: Red (#D13212)
**Text**: "Inspection NFG\nService Insertion"

### 3. Regional VPCs (Right Side - 4 Columns)

#### Region: eu-central-1 (10.0.0.0/16)
**Container**: Large rectangle with title

**Inspection Layer** (Top):
- NFG VPC: Red box
  ```
  NFG VPC
  100.64.0.0/20
  Appliance Mode Enabled
  ```
- NFW VPC: Red box
  ```
  NFW VPC
  10.0.255.0/24
  Network Firewall + GWLB
  ```

**Shared Services** (Middle):
- Shared VPC: Blue box
  ```
  Shared Services VPC
  10.0.250.0/24
  - VPC Endpoints (S3)
  - Route 53 Resolver
  ```

**SD-WAN** (Middle):
- SD-WAN VPC: Orange box
  ```
  SD-WAN VPC
  10.0.254.0/24
  Connect Tunnel-Less
  BGP Peering
  ```

**Workloads** (Bottom):
- Production VPC: Light Green box
  ```
  Production VPC
  10.0.0.0/24
  Primary CIDR
  + 100.64.100.0/22 (Secondary)
  ```
- Dev VPC: Light Green box
  ```
  Dev VPC
  10.0.64.0/24
  Primary CIDR
  + 100.64.100.0/22 (Secondary)
  ```

#### Region: eu-south-2 (10.1.0.0/16)
**Container**: Large rectangle with title

**Inspection Layer**:
- NFG VPC: `100.64.0.0/20`
- NFW VPC: `10.1.255.0/24`

**Shared Services**:
- Shared VPC: `10.1.250.0/24`

**Workloads**:
- Production VPC: `10.1.0.0/24`
- Dev VPC: `10.1.64.0/24`

#### Region: eu-south-1 (10.2.0.0/16)
**Container**: Large rectangle with title

**Shared Services**:
- Shared VPC: `10.2.250.0/24`

**Workloads**:
- Dev VPC: `10.2.64.0/24`

#### Region: eu-west-1 (10.3.0.0/16)
**Container**: Large rectangle with title

**Shared Services**:
- Shared VPC: `10.3.250.0/24`

**Workloads**:
- Dev VPC: `10.3.64.0/24`

## Connections and Arrows

### Connection Types
1. **Solid Lines with Arrows**: Direct connections/attachments
2. **Dashed Lines**: Traffic flow and access relationships
3. **Thick Lines**: High-bandwidth connections

### Key Connections to Draw

#### SD-WAN Connections
```
On-Premises SD-WAN ──[BGP Peering]──> SD-WAN VPC (eu-central-1)
SD-WAN VPC ──[Connect Tunnel-Less]──> Hybrid Segment
```

#### VPC to Segment Attachments
```
Production VPCs ──> Production Segment
Dev VPCs ──> Non-Production Segment
Shared VPCs ──> Shared Services Segment
NFG VPCs ──> Network Function Group
NFW VPCs ──> NVA Segment
SD-WAN VPC ──> Hybrid Segment
```

#### Inspection Flow (Dashed Lines)
```
Production Segment ┄┄[send-via]┄┄> Inspection NFG
Non-Production Segment ┄┄[send-via]┄┄> Inspection NFG
Hybrid Segment ┄┄[send-via]┄┄> Inspection NFG

Inspection NFG ┄┄> NFG VPC (eu-central-1)
Inspection NFG ┄┄> NFG VPC (eu-south-2)

NFG VPC ┄┄[GWLB Endpoint]┄┄> NFW VPC
```

#### Segment Sharing (Dashed Lines)
```
Production Segment ┄┄[Access]┄┄> Shared Services Segment
Non-Production Segment ┄┄[Access]┄┄> Shared Services Segment
Hybrid Segment ┄┄[Access]┄┄> Shared Services Segment
```

## Labels and Annotations

### Add these text boxes:

1. **Near SD-WAN Connection**:
   ```
   Connect Tunnel-Less
   Protocol: NO_ENCAP
   BGP ASN: 64600
   2 BGP Peers per region
   ```

2. **Near Inspection NFG**:
   ```
   Service Insertion
   All inter-segment traffic
   flows through inspection
   ```

3. **Near Network Firewall**:
   ```
   AWS Network Firewall
   Gateway Load Balancer
   Multi-AZ Deployment
   Stateful Inspection
   ```

4. **Near Shared Services**:
   ```
   Centralized Services:
   - VPC Endpoints
   - Route 53 Resolver
   - Cross-region DNS
   ```

5. **Routing Policies Box** (Bottom):
   ```
   Cloud WAN Routing Policies:
   ├─ Secondary CIDR Filtering (100.64.0.0/10)
   ├─ Cloud CIDR Summarization (10.x.0.0/16)
   ├─ SD-WAN Transit Blocking
   └─ Inside CIDR Blocking (192.168.0.0/16)
   ```

## Color Scheme

### Primary Colors
- **Cloud WAN Core**: #FF9900 (AWS Orange)
- **Segments**: #3F8624 (Dark Green)
- **Inspection**: #D13212 (Red)
- **Shared Services**: #527FFF (Blue)
- **Workloads**: #7AA116 (Light Green)
- **SD-WAN/Hybrid**: #FF9900 (Orange)

### Text Colors
- **Headers**: #232F3E (AWS Dark Blue)
- **Body Text**: #000000 (Black)
- **Labels**: #545B64 (Gray)

## Layout Tips

1. **Use Containers**: Group related VPCs in regional containers
2. **Align Elements**: Keep VPCs of the same type aligned horizontally
3. **Consistent Spacing**: Maintain equal spacing between regions
4. **Layer Order**: 
   - Background: Regional containers
   - Middle: VPC boxes
   - Foreground: Connection lines and labels

## Legend (Add to bottom-right)

```
┌─────────────────────────────┐
│         LEGEND              │
├─────────────────────────────┤
│ ──────>  Direct Connection  │
│ ┄┄┄┄┄>  Traffic Flow       │
│ ═════>  BGP Peering        │
│                             │
│ Colors:                     │
│ ■ Orange - Cloud WAN/SD-WAN│
│ ■ Green  - Segments         │
│ ■ Red    - Inspection       │
│ ■ Blue   - Shared Services  │
│ ■ Lt.Green - Workloads      │
└─────────────────────────────┘
```

## Step-by-Step Drawing Instructions

1. **Start with Cloud WAN Core** (center)
   - Draw large rounded rectangle
   - Add title "AWS Cloud WAN"
   - Add 5 segment boxes inside

2. **Add Inspection NFG** (inside Cloud WAN)
   - Draw hexagon
   - Position near NVA segment

3. **Draw Regional Containers** (right side)
   - 4 large rectangles
   - Label with region names

4. **Add VPCs to each region**
   - Follow the structure above
   - Use consistent colors

5. **Draw SD-WAN section** (left side)
   - Rounded rectangle
   - Add details

6. **Connect SD-WAN to Cloud WAN**
   - Thick solid line
   - Label "BGP Peering"

7. **Connect VPCs to Segments**
   - Solid lines from VPCs to Cloud WAN segments
   - Group by segment type

8. **Add Inspection Flow**
   - Dashed lines from segments to NFG
   - Dashed lines from NFG to NFG VPCs
   - Dashed lines from NFG VPCs to NFW VPCs

9. **Add Segment Sharing**
   - Dashed lines from segments to Shared Services

10. **Add Labels and Annotations**
    - Connection labels
    - Feature descriptions
    - Routing policies box

11. **Add Legend**
    - Bottom-right corner
    - Include all connection types and colors

## Export Settings

- **Format**: PNG
- **Resolution**: 300 DPI
- **Size**: 1920x1080 or larger
- **Background**: White
- **Border**: 20px padding

## Alternative: Use AWS Architecture Icons

Download AWS Architecture Icons from:
https://aws.amazon.com/architecture/icons/

Use official icons for:
- Cloud WAN
- VPC
- EC2 (for SD-WAN instance)
- Network Firewall
- Gateway Load Balancer
- Route 53
- VPC Endpoints
