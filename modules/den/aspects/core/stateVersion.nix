{ den, ... }:
{
  den.aspects.core.stateVersion = {
    nixos = {
      system.stateVersion = "26.05";
      home-manager.sharedModules = [
        { home.stateVersion = "26.05"; }
      ];
    };
  };
}
