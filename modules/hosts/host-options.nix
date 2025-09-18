{
  lib,
  ...
}:
let
  inherit (lib) types mkOption;
in
{
  config.text.readme.parts.host-options =
    # markdown
    ''
      ## Host Options

      This repository defines a set of hosts in the `flake.hosts` attribute set.
      Each host is defined as a submodule with its own configuration options.
      The host configurations can be used to deploy NixOS configurations to remote
      machines using Colmena or for local development. These options are defined for
      every host and include:

      - `system`: The system architecture of the host (e.g., `x86_64-linux`).
      - `unstable`: Whether to use unstable packages for the host.
      - `ipv4`: The static IP addresses of this host in it's home vlan.
      - `roles`: A list of roles for the host, which can also be used to target deployment.
      - `public_key`: The path or value of the public SSH key for the host used for encryption.
      - `facts`: The path to the Facter JSON file for the host, which is used to provide
        additional information about the host and for automated hardware configuration.
      - `extra_modules`: A list of additional modules to include for the host.
      - `tags`: An attribute set of string key-value pairs to annotate hosts with metadata.
        For example: `{ "kubernetes-cluster" = "prod"; "kubernetes-internal-ip" = "10.0.1.100"; }`
        Special tags:
        - `kubernetes-cluster`: Groups hosts into Kubernetes clusters
        - `kubernetes-internal-ip`: Override IP for Kubernetes internal communication (defaults to host ipv4)
        - `bgp-asn`: BGP AS number for this host (used by bgp-hub and thunderbolt-mesh modules)
        - `thunderbolt-loopback-ipv4`: Loopback IPv4 address for thunderbolt mesh BGP peering (e.g., "172.16.255.1/32")
        - `thunderbolt-loopback-ipv6`: Loopback IPv6 address for thunderbolt mesh BGP peering (e.g., "fdb4:5edb:1b00::1/128")
        - `thunderbolt-interface-1`: IPv4 address for first thunderbolt interface (e.g., "169.254.12.0/31")
        - `thunderbolt-interface-2`: IPv4 address for second thunderbolt interface (e.g., "169.254.31.1/31")
      - `exporters`: An attribute set defining Prometheus exporters exposed by this host.
        For example: `{ node = { port = 9100; }; k3s = { port = 10249; }; }`

    '';

  options.flake.hosts =
    let
      hostType = types.submodule {
        options = {
          system = mkOption {
            type = types.str;
            default = "x86_64-linux";
          };

          unstable = lib.mkOption {
            type = types.bool;
            default = true;
          };

          ipv4 = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "The static IP addresses of this host in it's home vlan.";
          };

          roles = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "List of roles for the host.";
          };

          public_key = mkOption {
            type = types.either types.path types.str;
            default = null;
            description = "Path to or string value of the public SSH key for the host.";
          };

          facts = mkOption {
            type = types.path;
            default = null;
            description = "Path to the Facter JSON file for the host.";
          };

          extra_modules = mkOption {
            type = types.listOf types.deferredModule;
            default = [ ];
            description = "List of additional modules to include for the host.";
          };

          tags = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              An attribute set of string key-value pairs to tag the host with metadata.
              Example: `{ "kubernetes-cluster" = "prod"; "kubernetes-internal-ip" = "10.0.1.100"; }`

              Special tags:
              - kubernetes-cluster: Groups hosts into Kubernetes clusters
              - kubernetes-internal-ip: Override IP for Kubernetes internal communication (defaults to host ipv4)
              - bgp-asn: BGP AS number for this host (used by bgp-hub and thunderbolt-mesh modules)
              - thunderbolt-loopback-ipv4: Loopback IPv4 address for thunderbolt mesh BGP peering (e.g., "172.16.255.1/32")
              - thunderbolt-loopback-ipv6: Loopback IPv6 address for thunderbolt mesh BGP peering (e.g., "fdb4:5edb:1b00::1/128")
              - thunderbolt-interface-1: IPv4 address for first thunderbolt interface (e.g., "169.254.12.0/31")
              - thunderbolt-interface-2: IPv4 address for second thunderbolt interface (e.g., "169.254.31.1/31")
            '';
          };

          environment = mkOption {
            type = types.str;
            default = "prod";
            description = "Environment name that this host belongs to (references flake.environments)";
          };

          exporters = mkOption {
            type = types.attrsOf (
              types.submodule {
                options = {
                  port = mkOption {
                    type = types.int;
                    description = "Port number for the exporter";
                  };
                  path = mkOption {
                    type = types.str;
                    default = "/metrics";
                    description = "HTTP path for metrics endpoint";
                  };
                  interval = mkOption {
                    type = types.str;
                    default = "30s";
                    description = "Scrape interval";
                  };
                };
              }
            );
            default = { };
            description = ''
              Prometheus exporters exposed by this host.
              Example: `{ node = { port = 9100; }; k3s = { port = 10249; }; }`
            '';
          };
        };
      };
    in
    mkOption {
      type = types.attrsOf hostType;
    };

  config.flake.modules.nixos.hosts = { };
}
