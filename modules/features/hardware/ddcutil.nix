{
  features.ddcutil.linux =
    {
      config,
      pkgs,
      host,
      ...
    }:
    {
      boot = {
        kernelModules = [
          "i2c-dev"
        ];
        initrd.availableKernelModules = [
          "i2c-dev"
        ];
        extraModulePackages = with config.boot.kernelPackages; [
          ddcci-driver
        ];
      };

      environment.systemPackages = with pkgs; [
        ddcutil
      ];

      services.udev.packages = with pkgs; [
        ddcutil
      ];

      # Add all enabled users to the i2c group
      users.users = builtins.listToAttrs (
        map (userName: {
          name = userName;
          value = {
            extraGroups = [ "i2c" ];
          };
        }) host.users.enabledNames
      );
    };
}
