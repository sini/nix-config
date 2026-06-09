{
  den.aspects.core.nix.stateVersion = {
    darwin = {
      system.stateVersion = 6;
    };

    nixos = {
      system.stateVersion = "26.11";
    };

    homeManager = {
      home.stateVersion = "26.11";
    };
  };
}
