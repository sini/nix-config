{ den, ... }:
{
  den.aspects.roles.dev-gui = {
    colmena = [ "dev-gui" ];
    includes = with den.aspects; [
      apps.dev.gpg
      apps.dev.vscode
      apps.dev.git.gitkraken
      apps.dev.wireshark
      roles.kube-tools
      apps.dev.zellij
    ];
  };
}
