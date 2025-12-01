{
  flake.features.shell.nixos = {
    # TODO: re-enable after https://github.com/NixOS/nixpkgs/issues/465358
    environment.enableAllTerminfo = false;
  };
}
