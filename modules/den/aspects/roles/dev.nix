# Dev role: core development tools and shell utilities.
{ den, ... }:
{
  den.aspects.dev = {
    includes = [
      den.aspects.adb
      den.aspects.direnv
      den.aspects.gpg
      den.aspects.bat
      den.aspects.claude
      den.aspects.eza
      den.aspects.nix-index
      den.aspects.nvf
      den.aspects.ssh
      den.aspects.starship
      den.aspects.sysmon
      den.aspects.yazi

      # Shell tools
      den.aspects.archive-tools
      den.aspects.search-tools
      den.aspects.data-tools
      den.aspects.disk-tools
      den.aspects.process-tools
      den.aspects.zoxide

      # Git ecosystem
      den.aspects.git

      # Lang support
      den.aspects.python

      # Admin tools
      den.aspects.k9s
    ];
  };
}
