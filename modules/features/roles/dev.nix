{
  features.dev = {
    requires = [
      "adb"
      "direnv"
      "gpg"
      "bat"
      "claude"
      "eza"
      "nix-index"
      "nvf"
      "ssh"
      "starship"
      "sysmon"
      "yazi"

      # Shell tools (decomposed from misc-tools)
      "archive-tools"
      "search-tools"
      "data-tools"
      "disk-tools"
      "process-tools"
      "zoxide"

      # Git ecosystem
      "git"

      # Lang support
      "python"

      # Admin tools
      "k9s"
    ];
  };
}
