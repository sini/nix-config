{ inputs, config, ... }:
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
        (wlib.wrapHomeModule {
          inherit pkgs;
          inherit (cfg) homeModules mainPackage;
          home-manager = inputs.home-manager-unstable;
        }).wrapper;
    in
    {
      packages = builtins.mapAttrs mkWrapped wrappedFeatures;
    };
}
