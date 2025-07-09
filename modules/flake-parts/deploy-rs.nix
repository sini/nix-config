{
  lib,
  inputs,
  self,
  ...
}:
let
  inherit (inputs) deploy-rs;
in
{
  flake =
    { config, ... }:
    {
      # deploy.nodes = lib.mapAttrs (hostname: hostOptions: {
      #   hostname = hostOptions.deployment.targetHost;
      #   sshUser = hostOptions.deployment.sshUser or "root";
      #   profiles.system = {
      #     user = "root";
      #     path = self.nixosConfigurations.${hostname}.config.system.build.toplevel;
      #   };
      # }) config.hosts;

      deploy.nodes = lib.mapAttrs (
        hostname: options:
        {
          inherit hostname;
          profiles.system = {
            user = "root";
            path = deploy-rs.lib.${options.system}.activate.nixos self.nixosConfigurations.${hostname};
          };
        }
        // options.deploy
      ) config.hosts;
    };

  perSystem =
    {
      system,
      inputs',
      ...
    }:
    {
      checks = deploy-rs.lib.${system}.deployChecks self.deploy;

      devshells.default.packages = [
        inputs'.deploy-rs.packages.default
      ];
    };
}
