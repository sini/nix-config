{ inputs, ... }:
{
  flake =
    {
      config,
      lib,
      ...
    }:
    let
      inherit (lib)
        mapAttrs
        ;
      namespace = "custom";
      extendedLib = inputs.nixpkgs.lib.extend (_self: _super: import ../lib _self namespace);
      system_modules = extendedLib.${namespace}.listModuleDefaultsRec (
        extendedLib.${namespace}.relativeToRoot "modules"
      );
    in
    {
      nixosConfigurations = {
        surge = inputs.nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit
              inputs
              ;
            lib = extendedLib;
            namespace = "custom";
          };
          modules = [
            {
              nixpkgs.config.allowUnfree = true;
              node.name = "surge";
              # node.arch = "x86_64-linux";
              node.rootPath = ../systems/x86_64-linux/surge;
              node.secretsDir = ../systems/x86_64-linux/surge/secrets;
            }
            inputs.nixos-facter-modules.nixosModules.facter
            inputs.disko.nixosModules.disko
            inputs.agenix.nixosModules.default
            inputs.agenix-rekey.nixosModules.default
            # inputs.sops-nix.nixosModules.sops

            ../systems/x86_64-linux/surge
          ] ++ system_modules;
        };
      };
      darwinConfigurations = { };

      # All nixosSystem instanciations are collected here, so that we can refer
      # to any system via nodes.<name>
      nodes = config.nixosConfigurations // config.darwinConfigurations;

      # Add a shorthand to easily target toplevel derivations
      "@" = mapAttrs (_: v: v.config.system.build.toplevel) config.nodes;
    };
}
