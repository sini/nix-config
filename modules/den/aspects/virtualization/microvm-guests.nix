{ den, lib, ... }:
let
  gpuLib = import ./_gpu-passthrough-lib.nix { inherit lib; };

  roStoreShare = {
    source = "/nix/store";
    mountPoint = "/nix/.ro-store";
    tag = "ro-store";
    proto = "virtiofs";
  };

  # The microvm.nix `microvm.vms.<name>` submodule does NOT accept a top-level
  # `imports` key — its option set is closed (pkgs/config/autostart/...). So the
  # resolved "microvm" class module (which sets host-side submodule options such
  # as `pkgs`) is evaluated here into a flat attrset of those options, which we
  # splice directly into the submodule definition alongside the delivered
  # `config`.
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
  # the class-module `config` arg is the host's NixOS config, not den's. With
  # the delivered-child primitive core.users now also fires inside the guest,
  # but this preserves the original root-key parity (admins/wheel keys).
  rootKeys = lib.concatMap (
    u:
    lib.optionals (builtins.any (g: g == "admins" || g == "wheel") (u.groups or [ ])) (
      map (k: k.key) (u.identity.sshKeys or [ ])
    )
  ) (lib.attrValues (den.users.registry or { }));
in
{
  # PRODUCE: a background GPU claim per delivered child with a non-empty
  # passthrough intent. windows-vfio's qemu hook consumes these to preempt the
  # microvm during interactive Windows sessions.
  den.aspects.virtualization.microvm.gpu-claims =
    { host, ... }:
    lib.concatMap (
      vm:
      lib.optional ((vm.microvm.passthrough or [ ]) != [ ]) {
        device = lib.head vm.microvm.passthrough;
        priority = "background";
        kind = "microvm";
        unit = "microvm@${vm.name}.service";
      }
    ) (lib.attrValues (host.deliveredChildren or { }));

  # CONSUME: layer the host-side GPU/passthrough overlay on top of the base
  # guest configs the delivered-child-host primitive delivers into
  # microvm.vms.<name>.config. The primitive resolves each child (agenix,
  # core.users, collect, home-env) and routes its guest-os content into
  # `.config`; here we add:
  #   - host-side microvm submodule options (CUDA pkgs from the guest's microvm
  #     class aspect), spliced as siblings of `.config`,
  #   - facter-derived PCI passthrough devices + the ro-store share + root keys,
  #     merged INTO the guest's `.config`,
  #   - host-side systemd ExecCondition vfio gates.
  den.aspects.virtualization.microvm.nixos =
    {
      host,
      config,
      pkgs,
      ...
    }:
    let
      facter = config.facter.report;

      children = lib.attrValues (host.deliveredChildren or { });

      # Per-child overlay data: resolved microvm host-side options + the
      # facter-resolved passthrough device records.
      withOverlay = vm: {
        inherit (vm) name;
        microvmOpts = microvmSubmoduleOpts (den.lib.aspects.resolve "microvm" vm.aspect);
        recs = gpuLib.resolvePassthrough (vm.microvm.passthrough or [ ]) facter;
        sharedNixStore = vm.microvm.sharedNixStore or true;
      };
      guests = map withOverlay children;
    in
    {
      microvm.vms = lib.mkMerge (
        map (g: {
          # Host-side submodule options (e.g. CUDA pkgs) from the microvm class.
          ${g.name} = g.microvmOpts // {
            # Layer the GPU host-side bits onto the primitive-delivered config.
            config = {
              microvm.devices = gpuLib.toMicrovmDevices g.recs;
              microvm.shares = lib.optional g.sharedNixStore roStoreShare;
              users.users.root.openssh.authorizedKeys.keys = rootKeys;
            };
          };
        }) guests
      );

      # Host-side gate: hold the VM's start units until the passed-through PCI
      # device has actually been unbound from the host onto vfio-pci.
      systemd.services = lib.mkMerge (
        map (
          g:
          lib.optionalAttrs (g.recs != [ ]) (
            let
              gate = gpuLib.mkVfioGate pkgs g.recs;
            in
            {
              "microvm@${g.name}".serviceConfig.ExecCondition = gate;
              "microvm-pci-devices@${g.name}".serviceConfig.ExecCondition = gate;
            }
          )
        ) guests
      );
    };
}
