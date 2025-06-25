{ inputs, ... }:
{
  imports = [
    inputs.pre-commit-hooks.flakeModule
    inputs.git-hooks-nix.flakeModule
  ];

  text.gitignore = ''
    /.pre-commit-config.yaml
  '';

  perSystem =
    { config, ... }:
    {
      devshells.default.devshell.startup.pre-commit.text = config.pre-commit.installationScript;

      pre-commit = {
        check.enable = true;

        settings.hooks = {
          treefmt.enable = true;
        };
      };

    };
}
