# Axon k3s cluster — 3-node production cluster with dual-stack networking.
#
# Network topology:
#   control-plane   — management VLAN, carries kube-apiserver VIP
#   kubernetes-pods — CNI pod overlay (Cilium, dual-stack)
#   kubernetes-services — ClusterIP range (dual-stack), CoreDNS lives here
#   kubernetes-loadbalancers — external LB pool advertised via BGP
{ ... }:
{
  den.clusters.axon = {
    environment = "prod";
    role = "k3s";
    secretPath = ./. + "/../../../.secrets/clusters/axon";

    networks = {
      control-plane = {
        cidr = "10.10.10.0/24";
        description = "Cluster control plane (VIP on management network)";
        assignments = {
          kube-apiserver-vip = "10.10.10.100";
        };
      };

      kubernetes-pods = {
        cidr = "172.20.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:0001::/96";
        description = "Kubernetes pod network";
      };

      kubernetes-services = {
        cidr = "172.21.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:8001::/112";
        description = "Kubernetes service network";
        assignments = {
          coredns = "172.21.0.10";
        };
      };

      kubernetes-loadbalancers = {
        cidr = "10.11.0.0/16";
        description = "LoadBalancer service IP range";
        assignments = {
          cilium-ingress-controller = "10.11.0.2";
          default-gateway = "10.11.0.1";
        };
      };
    };
  };
}
