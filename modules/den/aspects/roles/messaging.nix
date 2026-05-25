{ den, ... }:
{
  den.aspects.roles.messaging = {
    colmena = [ "messaging" ];
    includes = with den.aspects; [
      apps.discord
      apps.kdeconnect
      apps.telegram
      apps.zoom
    ];
  };
}
