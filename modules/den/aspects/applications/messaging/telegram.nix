{
  den.aspects.applications.messaging.telegram = {
    homeManager =
      { inputs', ... }:
      {
        home.packages = [
          inputs'.ayugram-desktop.packages.ayugram-desktop
        ];
      };
  };
}
