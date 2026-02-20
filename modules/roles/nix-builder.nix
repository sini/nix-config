{
  flake.roles.nix-builder = {
    features = [
      "nix-remote-build-server"
    ];
  };
}
