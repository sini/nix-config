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

      shared_modules = extendedLib.${namespace}.listModuleDefaultsRec (
        extendedLib.${namespace}.relativeToRoot "modules/shared"
      );

      nixos_modules = extendedLib.${namespace}.listModuleDefaultsRec (
        extendedLib.${namespace}.relativeToRoot "modules/nixos"
      );

      # darwin_modules = extendedLib.${namespace}.listModuleDefaultsRec (
      #   extendedLib.${namespace}.relativeToRoot "modules/darwin"
      # );

      linux_modules = shared_modules ++ nixos_modules;

      inherit (extendedLib.${namespace}) linuxHosts;
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
                node.hostname = _elem.hostname;
                # node.arch = "x86_64-linux";
                node.rootPath = _elem.path;
                node.secretsDir = _elem.path + "/secrets";
              }
              inputs.nixos-facter-modules.nixosModules.facter
              inputs.disko.nixosModules.disko
              inputs.agenix.nixosModules.default
              inputs.agenix-rekey.nixosModules.default
              # inputs.sops-nix.nixosModules.sops
              _elem.path
            ] ++ linux_modules;
          };
        }) linuxHosts
      );
      darwinConfigurations = { };

      # All nixosSystem instanciations are collected here, so that we can refer
      # to any system via nodes.<name>
      nodes = config.nixosConfigurations // config.darwinConfigurations;

      # Add a shorthand to easily target toplevel derivations
      "@" = mapAttrs (_: v: v.config.system.build.toplevel) config.nodes;
    };
}
