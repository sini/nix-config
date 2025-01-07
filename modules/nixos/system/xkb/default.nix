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
  cfg = config.system.xkb;
in
{
  options.system.xkb = with types; {
    enable = mkBoolOpt false "Whether or not to configure xkb.";
  };

  config = mkIf cfg.enable {
    console.useXkbConfig = true;
    services.xserver = {
      layout = "us";
      xkbOptions = "caps:escape";
    };
  };
}
