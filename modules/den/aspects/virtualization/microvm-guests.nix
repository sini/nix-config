{ den, lib, ... }:
let
  roStoreShare = {
    source = "/nix/store";
    mountPoint = "/nix/.ro-store";
    tag = "ro-store";
    proto = "virtiofs";
  };

  # The microvm.nix `microvm.vms.<name>` submodule does NOT accept a top-level
  # `imports` key — its option set is closed (pkgs/config/autostart/...). So the
  # resolved "microvm" class module (which sets host-side submodule options such
  # as `pkgs`) is evaluated here into a flat attrset of those options, which the
  # consumer can splice directly into the submodule definition.
  microvmSubmoduleOpts =
    mod:
    (lib.evalModules {
      modules = [
        mod
        { freeformType = lib.types.attrsOf lib.types.raw; }
      ];
    }).config;

  # M1: SSH keys for VM root access — collected from the den user registry
  # (wheel/admin members). Read from `den` here, where the registry lives;
  # the class-module `config` arg is the guest's NixOS config, not den's.
  rootKeys = lib.concatMap (
    u:
    lib.optionals (builtins.any (g: g == "admins" || g == "wheel") (u.groups or [ ])) (
      map (k: k.key) (u.identity.sshKeys or [ ])
    )
  ) (lib.attrValues (den.users.registry or { }));
in
{
  # PRODUCE: host-parametric, eager. Resolve each guest to module data.
  den.aspects.virtualization.microvm.microvm-guests =
    { host, ... }:
    map (vm: {
      inherit (vm) name;
      osModules = den.lib.aspects.resolve vm.class (den.lib.resolveEntity "host" { host = vm; });
      microvmOpts = microvmSubmoduleOpts (den.lib.aspects.resolve "microvm" vm.aspect);
      passthrough = vm.microvm.passthrough or [ ];
      sharedNixStore = host.microvm.sharedNixStore;
    }) host.microvm.guests;

  # CONSUME: turn each resolved guest into a microvm.vms.<name> definition.
  den.aspects.virtualization.microvm.nixos =
    { microvm-guests, ... }:
    {
      microvm.vms = lib.listToAttrs (
        map (
          g:
          lib.nameValuePair g.name (
            # Host-side submodule options (e.g. CUDA pkgs) from the microvm class…
            g.microvmOpts
            // {
              # …and the guest's full NixOS toplevel from its host pipeline.
              config = {
                imports = [
                  g.osModules
                  {
                    microvm.devices = [ ]; # Task 3 fills this
                    microvm.shares = lib.optional g.sharedNixStore roStoreShare;
                    users.users.root.openssh.authorizedKeys.keys = rootKeys;
                  }
                ];
              };
            }
          )
        ) microvm-guests
      );
    };
}
