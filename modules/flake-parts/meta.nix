{ lib, ... }:
let
  inherit (lib) mkOption types;
  forge = "github";
  owner = "sini";
  name = "nix-config";
  defaultBranch = "main";
  flakeUri = "git+https://github.com/${owner}/${name}?shallow=1";
in
{
  options.flake.meta = mkOption {
    type = types.lazyAttrsOf types.anything;
    description = "Flake-level metadata.";
  };

  config.flake.meta = {
    uri = "github:sini/nix-config";
    repo = {
      inherit
        forge
        owner
        name
        defaultBranch
        flakeUri
        ;
    };
  };
}
