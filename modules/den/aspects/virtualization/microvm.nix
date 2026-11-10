{
  inputs,
  lib,
  den,
  ...
}:
{
  den.aspects.virtualization.microvm-host = {
    # docs/microvm-persistent-store.md §2.10
    settings = {
      zvolParent = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "ZFS dataset under which guests' state zvols live (created if absent). null: zroot/local/microvms on a disk.zfs-disk-single host, none elsewhere.";
      };
      destroyStateZvols = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Full names of leaked state zvols to destroy. The sweep destroys one only if its name matches no configured guest under any backend and nothing holds it open.";
      };
    };

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
        options.microvm.scratchVolumes = lib.mkOption {
          type = lib.types.attrsOf lib.types.ints.positive;
          default = { };
          example = {
            "/tmp" = 131072;
          };
          description = ''
            Guest mount point -> size in MiB of a scratch disk, recreated empty at every
            VM start: a sparse ext4 image on the host's /cache volume
            (/cache/microvms/<guest>-<mountpoint>.img), so large scratch data lives on
            disk, not in the guest's tmpfs root.
          '';
        };
        options.microvm.vsockCid = lib.mkOption {
          type = lib.types.nullOr (lib.types.ints.between 3 4294967294);
          default = null;
          description = "AF_VSOCK CID of this guest (unique on its host); emitted as microvm.vsock.cid.";
        };
        # docs/microvm-persistent-store.md
        options.microvm.persistentStore = {
          enable = lib.mkEnableOption "a persistent local-overlay Nix store over the host's shared store";
          size = lib.mkOption {
            type = lib.types.ints.positive;
            default = 262144;
            description = ''
              Ceiling in MiB of the store volume (sparse ext4 on the host's /cache). Raising it
              grows the image at the next guest start; it never shrinks, so lowering it needs an
              `epoch` bump.
            '';
          };
          epoch = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 0;
            description = "Bump to discard the volume and start empty (recovery from a corrupt image).";
          };
          maxExportPaths = lib.mkOption {
            type = lib.types.ints.positive;
            default = 100000;
            description = "Most host paths the guest may pin; a larger export is refused whole.";
          };
        };
        # docs/microvm-persistent-store.md §2.10
        options.microvm.stateBackend = lib.mkOption {
          type = lib.types.enum [
            "virtiofs"
            "zvol"
          ];
          default = "virtiofs";
          description = ''
            How the guest's /persist and /cache reach it: host directories over virtiofs, or a
            ZFS zvol per volume, mounted as ext4 in the guest. Switching to zvol migrates the
            state at the next guest start, one-way: setting virtiofs again afterwards refuses
            to start the guest.
          '';
        };
        options.microvm.stateVolumeSizes = lib.mkOption {
          type = lib.types.attrsOf lib.types.ints.positive;
          default = {
            "/persist" = 262144;
            "/cache" = 131072;
          };
          description = "zvol size in MiB per state volume (stateBackend = zvol), sparse. Grow-only; a grow applies at the next guest start, and a smaller value fails that start.";
        };
        options.microvm.dropPreZvolBackup = lib.mkEnableOption "deleting this guest's pre-zvol backup of its old state directories";
      }
    )
  ];
}
