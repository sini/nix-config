# Dev GUI role: graphical development tools.
{ den, ... }:
{
  den.aspects.dev-gui = {
    includes = [
      den.aspects.gpg
      den.aspects.vscode
      den.aspects.gitkraken
      den.aspects.wireshark
      den.aspects.kube-tools
      den.aspects.zellij
    ];
  };
}
