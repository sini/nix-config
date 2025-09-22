{
  flake.role.dev = {
    nixosModules = [
      "adb"
      "direnv"
      #"gpg"
    ];

    homeModules = [
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
