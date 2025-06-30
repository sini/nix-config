{
  flake.modules.nixos.ssd = {
    services.fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
