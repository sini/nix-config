# cortex-cuda's ninfer port admits exactly its consumers (the hosts using
# ninfer-endpoints: an address, or the dev network for a host with none) and
# the axon cluster's nodes, on the nftables backend, and is not opened to any
# source; the gateway
# admits exactly the axon nodes across prod->dev (a LAN_IN rule on an address
# group), and declares no route:
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
          net = nixosConfigurations.cortex.config.microvm.vms.cortex-cuda.config.config.networking;
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
          rules = tf.resource.unifi_firewall_rule or { };
          groups = tf.resource.unifi_firewall_group or { };
          name = "ninfer_to_cortex_cuda_from_prod";
          ok =
            !(tf.resource ? unifi_static_route)
            && !(tf.resource ? unifi_firewall_policy)
            && builtins.attrNames rules == [ name ]
            && builtins.attrNames groups == [ name ]
            &&
              rules.${name} == {
                name = "ninfer-to-cortex-cuda from prod";
                ruleset = "LAN_IN";
                action = "accept";
                enabled = true;
                protocol = "tcp";
                dst_address = "10.9.2.2";
                dst_port = "8081";
                rule_index = 20501;
                src_firewall_group_ids = [ "\${unifi_firewall_group.${name}.id}" ];
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
