{
  config,
  inputs,
  lib,
  withSystem,
  ...
}:
{
  flake = {
    nixidyEnvs = lib.genAttrs config.systems (
      system:
      (withSystem system (
        { pkgs, ... }:
        inputs.nixidy.lib.mkEnvs {
          inherit pkgs;
          charts = inputs.nixhelm.chartsDerivations.${system};
          # extraSpecialArgs = {
          #   inherit (config) environments hosts;
          # };
          envs = {
            prod.modules = [
              ../../k8s/prod/default.nix
            ];
          };
        }
      ))
    );
  };

  perSystem =
    {
      inputs',
      pkgs,
      system,
      ...
    }:
    let
      crds = import ../../k8s/crds {
        inherit
          inputs
          system
          pkgs
          lib
          ;
      };
    in
    {
      imports = [ crds ];

      devshells.default.packages = [ inputs'.nixidy.packages.default ];
      devshells.default.commands = [
        {
          package = inputs'.nixidy.packages.default;
          help = "Manage kubernetes cluster deployment configuration";
        }
        {
          package = crds.packages.generate-crds;
          help = "Generate CRDs";
        }
      ];
    };
}
