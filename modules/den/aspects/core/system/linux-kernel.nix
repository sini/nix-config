# linux-kernel — CachyOS kernel selection.
#
# Ported from main:modules/_legacy/core/linux-kernel.nix.
{ lib, ... }:
{
  den.aspects.core.system.linux-kernel = {
    nixpkgs-overlays =
      { inputs', ... }:
      [ inputs'.nix-cachyos-kernel.overlays.default ];

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
        nix.settings.substituters = [ "https://attic.xuyh0120.win/lantian" ];
        nix.settings.trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];

        boot.kernelPackages =
          if pkgs ? cachyosKernels && pkgs.cachyosKernels ? ${kernelName} then
            pkgs.cachyosKernels.${kernelName}
          else if pkgs ? ${kernelName} then
            pkgs.${kernelName}
          else
            pkgs.linuxPackages_latest;
      };
  };
}
