# Cilium Installation Guide - Dev Environment

## Prerequisites

1. Ensure bitstream node is deployed with the `kubernetes` role enabled
1. Verify the node is healthy and FRR is running:
   ```bash
   # On bitstream, check system status
   sudo systemctl status frr
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
   # Check Cilium BGP peer status
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

1. **Verify routes in FRR (if BGP is configured):**

   ```bash
   # On bitstream, check if Kubernetes routes are being learned
   sudo vtysh -c "show bgp ipv4 unicast"
   sudo vtysh -c "show ip route"
   ```

## Architecture

The dev configuration creates this simple architecture:

```
┌─────────────────┐
│    bitstream    │
│                 │
│ ┌─────────────┐ │
│ │   Cilium    │ │
│ │  (AS 65001) │ │
│ └─────────────┘ │
│       │ iBGP    │
│ ┌─────────────┐ │
│ │     FRR     │ │
│ │  (AS 65001) │ │
│ └─────────────┘ │
└─────────────────┘
   10.10.10.5
```

- **Single Node**: bitstream runs both Cilium and FRR
- **iBGP**: Cilium and FRR use the same ASN for local peering
- **Traffic Flow**: K8s services → Cilium BGP → FRR → External network

## Troubleshooting

1. **BGP Peering Issues:**

   ```bash
   # Check if bond0 interface is up and configured
   ip addr show bond0

   # Verify FRR is listening on BGP port
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
