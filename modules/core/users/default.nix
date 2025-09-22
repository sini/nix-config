{
  flake.modules.nixos.users =
    {
      users,
      # hostOptions,
      # lib,
      ...
    }:
    let
      # Get users specified for this host (we'll need to add this to host options later)
      # For now, let's include all users by default
      enabledUsers = builtins.attrNames users;

      # Collect all user configurations
      userConfigs = builtins.map (userName: users.${userName}.userConfig) enabledUsers;
    in
    {
      imports = userConfigs;
    };
}
