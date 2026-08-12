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

    # TODO: Remove this once nixpkgs updates nanoemoji to v0.16.0 (or later)
    # nanoemoji's v0.16.0 GitHub tag tarball re-hashed upstream; nixpkgs (incl.
    # master) still pins the stale FOD hash. gftools -> nanoemoji drags it into
    # from-source font builds (jetbrains-mono, openmoji, ...), so the whole font
    # set fails on the hash mismatch. Pin the corrected src across all python
    # sets until nixpkgs catches up.
    pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
      (_pyfinal: pyprev: {
        nanoemoji = pyprev.nanoemoji.overrideAttrs (_old: {
          src = prev.fetchFromGitHub {
            owner = "googlefonts";
            repo = "nanoemoji";
            tag = "v0.16.0";
            hash = "sha256-FysyKC01XBnRiur5RR9fcsTxQqE8x0JJHSoe3q6JtKc=";
          };
        });
      })
    ];

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
