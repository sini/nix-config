{
  flake.role.dev = {
    nixosModules = [
      "adb"
      "direnv"
      #"gpg"
    ];

    homeManagerModules = [
      "bat"
      "claude"
      "direnv"
      "eza"
      "misc-tools"
      "nvf"
      "git"
      #"gpg"
      "ssh"
      "yazi"
      #"zellij"

      # Admin tools
      "k9s"
    ];
  };
}
