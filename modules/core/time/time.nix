{
  flake.features.time.nixos =
    { environment, ... }:
    {
      time.timeZone = environment.timezone or "UTC";
    };
}
