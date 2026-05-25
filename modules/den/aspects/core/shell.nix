_: {
  den.aspects.core.shell = {
    os =
      { pkgs, ... }:
      {
        programs.zsh = {
          enable = true;
          enableCompletion = true;
        };

        users.users.root.shell = pkgs.bashInteractive;

        # TODO: revert to enableAllTerminfo = true once nixpkgs-unstable
        # drops termite from the list (already removed on master).
        environment.enableAllTerminfo = false;
        environment.systemPackages = map (x: x.terminfo) (
          with pkgs;
          [
            alacritty
            contour
            foot
            ghostty
            kitty
            mtm
            rio
            rxvt-unicode-unwrapped
            rxvt-unicode-unwrapped-emoji
            st
            tmux
            wezterm
            yaft
          ]
        );
      };

    nixos =
      { pkgs, ... }:
      {
        users.defaultUserShell = pkgs.zsh;
      };
  };
}
