{ den, ... }:
{
  den.aspects.roles.messaging = {
    colmena = [ "messaging" ];
    includes = with den.aspects; [
      apps.messaging.discord
      apps.messaging.element
      apps.messaging.kdeconnect
      apps.messaging.messenger
      apps.messaging.telegram
      apps.messaging.zoom
    ];
  };
}
