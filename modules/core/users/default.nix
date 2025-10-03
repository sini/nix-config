{
  flake.features.users.nixos =
    {
      users,
      ...
    }:
    let
      # Users are already filtered in specialArgs, so we just collect all user configurations
      enabledUsers = builtins.attrNames users;
      userConfigs = builtins.map (userName: users.${userName}.configuration) enabledUsers;
    in
    {
      imports = userConfigs;
      users.mutableUsers = false;
    };
}
