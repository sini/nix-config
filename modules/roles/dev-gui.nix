{
  flake.role.dev-gui = {
    nixosModules = [
      "gpg"
      "vscode"
    ];

    homeModules = [
      "gitkraken"
      "gpg"
      "wireshark"
      "kube-tools"
      "zellij"
    ];
  };
}
