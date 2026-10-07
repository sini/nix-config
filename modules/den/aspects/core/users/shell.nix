{
  den.aspects.core.users.shell = {
    os = {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
      };
    };

    nixos =
      { pkgs, ... }:
      {
        # enableAllTerminfo builds contour, which fails on GCC 16 (nixpkgs#569719)
        environment.systemPackages = map (p: p.terminfo) [
          pkgs.alacritty
          pkgs.ghostty
          pkgs.kitty
        ];
        users.users.root.shell = pkgs.bashInteractive;
        users.defaultUserShell = pkgs.zsh;
      };
  };
}
