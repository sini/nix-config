{ inputs, config, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      wlib = inputs.nix-wrapper-modules.lib;

      # Static registry of features to wrap as standalone packages.
      # Each entry maps a package output name to its wrapping config.
      # Only Tier 1 features (no user/host/environment context) belong here.
      wrappedFeatures = {
        alacritty = {
          homeModules = [ config.features.alacritty.home ];
        };
      };

      mkWrapped =
        name: cfg:
        let
          base = wlib.wrapHomeModule {
            inherit pkgs;
            inherit (cfg) homeModules;
            programName = cfg.programName or name;
            home-manager = inputs.home-manager-unstable;
          };
        in
        base.wrap {
          imports = [ wlib.modules.bwrapConfig ];
          bwrapConfig.binds.ro = wlib.mkBinds base.passthru.hmAdapter;
          env.XDG_CONFIG_HOME = lib.mkForce null;
        };
    in
    {
      packages = builtins.mapAttrs mkWrapped wrappedFeatures;
    };
}
