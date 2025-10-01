{
  writeShellApplication,
  gh,
  nix,
}:
writeShellApplication {
  name = "nix-flake-update";
  runtimeInputs = [
    gh
    nix
  ];
  text = ''
    # Check GitHub CLI auth status
    if ! gh auth status &>/dev/null; then
      echo "GitHub CLI not authenticated. Logging in..."
      gh auth login
    fi

    # Run flake update with the GitHub token
    nix flake update --option access-tokens "github.com=$(gh auth token)"
  '';
}
