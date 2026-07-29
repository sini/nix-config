{ den, ... }:
{
  den.aspects.roles.messaging = {
    includes = with den.aspects; [
      applications.messaging.discord
      applications.messaging.element
      applications.messaging.kdeconnect
      applications.messaging.messenger
      applications.messaging.telegram
      applications.messaging.zoom
    ];
  };
}
