{
  features.users.linux =
    { flakeLib, users, ... }:
    {
      # Let all users with the "wheel" group have their keys in the authorized_keys for root.
      users.users.root.openssh.authorizedKeys.keys = flakeLib.users.getSshKeysForGroup users "wheel";
    };
}
