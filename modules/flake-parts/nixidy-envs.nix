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
      generators = import ../../k8s/generators {
        inherit
          inputs
          system
          pkgs
          lib
          ;
      };
    in
    {
      imports = [ generators ];

      devshells.default.packages = [ inputs'.nixidy.packages.default ];
      devshells.default.commands = [
        {
          package = inputs'.nixidy.packages.default;
          help = "Manage kubernetes cluster deployment configuration";
        }
        {
          package = generators.packages.generate-crds;
          help = "Generate crds";
        }
      ];
    };
}
