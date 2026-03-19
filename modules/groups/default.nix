{
  groups = {
    # =========================================================================
    # Identity groups (kanidm)
    # =========================================================================
    admins = {
      scope = "kanidm";
      description = "Full administrative access";
    };
    users = {
      scope = "kanidm";
      description = "Standard user access";
      members = [ "admins" ];
    };

    # =========================================================================
    # System login gates
    # =========================================================================
    system-access = {
      scope = "system";
      description = "Login access to all hosts";
    };
    workstation-access = {
      scope = "system";
      description = "Login access to workstation hosts";
      members = [ "system-access" ];
    };
    server-access = {
      scope = "system";
      description = "Login access to server hosts";
      members = [ "system-access" ];
    };

    # =========================================================================
    # Service access (kanidm oauth2)
    # =========================================================================

    # Grafana
    "grafana.access" = {
      scope = "kanidm";
      description = "Grafana login";
      members = [ "users" ];
    };
    "grafana.editors" = {
      scope = "kanidm";
      description = "Grafana editor role";
    };
    "grafana.admins" = {
      scope = "kanidm";
      description = "Grafana admin role";
    };
    "grafana.server-admins" = {
      scope = "kanidm";
      description = "Grafana server admin role";
      members = [ "admins" ];
    };

    # Media (Jellyfin)
    "media.access" = {
      scope = "kanidm";
      description = "Jellyfin access";
      members = [ "users" ];
    };
    "media.admins" = {
      scope = "kanidm";
      description = "Jellyfin admin role";
      members = [ "admins" ];
    };

    # ArgoCD
    "argocd.access" = {
      scope = "kanidm";
      description = "ArgoCD access";
      members = [ "users" ];
    };
    "argocd.admins" = {
      scope = "kanidm";
      description = "ArgoCD admin role";
      members = [ "admins" ];
    };

    # Forgejo
    "forgejo.access" = {
      scope = "kanidm";
      description = "Forgejo access";
      members = [ "users" ];
    };
    "forgejo.admins" = {
      scope = "kanidm";
      description = "Forgejo admin role";
      members = [ "admins" ];
    };

    # Headscale VPN
    "vpn.users" = {
      scope = "kanidm";
      description = "Headscale VPN access";
      members = [ "admins" ];
    };

    # Open WebUI
    "open-webui.access" = {
      scope = "kanidm";
      description = "Open WebUI access";
      members = [ "admins" ];
    };
    "open-webui.admins" = {
      scope = "kanidm";
      description = "Open WebUI admin role";
      members = [ "admins" ];
    };

    # =========================================================================
    # Unix system groups
    # =========================================================================
    wheel = {
      scope = "unix";
      description = "Sudo access";
    };
    audio = {
      scope = "unix";
      description = "Audio device access";
    };
    sound = {
      scope = "unix";
      description = "Sound device access";
    };
    video = {
      scope = "unix";
      description = "Video device access";
    };
    networkmanager = {
      scope = "unix";
      description = "NetworkManager control";
    };
    input = {
      scope = "unix";
      description = "Input device access";
    };
    tty = {
      scope = "unix";
      description = "TTY access";
    };
    podman = {
      scope = "unix";
      description = "Container runtime access";
    };
    media = {
      scope = "unix";
      description = "Media files access";
    };
    gamemode = {
      scope = "unix";
      description = "GameMode access";
    };
    render = {
      scope = "unix";
      description = "GPU render access";
    };
    libvirtd = {
      scope = "unix";
      description = "VM management access";
    };
    kvm = {
      scope = "unix";
      description = "KVM hypervisor access";
    };
  };
}
