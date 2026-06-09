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
      # srcHash is consumed by chartsMetadata (CRD/cni source pin); it is not a
      # downloadHelmChart argument, so strip it before building the chart.
      trimBogusVersion =
        attrs:
        removeAttrs attrs [
          "bogusVersion"
          "srcHash"
        ];
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

  perSystem = _: {
  };
}
