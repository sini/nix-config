{
  flake.features.users.nixos =
    {
      users,
      hostOptions,
      environment,
      ...
    }:
    let
      # Users are already filtered in specialArgs, so we just collect all user configurations
      enabledUsers = builtins.attrNames users;

      # Function to build merged user configuration from all sources
      buildUserConfig =
        userName:
        let
          # Get user from flake.users
          baseUser = users.${userName} or { };
          baseConfig = baseUser.configuration or { };

          # Get user from environment
          envUser = environment.users.${userName} or { };
          envConfig = envUser.configuration or { };

          # Get user from host
          hostUser = hostOptions.users.${userName} or { };
          hostConfig = hostUser.configuration or { };

          # Merge all configurations - later configs can override earlier ones
          mergedConfig = {
            imports = [
              baseConfig
              envConfig
              hostConfig
            ];
          };
        in
        mergedConfig;

      userConfigs = map buildUserConfig enabledUsers;
    in
    {
      imports = userConfigs;
      users.mutableUsers = false;
    };
}
