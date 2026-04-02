{ inputs, ... }:
{
  flake-file.inputs.flake-root.url = "github:srid/flake-root";

  imports = [
    inputs.flake-root.flakeModule
  ];

  _module.args.rootPath = ../../..;

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
