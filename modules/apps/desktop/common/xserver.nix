{
  flake.features.xserver.linux = {
    services = {
      libinput.enable = true;
      xserver = {
        enable = true;
        xkb = {
          layout = "us";
          variant = "";
        };
      };
    };
  };
}
