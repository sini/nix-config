# This file defines overlays
{ inputs, ... }:
{
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {

    kanidm-provision = prev.kanidm-provision.overrideAttrs (_old: rec {
      src = prev.fetchFromGitHub {
        owner = "sini";
        repo = "kanidm-provision";
        rev = "576666aa70e045142665215a8d29ea2bbbb6bcf6";
        hash = "sha256-12XZRrs71tcUVyFBm7rrAM6DdOz8+wY0MmB+yvwGrt0=";
      };

      cargoDeps = prev.rustPlatform.fetchCargoVendor {
        inherit src;
        hash = "sha256-dPTrIc/hTbMlFDXYMk/dTjqaNECazldfW43egDOwyLM=";
      };
    });

    openldap = prev.openldap.overrideAttrs { doCheck = false; };

    inherit (inputs.ayugram-desktop.packages.${prev.stdenv.hostPlatform.system}) ayugram-desktop;

    zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
    nixidy = inputs.nixidy.packages.${prev.stdenv.hostPlatform.system}.default;
    agenix-rekey = inputs.agenix-rekey.packages.${prev.stdenv.hostPlatform.system}.default;
  };

  # Thread the gen-lsp flake source to pkgs-by-name so pkgs/by-name/gen-lsp-mcp
  # can take `gen-lsp-src` as a callPackage arg and build the mcp/ subdir
  # hermetically (from the locked gen-lsp input, not a re-export of its package).
  gen-lsp-src = _final: _prev: {
    gen-lsp-src = inputs.gen-lsp;
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  };

  # stable-packages = final: _prev: {
  #   stable = import inputs.nixpkgs {
  #     inherit (final.stdenv.hostPlatform) system;
  #     config.allowUnfree = true;
  #   };
  # };
}
