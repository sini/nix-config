{
  flake.features.shell = {
    system =
      { pkgs, ... }:
      {
        users.users.root.shell = pkgs.bashInteractive;
      };
  };
}
