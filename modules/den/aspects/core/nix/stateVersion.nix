{
  den.aspects.core.nix.stateVersion = {
    darwin = {
      system.stateVersion = 6;
    };

    nixos = {
      system.stateVersion = "26.05";
    };

    homeManager = {
      home.stateVersion = "26.05";
    };
  };
}
