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
  };

  config = mkIf cfg.enable {
    networking.networkmanager.enable = true;
    systemd.services.NetworkManager-wait-online.enable = false;
    systemd.network.wait-online.anyInterface = true;
  };
}
