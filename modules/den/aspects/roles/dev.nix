{ den, ... }:
{
  den.aspects.roles.dev = {
    includes = with den.aspects; [
      hardware.adb
      apps.direnv
      apps.gpg
      apps.bat
      apps.claude
      apps.eza
      apps.nix-index
      apps.nvf
      apps.ssh
      apps.starship
      apps.sysmon
      apps.yazi
      apps.misc-tools
      apps.zoxide
      apps.git
      apps.python
      apps.k9s
    ];
  };
}
