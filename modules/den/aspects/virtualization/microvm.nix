{ inputs, ... }:
{
  den.aspects.virtualization.microvm = {
    nixos =
      { ... }:
      {
        imports = [ inputs.microvm.nixosModules.host ];

        microvm.host.enable = true;

        users.users.microvm.extraGroups = [ "disk" ];
      };

    firewall = {
      networking.firewall.allowedUDPPorts = [ 67 ];
    };

    persist.directories = [
      {
        directory = "/var/lib/microvms";
        user = "microvm";
        group = "kvm";
        mode = "0775";
      }
    ];
  };
}
