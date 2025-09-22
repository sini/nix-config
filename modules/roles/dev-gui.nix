{
  flake.role.dev-gui = {
    nixosModules = [
      "gpg"
      "vscode"
    ];

    homeManagerModules = [
      "gitkraken"
      "gpg"
      "vscode"
      "wireshark"
      "kube-tools"
      "zellij"
    ];
  };
}
