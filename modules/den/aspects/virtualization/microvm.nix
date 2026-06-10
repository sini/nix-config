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
        options.microvm.guests = lib.mkOption {
          type = lib.types.listOf lib.types.raw;
          default = [ ];
          defaultText = lib.literalExpression "[ ]";
          description = "Guest MicroVMs to run on this host. List of den hosts, e.g. [ den.hosts.x86_64-linux.cortex-cuda ].";
        };
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
