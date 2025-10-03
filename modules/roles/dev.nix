{
  flake.roles.dev = {
    features = [
      "adb"
      "direnv"
      #"gpg"
      #"bat"
      "claude"
      "eza"
      "misc-tools"
      "nvf"
      "git"
      "ssh"
      "yazi"
      #"zellij"

      # Admin tools
      "k9s"
    ];
  };
}
