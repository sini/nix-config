{
  flake.features.ssd.nixos = {
    services.fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
