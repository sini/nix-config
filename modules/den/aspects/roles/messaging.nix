# Messaging role: communication apps.
{ den, ... }:
{
  den.aspects.messaging = {
    includes = [
      den.aspects.discord
      den.aspects.kdeconnect
      den.aspects.telegram
      den.aspects.zoom
    ];
  };
}
