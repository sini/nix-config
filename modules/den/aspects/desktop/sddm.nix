_: {
  den.aspects.desktop.sddm = {
    nixos = {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
    };
  };
}
