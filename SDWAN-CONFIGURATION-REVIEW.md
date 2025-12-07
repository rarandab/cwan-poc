# Cloud WAN Connect Tunnel-Less Configuration Review

## Overview
This document provides a comprehensive review of the SDWAN Connect Tunnel-Less configuration for announcing BGP routes to AWS Cloud WAN using FRRouting.

## Configuration Summary

### 1. **Variable Configuration** (`variables.tf`)
```hcl
variable "sdwan" {
  description = "Cloud WAN Connect Tunnel-Less configuration"
  type = object({
    regions = list(string)
    asn     = number
    cidrs   = optional(list(string), [])
  })
  default = null
}
```

### 2. **Terraform Configuration** (`terraform.tfvars`)
```hcl
sdwan = {
  regions = ["eu-central-1"]
  asn     = 64600
  cidrs   = ["172.16.0.0/16", "172.18.0.0/16", "172.20.0.0/16"]
}
```

## Key Components Added to `sdwan-frr-userdata.sh.tftpl`

### 1. **System Configuration**
- ✅ Proper FRRouting installation from official repository
- ✅ IP forwarding enabled
- ✅ Reverse path filtering disabled (required for BGP routing)
- ✅ Security hardening (disable redirects, source routing)

### 2. **Zebra Configuration** (Routing Daemon)
```bash
# Static routes to Null0 for networks we want to announce
# This makes the routes "exist" in the routing table so BGP can advertise them
ip route 172.16.0.0/16 Null0 254
ip route 172.18.0.0/16 Null0 254
ip route 172.20.0.0/16 Null0 254
```

**Why Null0 routes?**
- BGP can only advertise routes that exist in the routing table
- Null0 routes create "blackhole" routes with low administrative distance (254)
- These routes tell BGP "I can reach these networks" without actually forwarding traffic
- Real traffic will use more specific routes learned from Cloud WAN or local networks

### 3. **BGP Configuration** (Border Gateway Protocol)
```bash
router bgp 64600
 bgp router-id <instance_ip>
 bgp log-neighbor-changes
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 
 # Cloud WAN Peer Group
 neighbor CLOUDWAN peer-group
 neighbor <peer_ip1> peer-group CLOUDWAN
 neighbor <peer_ip2> peer-group CLOUDWAN
 neighbor CLOUDWAN remote-as <cloud_wan_asn>
 neighbor CLOUDWAN ebgp-multihop 255
 neighbor CLOUDWAN timers 10 30
 
 address-family ipv4 unicast
  # Announce the CIDRs to Cloud WAN
  network 172.16.0.0/16
  network 172.18.0.0/16
  network 172.20.0.0/16
  
  neighbor CLOUDWAN activate
  neighbor CLOUDWAN soft-reconfiguration inbound
 exit-address-family
```

### 4. **Verification and Logging**
- ✅ Configuration summary logged to `/var/log/frr-setup.log`
- ✅ BGP status check after startup
- ✅ Routing table verification

## How BGP Route Announcement Works

### Step-by-Step Process:

1. **Static Routes Created**
   ```
   ip route 172.16.0.0/16 Null0 254
   ```
   - Creates a route in the kernel routing table
   - Administrative distance 254 (very low priority)
   - Points to Null0 (blackhole interface)

2. **BGP Network Statements**
   ```
   network 172.16.0.0/16
   ```
   - Tells BGP to advertise this network
   - BGP checks if the route exists in the routing table
   - If route exists, BGP advertises it to peers

3. **BGP Peering with Cloud WAN**
   ```
   neighbor <cloud_wan_ip> remote-as <cloud_wan_asn>
   ```
   - Establishes BGP session with Cloud WAN
   - Exchanges routing information
   - Cloud WAN learns about 172.16.0.0/16, 172.18.0.0/16, 172.20.0.0/16

4. **Route Propagation**
   - Cloud WAN receives the BGP advertisements
   - Cloud WAN propagates routes to other segments (based on policy)
   - Other VPCs/networks in Cloud WAN can now route to these CIDRs via this instance

## Architecture Benefits

### Connect Tunnel-Less Advantages:
1. **No GRE Tunnels** - Simpler configuration, no tunnel overhead
2. **Direct BGP** - BGP runs directly on the VPC subnet
3. **Automatic Failover** - Two BGP peers for redundancy
4. **Dynamic Routing** - Routes learned dynamically via BGP
5. **Scalable** - Easy to add/remove announced networks

### FRRouting Benefits:
1. **Free and Open Source** - No licensing costs
2. **Industry Standard** - Uses standard BGP (RFC 4271)
3. **Well Documented** - Extensive community support
4. **Feature Rich** - Supports advanced BGP features
5. **Production Ready** - Used by major ISPs and cloud providers

## Verification Commands

### On the Instance (via SSM or SSH):
```bash
# Check BGP summary
sudo vtysh -c "show ip bgp summary"

# Check advertised routes
sudo vtysh -c "show ip bgp neighbors <cloud_wan_ip> advertised-routes"

# Check received routes
sudo vtysh -c "show ip bgp neighbors <cloud_wan_ip> routes"

# Check routing table
sudo vtysh -c "show ip route"

# Check BGP configuration
sudo vtysh -c "show running-config"
```

### Expected Output:
```
BGP router identifier <instance_ip>, local AS number 64600
Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
<peer_ip1>      4 <asn>     123     120        0    0    0 00:15:23        5
<peer_ip2>      4 <asn>     123     120        0    0    0 00:15:23        5
```

## Troubleshooting

### Common Issues:

1. **BGP Session Not Establishing**
   - Check security group allows TCP/179
   - Verify peer IPs are correct
   - Check FRR logs: `tail -f /var/log/frr/bgpd.log`

2. **Routes Not Being Advertised**
   - Verify Null0 routes exist: `ip route show`
   - Check BGP network statements: `vtysh -c "show running-config"`
   - Verify routes in BGP table: `vtysh -c "show ip bgp"`

3. **Routes Not Propagating in Cloud WAN**
   - Check Cloud WAN policy allows route sharing
   - Verify segment associations
   - Check attachment routing policies

## Security Considerations

1. **BGP Authentication** - Consider adding MD5 authentication for production
2. **Route Filtering** - Implement prefix-lists to control what's advertised
3. **AS-Path Filtering** - Prevent route loops
4. **Security Groups** - Restrict BGP (TCP/179) to Cloud WAN IPs only

## Next Steps

1. **Monitor BGP Sessions** - Set up CloudWatch alarms for BGP state
2. **Add Route Filtering** - Implement prefix-lists for security
3. **Enable BFD** - Bidirectional Forwarding Detection for faster failover
4. **Add Logging** - Send FRR logs to CloudWatch Logs
5. **Implement Graceful Restart** - For maintenance windows

## References

- [FRRouting Documentation](https://docs.frrouting.org/)
- [AWS Cloud WAN Connect](https://docs.aws.amazon.com/network-manager/latest/cloudwan/cloudwan-connect-attachment.html)
- [BGP Best Practices](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html)
