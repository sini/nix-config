{
  features.time.os =
    { environment, ... }:
    {
      time.timeZone = environment.timezone or "UTC";
    };
}
