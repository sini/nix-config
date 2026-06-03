{ den, ... }:
{
  den.aspects.roles.dev = {
    includes = with den.aspects; [
      hardware.adb
      apps.dev.ai.claude

      apps.shell.nix-index

      apps.dev.editor.nvf

      apps.dev.security.gpg
      apps.dev.security.ssh

      apps.dev.shell.bat
      apps.dev.shell.bottom
      apps.dev.shell.btop
      apps.dev.shell.direnv
      apps.dev.shell.eza
      apps.dev.shell.starship

      apps.shell.yazi
      apps.shell.archive
      apps.shell.data
      apps.shell.disk
      apps.shell.process
      apps.shell.search
      apps.shell.zoxide

      apps.dev.git
      apps.dev.git.delta
      apps.dev.git.github
      apps.dev.git.jujutsu
      apps.dev.git.lazygit
      apps.dev.git.mergiraf

      apps.dev.lang.go
      apps.dev.lang.rust
      apps.dev.lang.python
      apps.dev.lang.nix

      apps.dev.k8s.k9s
    ];
  };
}
