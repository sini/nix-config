{ den, ... }:
{
  den.aspects.apps.wireshark = {
    nixos =
      {
        pkgs,
        host,
        ...
      }:
      {
        programs.wireshark = {
          enable = true;
          package = pkgs.wireshark;
        };

        # TODO: restore per-user wireshark group assignment — needs host.users.enabledNames
        # or equivalent from den's user resolution. For now, system-owner only.
        users.users.${host.system-owner or "root"}.extraGroups = [ "wireshark" ];
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
