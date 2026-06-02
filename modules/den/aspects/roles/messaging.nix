{ den, ... }:
{
  den.aspects.roles.messaging = {
    colmena = [ "messaging" ];
    includes = with den.aspects; [
      apps.messaging.discord
      apps.messaging.kdeconnect
      apps.messaging.telegram
      apps.messaging.zoom
    ];
  };
}
