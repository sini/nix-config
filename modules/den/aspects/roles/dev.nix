{ den, ... }:
{
  den.aspects.roles.dev = {
    colmena = [ "dev" ];
    includes = with den.aspects; [
      hardware.adb
      apps.dev.direnv
      apps.dev.gpg
      apps.dev.bat
      apps.dev.claude
      apps.dev.eza
      apps.shell.nix-index
      apps.dev.editor.nvf
      apps.dev.ssh
      apps.dev.starship
      apps.shell.btop
      apps.shell.bottom
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
      apps.dev.lang.python
      apps.dev.k8s.k9s
    ];
  };
}
