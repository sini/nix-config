{ den, ... }:
{
  den.aspects.coolercontrol = den.lib.perHost {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [ liquidctl ];

        programs = {
          coolercontrol = {
            enable = true;
          };
        };
      };
  };
}
