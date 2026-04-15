{
  den,
  lib,
  inputs,
  ...
}:
{
  den.aspects.linux-kernel = {
    settings = {
      linux-kernel = {
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
      };
    };
    config = den.lib.perHost (
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
  };
}
