{
  lib,
  rootPath,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.flake.secretsPaths = {
    secretsPath = mkOption {
      type = types.path;
      description = ''
        Content-addressed store path for the .secrets directory.
        Only changes when secrets files change, not on every source edit.
        Prevents unnecessary rebuilds of derivations that embed secret references.
      '';
    };
    rawSecretsPath = mkOption {
      type = types.path;
      description = ''
        Raw flake-relative path to the .secrets directory.
        Use this when the consumer requires a path that is a subpath of the flake
        source (e.g. agenix-rekey-to-sops origin validation).
      '';
    };
    rawSopsConfigPath = mkOption {
      type = types.path;
      description = ''
        Raw flake-relative path to .sops.yaml.
        Use this when the consumer requires a path that is a subpath of the flake source.
      '';
    };
  };

  config.flake.secretsPaths = {
    secretsPath = builtins.path {
      path = rootPath + "/.secrets";
      name = "nix-config-secrets";
    };
    rawSecretsPath = rootPath + "/.secrets";
    rawSopsConfigPath = rootPath + "/.sops.yaml";
  };
}
