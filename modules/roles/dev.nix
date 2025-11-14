{
  flake.roles.dev = {
    features = [
      "adb"
      "direnv"
      #"gpg"
      "bat"
      "claude"
      "eza"
      "misc-tools"
      "nvf"
      "git"
      "ssh"
      "sysmon"
      "yazi"
      #"zellij"

      # Admin tools
      "k9s"
    ];
  };
}
