{ den, ... }:
{
  den.aspects.sini = {
    includes = [
      den._.primary-user
      den.aspects.shell
    ];

    user = {
      isNormalUser = true;
      description = "Jason Bowman";
    };

    homeManager =
      { lib, ... }:
      {
        home.stateVersion = lib.mkDefault "25.11";
      };
  };
}
