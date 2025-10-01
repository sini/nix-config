{
  flake.aspects.nixpkgs.nixos = {
    nixpkgs.config.allowUnfree = true;
  };
}
