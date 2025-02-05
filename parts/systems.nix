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

      shared_modules =
        extendedLib.${namespace}.listModuleDefaultsRec (
          extendedLib.${namespace}.relativeToRoot "modules/shared"
        )
        ++ [
          inputs.agenix.nixosModules.default
          inputs.agenix-rekey.nixosModules.default
        ];

      nixos_modules =
        shared_modules
        ++ extendedLib.${namespace}.listModuleDefaultsRec (
          extendedLib.${namespace}.relativeToRoot "modules/nixos"
        )
        ++ [
          inputs.nixos-facter-modules.nixosModules.facter
          inputs.disko.nixosModules.disko
        ];

      darwin_modules =
        shared_modules
        ++ extendedLib.${namespace}.listModuleDefaultsRec (
          extendedLib.${namespace}.relativeToRoot "modules/darwin"
        );

      inherit (extendedLib.${namespace}) linuxHosts darwinHosts;
    in
    {
      nixosConfigurations = lib.attrsets.mergeAttrsList (
        builtins.map (_elem: {
          "${_elem.hostname}" = inputs.nixpkgs.lib.nixosSystem {
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
                networking.hostName = _elem.hostname;
              }
              _elem.path
            ] ++ nixos_modules;
          };
        }) linuxHosts
      );

      darwinConfigurations = lib.attrsets.mergeAttrsList (
        builtins.map (_elem: {
          "${_elem.hostname}" = inputs.nixpkgs.lib.nixosSystem {
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
                networking.hostName = _elem.hostname;
              }
              _elem.path
            ] ++ darwin_modules;
          };
        }) darwinHosts
      );

      # All nixosSystem instanciations are collected here, so that we can refer
      # to any system via nodes.<name>
      nodes = config.nixosConfigurations // config.darwinConfigurations;

      # Add a shorthand to easily target toplevel derivations
      "@" = mapAttrs (_: v: v.config.system.build.toplevel) config.nodes;
    };
}
