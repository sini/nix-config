{
  flake.features.microvm = {

    nixos =
      {
        inputs,
        ...
      }:
      {
        imports = [ inputs.microvm.nixosModules.host ];

        microvm.host.enable = true;

        # systemd.network = {
        #   enable = true;
        #   netdevs.virbr0.netdevConfig = {
        #     Kind = "bridge";
        #     Name = "virbr0";
        #   };
        #   networks.virbr0 = {
        #     matchConfig.Name = "virbr0";
        #     # Hand out IP addresses to MicroVMs.
        #     # Use `networkctl status virbr0` to see leases.
        #     networkConfig = {
        #       DHCPServer = true;
        #       IPv6SendRA = true;
        #     };
        #     addresses = [
        #       { addressConfig.Address = "10.0.0.1/24"; }
        #       { addressConfig.Address = "fd12:3456:789a::1/64"; }
        #     ];
        #     ipv6Prefixes = [ { ipv6PrefixConfig.Prefix = "fd12:3456:789a::/64"; } ];
        #   };
        #   networks.microvm-eth0 = {
        #     matchConfig.Name = "vm-*";
        #     networkConfig.Bridge = "virbr0";
        #   };
        # };

        # Allow inbound traffic for the DHCP server
        networking.firewall.allowedUDPPorts = [ 67 ];
        environment.persistence."/persist".directories = [
          {
            directory = "/var/lib/microvms";
            user = "microvm";
            group = "kvm";
            mode = "0775";
          }
        ];
        users.users = {
          # allow microvm access to zvol
          microvm.extraGroups = [ "disk" ];
        };
      };
  };
}
