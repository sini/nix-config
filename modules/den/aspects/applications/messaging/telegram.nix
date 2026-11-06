{
  den.aspects.applications.messaging.telegram = {
    homeManager =
      { inputs', ... }:
      {
        home.packages = [
          inputs'.ayugram-desktop.packages.ayugram-desktop
        ];
      };

    # The AyuGram session and its media.
    persistHome.directories = [
      ".local/share/AyuGramDesktop"
    ];
  };
}
