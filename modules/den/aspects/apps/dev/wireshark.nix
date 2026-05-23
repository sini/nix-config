_:
{
  den.aspects.apps.wireshark = {
    os =
      { pkgs, ... }:
      {
        programs.wireshark = {
          enable = true;
          package = pkgs.wireshark;
        };
      };

    nixos =
      { host, lib, ... }:
      {
        users.users = lib.genAttrs (builtins.attrNames host.users) (_: {
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
