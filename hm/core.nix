{
  pkgs,
  ...
}:
{
  imports = [
    ./modules/vscode.nix
    ./modules/zsh.nix
  ];

  home.packages = with pkgs; [
    # Utilities
    ripgrep
    fd
    jq
  ];
}
