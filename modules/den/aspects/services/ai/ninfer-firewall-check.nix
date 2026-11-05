# cortex-cuda's ninfer port admits exactly its consumers (the hosts using
# ninfer-endpoints: an address, or the dev network for a host with none) and
# the axon cluster's nodes, on the nftables backend, and is not opened to any
# source; the gateway
# admits exactly the axon nodes across prod->dev (an Internal -> Internal zone
# policy from an address group), and declares no route:
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
          guest = nixosConfigurations.cortex.config.microvm.vms.cortex-cuda.config.config;
          net = guest.networking;
          fw = net.firewall;
          rules = builtins.filter (lib.hasInfix "dport 8081") (lib.splitString "\n" fw.extraInputRules);
          want = [
            ''ip saddr 10.10.10.2 tcp dport 8081 accept comment "ninfer: axon-01"''
            ''ip saddr 10.10.10.3 tcp dport 8081 accept comment "ninfer: axon-02"''
            ''ip saddr 10.10.10.4 tcp dport 8081 accept comment "ninfer: axon-03"''
            ''ip saddr 10.9.0.0/16 tcp dport 8081 accept comment "ninfer: blade patch slab"''
            ''ip saddr 10.9.1.1 tcp dport 8081 accept comment "ninfer: bitstream"''
            ''ip saddr 10.9.2.1 tcp dport 8081 accept comment "ninfer: cortex"''
          ];
          # extraInputRules are nftables syntax; the iptables backend ignores them.
          ok = net.nftables.enable && rules == want && !(builtins.elem 8081 fw.allowedTCPPorts);
        in
        assert lib.assertMsg ok
          "ninfer-firewall:\nnftables.enable: ${lib.boolToString net.nftables.enable}\n${lib.concatStringsSep "\n" rules}\nallowedTCPPorts: ${builtins.toJSON fw.allowedTCPPorts}";
        pkgs.writeText "ninfer-firewall" (lib.concatStringsSep "\n" rules);

      checks.ninfer-gateway-policy =
        let
          tf = config.terranix.terranixConfigurations.unifi.result.terraformConfiguration.config;
          rules = tf.resource.unifi_firewall_policy or { };
          groups = tf.resource.unifi_firewall_group or { };
          name = "ninfer_to_cortex_cuda_from_prod";
          internal = "\${data.unifi_firewall_zone.unifi_zone_internal.id}";
          ok =
            !(tf.resource ? unifi_static_route)
            && !(tf.resource ? unifi_firewall_rule)
            && builtins.attrNames groups == [ name ]
            &&
              rules.${name} == {
                name = "ninfer-to-cortex-cuda from prod";
                action = "ALLOW";
                enabled = true;
                ip_version = "IPV4";
                protocol = "tcp";
                source = {
                  zone_id = internal;
                  matching_target = "IP";
                  ip_group_id = "\${unifi_firewall_group.${name}.id}";
                  port_matching_type = "ANY";
                };
                destination = {
                  zone_id = internal;
                  matching_target = "IP";
                  ips = [ "10.9.2.2" ];
                  port_matching_type = "SPECIFIC";
                  port = "8081";
                };
              }
            &&
              groups.${name} == {
                name = "ninfer-to-cortex-cuda from prod";
                type = "address-group";
                members = [
                  "10.10.10.2"
                  "10.10.10.3"
                  "10.10.10.4"
                ];
              };
          policies = { inherit rules groups; };
        in
        assert lib.assertMsg ok "ninfer-gateway-policy:\n${builtins.toJSON policies}";
        pkgs.writeText "ninfer-gateway-policy" (builtins.toJSON policies);
    };
}
