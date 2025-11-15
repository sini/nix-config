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
        rev = "e8dc56e3d02ecd9ab16331649516b3dd0f73d4ad";
        hash = "sha256-M4tFZeTlvmybMAltSdkbmei0mMf/sh9A/S8t7ZxefHA=";
      };
    });

    custom-xrizer = prev.xrizer.overrideAttrs rec {
      src = prev.fetchFromGitHub {
        owner = "Mr-Zero88";
        repo = "xrizer";
        rev = "7328384195e3255f16b83ba06248cd74d67237eb";
        hash = "sha256-12M7rkTMbIwNY56Jc36nC08owVSPOr1eBu0xpJxikdw=";
      };

      cargoDeps = prev.rustPlatform.fetchCargoVendor {
        inherit src;
        hash = "sha256-87JcULH1tAA487VwKVBmXhYTXCdMoYM3gOQTkM53ehE=";
      };

      patches = [ ];

      doCheck = false;
    };

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
