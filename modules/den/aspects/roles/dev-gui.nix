{ den, ... }:
{
  den.aspects.roles.dev-gui = {
    includes = with den.aspects; [
      apps.dev.editor.codium.antigravity
      apps.dev.editor.codium.vscode
      apps.dev.editor.codium.core
      apps.dev.lang.c
      apps.dev.lang.go
      apps.dev.lang.lua
      apps.dev.lang.markdown
      apps.dev.lang.nix
      apps.dev.lang.python
      apps.dev.lang.shell
      apps.dev.git.gitkraken
      apps.dev.networking.wireshark
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
