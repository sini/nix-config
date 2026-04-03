{ den, inputs, ... }:
{
  den.aspects.facter = den.lib.perHost (
    { host }:
    {
      nixos =
        { lib, ... }:
        {
          imports = [ inputs.nixos-facter-modules.nixosModules.facter ];
          facter = {
            reportPath = lib.mkIf (host ? facts) host.facts;
            detected = {
              dhcp.enable = false;
              graphics.enable = false;
            };
          };
        };
    }
  );
}
