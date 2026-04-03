{ den, inputs, ... }:
{
  den.aspects.linux-kernel = den.lib.perHost (
    { host }:
    {
      nixos =
        { pkgs, ... }:
        let
          cfg = host.settings.linux-kernel;
          # server is a standalone variant, not a channel+arch combination
          kernelName =
            if cfg.optimization == "server" then
              "linuxPackages-cachyos-server-lto"
            else
              "linuxPackages-cachyos-${cfg.channel}-lto-${cfg.optimization}";
        in
        {
          nixpkgs.overlays = [
            inputs.nix-cachyos-kernel.overlays.default
          ];

          # xddxdd's binary cache for CachyOS kernels
          nix.settings.substituters = [ "https://attic.xuyh0120.win/lantian" ];
          nix.settings.trusted-public-keys = [
            "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
          ];

          boot.kernelPackages = pkgs.cachyosKernels.${kernelName};
        };
    }
  );
}
