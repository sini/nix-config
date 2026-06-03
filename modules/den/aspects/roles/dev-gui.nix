{ den, ... }:
{
  den.aspects.roles.dev-gui = {
    includes = with den.aspects; [
      apps.dev.security.gpg
      apps.dev.editor.vscode
      apps.dev.git.gitkraken
      apps.dev.networking.wireshark
      apps.dev.zellij
    ];
  };
}
