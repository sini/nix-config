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
      settings.PermitRootLogin = "prohibit-password";
    };

    # Let all users with the wheel group have their keys in the authorized_keys for root
    users.users.root.openssh.authorizedKeys.keys =
      with lib;
      concatLists (
        mapAttrsToList (
          _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
        ) config.users.users
      );

    home.file.".ssh/config".text = ''
      identityfile ~/.ssh/key
    '';
  };
}
