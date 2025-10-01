{
  flake.aspects.gdm.nixos = {
    services = {
      displayManager = {
        gdm = {
          enable = true;
          autoSuspend = false;
          wayland = true;
        };
      };
    };
  };
}
