{
  inputs,
  config,
  lib,
  ...
}:
let
  mkCharts =
    { pkgs }:
    let
      kubelib = inputs.nix-kube-generators.lib { inherit pkgs; };
      trimBogusVersion = attrs: removeAttrs attrs [ "bogusVersion" ];
    in
    inputs.haumea.lib.load {
      src = ../../charts;
      loader = _: p: kubelib.downloadHelmChart (trimBogusVersion (import p));
      transformer = inputs.haumea.lib.transformers.liftDefault;
    };
in
{
  flake = {
    chartsMetadata = inputs.haumea.lib.load {
      src = ../../charts;
      transformer = inputs.haumea.lib.transformers.liftDefault;
    };

    charts = mkCharts;

    chartsDerivations = lib.genAttrs config.systems (
      system: mkCharts { pkgs = inputs.nixpkgs-unstable.legacyPackages.${system}; }
    );
  };

  perSystem =
    { inputs', ... }:
    {
      devshells.default.commands = [
        {
          name = "helmupdater";
          command = ''${inputs'.nixhelm.packages.helmupdater}/bin/helmupdater "$@"'';
          help = "Update helm chart versions and hashes";
        }
      ];
    };
}
