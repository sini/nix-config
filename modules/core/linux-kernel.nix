{ lib, ... }:
{
  features.linux-kernel = {
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

    linux =
      {
        pkgs,
        settings,
        ...
      }:
      let
        cfg = settings.linux-kernel;

        # server is a standalone variant, not a channel+arch combination
        kernelName =
          if cfg.optimization == "server" then
            "linuxPackages-cachyos-server-lto"
          else
            "linuxPackages-cachyos-${cfg.channel}-lto-${cfg.optimization}";
      in
      {
        boot.kernelPackages = pkgs.cachyosKernels.${kernelName};
      };
  };
}
