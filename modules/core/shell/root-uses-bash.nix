{
  flake.modules =
    { pkgs, ... }:
    {
      nixos.shell = {
        users.users.root.shell = pkgs.bashInteractive;
      };
    };
}
