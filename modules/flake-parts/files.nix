{
  inputs,
  config,
  ...
}:
{
  imports = [
    inputs.files.flakeModules.default
    inputs.flake-parts.flakeModules.modules
  ];

  _module.args.dag = inputs.dag.lib { lib = inputs.nixpkgs-unstable.lib; };

  flake-file.inputs.dag.url = "github:denful/dag";

  perSystem =
    {
      config,
      ...
    }:
    {
      devshells.default.packages = [ config.files.writer.drv ];
      devshells.default.commands = [
        {
          package = config.files.writer.drv;
          help = "Generate files";
        }
      ];
      apps.write-files = {
        type = "app";
        program = "${config.files.writer.drv}/bin/write-files";
      };
    };
}
