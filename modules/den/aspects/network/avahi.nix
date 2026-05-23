_:
{
  den.aspects.network.avahi = {
    nixos =
      { host, ... }:
      let
        interfaces = builtins.attrNames host.networking.interfaces;
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
  };
}
