{
  config,
  inputs,
  pkgs,
  ...
}:
{
  # imports = with inputs; [
  #   home-manager.nixosModules.home-manager
  # ];

  config = {

    nixpkgs.overlays = [
      inputs.nix-vscode-extensions.overlays.default
    ];

    home-manager = {
      useGlobalPkgs = true;
      # useUserPackages = true;
      verbose = true;

      extraSpecialArgs = {
        inherit inputs;
        systemPkgs = pkgs;
        nixConfig = config;
      };
    };
  };
}
