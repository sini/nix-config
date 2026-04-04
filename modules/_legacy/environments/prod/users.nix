{
  environments.prod = {
    access = {
      # System admins (full login + admin access)
      # system-access grants workstation-access transitively, which includes:
      # wheel, audio, sound, video, networkmanager, input, tty, podman, media, gamemode, render
      sini = [
        "admins"
        "system-access"
        "libvirtd"
        "kvm"
      ];

      # Workstation users
      # workstation-access grants: wheel, audio, sound, video, networkmanager, input, tty, podman, media, gamemode, render
      shuo = [
        "users"
        "workstation-access"
      ];
      will = [
        "users"
        "workstation-access"
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
