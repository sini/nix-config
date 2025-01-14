{ pkgs, config, ... }:
{
  imports = [
    ../shared/boot.nix
  ];

  facter.reportPath = ./facter.json;

  topology.self = {
    hardware.info = "burst";
    services.k8s.name = "k8s";
  };

  hardware.disk.single.enable = true;

  config.hardware.networking.enable = true;

  config.services.ssh.enable = true;
  config.programs.dconf.enable = true;

  config.system.nix.enable = true;
  config.time.timeZone = "America/Los_Angeles";
  config.i18n.defaultLocale = "en_US.UTF-8";

  configconsole = {
    keyMap = mkForce "us";
  };

  environment.systemPackages = with pkgs; [
    # Any particular packages only for this host
    wget
    vim
    git
    doas
    doas-sudo-shim
  ];

  services = {
    rpcbind.enable = true; # needed for NFS
  };

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = "24.11";
  # ======================== DO NOT CHANGE THIS ========================
}
