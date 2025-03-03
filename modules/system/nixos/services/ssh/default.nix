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
  cfg = config.services.ssh;
in
{
  options.services.ssh = with types; {
    enable = mkBoolOpt false "Enable ssh";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      ports = [ 22 ];

      openFirewall = true;

      settings.PermitRootLogin = "prohibit-password";

      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };

      extraConfig = ''
        AllowTcpForwarding yes
        X11Forwarding no
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
        AuthenticationMethods publickey
      '';
    };

    # Let all users with the wheel group have their keys in the authorized_keys for root
    users.users.root.openssh.authorizedKeys.keys =
      with lib;
      concatLists (
        mapAttrsToList (
          _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
        ) config.users.users
      );
  };
}
