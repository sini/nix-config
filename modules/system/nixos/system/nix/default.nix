{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.custom;
let
  cfg = config.system.nix;
in
{
  options.system.nix = with types; {
    enable = mkBoolOpt true "Whether or not to manage nix configuration.";
    package = mkOpt package pkgs.nixVersions.latest "Which nix package to use.";
    extraUsers = mkOpt (listOf str) [ ] "Extra users to trust";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      nil
      nixfmt-rfc-style
      nix-index
      nix-prefetch-git
    ];

    nix =
      let
        users = [
          "root"
          config.node.mainUser
        ];
      in
      {
        inherit (cfg) package;

        settings =
          {
            experimental-features = "nix-command flakes";
            http-connections = 50;
            warn-dirty = false;
            log-lines = 50;
            sandbox = "relaxed";
            auto-optimise-store = true;
            trusted-users = users ++ cfg.extraUsers;
            allowed-users = users;
            substituters = [
              "https://cache.nixos.org/"
              "https://cache.saumon.network/proxmox-nixos"
            ];
            trusted-public-keys = [
              "proxmox-nixos:nveXDuVVhFDRFx8Dn19f1WDEaNRJjPrF2CPD2D+m1ys="
            ];
          }
          // (lib.optionalAttrs config.apps.tools.direnv.enable {
            keep-outputs = true;
            keep-derivations = true;
          });

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };

      };
  };
}
