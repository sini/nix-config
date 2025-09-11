{
  flake.modules.nixos.time =
    { environment, ... }:
    {
      time.timeZone = environment.timezone or "UTC";
    };
}
