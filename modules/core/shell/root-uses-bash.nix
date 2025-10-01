{
  flake.aspects.shell = {
    nixos =
      { pkgs, ... }:
      {
        users.users.root.shell = pkgs.bashInteractive;
      };
  };
}
