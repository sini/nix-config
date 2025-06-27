{
  flake.modules.nixos.nixpkgs = {
    nixpkgs.config.allowUnfree = true;
  };
}
