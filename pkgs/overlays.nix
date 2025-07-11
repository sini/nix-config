# This file defines overlays
{ inputs, ... }:
{
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {
    zjstatus = inputs.zjstatus.packages.${prev.system}.default;

    gitkraken = prev.gitkraken.overrideAttrs (_old: rec {
      version = "11.2.0";

      src =
        {
          x86_64-linux = prev.fetchzip {
            url = "https://api.gitkraken.dev/releases/production/linux/x64/${version}/gitkraken-amd64.tar.gz";
            hash = "sha256-yCAxNYwjnmK0lSkH9x8Q4KoQgAWwWmCS8O81tcsqWhs=";
          };

          x86_64-darwin = prev.fetchzip {
            url = "https://api.gitkraken.dev/releases/production/darwin/x64/${version}/installGitKraken.dmg";
            hash = "";
          };

          aarch64-darwin = prev.fetchzip {
            url = "https://api.gitkraken.dev/releases/production/darwin/arm64/${version}/installGitKraken.dmg";
            hash = "";
          };
        }
        .${prev.stdenv.hostPlatform.system}
          or (throw "Unsupported system: ${prev.stdenv.hostPlatform.system}");
    });
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };
}
