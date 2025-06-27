{ config, ... }:
let
  inherit (config.flake.meta.accounts) github;
  forge = "github";
  owner = github.username;
  name = "nix-config";
  defaultBranch = "main";
  flakeUri = "git+https://${github.domain}/${owner}/${name}?shallow=1";
in
{
  flake.meta.repo = {
    inherit
      forge
      owner
      name
      defaultBranch
      flakeUri
      ;
  };
}
