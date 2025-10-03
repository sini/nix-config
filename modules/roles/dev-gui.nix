{
  flake.roles.dev-gui = {
    features = [
      "gpg"
      "vscode"
      "gitkraken"
      "wireshark"
      "kube-tools"
      "zellij"
    ];
  };
}
