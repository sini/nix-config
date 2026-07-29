{ den, ... }:
{
  den.aspects.roles.dev-gui = {
    includes = with den.aspects; [
      applications.dev.editor.codium.antigravity
      applications.dev.editor.codium.vscode
      applications.dev.editor.codium.core
      applications.dev.lang.c
      applications.dev.lang.go
      applications.dev.lang.lua
      applications.dev.lang.markdown
      applications.dev.lang.nix
      applications.dev.lang.python
      applications.dev.lang.shell
      applications.dev.git.gitkraken
      applications.dev.networking.wireshark
      applications.dev.k8s.core
      applications.dev.k8s.dev
      applications.dev.k8s.helm
      applications.dev.k8s.observability
      applications.dev.k8s.plugins
      applications.dev.k8s.security
      applications.dev.k8s.tui
      applications.dev.k8s.utils
    ];
  };
}
