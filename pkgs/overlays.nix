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

    pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
      (_pyfinal: pyprev: {
        # TODO: Remove once nixpkgs picks up
        # https://github.com/NixOS/nixpkgs/pull/554405 or bumps curl-cffi to
        # 0.16.0. The 0.15.0 test suite asserts on TLS/cookie error strings that
        # the current curl-impersonate no longer emits. yt-dlp pulls curl-cffi
        # into every closure, so the whole host build fails on it.
        curl-cffi = pyprev.curl-cffi.overrideAttrs (old: {
          disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
            "tests/unittest/test_async_session.py::test_verify"
            "tests/unittest/test_curl.py::test_verify"
            "tests/unittest/test_requests.py::test_verify"
            "tests/unittest/test_requests.py::test_delete_cookies"
          ];
        });

        # Our ZFS datasets are created with utf8only=on, so the kernel refuses
        # filenames that are not valid UTF-8 (EILSEQ) instead of creating them.
        # These two tests exist to exercise exactly such names, so they can never
        # pass on this machine regardless of nixpkgs revision. gftools -> pygit2
        # drags this into from-source font builds.
        pygit2 = pyprev.pygit2.overrideAttrs (old: {
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_lookup_branch_local"
            "test_nonunicode_status_path"
          ];
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
