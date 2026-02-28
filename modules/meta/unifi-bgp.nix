{ config, lib, ... }:
let
  environments = config.flake.environments;

  # Unifi router ASN
  unifiAsn = 65999;

  # Helper to calculate .1 address from CIDR
  # For now, we'll use the gatewayIp from the environment directly
  getManagementGateway = env: env.gatewayIp;

  # Generate neighbor peer-group assignment for each bgp-hub host
  generateNeighborPeerGroup =
    hostname: host:
    let
      neighborIp = builtins.head host.ipv4;
    in
    ''
      neighbor ${neighborIp} peer-group bgp-hubs
      neighbor ${neighborIp} description ${hostname}
    '';

  # Generate FRR BGP configuration for a specific environment
  generateFrrConfig =
    envName: env:
    let
      # Filter bgp-hub hosts for this environment
      envBgpHubHosts = lib.filterAttrs (
        name: host: lib.elem "bgp-hub" (host.roles or [ ]) && host.environment == envName
      ) config.flake.hosts;

      routerId = getManagementGateway env;

      # Get unique ASNs from bgp-hub hosts (assuming they all use the same ASN for the peer-group)
      hubAsn =
        if envBgpHubHosts != { } then
          let
            firstHost = builtins.head (builtins.attrValues envBgpHubHosts);
          in
          if (firstHost.tags or { }) ? "bgp-asn" then lib.toInt firstHost.tags."bgp-asn" else 65000
        else
          65000;
    in
    ''
      ! -*- bgp -*-
      !
      ! FRR BGP Configuration for Unifi Router
      ! Environment: ${envName}
      ! Management Network: ${env.networks.management.cidr}
      ! Generated: ${lib.trivial.release}
      !
      frr defaults traditional
      !
      hostname edge-${envName}
      password zebra
      !
      router bgp ${toString unifiAsn}
       bgp router-id ${routerId}
       no bgp ebgp-requires-policy
       bgp bestpath as-path multipath-relax
       maximum-paths 8
       !
       ! Peer group for BGP hub hosts
       neighbor bgp-hubs peer-group
       neighbor bgp-hubs remote-as ${toString hubAsn}
       neighbor bgp-hubs soft-reconfiguration inbound
       !
       ! Hub host neighbors
       ${lib.concatStringsSep "\n " (lib.mapAttrsToList generateNeighborPeerGroup envBgpHubHosts)}
       !
       address-family ipv4 unicast
        neighbor bgp-hubs activate
       exit-address-family
      !
      line vty
      !
    '';

in
{
  perSystem =
    { pkgs, ... }:
    {
      files.files = lib.mapAttrsToList (envName: env: {
        path_ = "docs/unifi-frr-bgp-${envName}.conf";
        drv = pkgs.writeText "unifi-frr-bgp-${envName}.conf" (generateFrrConfig envName env);
      }) environments;
    };
}
