{
  den.aspects.apps.messaging.messenger = {
    homeManager =
      {
        pkgs,
        ...
      }:
      {
        home.packages = [
          pkgs.caprine
        ];
      };

    persistHome.directories = [
      ".config/Element"
    ];
  };
}
