{
  flake.modules.nixos.xserver = {
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
