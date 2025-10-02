{
  flake.features.shell = {
    nixos =
      { pkgs, ... }:
      {
        users.users.root.shell = pkgs.bashInteractive;
      };
  };
}
