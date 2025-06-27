{ config, ... }:
let
  user = config.flake.meta.user.username;
in
{
  flake.modules.nixos.doas =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        doas
        doas-sudo-shim
      ];

      # Disable sudo
      security.sudo.enable = false;

      # Enable and configure `doas`.
      security.doas = {
        enable = true;
        wheelNeedsPassword = false;
        extraRules = [
          {
            users = [ user ];
            noPass = true;
            keepEnv = true;
          }
        ];
      };
    };
}
