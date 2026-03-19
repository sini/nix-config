{
  features.time.system =
    { environment, ... }:
    {
      time.timeZone = environment.timezone or "UTC";
    };
}
