{
  flake.aspects.ssd.nixos = {
    services.fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
