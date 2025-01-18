{
  inputs,
  outputs,
  ...
}:
{
  flake.nixosConfigurations = {
    surge = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit
          inputs
          outputs
          ;

        # ========== Extend lib with lib.custom ==========
        # NOTE: This approach allows lib.custom to propagate into hm
        # see: https://github.com/nix-community/home-manager/pull/3454
        lib = inputs.nixpkgs.lib.extend (
          _self: _super: { custom = import ../lib { inherit (inputs.nixpkgs) lib; }; }
        );
        namespace = "custom";

      };
      modules = [
        inputs.nixos-facter-modules.nixosModules.facter
        inputs.disko.nixosModules.disko
        inputs.sops-nix.nixosModules.sops

        ./surge
      ];
    };
  };
}
