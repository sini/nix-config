{ den, ... }:
{
  den.aspects.virtualization.microvm = {
    nixos =
      { inputs, ... }:
      {
        imports = [ inputs.microvm.nixosModules.host ];

        microvm.host.enable = true;

        users.users.microvm.extraGroups = [ "disk" ];
      };

    provides.firewall.nixos = {
      networking.firewall.allowedUDPPorts = [ 67 ];
    };

    provides.impermanence = {
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
}
