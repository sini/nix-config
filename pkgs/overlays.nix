# This file defines overlays
{ inputs, ... }:
{
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
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

    # hermes-agent's own flake package, with one darwin fix. shortcut:
    # NousResearch/hermes-agent#150713. On macOS pnpm's clone probe leaves an empty
    # v11/links in the store, so pnpm-deps misses its one pinned hash. This applies
    # upstream's fix (PR #150967, open) to lib.nix's fetchPnpmDeps, against hermes' own
    # nixpkgs, so the store matches Linux's byte for byte (same output path).
    # Remove the override once #150967 merges.
    hermes-agent =
      let
        inherit (prev.stdenv.hostPlatform) system isDarwin;
        package = inputs.hermes-agent.packages.${system}.default;
        hpkgs = inputs.hermes-agent.inputs.nixpkgs.legacyPackages.${system};
      in
      if !isDarwin then
        package
      else
        package.override {
          callPackage =
            fn: args:
            hpkgs.callPackage fn (
              args
              // prev.lib.optionalAttrs (baseNameOf fn == "lib.nix") {
                fetchPnpmDeps =
                  a:
                  hpkgs.fetchPnpmDeps (
                    a
                    // {
                      preFixup = (a.preFixup or "") + ''
                        rmdir "$storePath/v11/links" 2>/dev/null || true
                      '';
                    }
                  );
              }
            );
        };

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

  # Thread the xmsg flake source to pkgs-by-name for pkgs/by-name/xmsg.
  xmsg-src = _final: _prev: {
    xmsg-src = inputs.xmsg;
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
