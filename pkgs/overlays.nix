# This file defines overlays
{ inputs, ... }:
{
  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = _final: prev: {
    # https://discord.com/channels/1065291958328758352/1071254299998421052/threads/1428125264319352904
    # branch: next
    custom-monado = prev.monado.overrideAttrs (_old: {
      src = prev.fetchgit {
        url = "https://tangled.org/@matrixfurry.com/monado";
        rev = "ecf484dd36c2bb475616189dbc222f5dc9c1c396";
        hash = "sha256-+Y6Y3J+UDa7UuYAlEMPwlhl2+FRxu7diXdBr5m8TIYs=";
      };
    });

    custom-xrizer = prev.xrizer.overrideAttrs rec {
      src = prev.fetchFromGitHub {
        owner = "Mr-Zero88";
        repo = "xrizer";
        rev = "494617d132c59fceeb10cc70c865b3065e6070c1";
        hash = "sha256-D9jLaxWNce8XHfYePyOF2HEmJuDMKhuty+VO0CP8I38=";
      };

      cargoDeps = prev.rustPlatform.fetchCargoVendor {
        inherit src;
        hash = "sha256-tLPwiwKkEBdsRxXgdcTM9TLJeNRZV32W11qUbyCVdHw=";
      };

      patches = [ ];

      doCheck = false;
    };

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

    # upstream build failures in nixpkgs-unstable
    onnxruntime = prev.onnxruntime.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        # Fix duplicate arena_extend_strategy when USE_CUDA and USE_MIGRAPHX both enabled
        sed -i 's/#if defined(USE_MIGRAPHX)/#if defined(USE_MIGRAPHX) \&\& !defined(USE_CUDA) \&\& !defined(USE_CUDA_PROVIDER_INTERFACE)/' \
          onnxruntime/python/onnxruntime_pybind_state_common.cc
      '';
    });
    openldap = prev.openldap.overrideAttrs { doCheck = false; };

    # Bump containerd to 2.3.1: the channel's 2.3.0 has a transfer-plugin bug
    # where a failed EROFS differ (no mkfs.erofs) leaves "no unpack platforms
    # defined", so CRI can't unpack the sandbox image. Fixed in 2.3.1 (#13364).
    # Vendored build (vendorHash=null), so a src bump is sufficient; makeFlags
    # are recomputed for the new version/revision.
    containerd = prev.containerd.overrideAttrs (
      old:
      let
        version = "2.3.1";
        src = prev.fetchFromGitHub {
          owner = "containerd";
          repo = "containerd";
          rev = "v${version}";
          hash = "sha256-BpKBrMluU5MmojJp/9Og5UrkUBLHav5qx6Re1SFhlhY=";
        };
      in
      {
        inherit version src;
        makeFlags =
          builtins.filter (
            x: !(prev.lib.hasPrefix "VERSION=" x) && !(prev.lib.hasPrefix "REVISION=" x)
          ) old.makeFlags
          ++ [
            "REVISION=${src.rev}"
            "VERSION=v${version}"
          ];
      }
    );

    inherit (inputs.ayugram-desktop.packages.${prev.stdenv.hostPlatform.system}) ayugram-desktop;

    kvmfr = prev.kvmfr.override { looking-glass-client = prev.local.looking-glass-client-vulkan; };
    zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
    nixidy = inputs.nixidy.packages.${prev.stdenv.hostPlatform.system}.default;
    agenix-rekey = inputs.agenix-rekey.packages.${prev.stdenv.hostPlatform.system}.default;

    # Override default electron with the latest available non-EOL version.
    # Picks the first version that exists in the channel's package set.
    # electron =
    #   let
    #     pick = names: builtins.head (builtins.filter (n: prev ? ${n}) names);
    #   in
    #   prev.${
    #     pick [
    #       "electron_41"
    #       "electron_40"
    #       "electron_39"
    #     ]
    #   };
  };

  # Thread the gen-lsp flake source to pkgs-by-name so pkgs/by-name/gen-lsp-mcp
  # can take `gen-lsp-src` as a callPackage arg and build the mcp/ subdir
  # hermetically (from the locked gen-lsp input, not a re-export of its package).
  gen-lsp-src = _final: _prev: {
    gen-lsp-src = inputs.gen-lsp;
  };

  # codebase-memory-mcp: take the upstream flake's build, not the channel's, and
  # carry two local patches. One patch per upstream PR, so each can be dropped
  # independently as they land.
  #
  # 1. nix-function-header (PR #1304) — total definition loss for the dominant Nix
  #    file shape. A library or module file's root expression is normally itself a
  #    function (`{ pkgs, lib, ... }: <body>`), which matches the extractor's Nix
  #    function types, resolves no name of its own, and then hit
  #    `if (!descend_into_func) continue;` — abandoning the whole subtree before
  #    any binding below the header was visited. Files opening with a bare `let`
  #    or attrset were walked normally, which is why the language looked
  #    supported.
  #
  # 2. nix-attrpath-variables (PR #1305) — a Nix binding's name is a PATH, and the
  #    resolver took only its first segment. `setA.dup` and `setB.dup` collapsed
  #    onto one node, silently discarding the second definition and every CALLS
  #    edge sourced from it; `a.b.fn` was named `a`; `"kebab-case"` kept its
  #    quotes. Also mints Variable nodes for module-level bindings, which were
  #    unconditionally absent. Scope is bounded to file level — the `let` bindings
  #    and the returned attrset — so a NixOS module's settings tree does not mint
  #    a node per `enable = true`.
  #
  # Cumulative on this repository, mode=full: Function 293 -> 684, CALLS 204 ->
  # 327, and 226 Nix Variables where there were none. On den-hoag: Function
  # 48 -> 2213, CALLS 56 -> 1461.
  #
  # Upstream: sini/codebase-memory-mcp, branches spike/nix-function-header-defs and
  # feat/nix-attrpath-and-variables. Drop each entry with its PR.
  #
  # The version is corrected here too. Upstream's flake hardcodes `version =
  # "0.6.0"` while its src is whatever the input resolves to — currently 438
  # commits PAST v0.9.0 — so the store path read `codebase-memory-mcp-0.6.0`,
  # three releases behind the code in it. Separately the binary reported `dev`,
  # because Makefile.cbm only picks up a real version when CI injects
  # `-DCBM_VERSION` through CFLAGS_EXTRA. That value is not cosmetic: cli.c feeds
  # it to `source_version` in the CLI and MCP JSON output, so an agent asking the
  # server what it is running was told `dev`.
  #
  # CFLAGS_EXTRA is only ever read in Makefile.cbm, never assigned, so make picks
  # it up from the environment.
  codebase-memory-mcp =
    _final: prev:
    let
      unstableVersion = "0.9.0-unstable-2026-07-27";
    in
    {
      codebase-memory-mcp =
        inputs.codebase-memory-mcp.packages.${prev.stdenv.hostPlatform.system}.default.overrideAttrs
          (old: {
            version = unstableVersion;
            env = (old.env or { }) // {
              CFLAGS_EXTRA = "-DCBM_VERSION=\\\"${unstableVersion}\\\"";
            };
            patches = (old.patches or [ ]) ++ [
              ./patches/codebase-memory-mcp-nix-function-header.patch
              ./patches/codebase-memory-mcp-nix-attrpath-variables.patch
            ];
          });
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
