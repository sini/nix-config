# Canonical secretsConfig option — single source of truth for master
# identity paths used by agenix, nixidy, and sops-config.
{
  lib,
  rootPath,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.den.secretsConfig = {
    masterIdentities = mkOption {
      type = types.listOf types.path;
      description = "Age master identity public key paths for agenix-rekey";
    };
  };

  config.den.secretsConfig = {
    masterIdentities = [
      (rootPath + "/.secrets/pub/master.pub")
      (rootPath + "/.secrets/pub/master-clone1.pub")
      (rootPath + "/.secrets/pub/master-clone2.pub")
    ];
  };
}
