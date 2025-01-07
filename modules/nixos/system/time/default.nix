{
  options,
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.system.time;
in
{
  options.system.time = with types; {
    enable = mkBoolOpt false "Whether or not to configure timezone information.";
  };

  config = mkIf cfg.enable { time.timeZone = "America/Los_Angeles"; };
}
