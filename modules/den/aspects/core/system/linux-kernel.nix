# linux-kernel — CachyOS kernel selection.
#
# Ported from main:modules/_legacy/core/linux-kernel.nix.
{ lib, ... }:
{
  den.aspects.core.system.linux-kernel = {
    nixpkgs-overlays =
      { inputs', ... }:
      [
        # lld 21 built by GCC 16 corrupts `ld -r` output, so objtool rejects
        # every multi-object LTO module (nixpkgs#571232). lld 22 carries the
        # upstream fix (llvm/llvm-project@905a88b); build the kernels with it.
        (
          final: prev:
          inputs'.nix-cachyos-kernel.overlays.default final (
            prev.extend (_: p: { llvmPackages = p.llvmPackages_22; })
          )
        )

        # 7.2.5 added a memchr() bounds check to gud_connector_add_tv_mode();
        # Clang LTO can't prove num_modes <= GUD_CONNECTOR_TV_MODE_MAX_NUM, so
        # FORTIFY_SOURCE emits __read_overflow and every -lto variant fails to
        # link. Still unfixed in 7.2.6. Nothing in the fleet is a USB display.
        #
        # 7.3.3 with nixpkgs 2026-11-07 (pahole 1.32): BTF for the two Rust modules
        # fails ("FAILED: load BTF from drivers/block/rnull/rnull_mod.ko.BTF.1"), which
        # stops the modules build. Both are unused here: rnull is the Rust null-block
        # test driver, cpufreq-dt-rust a device-tree (ARM) cpufreq driver.
        (_final: prev: {
          cachyosKernels = lib.mapAttrs (
            _: v:
            if v ? kernel then
              v.extend (
                _: prevPkgs: {
                  kernel = prevPkgs.kernel.override {
                    structuredExtraConfig = {
                      DRM_GUD = lib.kernel.no;
                      BLK_DEV_RUST_NULL = lib.kernel.no;
                      CPUFREQ_DT_RUST = lib.kernel.no;
                    };
                  };
                }
              )
            else
              v
          ) prev.cachyosKernels;
        })
      ];

    settings = {
      channel = lib.mkOption {
        type = lib.types.enum [
          "lts"
          "latest"
        ];
        default = "latest";
        description = "CachyOS kernel release channel";
      };
      optimization = lib.mkOption {
        type = lib.types.enum [
          "server"
          "zen4"
          "x86_64-v4"
        ];
        default = "server";
        description = "CachyOS kernel optimization target";
      };
      # CachyOS ships MGLRU's thrashing guard on: once swap is full and kswapd cannot keep this
      # many ms of working set resident, kswapd invokes the OOM killer, with free memory left.
      # 0 disables the guard; real allocation failures still reach the ordinary OOM path.
      mglruMinTtlMs = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.unsigned;
        default = null;
        description = "/sys/kernel/mm/lru_gen/min_ttl_ms (null keeps the kernel default)";
      };
    };

    nixos =
      { host, pkgs, ... }:
      let
        cfg = host.settings.core.system.linux-kernel;
        kernelName =
          if cfg.optimization == "server" then
            "linuxPackages-cachyos-server-lto"
          else
            "linuxPackages-cachyos-${cfg.channel}-lto-${cfg.optimization}";
      in
      {
        boot.kernelPackages =
          if pkgs ? cachyosKernels && pkgs.cachyosKernels ? ${kernelName} then
            pkgs.cachyosKernels.${kernelName}
          else if pkgs ? ${kernelName} then
            pkgs.${kernelName}
          else
            pkgs.linuxPackages_latest;

        systemd.tmpfiles.rules = lib.optional (
          cfg.mglruMinTtlMs != null
        ) "w /sys/kernel/mm/lru_gen/min_ttl_ms - - - - ${toString cfg.mglruMinTtlMs}";
      };
  };
}
