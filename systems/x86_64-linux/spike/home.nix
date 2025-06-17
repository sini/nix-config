{
  config,
  inputs,
  pkgs,
  unstable,
  ...
}:
{
  imports = with inputs; [
    home-manager.nixosModules.home-manager
  ];

  config = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      verbose = true;

      extraSpecialArgs = {
        inherit inputs pkgs unstable;
        nixConfig = config;
      };
    };
  };
}
