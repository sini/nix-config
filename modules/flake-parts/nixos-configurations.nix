{
  inputs,
  withSystem,
  ...
}:
{
  flake =
    { config, ... }:
    let
      nixpkgsLib = inputs.nixpkgs.lib;
      unstableLib = inputs.nixpkgs-unstable.lib;

      hostDefs = nixpkgsLib.mapAttrs (
        hostname: hostOptions:
        withSystem hostOptions.system (
          { system, ... }:
          let
            nixpkgs' = if hostOptions.unstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
            homeManager' = if hostOptions.unstable then inputs.home-manager-unstable else inputs.home-manager;
            extendedLibrary = if hostOptions.unstable then unstableLib else nixpkgsLib;
            chaotic_imports =
              if hostOptions.unstable then
                [ inputs.chaotic.nixosModules.default ]
              else
                [
                  inputs.chaotic.nixosModules.nyx-cache
                  inputs.chaotic.nixosModules.nyx-overlay
                  inputs.chaotic.nixosModules.nyx-registry
                ];

            modules =
              [ config.modules.nixos.role_core ]
              ++ (nixpkgsLib.optionals (hostOptions ? roles) (
                builtins.map (role: inputs.self.modules.nixos."role_${role}") (
                  nixpkgsLib.filter (
                    role: nixpkgsLib.hasAttr "role_${role}" inputs.self.modules.nixos
                  ) hostOptions.roles
                )
              ))
              ++ hostOptions.extra_modules
              ++ chaotic_imports
              ++ [
                nixpkgs'.nixosModules.notDetected
                homeManager'.nixosModules.home-manager
                (inputs.self.modules.nixos."host_${hostname}" or { })
                {
                  networking.hostName = hostname;
                  facter.reportPath = hostOptions.facts;
                  age.rekey.hostPubkey = hostOptions.public_key;
                }
              ];

            specialArgs = {
              inherit inputs hostOptions;
              inherit (config) nodes;
              lib = extendedLibrary;
            };

            systemConfig = nixpkgs'.lib.nixosSystem {
              inherit system modules specialArgs;
            };
          in
          {
            inherit systemConfig modules specialArgs;
          }
        )
      ) config.hosts;

      nixosConfigurations = nixpkgsLib.mapAttrs (_: v: v.systemConfig) hostDefs;
    in
    {
      inherit nixosConfigurations;

      nodes = nixosConfigurations;

      colmena =
        nixpkgsLib.mapAttrs (hostname: v: {
          imports = v.modules;
          deployment = {
            targetHost = config.hosts.${hostname}.deployment.targetHost;
            tags = config.hosts.${hostname}.roles;
            allowLocalDeployment = true;
          };
        }) hostDefs
        // {
          meta = {
            nixpkgs = import inputs.nixpkgs-unstable {
              system = "x86_64-linux";
            };
            nodeNixpkgs = builtins.mapAttrs (_: v: v.systemConfig.pkgs) hostDefs;
            nodeSpecialArgs = builtins.mapAttrs (_: v: v.specialArgs) hostDefs;
          };
        };
    };
}
