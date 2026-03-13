{
  flake.features.ssd.linux = {
    services.fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
