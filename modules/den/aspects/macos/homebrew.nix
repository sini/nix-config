# Homebrew setup + collector for the fleet's Darwin hosts.
#
# nixpkgs is always the preferred source: aspects should install via
# `home.packages = [ pkgs.foo ]` whenever a real nixpkgs build exists. Homebrew
# is the fallback for macOS-only GUI apps with no nixpkgs equivalent. Such
# aspects contribute to the `homebrew-cask` / `homebrew-mas` quirks via a sibling
# key, e.g. `den.aspects.X.homebrew-cask = [ "raycast" ];`, and this aspect
# collects them into the system-wide homebrew config.
{ inputs, ... }:
{
  den.aspects.macos.homebrew = {
    darwin =
      {
        config,
        host,
        lib,
        homebrew-cask,
        homebrew-mas,
        ...
      }:
      {
        imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

        # Put the brew prefix on PATH so `brew`-managed CLIs resolve.
        environment.systemPath = [ (config.homebrew.prefix + "/bin") ];

        # Pin the taps to flake inputs (mutableTaps = false) so the cask/formula
        # set is reproducible and locked alongside the rest of the flake.
        nix-homebrew = {
          enable = true;
          enableRosetta = true;
          user = host.system-owner;
          autoMigrate = true;
          mutableTaps = false;
          taps = {
            "homebrew/homebrew-core" = inputs.homebrew-core;
            "homebrew/homebrew-cask" = inputs.homebrew-cask;
          };
        };

        homebrew = {
          enable = true;
          user = host.system-owner;
          taps = lib.attrNames config.nix-homebrew.taps;

          # No surprise network activity on switch; the lockfile is the source of
          # truth and upgrades happen via `nix flake update` + rebuild.
          global.autoUpdate = false;
          onActivation = {
            cleanup = "none";
            autoUpdate = false;
            upgrade = false;
          };

          casks = lib.unique homebrew-cask;
          masApps = lib.mkMerge homebrew-mas;
        };

        environment.variables = {
          HOMEBREW_NO_ANALYTICS = "1";
          HOMEBREW_NO_EMOJI = "1";
          HOMEBREW_NO_INSECURE_REDIRECT = "1";
        };
      };
  };
}
