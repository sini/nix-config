{
  config,
  lib,
  ...
}:
with lib;
with lib.custom;
let
  cfg = config.hardware.boot.plymouth;
in
{
  options.hardware.boot.plymouth = {
    enable = mkBoolOpt true "Enable plymouth";
  };

  config = mkIf cfg.enable {
    boot = {
      plymouth = {
        enable = true;
        catppuccin = {
          enable = true;
          flavor = "mocha";
        };
      };
    };
  };
}
