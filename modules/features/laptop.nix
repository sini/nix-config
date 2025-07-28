{
  flake.modules.nixos.laptop = {
    services = {
      # tlp.enable = true;
      logind = {
        lidSwitch = "ignore";
        lidSwitchDocked = "ignore";
        lidSwitchExternalPower = "ignore";
        extraConfig = ''
          HandlePowerKey=suspend
          HandleSuspendKey=suspend
          HandleHibernateKey=suspend
          PowerKeyIgnoreInhibited=yes
          SuspendKeyIgnoreInhibited=yes
          HibernateKeyIgnoreInhibited=yes
        '';
      };
    };

  };
  # systemd.sleep.extraConfig = lib.mkDefault "HibernateDelaySec=60m"; # Delay hibernate 60min after sleep.
  # services.logind.extraConfig = ''
  #   HandlePowerKey=suspend-then-hibernate
  #   IdleAction=suspend-then-hibernate
  #   IdleActionSec=10m
  # '';

}
