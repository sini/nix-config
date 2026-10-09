# cortex-cuda's ninfer port admits exactly its consumers (the hosts using
# ninfer-endpoints: an address, or the dev network for a host with none) and
# the axon cluster's nodes, and is not opened to any source; the gateway
# admits exactly the axon nodes across prod->dev, and declares no route:
#   nix build .#checks.x86_64-linux.ninfer-firewall
#   nix build .#checks.x86_64-linux.ninfer-gateway-policy
{ config, lib, ... }:
let
  inherit (config.flake) nixosConfigurations;
in
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    lib.optionalAttrs (system == "x86_64-linux") {
      checks.ninfer-firewall =
        let
          fw = nixosConfigurations.cortex.config.microvm.vms.cortex-cuda.config.config.networking.firewall;
          rules = builtins.filter (lib.hasInfix "dport 8081") (lib.splitString "\n" fw.extraInputRules);
          want = [
            ''ip saddr 10.10.10.2 tcp dport 8081 accept comment "ninfer: axon-01"''
            ''ip saddr 10.10.10.3 tcp dport 8081 accept comment "ninfer: axon-02"''
            ''ip saddr 10.10.10.4 tcp dport 8081 accept comment "ninfer: axon-03"''
            ''ip saddr 10.9.0.0/16 tcp dport 8081 accept comment "ninfer: blade patch slab"''
            ''ip saddr 10.9.1.1 tcp dport 8081 accept comment "ninfer: bitstream"''
            ''ip saddr 10.9.2.1 tcp dport 8081 accept comment "ninfer: cortex"''
          ];
          ok = rules == want && !(builtins.elem 8081 fw.allowedTCPPorts);
        in
        assert lib.assertMsg ok
          "ninfer-firewall:\n${lib.concatStringsSep "\n" rules}\nallowedTCPPorts: ${builtins.toJSON fw.allowedTCPPorts}";
        pkgs.writeText "ninfer-firewall" (lib.concatStringsSep "\n" rules);

      checks.ninfer-gateway-policy =
        let
          tf = config.terranix.terranixConfigurations.unifi.result.terraformConfiguration.config;
          policies = tf.resource.unifi_firewall_policy or { };
          p = policies.ninfer_to_cortex_cuda_from_prod or null;
          ok =
            !(tf.resource ? unifi_static_route)
            && builtins.attrNames policies == [ "ninfer_to_cortex_cuda_from_prod" ]
            && p.action == "ALLOW"
            && p.protocol == "tcp"
            && p.source.matching_target == "IP"
            &&
              p.source.ips == [
                "10.10.10.2"
                "10.10.10.3"
                "10.10.10.4"
              ]
            && p.destination.ips == [ "10.9.2.2" ]
            && p.destination.port == "8081"
            && p.destination.port_matching_type == "SPECIFIC";
        in
        assert lib.assertMsg ok "ninfer-gateway-policy:\n${builtins.toJSON policies}";
        pkgs.writeText "ninfer-gateway-policy" (builtins.toJSON policies);
    };
}
