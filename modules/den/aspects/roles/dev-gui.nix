{ den, ... }:
{
  den.aspects.roles.dev-gui = {
    colmena-tags = [ "dev-gui" ];
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
