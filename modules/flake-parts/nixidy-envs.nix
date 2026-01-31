{
  config,
  inputs,
  lib,
  withSystem,
  ...
}:
{
  flake = flakeOpts: {
    nixidyEnvs = lib.genAttrs config.systems (
      system:
      (withSystem system (
        { pkgs, ... }:
        (lib.mapAttrs (
          env: environment:
          inputs.nixidy.lib.mkEnv {
            inherit pkgs;
            charts = inputs.nixhelm.chartsDerivations.${system};
            extraSpecialArgs = {
              inherit environment;
              hosts = flakeOpts.config.hosts;
            };
            modules = [
              {
                nixidy.env = lib.mkDefault env;
                nixidy.target.rootPath = lib.mkDefault "./kubernetes/manifests/${env}";
              }
              ../../kubernetes/envs/${env}
            ];
          }
        ) flakeOpts.config.environments)
      )

      )
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
      crds = import ../../kubernetes/crds {
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
