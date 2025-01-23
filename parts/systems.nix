{
  inputs,
  outputs,
  ...
}:
{
  flake.nixosConfigurations =
    let
      namespace = "custom";
      lib = inputs.nixpkgs.lib.extend (_self: _super: import ../lib _self namespace);
      system_modules = lib.${namespace}.listModuleDefaultsRec (lib.${namespace}.relativeToRoot "modules");
    in
    {
      surge = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit
            inputs
            outputs
            ;

          # ========== Extend lib with lib.custom ==========
          # NOTE: This approach allows lib.custom to propagate into hm
          # see: https://github.com/nix-community/home-manager/pull/3454
          inherit lib;
          namespace = "custom";
        };
        modules = [
          inputs.nixos-facter-modules.nixosModules.facter
          inputs.disko.nixosModules.disko
          inputs.sops-nix.nixosModules.sops

          ../systems/x86_64-linux/surge
        ] ++ system_modules;
      };
    };
}
