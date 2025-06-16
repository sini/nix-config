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
    #catppuccin.tty.enable = true;
    catppuccin.plymouth.enable = true;
    catppuccin.plymouth.flavor = "mocha";
    boot = {
      plymouth.enable = true;
    };
  };
}
