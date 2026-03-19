{
  environments.prod = {
    access = {
      # System admins (full login + admin access)
      sini = [
        "admins"
        "system-access"
        "wheel"
        "audio"
        "sound"
        "video"
        "networkmanager"
        "input"
        "tty"
        "podman"
        "media"
        "gamemode"
        "render"
        "libvirtd"
        "kvm"
      ];

      # Workstation users
      shuo = [
        "users"
        "workstation-access"
        "wheel"
        "audio"
        "sound"
        "video"
        "networkmanager"
        "input"
        "tty"
        "podman"
        "media"
        "gamemode"
        "render"
      ];
      will = [
        "users"
        "workstation-access"
        "wheel"
        "audio"
        "sound"
        "video"
        "networkmanager"
        "input"
        "tty"
        "podman"
        "media"
        "gamemode"
        "render"
      ];

      # Identity-only users (kanidm only)
      json = [ "admins" ];
      json_user = [ "users" ];
      greco = [ "users" ];
      taiche = [ "users" ];
      jennism = [ "users" ];
      hugs = [
        "users"
        "grafana.server-admins"
      ];
      ellen = [ "users" ];
      jenn = [ "users" ];
      tyr = [ "users" ];
      zogger = [ "users" ];
      jess = [ "users" ];
      leo = [ "users" ];
      vincentpierre = [ "users" ];
      you = [ "users" ];
      yiran = [ "users" ];
      louisabella = [ "users" ];
    };
  };
}
