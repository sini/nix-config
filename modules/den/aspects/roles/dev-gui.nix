{ den, ... }:
{
  den.aspects.roles.dev-gui = {
    includes = with den.aspects; [
      apps.dev.security.gpg
      apps.dev.editor.vscode
      apps.dev.git.gitkraken
      apps.dev.networking.wireshark
      apps.dev.zellij
      apps.dev.k8s.core
      apps.dev.k8s.dev
      apps.dev.k8s.helm
      apps.dev.k8s.observability
      apps.dev.k8s.plugins
      apps.dev.k8s.security
      apps.dev.k8s.tui
      apps.dev.k8s.utils
    ];
  };
}
