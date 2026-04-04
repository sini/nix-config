# MicroVM: lightweight virtual machine host using microvm.nix.
{
  den,
  lib,
  inputs,
  ...
}:
{
  den.aspects.microvm = {
    includes = lib.attrValues den.aspects.microvm._;

    _ = {
      config = den.lib.perHost {
        nixos = {
          imports = [ inputs.microvm.nixosModules.host ];

          microvm.host.enable = true;

          users.users = {
            # allow microvm access to zvol
            microvm.extraGroups = [ "disk" ];
          };
        };
      };

      firewall = den.lib.perHost {
        nixos = {
          # Allow inbound traffic for the DHCP server
          networking.firewall.allowedUDPPorts = [ 67 ];
        };
      };

      persist = den.lib.perHost {
        nixos = _: {
          environment.persistence."/persist".directories = [
            {
              directory = "/var/lib/microvms";
              user = "microvm";
              group = "kvm";
              mode = "0775";
            }
          ];
        };
      };
    };
  };
}
