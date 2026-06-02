{ den, ... }:
{
  den.aspects.roles.dev-gui = {
    colmena = [ "dev-gui" ];
    includes = with den.aspects; [
      apps.dev.gpg
      apps.dev.vscode
      apps.dev.gitkraken
      apps.dev.wireshark
      apps.dev.kube-tools
      apps.dev.zellij
    ];
  };
}
