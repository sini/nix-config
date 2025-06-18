# This file defines overlays
{ inputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions =
    final: _prev:
    import ../pkgs {
      pkgs = final;
      inherit inputs;
    };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications =
    _final: prev:
    let
      openrazer_override = finalAttrs: prevAttrs: {
        version = "3.10.3";
        src = prevAttrs.src.override {
          tag = "v${finalAttrs.version}";
          hash = "sha256-M5g3Rn9WuyudhWQfDooopjexEgGVB0rzfJsPg+dqwn4=";
        };
      };
    in
    {
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

      # Overlay openrazer until https://github.com/NixOS/nixpkgs/pull/413803 makes it
      # to nixos-unstable.
      # openrazer = prev.unstable.openrazer.overrideAttrs openrazer_override;
      openrazer-daemon = prev.openrazer-daemon.overrideAttrs openrazer_override;

      linuxPackages_6_15 = prev.linuxPackages_6_15.extend (
        _: lpprev: {
          openrazer = lpprev.openrazer.overrideAttrs openrazer_override;
        }
      );
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
