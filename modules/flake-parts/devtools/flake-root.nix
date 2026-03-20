{ inputs, ... }:
{
  imports = [
    inputs.flake-root.flakeModule
  ];

  perSystem =
    {
      config,
      ...
    }:
    {
      flake-root.projectRootFile = "flake.nix";
      devshells.default.packages = [ config.flake-root.package ];
    };
}
