{ den, ... }:
{
  den.aspects.avahi = den.lib.perHost (
    { host }:
    {
      nixos = {
        services.avahi = {
          enable = true;
          allowInterfaces = builtins.attrNames (host.networking.interfaces or { });
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
  );
}
