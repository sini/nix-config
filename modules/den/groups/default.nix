# Group definitions — user roles, system gates, service access, and POSIX groups.
{
  den.groups = {
    # User role groups (identity & login gates)
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

    # System login gates
    system-access = {
      labels = [
        "user-role"
        "posix"
      ];
      description = "Login access to all hosts";
    };
    workstation-access = {
      labels = [
        "user-role"
        "posix"
      ];
      description = "Login access to workstation hosts";
      members = [ "system-access" ];
    };
    server-access = {
      labels = [
        "user-role"
        "posix"
      ];
      description = "Login access to server hosts";
      members = [ "system-access" ];
    };

    # Service access (OAuth2 grants)
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
    "matrix.access" = {
      labels = [ "oauth-grant" ];
      description = "Matrix (Synapse) login";
      members = [ "users" ];
    };
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
    "vpn.users" = {
      labels = [ "oauth-grant" ];
      description = "Headscale VPN access";
      members = [
        "admins"
        "system-access"
        "server-access"
        "workstation-access"
      ];
    };
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
    "coder.access" = {
      labels = [ "oauth-grant" ];
      description = "Coder access";
      members = [ "users" ];
    };
    "coder.admins" = {
      labels = [ "oauth-grant" ];
      description = "Coder admin role";
      members = [ "admins" ];
    };
    "opkssh.access" = {
      labels = [ "oauth-grant" ];
      description = "Members may obtain an opkssh OIDC SSH token from kanidm.";
      members = [
        "admins"
        "system-access"
        "server-access"
        "workstation-access"
      ];
    };

    # POSIX groups (Unix permissions)
    wheel = {
      labels = [ "posix" ];
      description = "Sudo access";
      members = [ "admins" ];
    };
    audio = {
      labels = [ "posix" ];
      description = "Audio device access";
      members = [ "workstation-access" ];
    };
    sound = {
      labels = [ "posix" ];
      description = "Sound device access";
      members = [ "workstation-access" ];
    };
    video = {
      labels = [ "posix" ];
      description = "Video device access";
      members = [ "workstation-access" ];
    };
    networkmanager = {
      labels = [ "posix" ];
      description = "NetworkManager control";
      members = [ "workstation-access" ];
    };
    input = {
      labels = [ "posix" ];
      description = "Input device access";
      members = [ "workstation-access" ];
    };
    tty = {
      labels = [ "posix" ];
      description = "TTY access";
      members = [ "workstation-access" ];
    };
    podman = {
      labels = [ "posix" ];
      description = "Container runtime access";
      members = [ "workstation-access" ];
    };
    media = {
      labels = [ "posix" ];
      description = "Media files access";
      members = [ "workstation-access" ];
    };
    gamemode = {
      labels = [ "posix" ];
      description = "GameMode access";
      members = [ "workstation-access" ];
    };
    render = {
      labels = [ "posix" ];
      description = "GPU render access";
      members = [ "workstation-access" ];
    };
    libvirtd = {
      labels = [ "posix" ];
      description = "VM management access";
      members = [ "admins" ];
    };
    kvm = {
      labels = [ "posix" ];
      description = "KVM hypervisor access";
      members = [ "admins" ];
    };
  };
}
