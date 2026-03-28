{
  # We are having issues with the nixpkg socket... so lets stash our own service for now with fixed users.
  features.forgejo.linux =
    {
      config,
      # environment,
      lib,
      ...
    }:
    {
      users.groups.git = { };
      users.users.git = {
        isSystemUser = true;
        useDefaultShell = true;
        group = "git";
        home = config.services.forgejo.stateDir;
      };

      networking.firewall.allowedTCPPorts = [ 7654 ];

      services.openssh = {
        authorizedKeysFiles = lib.mkForce [
          "${config.services.forgejo.stateDir}/.ssh/authorized_keys"
        ];
        # Recommended by forgejo: https://forgejo.org/docs/latest/admin/recommendations/#git-over-ssh
        settings.AcceptEnv = [ "GIT_PROTOCOL" ];
      };

    };

  features.forgejo.provides.impermanence.linux =
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
}
