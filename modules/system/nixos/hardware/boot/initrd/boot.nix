{
  config,
  lib,
  ...
}:
{
  config = {
    boot = {
      initrd = {
        availableKernelModules = [
          "r8169"
          "mlx4_core"
        ];
        systemd.users.root.shell = "/bin/systemd-tty-ask-password-agent";
        network = {
          enable = true;
          ssh = {
            enable = true;
            port = 22;
            authorizedKeys =
              with lib;
              concatLists (
                mapAttrsToList (
                  _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
                ) config.users.users
              );
            hostKeys = [
              config.age.secrets.initrd_host_ed25519_key.path
            ];
          };
        };
      };

      kernelParams = [
        "ip=dhcp"
      ];
    };
  };
}
