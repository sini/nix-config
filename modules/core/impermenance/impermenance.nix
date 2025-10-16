{ inputs, ... }:
{
  flake.features.impermenance.nixos =
    { lib, config, ... }:
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];
      chaotic.zfs-impermanence-on-shutdown = {
        # since this option enables the wiping of the root FS, I use it as
        # condition for `environment.persistence` in other modules
        enable = true;
        volume = "zroot/local/root";
        snapshot = "blank";
      };

      environment.persistence = {
        "/persist" = {
          hideMounts = true;
          directories = [
            "/var/lib/systemd"
            "/var/lib/nixos"
            "/var/log"
          ];
          files = [
            "/etc/machine-id"
            "/etc/adjtime"
          ];
        };
      };

      systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

      # Needed for home-manager's impermanence allowOther option to work
      programs.fuse.userAllowOther = true;

      system.activationScripts.persistent-dirs.text =
        let
          mkHomePersist =
            user:
            lib.optionalString user.createHome ''
              mkdir -p /persist/${user.home}
              chown ${user.name}:${user.group} /persist/${user.home}
              chmod ${user.homeMode} /persist/${user.home}
              mkdir -p /cache/${user.home}
              chown ${user.name}:${user.group} /cache/${user.home}
              chmod ${user.homeMode} /cache/${user.home}
            '';
          users = lib.attrValues config.users.users;
        in
        lib.concatLines (map mkHomePersist users);
    };
}
