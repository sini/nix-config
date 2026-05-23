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
      { host, ... }:
      {
        # den host schema exposes system-owner, not user lists;
        # grant wireshark group to system-owner (covers primary user)
        users.users.${host.system-owner}.extraGroups = [ "wireshark" ];
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
