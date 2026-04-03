{ den, inputs, ... }:
{
  den.aspects.linux-kernel = den.lib.perHost {
    nixos =
      { pkgs, ... }:
      {
        nixpkgs.overlays = [
          inputs.nix-cachyos-kernel.overlays.default
        ];

        # xddxdd's binary cache for CachyOS kernels
        nix.settings.substituters = [ "https://attic.xuyh0120.win/lantian" ];
        nix.settings.trusted-public-keys = [
          "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
        ];

        # Default: server-lto variant
        boot.kernelPackages = pkgs.cachyosKernels."linuxPackages-cachyos-server-lto";
      };
  };
}
