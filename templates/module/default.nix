# deadnix: skip
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
  cfg = config.module;
in
{
  options.module = with types; {
    enable = mkBoolOpt false "Enable module";
  };

  config = mkIf cfg.enable {
  };
}
