{
  flake.role.dev-gui = {
    nixosModules = [
      "gpg"
      "vscode"
    ];

    homeManagerModules = [
      "gitkraken"
      "gpg"
      "wireshark"
      "kube-tools"
      "zellij"
    ];
  };
}
