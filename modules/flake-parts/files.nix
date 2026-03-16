{
  inputs,
  config,
  withSystem,
  lib,
  ...
}:
{
  imports = [ inputs.files.flakeModules.default ];

  text.readme.parts.files =
    withSystem (builtins.head config.systems) (psArgs: psArgs.config.files.files)
    |> map (file: "- `${file.path_}`")
    |> lib.concat [
      # markdown
      ''
        ## Generated files

        The following files in this repository are generated and checked
        using [the _files_ flake-parts module](https://github.com/mightyiam/files):
      ''
    ]
    |> lib.concatLines
    |> (s: s + "\n");

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
