{
  inputs,
  ...
}:
{
  imports = [
    inputs.git-hooks-nix.flakeModule
  ];

  perSystem =
    {
      self',
      config,
      inputs',
      pkgs,
      ...
    }:
    {
      devshells.default.devshell.startup.git-hooks.text = config.pre-commit.installationScript;

      pre-commit = {
        check.enable = false;

        # Use prek instead of pre-commit to avoid dotnet dependency
        settings = {
          package = inputs'.git-hooks-nix.packages.prek or pkgs.prek;

          hooks = {
            # Use built-in treefmt hook (runs self'.formatter which is treefmt wrapper)
            treefmt = {
              enable = true;
              package = self'.formatter;
            };

            # TODO: re-enable after addressing pre-existing warnings
            # statix = {
            #   enable = true;
            #   package = inputs'.statix.packages.default;
            # };

            # Custom hook: write-files
            # write-files = {
            #   enable = true;
            #   name = "write-files";
            #   description = "Run write-files to re-generate documentation";
            #   entry = "nix run .#write-files";
            #   files = "\\.nix$";
            #   pass_filenames = false;
            # };
          };
        };
      };
    };
}
