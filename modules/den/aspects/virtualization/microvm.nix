{
  inputs,
  lib,
  den,
  ...
}:
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

  den.classes.microvm.description = "MicroVM guest configuration (microvm.nix options)";

  den.schema.host.imports = [
    (
      { ... }:
      {
        # Guest MicroVMs are delivered via the guests policy
        # (den.hosts.<sys>.<parent>.guests.<name>; see
        # virtualization/guests.nix), not a `microvm.guests` list. These options
        # document the per-guest entity contract read by the host-side GPU
        # overlay (microvm-guests.nix).
        options.microvm.passthrough = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Device-class passthrough intents for this (guest) host, e.g. [ \"nvidia\" ].";
        };
        options.microvm.sharedNixStore = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Auto-share the host nix store into guests over virtiofs.";
        };
      }
    )
  ];
}
