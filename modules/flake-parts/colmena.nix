{
  self,
  inputs,
  ...
}:
{
  text.readme.parts.colmena =
    # markdown
    ''
      ## Remote deployment via Colmena

      This repository uses [Colmena](https://github.com/zhaofengli/colmena) to deploy NixOS configurations to remote hosts.
      Colmena supports both local and remote deployment, and hosts can be targeted by roles as well as their name.
      Remote connection properties are defined in the `flake.hosts.<hostname>.deployment` attribute set, and implementation
      can be found in the `modules/hosts/<hostname>/default.nix` file. This magic deployment logic lives in the
      [./m/f-p/colmena.nix](modules/flake-parts/colmena.nix) file.

      ```bash
      # Deploy to all hosts
      colmena apply

      # Deploy to a specific host
      colmena apply --on <hostname>

      # Deploy to all hosts with the "server" tag
      colmena apply --on @server

      # Apply changes to the current host (useful for local development)
      colmena apply-local --sudo
      ```

    '';
  flake =
    {
      lib,
      config,
      ...
    }:
    {
      colmena =
        {
          meta = {
            nixpkgs = import inputs.nixpkgs-unstable {
              system = "x86_64-linux";
              overlays = [ ];
            };
            nodeNixpkgs = builtins.mapAttrs (_: v: v.pkgs) self.nixosConfigurations;
            nodeSpecialArgs = builtins.mapAttrs (_: v: v._module.specialArgs) self.nixosConfigurations;
          };
        }
        // (lib.mapAttrs (
          hostname: nixosConfig:
          # For each NixOS configuration, we find its original options from the flake.
          let
            hostOptions = config.hosts.${hostname};
          in
          {
            imports = nixosConfig._module.args.modules;
            deployment = {
              targetHost = hostOptions.deployment.targetHost;
              tags = hostOptions.roles;
              allowLocalDeployment = true;
              privilegeEscalationCommand = [
                "doas"
                "--"
              ];
            };
          }
        ) self.nixosConfigurations);
    };
}
