{
  options,
  config,
  pkgs,
  lib,
  ...
}:
with lib;
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

    # # Allow unfree packages globally
    # nixpkgs.config = {
    #   # allowUnfree = true;
    #   allowUnfreePredicate =
    #     pkg:
    #     builtins.elem (lib.getName pkg) [
    #       # Explicitly select unfree packages.
    #       "wpsoffice"
    #       "steam-run"
    #       "steam-original"
    #       "symbola"
    #       "vscode"
    #       "microsoft-edge-stable"
    #       "android-studio-stable"
    #       "zoom"
    #       "Oracle_VM_VirtualBox_Extension_Pack" # older
    #       "Oracle_VirtualBox_Extension_Pack" # newer
    #       "google-chrome"
    #       "intel-ocl"
    #       "cursor"
    #       "steam-unwrapped"
    #       "windsurf"
    #     ];
    # };
    nix =
      let
        users = [
          "root"
          "@wheel"
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
            trusted-users = users;
            allowed-users = users;
            substituters = [
              "https://cache.nixos.org/"
              "https://nix-community.cachix.org"
              "https://chaotic-nyx.cachix.org/"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
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
