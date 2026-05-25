{ den, ... }:
{
  den.aspects.roles.messaging = {
    colmena-tags = [ "messaging" ];
    includes = with den.aspects; [
      apps.discord
      apps.kdeconnect
      apps.telegram
      apps.zoom
    ];
  };
}
