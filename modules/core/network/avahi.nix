{
  flake.features.avahi.nixos =
    { config, ... }:
    let
      cfg = config.hardware.networking;
    in
    {
      services.avahi = {
        enable = true;
        allowInterfaces = cfg.interfaces;
        nssmdns4 = true;
        nssmdns6 = true;
        publish = {
          enable = true;
          addresses = true;
          domain = true;
          hinfo = true;
          userServices = true;
          workstation = true;
        };
      };
    };
}
