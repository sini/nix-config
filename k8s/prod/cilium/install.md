# Cilium Installation Guide

## Prerequisites

1. Ensure all axon nodes are deployed with the `thunderbolt-mesh` module enabled
1. Verify BGP peering is working between nodes:
   ```bash
   # On each node, check BGP neighbors
   sudo vtysh -c "show bgp neighbors"
   sudo vtysh -c "show bgp ipv4 unicast summary"
   ```

## Installation

Install Cilium with the optimized configuration:

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

# Install or upgrade Cilium
helm upgrade --install cilium cilium/cilium \
  --version 1.18.1 \
  --namespace kube-system \
  --values values.yaml \
  --wait
```

## Apply BGP Policies

After Cilium is installed, apply the BGP configuration:

```bash
kubectl apply -f cilium-bgp-policy.yaml
```

## Verification

1. **Check Cilium status:**

   ```bash
   kubectl get pods -n kube-system -l k8s-app=cilium
   cilium status
   ```

1. **Verify BGP peering:**

   ```bash
   # Check Cilium BGP status
   cilium bgp peers
   cilium bgp routes

   # Check if Cilium is peering with local FRR
   kubectl logs -n kube-system -l k8s-app=cilium | grep -i bgp
   ```

1. **Test LoadBalancer services:**

   ```bash
   # Create a test service
   kubectl create deployment test-app --image=nginx
   kubectl expose deployment test-app --type=LoadBalancer --port=80

   # Verify LoadBalancer IP is assigned from the pool
   kubectl get svc test-app

   # Check BGP advertisement
   cilium bgp routes advertised
   ```

1. **Verify routes in FRR:**

   ```bash
   # On each node, check if Kubernetes routes are being learned
   sudo vtysh -c "show bgp ipv4 unicast"
   sudo vtysh -c "show ip route"
   ```

## Architecture

The configuration creates this BGP architecture:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     axon-01     │    │     axon-02     │    │     axon-03     │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   Cilium    │ │    │ │   Cilium    │ │    │ │   Cilium    │ │
│ │  (AS 65001) │ │    │ │  (AS 65002) │ │    │ │  (AS 65003) │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│       │ iBGP    │    │       │ iBGP    │    │       │ iBGP    │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │     FRR     │◄┼────┼─┤     FRR     │◄┼────┼─┤     FRR     │ │
│ │  (AS 65001) │ │eBGP│ │  (AS 65002) │ │eBGP│ │  (AS 65003) │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
    172.16.255.1          172.16.255.2          172.16.255.3
```

- **FRR Layer**: Handles inter-node routing via thunderbolt mesh (eBGP)
- **Cilium Layer**: Handles Kubernetes service/pod advertisement (iBGP with local FRR)
- **Traffic Flow**: K8s services → Cilium BGP → FRR → Thunderbolt mesh → Remote FRR → Remote Cilium BGP → Remote pods

## Troubleshooting

1. **BGP Peering Issues:**

   ```bash
   # Check if dummy0 interface is up
   ip addr show dummy0

   # Verify FRR is listening on loopback
   sudo netstat -ln | grep 179

   # Check Cilium BGP logs
   kubectl logs -n kube-system -l k8s-app=cilium | grep -i "bgp\|neighbor"
   ```

1. **Route Advertisement Issues:**

   ```bash
   # Check if routes are being advertised
   cilium bgp routes advertised

   # Verify LoadBalancer IP pool
   kubectl get ciliumloadbalancerippool

   # Check service selector matching
   kubectl get svc --show-labels
   ```

1. **Service Connectivity Issues:**

   ```bash
   # Test connectivity to LoadBalancer service
   curl -v <loadbalancer-ip>

   # Check if routes are installed in kernel
   ip route show table main | grep <service-cidr>
   ```
