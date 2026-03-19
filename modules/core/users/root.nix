{
  features.users.linux =
    { config, lib, ... }:
    {
      # Let all users with the "wheel" group have their keys in the authorized_keys for root.
      users.users.root.openssh.authorizedKeys.keys =
        with lib;
        concatLists (
          mapAttrsToList (
            _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
          ) config.users.users
        );
    };
}
