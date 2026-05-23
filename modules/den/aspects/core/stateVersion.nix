_: {
  den.aspects.core.stateVersion = {
    darwin = {
      system.stateVersion = 6;
      home-manager.sharedModules = [
        { home.stateVersion = "26.05"; }
      ];
    };
    nixos = {
      system.stateVersion = "26.05";
      home-manager.sharedModules = [
        { home.stateVersion = "26.05"; }
      ];
    };
  };
}
