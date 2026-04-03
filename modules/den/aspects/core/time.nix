{ den, ... }:
{
  den.aspects.time = den.lib.perHost (
    { host }:
    {
      os.time.timeZone = host.environment.timezone or "UTC";
    }
  );
}
