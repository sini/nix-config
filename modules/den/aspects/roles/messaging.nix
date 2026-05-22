{ den, ... }:
{
  den.aspects.roles.messaging = {
    includes = with den.aspects; [
      apps.discord
      apps.kdeconnect
      apps.telegram
      apps.zoom
    ];
  };
}
