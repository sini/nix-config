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
      apps.dev.nvf
      apps.dev.ssh
      apps.dev.starship
      apps.shell.sysmon
      apps.shell.yazi
      apps.shell.misc-tools
      apps.shell.zoxide
      apps.dev.git
      apps.shell.python
      apps.shell.k9s
    ];
  };
}
