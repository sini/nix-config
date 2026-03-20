{
  groups = {
    # =========================================================================
    # User role groups (identity & login gates)
    # =========================================================================
    admins = {
      labels = [
        "user-role"
        "oauth-grant"
      ];
      description = "Full administrative access";
    };
    users = {
      labels = [
        "user-role"
        "oauth-grant"
      ];
      description = "Standard user access";
      members = [ "admins" ];
    };

    # =========================================================================
    # System login gates
    # =========================================================================
    system-access = {
      labels = [ "user-role" ];
      description = "Login access to all hosts";
    };
    workstation-access = {
      labels = [ "user-role" ];
      description = "Login access to workstation hosts";
      members = [ "system-access" ];
    };
    server-access = {
      labels = [ "user-role" ];
      description = "Login access to server hosts";
      members = [ "system-access" ];
    };

    # =========================================================================
    # Service access (OAuth2 grants)
    # =========================================================================

    # Grafana
    "grafana.access" = {
      labels = [ "oauth-grant" ];
      description = "Grafana login";
      members = [ "users" ];
    };
    "grafana.editors" = {
      labels = [ "oauth-grant" ];
      description = "Grafana editor role";
    };
    "grafana.admins" = {
      labels = [ "oauth-grant" ];
      description = "Grafana admin role";
    };
    "grafana.server-admins" = {
      labels = [ "oauth-grant" ];
      description = "Grafana server admin role";
      members = [ "admins" ];
    };

    # Media (Jellyfin)
    "media.access" = {
      labels = [ "oauth-grant" ];
      description = "Jellyfin access";
      members = [ "users" ];
    };
    "media.admins" = {
      labels = [ "oauth-grant" ];
      description = "Jellyfin admin role";
      members = [ "admins" ];
    };

    # ArgoCD
    "argocd.access" = {
      labels = [ "oauth-grant" ];
      description = "ArgoCD access";
      members = [ "users" ];
    };
    "argocd.admins" = {
      labels = [ "oauth-grant" ];
      description = "ArgoCD admin role";
      members = [ "admins" ];
    };

    # Forgejo
    "forgejo.access" = {
      labels = [ "oauth-grant" ];
      description = "Forgejo access";
      members = [ "users" ];
    };
    "forgejo.admins" = {
      labels = [ "oauth-grant" ];
      description = "Forgejo admin role";
      members = [ "admins" ];
    };

    # Headscale VPN
    "vpn.users" = {
      labels = [ "oauth-grant" ];
      description = "Headscale VPN access";
      members = [ "admins" ];
    };

    # Open WebUI
    "open-webui.access" = {
      labels = [ "oauth-grant" ];
      description = "Open WebUI access";
      members = [ "admins" ];
    };
    "open-webui.admins" = {
      labels = [ "oauth-grant" ];
      description = "Open WebUI admin role";
      members = [ "admins" ];
    };

    # =========================================================================
    # POSIX groups (Unix permissions with gidNumber)
    # =========================================================================
    # Common workstation groups (inherited by workstation-access members)
    wheel = {
      labels = [ "posix" ];
      gid = 10;
      description = "Sudo access";
      members = [ "workstation-access" ];
    };
    audio = {
      labels = [ "posix" ];
      gid = 63;
      description = "Audio device access";
      members = [ "workstation-access" ];
    };
    sound = {
      labels = [ "posix" ];
      gid = 64;
      description = "Sound device access";
      members = [ "workstation-access" ];
    };
    video = {
      labels = [ "posix" ];
      gid = 44;
      description = "Video device access";
      members = [ "workstation-access" ];
    };
    networkmanager = {
      labels = [ "posix" ];
      gid = 84;
      description = "NetworkManager control";
      members = [ "workstation-access" ];
    };
    input = {
      labels = [ "posix" ];
      gid = 40;
      description = "Input device access";
      members = [ "workstation-access" ];
    };
    tty = {
      labels = [ "posix" ];
      gid = 5;
      description = "TTY access";
      members = [ "workstation-access" ];
    };
    podman = {
      labels = [ "posix" ];
      gid = 993;
      description = "Container runtime access";
      members = [ "workstation-access" ];
    };
    media = {
      labels = [ "posix" ];
      gid = 900;
      description = "Media files access";
      members = [ "workstation-access" ];
    };
    gamemode = {
      labels = [ "posix" ];
      gid = 981;
      description = "GameMode access";
      members = [ "workstation-access" ];
    };
    render = {
      labels = [ "posix" ];
      gid = 106;
      description = "GPU render access";
      members = [ "workstation-access" ];
    };

    # Specialized groups (not inherited by workstation-access)
    libvirtd = {
      labels = [ "posix" ];
      gid = 901;
      description = "VM management access";
    };
    kvm = {
      labels = [ "posix" ];
      gid = 902;
      description = "KVM hypervisor access";
    };
  };
}
