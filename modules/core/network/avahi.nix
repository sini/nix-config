{
  flake.features.avahi.nixos =
    { hostOptions, ... }:
    let
      interfaces = builtins.attrNames hostOptions.networking.interfaces;
    in
    {
      services.avahi = {
        enable = true;
        allowInterfaces = interfaces;
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
        openFirewall = true;
      };
    };
}
