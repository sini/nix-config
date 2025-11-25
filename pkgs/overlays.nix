# This file defines overlays
{ inputs, ... }:
{
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {
    # https://discord.com/channels/1065291958328758352/1071254299998421052/threads/1428125264319352904
    # branch: next
    custom-monado = prev.monado.overrideAttrs (old: {
      src = prev.fetchgit {
        url = "https://tangled.org/@matrixfurry.com/monado";
        rev = "c51275cb06738cdbcd6a356c3b2fcf508ab92f1e";
        hash = "sha256-RK3bCj0V/44/efDD0VFWerAGMLJhpR4/V5NK4BmDUs0=";
      };
    });

    custom-xrizer = prev.xrizer.overrideAttrs rec {
      src = prev.fetchFromGitHub {
        owner = "Mr-Zero88";
        repo = "xrizer";
        rev = "494617d132c59fceeb10cc70c865b3065e6070c1";
        hash = "sha256-12M7rkTMbIwNY56Jc36nC08owVSPOr1eBu0xpJxikdw=";
      };

      cargoDeps = prev.rustPlatform.fetchCargoVendor {
        inherit src;
        hash = "sha256-87JcULH1tAA487VwKVBmXhYTXCdMoYM3gOQTkM53ehE=";
      };

      patches = [ ];

      doCheck = false;
    };

    ayugram-desktop =
      inputs.ayugram-desktop.packages.${prev.stdenv.hostPlatform.system}.ayugram-desktop;

    split-monitor-workspaces =
      inputs.hyprland-split-monitor-workspaces.packages.${prev.stdenv.hostPlatform.system}.split-monitor-workspaces;
    # # TODO: remove once nixpkgs is fixed
    # ddcutil = prev.ddcutil.overrideAttrs (old: {
    #   version = "2.2.3";
    #   src = prev.fetchurl {
    #     url = "https://www.ddcutil.com/tarballs/ddcutil-2.2.3.tar.gz";
    #     hash = "sha256-4XvAUqYvnqhS2eOLpPHtfnNmVnoOGdvhpDnuca2+BqA=";
    #   };
    # });

    zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
    nixidy = inputs.nixidy.packages.${prev.stdenv.hostPlatform.system}.default;
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };
}
