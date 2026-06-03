{
  den.aspects.apps.mail.protonmail = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          protonmail-bridge
        ];

      };

    homeLinux =
      { pkgs, ... }:
      {
        services.protonmail-bridge = {
          enable = true;
          path = with pkgs; [
            gnome-keyring
            libnotify
            gnupg
          ];
        };
      };
  };
}
