{ den, lib, ... }:
{
  den.aspects.forgejo = {
    includes = lib.attrValues den.aspects.forgejo._;

    _ = {
      config = den.lib.perHost {
        nixos =
          { config, lib, ... }:
          {
            users.groups.git = { };
            users.users.git = {
              isSystemUser = true;
              useDefaultShell = true;
              group = "git";
              home = config.services.forgejo.stateDir;
            };

            services.openssh = {
              authorizedKeysFiles = lib.mkForce [
                "${config.services.forgejo.stateDir}/.ssh/authorized_keys"
              ];
              # Recommended by forgejo: https://forgejo.org/docs/latest/admin/recommendations/#git-over-ssh
              settings.AcceptEnv = [ "GIT_PROTOCOL" ];
            };
          };
      };

      firewall = den.lib.perHost {
        firewall.allowedTCPPorts = [ 7654 ];
      };

      impermanence = den.lib.perHost {
        nixos =
          { config, ... }:
          {
            environment.persistence."/persist".directories = [
              {
                directory = config.services.forgejo.stateDir;
                inherit (config.services.forgejo) user group;
                mode = "0700";
              }
            ];
          };
      };
    };
  };
}
