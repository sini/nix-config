{
  den.aspects.apps.messaging.element = {
    homeLinux =
      {
        pkgs,
        ...
      }:
      {
        home.packages = [
          pkgs.element-desktop
        ];
      };

    darwin = {
      # TODO: Darwin support...
      #homebrew.casks = [ "element" ];
    };

    persistHome.directories = [
      ".config/Element"
    ];
  };
}
