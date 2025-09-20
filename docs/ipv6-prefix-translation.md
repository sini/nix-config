# IPv6 Prefix Translation (NPTv6) Implementation Plan

## Overview

This document outlines a plan to implement IPv6 Network Prefix Translation (NPTv6) to provide static internal IPv6 addressing while utilizing the dynamic /56 IPv6 prefix delegated by the ISP.

## Current State

- **Current IPv6**: `2001:5a8:608c:4a00::/64` (static/hardcoded)
- **ISP Assignment**: Dynamic /56 prefix delegation
- **Problem**: Need stable internal addressing with dynamic external prefix

## Proposed Architecture

### IPv6 Addressing Scheme

**Internal ULA (Unique Local Address) Range**:

- Base prefix: `fd64::/48`
- Network allocation:
  - `fd64:0:1::/64` - Management network (infrastructure hosts)
  - `fd64:0:2::/64` - Kubernetes pods
  - `fd64:0:3::/64` - Kubernetes services
  - `fd64:0:4::/64` - Future expansion

**Host Assignments (Internal ULA)**:

```
uplink:    fd64:0:1::1/64
axon-01:   fd64:0:1::2/64
axon-02:   fd64:0:1::3/64
axon-03:   fd64:0:1::4/64
cortex:    fd64:0:1::5/64
```

**External ISP Prefix**:

- Dynamic /56 prefix from ISP
- Example: `2001:db8:abcd::/56`
- Carved into /64 subnets as needed

### NPTv6 Translation

**Translation Rules**:

- Internal `fd64:0:1::/64` ↔ External `<ISP-PREFIX>::/64`
- 1:1 stateless mapping preserves host identifiers
- Bidirectional translation for inbound/outbound traffic

**Example Translation**:

```
Internal Host:    fd64:0:1::1      → External: 2001:db8:abcd::1
Internal Service: fd64:0:1::100    → External: 2001:db8:abcd::100
```

## Implementation Details

### Phase 1: Static ULA Configuration

1. **Update Host Configurations**:
   - Change all hosts from current IPv6 to ULA addresses
   - Update DNS records for internal services
   - Test internal connectivity

1. **Files to Modify**:

   ```
   modules/hosts/uplink/host.nix      → fd64:0:1::1/64
   modules/hosts/axon-01/host.nix     → fd64:0:1::2/64
   modules/hosts/axon-02/host.nix     → fd64:0:1::3/64
   modules/hosts/axon-03/host.nix     → fd64:0:1::4/64
   modules/hosts/cortex/host.nix      → fd64:0:1::5/64
   ```

1. **Environment Configuration**:
   - Add ULA prefix definitions to environment.nix
   - Define translation mapping configuration

### Phase 2: Dynamic Prefix Detection

1. **ISP Prefix Detection Service**:

   ```nix
   systemd.services.ipv6-prefix-detector = {
     description = "Detect ISP IPv6 prefix delegation";
     script = ''
       # Monitor DHCPv6 PD or Router Advertisement
       # Extract dynamic /56 prefix
       # Update NPTv6 translation rules
     '';
   };
   ```

1. **Prefix Storage**:
   - Store detected prefix in `/var/lib/ipv6-prefix`
   - Trigger NPTv6 rule updates on change

### Phase 3: NPTv6 Translation Rules

1. **Translation Implementation**:

   ```bash
   # Outbound: Internal ULA → External ISP prefix
   ip6tables -t mangle -A POSTROUTING -s fd64:0:1::/64 \
     -j NETMAP --to ${ISP_PREFIX}::/64

   # Inbound: External ISP prefix → Internal ULA
   ip6tables -t mangle -A PREROUTING -d ${ISP_PREFIX}::/64 \
     -j NETMAP --to fd64:0:1::/64
   ```

1. **NixOS Service Configuration**:

   ```nix
   systemd.services.nptv6-translation = {
     description = "IPv6 Network Prefix Translation";
     after = [ "network.target" "ipv6-prefix-detector.service" ];
     # Apply translation rules based on detected prefix
   };
   ```

### Phase 4: DNS and Service Updates

1. **DNS Records**:
   - Internal DNS: Use ULA addresses
   - External DNS: Use translated external addresses
   - AAAA records point to translated addresses

1. **Service Bindings**:
   - Services bind to ULA addresses internally
   - External access via translated addresses
   - No service configuration changes needed

## Benefits

1. **Static Internal Addressing**:
   - Consistent internal IPv6 addresses
   - No configuration changes when ISP prefix changes
   - Simplified internal service discovery

1. **Dynamic External Adaptation**:
   - Automatic adaptation to ISP prefix changes
   - No manual reconfiguration required
   - Maintains external connectivity

1. **Service Isolation**:
   - Internal services not directly exposed
   - Control external accessibility per service
   - Enhanced security posture

## Risk Assessment

**Low Risk**:

- ULA addresses are standardized (RFC 4193)
- NPTv6 is well-supported in Linux netfilter
- Stateless translation preserves connection state

**Medium Risk**:

- Requires careful rule ordering in iptables
- ISP prefix detection needs robust implementation
- DNS propagation during prefix changes

**Mitigation**:

- Thorough testing in dev environment first
- Rollback plan to current configuration
- Monitoring for translation failures

## Testing Plan

1. **Phase 1 Testing**:
   - Deploy ULA addresses to dev environment
   - Verify internal connectivity
   - Test service-to-service communication

1. **Phase 2 Testing**:
   - Test prefix detection with ISP changes
   - Verify automatic rule updates
   - Monitor for detection failures

1. **Phase 3 Testing**:
   - Test NPTv6 translation rules
   - Verify bidirectional connectivity
   - Test with various protocols and services

1. **Production Deployment**:
   - Deploy during maintenance window
   - Monitor external service accessibility
   - Verify translation performance

## Implementation Timeline

- **Week 1**: Phase 1 - ULA configuration and testing
- **Week 2**: Phase 2 - Prefix detection implementation
- **Week 3**: Phase 3 - NPTv6 translation rules
- **Week 4**: Phase 4 - DNS updates and production deployment

## Rollback Plan

If issues arise:

1. Revert host configurations to current IPv6 addresses
1. Disable NPTv6 translation service
1. Restore original DNS records
1. Verify service restoration

---

_This plan provides a structured approach to implementing NPTv6 while maintaining service availability and enabling rollback if needed._
