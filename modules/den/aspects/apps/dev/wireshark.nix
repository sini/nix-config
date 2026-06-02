_: {
  den.aspects.apps.dev.wireshark = {
    os =
      { pkgs, ... }:
      {
        programs.wireshark = {
          enable = true;
          package = pkgs.wireshark;
        };
      };

    nixos =
      { resolved-users, lib, ... }:
      {
        users.users = lib.genAttrs (map (u: u.name) resolved-users) (_: {
          extraGroups = [ "wireshark" ];
        });
      };

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.termshark
        ];
      };
  };
}
