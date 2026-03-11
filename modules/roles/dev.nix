{
  flake.roles.dev = {
    features = [
      "adb"
      "direnv"
      "gpg"
      "bat"
      "claude"
      "eza"
      "misc-tools"
      "nix-index"
      "nvf"
      "git"
      "ssh"
      "sysmon"
      "yazi"

      # Lang support
      "python"

      #"zellij"

      # Admin tools
      "k9s"
    ];
  };
}
