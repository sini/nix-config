{
  flake.modules = {
    nixos.shell =
      { pkgs, ... }:
      {
        users.users.root.shell = pkgs.bashInteractive;
      };
  };
}
