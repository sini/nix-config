{
  options,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.hardware.networking;
in
{
  options.hardware.networking = with types; {
    enable = mkBoolOpt false "Enable networkmanager";
    interface = mkOption {
      type = types.str;
      default = "enp1s0";
      description = "The interface to configure";
    };
  };

  config = mkIf cfg.enable {
    networking.useDHCP = true;

    systemd.network = {
      enable = true;
      wait-online.enable = false;
      networks = {
        "${cfg.interface}" = {
          enable = true;
          matchConfig.Name = cfg.interface;
          networkConfig.DHCP = "yes";
        };
      };
    };

    #TODO: Remove this once we have a better way to expose ports...
    networking.firewall.enable = false;

  };
}
