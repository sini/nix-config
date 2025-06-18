{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.hardware.boot.plymouth;
in
{
  options.hardware.boot.plymouth = {
    enable = mkBoolOpt true "Enable plymouth";
  };

  config = mkIf cfg.enable {
    # catppuccin.enable = true;
    # catppuccin.flavor = "mocha";
    boot = {
      plymouth = {
        enable = true;
        # catppuccin = {
        #   enable = true;
        #   flavor = "mocha";
        # };
      };
    };
  };
}
