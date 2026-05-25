{ den, ... }:
{
  den.aspects.roles.dev-gui = {
    colmena = [ "dev-gui" ];
    includes = with den.aspects; [
      apps.gpg
      apps.vscode
      apps.gitkraken
      apps.wireshark
      apps.kube-tools
      apps.zellij
    ];
  };
}
