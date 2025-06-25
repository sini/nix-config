{ inputs, ... }:
{
  imports = [
    inputs.pre-commit-hooks.flakeModule
    inputs.git-hooks-nix.flakeModule
  ];

  perSystem = _: {
    pre-commit = {
      check.enable = true;

      settings.hooks = {
        treefmt.enable = true;
      };
    };

  };
}
