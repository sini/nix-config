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
          mainPackage = pkgs.alacritty;
        };
      };

      mkWrapped =
        _name: cfg:
        let
          base = wlib.wrapHomeModule {
            inherit pkgs;
            inherit (cfg) homeModules mainPackage;
            home-manager = inputs.home-manager-unstable;
          };

          # Build bwrap ro-binds using placeholder "out" instead of store paths.
          # mkBinds uses resolved store paths as attr keys, which strips string
          # context. placeholder "out" is substituted at build time and avoids this.
          hmAdapter = base.passthru.hmAdapter;
          xdgBinds = builtins.mapAttrs (
            name: _:
            ".config/${name}"
          ) hmAdapter.xdgConfigFiles;
          homeBinds = builtins.mapAttrs (
            name: fileCfg:
            fileCfg.target or name
          ) hmAdapter.homeFiles;
          # Re-key with placeholder "out" so bwrap can reference the derivation
          placeholderBinds =
            let
              out = builtins.placeholder "out";
              mkXdg = name: target: {
                name = "${out}/hm-xdg-config/${name}";
                value = target;
              };
              mkHome = name: target: {
                name = "${out}/hm-home/${name}";
                value = target;
              };
            in
            builtins.listToAttrs (
              lib.mapAttrsToList mkXdg xdgBinds
              ++ lib.mapAttrsToList mkHome homeBinds
            );
        in
        base.wrap {
          imports = [ wlib.modules.bwrapConfig ];
          bwrapConfig.binds.ro = placeholderBinds;
          # bwrap presents config at the real path, so XDG_CONFIG_HOME
          # override from the HM adapter is no longer needed.
          env.XDG_CONFIG_HOME = lib.mkForce null;
        };
    in
    {
      packages = builtins.mapAttrs mkWrapped wrappedFeatures;
    };
}
