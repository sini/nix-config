{
  flake.features.nixpkgs.system = {
    nixpkgs.config.allowUnfree = true;
  };
}
