{ den, ... }:
{
  den.aspects.kde = den.lib.perHost {
    nixos = {
      services.desktopManager.plasma6.enable = true;
    };
  };
}
