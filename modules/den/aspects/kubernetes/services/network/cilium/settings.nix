# Settings for the cilium aspect. Auto-discovered onto the cluster the aspect
# runs in as `cluster.settings.kubernetes.services.network.cilium.*` (the
# cluster mirror of host.settings); set per-cluster via
# `den.clusters.<name>.settings.kubernetes.services.network.cilium.<key>`.
{ lib, ... }:
{
  den.aspects.kubernetes.services.network.cilium.settings.devices = lib.mkOption {
    type = lib.types.str;
    default = "";
    example = "enp+";
    description = ''
      Value for Cilium's `devices` helm value (the agent's `--devices` flag):
      the set of native devices Cilium attaches its datapath to and masquerades
      on. Empty (the default) leaves Cilium's auto-detection in place.

      Auto-detection picks every device with a global address and a route,
      which on the axon nodes wrongly pulls in `tailscale0` (the admin tailnet)
      alongside the real NICs — putting pod-egress masquerade and a
      device-state watch on an interface that flaps with tailscale's peer/DERP
      churn. Pinning this to the physical-NIC wildcard `enp+` matches the WAN
      NIC (enp2s0) and both thunderbolt-fabric NICs (enp199s0f5/f6) on every
      node while excluding tailscale0, cilium_host and lxc* veths.

      This maps to the cluster's network architecture: world ingress/egress +
      masquerade ride enp2s0; inter-node pod (geneve) rides the thunderbolt
      fabric via OpenFabric routing; tailscale stays out of the data plane.
    '';
  };
}
